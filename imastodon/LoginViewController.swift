import Foundation
import Eureka

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

        showHUD()
        var client = Client(baseURL: host, accessToken: nil, account: nil)
        client.registerApp()
            .flatMap { app in
                client.login(app: app, email: email, password: password).onSuccess {
                    client.accessToken = $0.access_token
                }
            }
            .flatMap { loginSettings in
                client.currentInstance().zip(client.currentUser())
                    .map {(loginSettings, $0.0, $0.1)}
            }
            .onComplete {_ in self.dismissHUD()}
            .onSuccess {
                let (loginSettings, instance, account) = $0
                self.onNewInstance?(InstanceAccout(instance: instance, account: account, accessToken: loginSettings.access_token))
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }
}
