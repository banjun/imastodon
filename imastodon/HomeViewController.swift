import Foundation
import Eureka
import SVProgressHUD
import MastodonKit

class HomeViewController: TimelineViewController {
    let instanceAccount: InstanceAccout

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(statuses: [], baseURL: instanceAccount.instance.baseURL)
        title = "Home@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        toolbarItems = [UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))]
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if statuses.isEmpty {
            fetch()
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
