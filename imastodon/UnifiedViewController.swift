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

        unifiedSignal = Signal.merge([
            localStream.updateSignal.map {($0, $0.status.map {.local($0, nil)})},
            userStream.updateSignal.map {($0, $0.status.map {.home($0, nil)})}])
        unifiedSignal?
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
            switch r {
            case let .success(n):
                // NSLog("%@", "notification: \(n.account), \(n.type), \(String(describing: n.status?.textContent))")
                let content = UNMutableNotificationContent()
                content.title = "\(n.account.display_name) \(n.type)"
                content.body = n.status?.textContent ?? "you"
                UNUserNotificationCenter.current()
                    .add(UNNotificationRequest(identifier: "notification \(n.id)", content: content, trigger: nil))
                self?.append([.notification(n, nil)])
            case let .failure(e): self?.append([.local(e.errorStatus, nil)])
            }
        }
    }

    private func fetch() {
        SVProgressHUD.show()
        let since = timelineEvents.flatMap {$0.status?.id}.first {$0 != "0"}
        client.local(since: since)
            .zip(client.home(since: since))
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { ls, hs in
                let events: [TimelineEvent] = ls.map {.local($0, nil)} + hs.map {.home($0, nil)}
                self.append(events.sorted {($0.status?.createdAt?.timeIntervalSinceReferenceDate ?? 0) > ($1.status?.createdAt?.timeIntervalSinceReferenceDate ?? 0)})
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

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // super.collectionView(collectionView, willDisplay: cell, forItemAt: indexPath)
        let e = timelineEvent(indexPath)
        switch e {
        case .home:
            cell.contentView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
            (cell as? StatusCollectionViewCell)?.showInnerShadow = true
        case .local:
            cell.contentView.backgroundColor = .white
            (cell as? StatusCollectionViewCell)?.showInnerShadow = false
        case .notification:
            cell.contentView.backgroundColor = UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1.0)
        }
    }
}

