import Foundation
import SVProgressHUD
import UserNotifications
import Kingfisher

class LocalViewController: TimelineViewController, ClientContainer {
    let instanceAccount: InstanceAccout
    let client: Client
    
    private var localStream: Stream?
    private var userStream: Stream?
    private var streams: [Stream] {return [localStream, userStream].flatMap {$0}}
    
    private let refreshControl = UIRefreshControl()

    init(instanceAccount: InstanceAccout, timelineEvents: [TimelineEvent] = []) {
        self.instanceAccount = instanceAccount
        self.client = Client(instanceAccount)!
        super.init(timelineEvents: timelineEvents, baseURL: instanceAccount.instance.baseURL)
        title = "Local@\(instanceAccount.instance.title) \(instanceAccount.account.display_name)"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))
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
        navigationController?.setToolbarHidden(true, animated: animated)
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

        localStream = Stream(localTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        localStream?.updateSignal.observeResult { [weak self] r in
            DispatchQueue.main.async {
                switch r {
                case .success(.open): self?.refreshControl.endRefreshing()
                case let .success(.update(s)): self?.append([.local(s, nil)])
                case let .failure(e):
                    self?.refreshControl.endRefreshing()
                    self?.append([.local(e.errorStatus, nil)])
                }
            }
        }

        userStream = Stream(userTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        userStream?.notificationSignal.observeResult { [weak self] r in
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
        client.local(since: timelineEvents.flatMap {$0.status?.id}.first {$0 != "0"})
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.append(statuses.map {.local($0, nil)})
                self.collectionView?.reloadData()
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }
    
    @objc private func refresh() {
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
