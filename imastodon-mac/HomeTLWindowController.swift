import Cocoa
import API
import ReactiveSSE
import ReactiveSwift
import Ikemen

final class HomeTLWindowController: TimelineWindowController {
    init(instanceAccount: InstanceAccout, streamClient: StreamClient) {
        super.init(
            title: "HomeTL @ \(instanceAccount.instance.title)",
            content: HomeTLViewController(instanceAccount: instanceAccount, streamClient: streamClient))
    }
    required init?(coder: NSCoder) {fatalError()}
}

final class HomeTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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

    private lazy var postWindowController: PostWindowController = PostWindowController(instanceAccount: instanceAccount, visibility: .unlisted)

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

        streamClient.homeToots(during: reactive.lifetime)
            .take(during: reactive.lifetime)
            .observe(on: UIScheduler())
            .observeValues {[unowned self] in self.viewModel.insert(status: $0)}
        streamClient.homeDeletedIDs(during: reactive.lifetime)
            .take(during: reactive.lifetime)
            .observe(on: UIScheduler())
            .observeValues {[unowned self] in self.viewModel.delete(id: $0)}
        streamClient.notifications(during: reactive.lifetime)
            .take(during: reactive.lifetime)
            .observe(on: UIScheduler())
            .observeValues { n in
                // TODO: post as user notification
                NSLog("%@", String(describing: n))
        }
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
