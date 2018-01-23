import Cocoa
import API

class TimelineWindowController: NSWindowController {
    init(title: String, content: NSViewController) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 256, height: 512),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: window)
        window.contentViewController = content
        window.title = title
        window.tabbingIdentifier = .init("TimelineWindowController")
        NotificationCenter.default.reactive.notifications(forName: NSWindow.willCloseNotification, object: window)
            .take(duringLifetimeOf: self)
            .observeValues {[unowned self] _ in appDelegate.removeWindowController(self)}
    }
    required init?(coder: NSCoder) {fatalError()}
    deinit {NSLog("%@", "deinit \(self)")}
}
