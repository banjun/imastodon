import Foundation
import SVProgressHUD
import UserNotifications
import Kingfisher
import ReactiveSwift

class UnifiedViewController: TimelineViewController, ClientContainer {
    let instanceAccount: InstanceAccout
    var client: Client {return Client(instanceAccount)!}

    private var localStream: Stream?
    private var userStream: Stream?
    private var streams: [Stream] {return [localStream, userStream].flatMap {$0}}
    private var unifiedSignal: Signal<(Stream.Event, TimelineEvent?), AppError>?

    private let refreshControl = UIRefreshControl()

    init(instanceAccount: InstanceAccout, timelineEvents: [TimelineEvent] = []) {
        self.instanceAccount = instanceAccount
        super.init(timelineEvents: timelineEvents, baseURL: instanceAccount.instance.baseURL)
        title = "\(instanceAccount.instance.title) \(instanceAccount.account.displayNameOrUserName)"
        toolbarItems = [UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))]
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        streams.forEach {$0.close()}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        collectionView?.addSubview(refreshControl)
        collectionView?.alwaysBounceVertical = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if timelineEvents.isEmpty {
            fetch()
        }
        if localStream == nil || userStream == nil {
            reconnectStream()
        }
    }

    private func reconnectStream() {
        streams.forEach {$0.close()}

        let localStream = Stream(localTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        self.localStream = localStream
        let userStream = Stream(userTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        self.userStream = userStream

        var recents: [Status] = []
        unifiedSignal = Signal.merge([
            localStream.updateSignal.map {($0, $0.status.map {.local($0, nil)})},
            userStream.updateSignal.map {($0, $0.status.map {.home($0, nil)})}])
        unifiedSignal?
            .filter { (ev, tev) in
                guard let s = tev?.status else { return true }
                guard !(recents.contains {$0.id == s.id}) else { return false }
                recents.append(s)
                recents.removeFirst(max(0, recents.count - 20))
                return true
            }
            .observeResult { [weak self] r in
                switch r {
                case .success(.open, _): self?.refreshControl.endRefreshing()
                case let .success(.update, tev): _ = tev.map {self?.append([$0])}
                case let .failure(e):
                    self?.refreshControl.endRefreshing()
                    self?.append([.local(e.errorStatus, nil)])
                }
        }

        userStream.notificationSignal.observeResult { [weak self] r in
            DispatchQueue.main.async {
                switch r {
                case let .success(n):
                    // NSLog("%@", "notification: \(n.account), \(n.type), \(String(describing: n.status?.textContent))")
                    let content = UNMutableNotificationContent()
                    content.title = "\(n.account.display_name) \(n.type)"
                    content.body = n.status?.textContent ?? "you"
                    UNUserNotificationCenter.current()
                        .add(UNNotificationRequest(identifier: "notification \(n.id)", content: content, trigger: nil))
                case let .failure(e): self?.append([.local(e.errorStatus, nil)])
                }
            }
        }
    }

    private func fetch() {
        SVProgressHUD.show()
        client.local(since: timelineEvents.flatMap {$0.status?.id}.first {$0 > 0})
            .flatMap { ls in self.client.home().map {(ls, $0)}}
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { ls, hs in
                let events: [TimelineEvent] = ls.map {.local($0, nil)} + hs.map {.home($0, nil)}
                self.append(events
                    .filter {e in !self.timelineEvents.contains {$0.status == e.status}}
                    .sorted {($0.status?.id ?? 0) < ($1.status?.id ?? 0)})
                self.collectionView?.reloadData()
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    @objc private func refresh() {
        guard !(streams.contains {$0.source.readyState == .connecting}) else {
            refreshControl.endRefreshing()
            return
        }
        fetch()
        reconnectStream()
    }

    @objc private func showPost() {
        let vc = PostViewController(client: client)
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true)
    }
}

