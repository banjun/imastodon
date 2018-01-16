import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var instanceAccountsWindowController: InstanceAccountsWindowController = .init()

    func applicationDidFinishLaunching(_ notification: AppKit.Notification) {
    }

    @IBAction func showPrefererences(_ sender: Any?) {
        showInstanceAccounts(sender)
    }

    @IBAction func showInstanceAccounts(_ sender: Any?) {
        instanceAccountsWindowController.showWindow(self)
    }
}
