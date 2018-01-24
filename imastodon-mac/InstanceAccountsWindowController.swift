import Cocoa
import NorthLayout
import Ikemen

final class InstanceAccountsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var accounts: [InstanceAccout] {
        get {return StoreFile.shared.store.instanceAccounts}
        set {StoreFile.shared.store.instanceAccounts = accounts}
    }
    private lazy var accountsView: NSTableView = .init() ※ { tv in
        tv.addTableColumn(accountsColumn)
        tv.dataSource = self
        tv.delegate = self
        tv.target = self
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
        let a = accounts[row]
        return "\(a.account.display_name) (@\(a.account.username)) at \(a.instance.title)"
    }

    @objc private func tableViewDidDoubleClick(_ sender: Any?) {
        appDelegate.appendWindowControllerAndShowWindow(LocalTLWindowController(instanceAccount: accounts[accountsView.clickedRow]))
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
        appDelegate.appendWindowControllerAndShowWindow(HomeTLWindowController(instanceAccount: accounts[row]))
    }

    @objc private func openLocal() {
        let row = accountsView.selectedRow
        guard case 0..<accounts.count = row else { return }
        appDelegate.appendWindowControllerAndShowWindow(LocalTLWindowController(instanceAccount: accounts[row]))
    }

    @objc private func openHashtag() {
        let row = accountsView.selectedRow
        guard case 0..<accounts.count = row else { return }
        let hashtag = hashtagField.stringValue
        guard !hashtag.isEmpty else { return }
        appDelegate.appendWindowControllerAndShowWindow(HashtagTLWindowController(instanceAccount: accounts[row], hashtag: hashtag))
    }
}

