import Foundation
import Eureka
import SVProgressHUD
import BrightFutures
import MastodonKit

enum AppError: Error {
    case mastodonKit(Error)
    case mastodonKitNullPo
}

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

extension Client {
    func registerApp() -> Future<MastodonKit.ClientApplication, AppError> {
        let promise = Promise<MastodonKit.ClientApplication, AppError>()
        run(Clients.register(
            clientName: "iM@STODON-banjun",
            scopes: [.read, .write, .follow],
            website: "https://imastodon.banjun.jp/")) { app, error in
                if let error = error {
                    promise.failure(.mastodonKit(error))
                    return
                }
                guard let app = app else {
                    promise.failure(.mastodonKitNullPo)
                    return
                }

                print("id: \(app.id)")
                print("redirect uri: \(app.redirectURI)")
                print("client id: \(app.clientID)")
                print("client secret: \(app.clientSecret)")

                promise.success(app)
        }
        return promise.future
    }

    func login(app: MastodonKit.ClientApplication, email: String, password: String) -> Future<LoginSettings, AppError> {
        let promise = Promise<LoginSettings, AppError>()
        run(Login.silent(
            clientID: app.clientID,
            clientSecret: app.clientSecret,
            scopes: [.read, .write, .follow],
            username: email,
            password: password)) { settings, error in
                if let error = error {
                    promise.failure(.mastodonKit(error))
                    return
                }
                guard let settings = settings else {
                    promise.failure(.mastodonKitNullPo)
                    return
                }

                // update token on self
                self.accessToken = settings.accessToken
                promise.success(settings)
        }
        return promise.future
    }

    func currentUser() -> Future<Account, AppError> {
        let promise = Promise<Account, AppError>()
        run(Accounts.currentUser()) { account, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let account = account else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(Account(account))
        }
        return promise.future
    }

    func currentInstance() -> Future<Instance, AppError> {
        let promise = Promise<Instance, AppError>()
        run(Instances.current()) { instance, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let instance = instance else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(Instance(instance))
        }
        return promise.future
    }
}
