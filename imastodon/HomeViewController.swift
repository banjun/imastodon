import Foundation
import Eureka
import UserNotifications

class HomeViewController: TimelineViewController, ClientContainer {
    let instanceAccount: InstanceAccout
    private var userStream: Stream?
    let client: Client

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        self.client = Client(instanceAccount)!
        super.init(timelineEvents: [], baseURL: instanceAccount.instance.baseURL)
        title = "Home@\(instanceAccount.instance.title) \(instanceAccount.account.display_name)"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        userStream?.close()
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
        if userStream == nil {
            reconnectStream()
        }
    }

    private func reconnectStream() {
        userStream?.close()

        userStream = Stream(userTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        userStream?.updateSignal.observeResult { [weak self] r in
            DispatchQueue.main.async {
                switch r {
                case .success(.open): break //self?.refreshControl.endRefreshing()
                case let .success(.update(s)): self?.append([.home(s, nil)])
                case let .failure(e): self?.append([.home(e.errorStatus, nil)])
                }
            }
        }
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
                case let .failure(e): self?.append([.home(e.errorStatus, nil)])
                }
            }
        }
    }

    private func fetch() {
        showHUD()
        client.home()
            .onComplete {_ in self.dismissHUD()}
            .onSuccess { statuses in
                self.append(statuses.map {.home($0, nil)})
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    @objc private func showPost() {
        let vc = PostViewController(client: client)
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true)
    }
}
