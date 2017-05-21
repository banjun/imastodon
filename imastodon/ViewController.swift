import UIKit
import NorthLayout
import Ikemen
import MastodonKit

class ViewController: UIViewController {
    let client: Client

    init() {
        self.client = Client(baseURL: imastodonBaseURL)
        super.init(nibName: nil, bundle: nil)
        title = "iM@STODON"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "⚙️", style: .plain, target: self, action: #selector(showInstances))
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
    }

    @objc private func showInstances() {
        let vc = InstanceListViewController(instances: Store.shared.instanceAccounts)
        vc.onNewInstance = { instanceAccount in
            var store = Store.shared
            store.instanceAccounts.append(instanceAccount)
            store.writeToShared()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

//    @objc private func login() {
//        guard let id = idField.text, let pass = passwordField.text else { return }
//
//        let req = Login.silent(clientID: imastodon_banjun_app.clientID, clientSecret: imastodon_banjun_app.clientSecret, scopes: [.read, .write, .follow], username: id, password: pass)
//        client.run(req) { settings, error in
//            guard let token = settings?.accessToken else {
//                NSLog("%@", "failed to login: settings = \(String(describing: settings)), error = \(String(describing: error))")
//                return
//            }
//            self.client.accessToken = token
//
//            //// test
//
//            let req = Timelines.home()
//            self.client.run(req) { statuses, error in
//                guard let statuses = statuses else {
//                    NSLog("%@", "failed to fetch home timeline: error = \(String(describing: error))")
//                    return
//                }
//                DispatchQueue.main.async {
//                    let message = statuses.map { s in
//                        "\(s.account.username): \(s.content)"
//                        }.joined(separator: "\n")
//
//                    let ac = UIAlertController(title: "Home", message: message, preferredStyle: .alert)
//                    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//                    self.present(ac, animated: true)
//                }
//            }
//        }
//    }
}
