import Cocoa
import NorthLayout
import Ikemen
import Differ
import ReactiveSSE
import ReactiveSwift
import ReactiveCocoa
import API

final class LocalTLWindowController: TimelineWindowController, NSWindowRestoration, NSWindowDelegate {
    init(savedInstanceAccount: Store.IDAndInstanceAccount, streamClient: StreamClient) {
        super.init(
            title: "LocalTL @ \(savedInstanceAccount.instanceAccount.instance.title)",
            content: LocalTLViewController(instanceAccount: savedInstanceAccount.instanceAccount, streamClient: streamClient))
        let uuid = UUID()
        window?.isRestorable = true
        window?.identifier = NSUserInterfaceItemIdentifier(rawValue: uuid.uuidString)
        window?.restorationClass = type(of: self)
        StoreFile.shared.store.windowState[uuid] = try? JSONEncoder().encode(Restoration(savedInstanceAccountUUID: savedInstanceAccount.uuid))
    }
    required init?(coder: NSCoder) {fatalError()}

    struct Restoration: Codable {
        let savedInstanceAccountUUID: UUID
    }

    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        guard let uuid = UUID(uuidString: identifier.rawValue),
            let data = StoreFile.shared.store.windowState[uuid] as Data?,
            let savedInstanceAccountUUID = try? JSONDecoder().decode(Restoration.self, from: data).savedInstanceAccountUUID,
            let savedInstanceAccount = (StoreFile.shared.store.instanceAccounts.first {$0.uuid == savedInstanceAccountUUID}) else { return completionHandler(nil, nil) }
        let wc = self.init(savedInstanceAccount: savedInstanceAccount,
                           streamClient: SharedStreamClients.shared.streamClient(savedInstanceAccount.instanceAccount))
        completionHandler(wc.window, nil)
        appDelegate.appendWindowControllerAndShowWindow(wc)
    }
}

final class LocalTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let instanceAccount: InstanceAccout
    private let client: Client?
    private let streamClient: StreamClient
    private let viewModel = TimelineViewModel()
    private lazy var scrollView = NSScrollView() ※ { sv in
        sv.hasVerticalScroller = true
        sv.documentView = timelineView
    }
    private lazy var searchField: NSSearchField = .init() ※ { sf in
        sf.placeholderString = "Filter"
        viewModel.filterText <~ sf.reactive.continuousStringValues
        sf.nextKeyView = timelineView
    }
    private let timelineView: VisibleLimitedTableView = .init(frame: .zero)

    private lazy var postWindowController: PostWindowController = PostWindowController(instanceAccount: instanceAccount, visibility: .public)

    init(instanceAccount: InstanceAccout, streamClient: StreamClient) {
        self.instanceAccount = instanceAccount
        self.client = Client(instanceAccount)
        self.streamClient = streamClient
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {fatalError()}
    deinit {NSLog("%@", "deinit \(self)")}

    override func loadView() {
        view = NSView()
        scrollView.wantsLayer = true

        timelineView.dataSource = self
        timelineView.delegate = self
        timelineView.headerView = nil
        timelineView.target = self
        timelineView.doubleAction = #selector(tableViewDidDoubleClick)
        timelineView.usesAutomaticRowHeights = true
        timelineView.intercellSpacing = .zero
        let tc = NSTableColumn() ※ {
            $0.identifier = NSUserInterfaceItemIdentifier(rawValue: "Status")
            $0.title = ""
        }
        timelineView.addTableColumn(tc)
        viewModel.filteredTimeline.combinePrevious([]).producer.take(duringLifetimeOf: self).startWithValues { [unowned self] in
            self.timelineView.animateRowAndSectionChanges(
                oldData: $0.map {TimelineStatus(status: $0)},
                newData: $1.map {TimelineStatus(status: $0)},
                rowDeletionAnimation: [], // fade cause memory issue (generates unreused cell views)
                rowInsertionAnimation: .slideDown) // TODO: appropriate animation for just reloaded cells
        }

        let autolayout = view.northLayoutFormat([:], ["search": searchField, "sv": scrollView])
        autolayout("H:|[search]|")
        autolayout("H:|[sv(>=128)]|")
        autolayout("V:|[search][sv(>=128)]|")

        client?.local().onSuccess {self.viewModel.insert(statuses: $0)}
        streamClient.localToots(during: reactive.lifetime)
            .take(during: reactive.lifetime)
            .observe(on: UIScheduler())
            .observeValues {[unowned self] in self.viewModel.insert(statuses: [$0])}
        streamClient.localDeletedIDs(during: reactive.lifetime)
            .take(during: reactive.lifetime)
            .observe(on: UIScheduler())
            .observeValues {[unowned self] in self.viewModel.delete(id: $0)}
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.initialFirstResponder = timelineView
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.filteredTimeline.value.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let s = viewModel.filteredTimeline.value[row]
        let cellView = tableView.makeView(type: StatusTableCellView.self, identifier: tableColumn.identifier, owner: self)
        cellView.setStatus(s, baseURL: instanceAccount.instance.baseURL!)
        return cellView
    }

    @objc private func tableViewDidDoubleClick(_ sender: Any?) {
        let s = viewModel.filteredTimeline.value[timelineView.clickedRow]
        guard let url = ((s.mainContentStatus.url ?? s.url).flatMap {URL(string: $0)}) else { return }
        NSWorkspace.shared.open(url)
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        switch edge {
        case .leading:
            return []
        case .trailing:
            let s = viewModel.filteredTimeline.value[row]
            let client = self.client
            let window = self.view.window
            return [
                NSTableViewRowAction(style: .regular, title: s.favourited == true ? "★" : "☆") { [weak viewModel] _, _ in
                    guard let viewModel = viewModel, let client = client, let window = window else { return }
                    viewModel.toggleFavorite(status: s, client: client)
                        .onFailure {NSAlert(error: $0).beginSheetModal(for: window)}
                    tableView.rowActionsVisible = false
                }]
        @unknown default:
            return []
        }
    }

    @IBAction func filter(_ sender: Any?) {
        view.window?.makeFirstResponder(searchField)
    }

    @IBAction func post(_ sender: Any?) {
        guard let sheet = postWindowController.window else { return }
        view.window?.beginSheet(sheet)
    }
}
