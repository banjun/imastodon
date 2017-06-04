import Foundation
import Eureka
import SVProgressHUD
import MastodonKit
import UserNotifications

class HomeViewController: TimelineViewController {
    let instanceAccount: InstanceAccout
    private var userStream: Stream?

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(statuses: [], baseURL: instanceAccount.instance.baseURL)
        title = "Home@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        toolbarItems = [UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))]
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        userStream?.close()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if statuses.isEmpty {
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
                case let .success(s): self?.append([s])
                case let .failure(e): self?.append([e.errorStatus])
                }
            }
        }
        userStream?.notificationSignal.observeResult { [weak self] r in
            DispatchQueue.main.async {
                switch r {
                case let .success(n):
                    // NSLog("%@", "notification: \(n.account), \(n.type), \(String(describing: n.status?.textContent))")
                    let content = UNMutableNotificationContent()
                    content.title = "\(n.account.displayName) \(n.type)"
                    content.body = n.status?.textContent ?? "you"
                    UNUserNotificationCenter.current()
                        .add(UNNotificationRequest(identifier: "notification \(n.id)", content: content, trigger: nil))
                case let .failure(e): self?.append([e.errorStatus])
                }
            }
        }
    }

    private func fetch() {
        SVProgressHUD.show()
        Client(instanceAccount).home()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.append(statuses)
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    private func didTap(status: Status, cell: BaseCell, row: BaseRow) {
        let ac = UIAlertController(actionFor: status,
                                   safari: {[unowned self] in self.show($0, sender: nil)},
                                   boost: {},
                                   favorite: {})
        present(ac, animated: true)
    }

    @objc private func showPost() {
        let vc = PostViewController(client: Client(instanceAccount))
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true)
    }
}
