import Foundation
import Eureka
import SVProgressHUD
import MastodonKit

class LoginViewController: FormViewController {
    var onNewInstance: ((InstanceAccout) -> Void)?

    private let hostRow = TextRow() {
        $0.title = "Host"
    }

    private let emailRow = EmailRow() {
        $0.title = "Email"
    }

    private let passwordRow = PasswordRow() {
        $0.title = "Password"
    }

    init() {
        super.init(style: .grouped)
        title = "Login"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(login))

        form +++ Section()
            <<< hostRow
            <<< emailRow
            <<< passwordRow
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func login() {
        guard let host = (hostRow.value.flatMap {URL(string: "https://" + $0)}),
            let email = emailRow.value,
            let password = passwordRow.value else { return }

        SVProgressHUD.show()
        let client = Client(baseURL: host.absoluteString)
        client.registerApp()
            .flatMap { app in
                client.login(app: app, email: email, password: password)
                    .map {(app, $0)}
            }
            .flatMap { app, loginSettings in
                client.currentInstance().zip(client.currentUser())
                    .map {(app, loginSettings, $0.0, $0.1)}
            }
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { app, loginSettings, instance, account in
                self.onNewInstance?(InstanceAccout(instance: instance, account: account, accessToken: loginSettings.accessToken))
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                self.present(ac, animated: true)
        }
    }
}
