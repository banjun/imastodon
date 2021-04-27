import Cocoa
import NorthLayout
import Ikemen

final class InstanceAccountsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var accounts: [Store.IDAndInstanceAccount] {
        get {StoreFile.shared.store.instanceAccounts}
        set {StoreFile.shared.store.instanceAccounts = newValue}
    }
    private lazy var accountsView: VisibleLimitedTableView = .init() ※ { tv in
        tv.addTableColumn(accountsColumn)
        tv.dataSource = self
        tv.delegate = self
        tv.target = self
        if #available(OSX 11.0, *) {
            tv.style = .plain
        }
    }
    private lazy var accountsColumn: NSTableColumn = .init(identifier: .init("Account")) ※ { c in
        c.title = "\(StoreFile.shared.store.instanceAccounts.count) Accounts"
    }
    private lazy var addButton: NSButton = .init(title: "Add Mastodon Account...", target: self, action: #selector(addAccount))

    private lazy var homeTLButton: NSButton = .init(title: "Open Home Timeline", target: self, action: #selector(openHome))
    private lazy var localTLButton: NSButton = .init(title: "Open Local Timeline...", target: self, action: #selector(openLocal))
    private lazy var hashtagTLButton: NSButton = .init(title: "Open Hashtag...", target: self, action: #selector(openHashtag))
    private let hashtagField = NSTextField() ※ { tf in
        tf.placeholderString = "Hashtag"
    }

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 256),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: window)
        window.title = "Accounts"
        window.center()

        let view = window.contentView!
        let scrollView = NSScrollView()
        scrollView.documentView = accountsView

        let autolayout = view.northLayoutFormat(["p": 20], [
            "sv": scrollView,
            "add": addButton,
            "home": homeTLButton,
            "local": localTLButton,
            "hashtagName": hashtagField,
            "hashtagTL": hashtagTLButton])
        autolayout("H:|[sv]")
        autolayout("H:[sv]-p-[home]-p-|")
        autolayout("H:[sv]-p-[local(==home)]-p-|")
        autolayout("H:[sv]-(>=p)-[hashtagName(==hashtagTL)]-p-|")
        autolayout("H:[sv]-(>=p)-[hashtagTL]-p-|")
        autolayout("H:|-p-[add]-(>=p)-|")
        autolayout("V:|[sv]-p-[add]-p-|")
        autolayout("V:|-p-[home]-[local(==home)]-p-[hashtagName(==hashtagTL)]-[hashtagTL]-(>=p)-|")
    }

    required init?(coder: NSCoder) {fatalError()}

    func numberOfRows(in tableView: NSTableView) -> Int {
        return accounts.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let a = accounts[row].instanceAccount
        return "\(a.account.display_name) (@\(a.account.username)) at \(a.instance.title)"
    }

    @objc private func addAccount() {
        let wc = NewAccountWindowController()
        window?.beginSheet(wc.window!) { r in
            _ = wc // capture & release
            self.accountsView.reloadData()
        }
    }

    @objc private func openHome() {
        let row = accountsView.selectedRow
        guard case 0..<accounts.count = row else { return }
        let a = accounts[row]
        let sc = SharedStreamClients.shared.streamClient(a.instanceAccount)
        appDelegate.appendWindowControllerAndShowWindow(HomeTLWindowController(savedInstanceAccount: a, streamClient: sc))
    }

    @objc private func openLocal() {
        let row = accountsView.selectedRow
        guard case 0..<accounts.count = row else { return }
        let a = accounts[row]
        let sc = SharedStreamClients.shared.streamClient(a.instanceAccount)
        appDelegate.appendWindowControllerAndShowWindow(LocalTLWindowController(savedInstanceAccount: a, streamClient: sc))
    }

    @objc private func openHashtag() {
        let row = accountsView.selectedRow
        guard case 0..<accounts.count = row else { return }
        let hashtag = hashtagField.stringValue
        guard !hashtag.isEmpty else { return }
        let a = accounts[row].instanceAccount
        appDelegate.appendWindowControllerAndShowWindow(HashtagTLWindowController(instanceAccount: a, hashtag: hashtag))
    }
}

