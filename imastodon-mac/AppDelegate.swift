import Cocoa
import Kingfisher

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

    func removeWindowController(_ wc: NSWindowController) {
        windowControllers = windowControllers.filter {$0 != wc}
    }

    func applicationWillResignActive(_ notification: Notification) {
        ImageCache.default.cleanExpiredDiskCache()

        StoreFile.shared.store.cleanNotUsedUUIDs(
            usedUUIDs: windowControllers
                .compactMap {$0.window?.identifier}
                .compactMap {UUID(uuidString: $0.rawValue)})
    }
}
