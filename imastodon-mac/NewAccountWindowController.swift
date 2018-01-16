import Cocoa
import NorthLayout
import Ikemen
import BrightFutures

final class NewAccountWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let urlField = NSTextField() ※ { tf in
        tf.placeholderString = "https://imastodon.net"
    }
    private let emailField = NSTextField() ※ { tf in
        tf.placeholderString = "Email"
    }
    private let passwordField = NSSecureTextField() ※ { tf in
        tf.placeholderString = "Password"
    }
    private lazy var cancelButton: NSButton = .init(title: "Cancel", target: self, action: #selector(cancel)) ※ { b in
        b.keyEquivalent = "\u{1b}" // ESC
    }
    private lazy var loginButton: NSButton = .init(title: "Login", target: self, action: #selector(login)) ※ { b in
        b.keyEquivalent = "\r"
    }

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 256, height: 192),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: window)
        window.title = "Login"

        let view = window.contentView!
        let autolayout = view.northLayoutFormat(["p": 20], [
            "url": urlField,
            "email": emailField,
            "password": passwordField,
            "cancel": cancelButton,
            "login": loginButton])
        autolayout("H:|-p-[url]-p-|")
        autolayout("H:|-p-[email]-p-|")
        autolayout("H:|-p-[password]-p-|")
        autolayout("H:|-p-[cancel]-(>=p)-[login(==cancel)]-p-|")
        autolayout("V:|-p-[url]-[email]-[password]-p-[login]-p-|")
        autolayout("V:[password]-p-[cancel]-p-|")
    }

    required init?(coder: NSCoder) {fatalError()}

    @objc func cancel() {
        window!.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
    }
    @objc func login() {
        let window = self.window!
        let email = emailField.stringValue
        let password = passwordField.stringValue
        guard let host = URL(string: urlField.stringValue),
            !email.isEmpty,
            !password.isEmpty else { __NSBeep(); return }

        var client = Client(baseURL: host, accessToken: nil, account: nil)
        loginButton.isEnabled = false
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
            .onComplete {_ in self.loginButton.isEnabled = true}
            .onSuccess {
                let (loginSettings, instance, account) = $0
                StoreFile.shared.store.instanceAccounts.append(
                    InstanceAccout(instance: instance, account: account, accessToken: loginSettings.access_token))
                window.sheetParent?.endSheet(window, returnCode: NSApplication.ModalResponse.OK)
            }.onFailure { e in
                NSAlert(error: e).beginSheetModal(for: window)
        }
    }
}
