import Cocoa
import NorthLayout
import Ikemen
import BrightFutures
import Kingfisher
import API
import ReactiveSwift
import ReactiveCocoa

final class PostWindowController: NSWindowController, NSTextViewDelegate {
    let instanceAccount: InstanceAccout
    private let visibility: MutableProperty<Visibility>
    private let defaultVisibility: Visibility?

    private lazy var iconView: IconView = IconView() ※ { iv in
        guard let baseURL = instanceAccount.instance.baseURL,
            let avatarURL = instanceAccount.account.avatarURL(baseURL: baseURL) else { return }
        iv.kf.setImage(with: avatarURL)
    }
    private lazy var nameLabel = AutolayoutLabel() ※ { l in
        l.stringValue = instanceAccount.account.displayNameOrUserName
        l.isBezeled = false
        l.drawsBackground = false
    }
    private lazy var scrollView: NSScrollView = .init() ※ { sv in
        sv.documentView = tootView
        sv.hasVerticalScroller = true
    }
    private let tootView = NSTextView() ※ { tv in
        tv.font = .systemFont(ofSize: 15)
        tv.autoresizingMask = [.width] // fit to scrollView width
        tv.isEditable = true
        tv.isRichText = false
    }
    private lazy var cancelButton: NSButton = .init(title: "Cancel", target: self, action: #selector(cancel)) ※ { b in
        b.keyEquivalent = "\u{1b}" // ESC
    }
    private lazy var postButton: NSButton = .init(title: "Toot", target: self, action: #selector(post)) ※ { b in
         b.keyEquivalent = "\r" // does not trigger when tootView is focused. safe enough not to post by mistake.
    }
    private let visibilities: [Visibility] = [.public, .unlisted, .private, .direct]
    private lazy var visibilityPopup: NSPopUpButton = .init(frame: .zero, pullsDown: false) ※ {
        $0.addItems(withTitles: visibilities.map {$0.displayName})
        visibility <~ $0.reactive.selectedIndexes.map {[unowned self] in self.visibilities[$0]}
        $0.reactive.selectedIndex <~ visibility.map {[unowned self] in self.visibilities.index(of: $0)}
    }

    init(instanceAccount: InstanceAccout, visibility: Visibility?) {
        self.instanceAccount = instanceAccount
        self.visibility = .init(visibility ?? .public)
        self.defaultVisibility = visibility
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 192),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: window)
        window.title = "Toot"

        let scrollView = NSScrollView()
        scrollView.documentView = tootView
        scrollView.hasVerticalScroller = true

        let view = window.contentView!
        let autolayout = view.northLayoutFormat(["p": 20], [
            "icon": iconView,
            "name": nameLabel,
            "text": scrollView,
            "cancel": cancelButton,
            "post": postButton,
            "visibility": visibilityPopup])
        autolayout("H:|-p-[icon(==48)]-[name]-p-|")
        autolayout("H:|-p-[text]-p-|")
        autolayout("H:|-p-[cancel]-(>=p)-[visibility]-p-[post(==cancel)]-p-|")
        autolayout("V:|-p-[icon(==48)]-[text(>=64)]-p-[cancel]-p-|")
        autolayout("V:|-p-[name]-(>=8)-[text]-p-[post]-p-|")
        autolayout("V:[text]-p-[visibility]-p-|")

        tootView.delegate = self

        NotificationCenter.default.reactive.notifications(forName: NSWindow.didBecomeKeyNotification, object: window)
            .take(duringLifetimeOf: self)
            .observeValues {[unowned self] _ in self.window?.makeFirstResponder(self.tootView)}
    }

    required init?(coder: NSCoder) {fatalError()}

    @objc func cancel() {
        window!.sheetParent?.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
    }
    @objc func post() {
        guard let client = Client(instanceAccount) else { return }
        let window = self.window!
        let text = tootView.string

        postButton.isEnabled = false
        client.post(message: text, visibility: visibility.value)
            .onComplete {_ in self.postButton.isEnabled = true}
            .onSuccess { _ in
                self.tootView.string = ""
                _ = self.defaultVisibility.map {self.visibility.value = $0}
                window.sheetParent?.endSheet(window, returnCode: .OK)
            }
            .onFailure {NSAlert(error: $0).beginSheetModal(for: window)}
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(insertTab(_:)):
            window?.selectNextKeyView(nil)
            return true
        default:
            return false
        }
    }
}
