import Cocoa

let appDelegate = NSApp.delegate as! AppDelegate

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var instanceAccountsWindowController: InstanceAccountsWindowController = .init()
    var windowControllers: [NSWindowController] = []

    func applicationDidFinishLaunching(_ notification: AppKit.Notification) {
    }

    @IBAction func showPrefererences(_ sender: Any?) {
        showInstanceAccounts(sender)
    }

    @IBAction func showInstanceAccounts(_ sender: Any?) {
        instanceAccountsWindowController.showWindow(self)
    }

    func appendWindowControllerAndShowWindow(_ wc: NSWindowController) {
        windowControllers.append(wc)
        wc.showWindow(self)
    }
}
