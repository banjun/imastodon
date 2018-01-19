import Cocoa
import NorthLayout
import Ikemen
import Differ
import ReactiveSSE
import ReactiveSwift
import ReactiveCocoa
import Result

final class LocalTLWindowController: NSWindowController {
    init(instanceAccount: InstanceAccout) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 256, height: 512),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        super.init(window: window)
        window.contentViewController = LocalTLViewController(instanceAccount: instanceAccount)
        window.title = "LocalTL @ \(instanceAccount.instance.title)"
    }

    required init?(coder: NSCoder) {fatalError()}
}

final class TimelineViewModel {
    let timeline = MutableProperty<[Status]>([])
    let filterText = MutableProperty<String>("")
    var filterPredicate: Property<((Status) -> Bool)?> {return filterText.map { t in t.isEmpty ? nil
        : {$0.mainContentStatus.textContent.range(
            of: t,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current) != nil}
        }}
    private let backgroundQueue = QueueScheduler(name: "TimelineViewModel.background")
    private(set) lazy var filteredTimeline = Property<[Status]>(initial: timeline.value, then:
        filterPredicate.producer
            .debounce(0.1, on: backgroundQueue)
            .combineLatest(with: timeline)
            .throttle(0.1, on: backgroundQueue)
            // TODO: consider scan to apply filter only on inserted toots
            .map {filterPredicate, timeline in filterPredicate.map {timeline.filter($0)} ?? timeline}
            .observe(on: UIScheduler()))

    func insert(status: Status) {
        timeline.value = [status] + timeline.value.prefix(345)
    }
}

final class LocalTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let instanceAccount: InstanceAccout
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
    private let timelineView = NSTableView(frame: .zero)

    private lazy var postWindowController: PostWindowController = PostWindowController(instanceAccount: instanceAccount, visibility: .public)

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {fatalError()}

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        timelineView.dataSource = self
        timelineView.delegate = self
        timelineView.headerView = nil
        timelineView.target = self
        timelineView.doubleAction = #selector(tableViewDidDoubleClick)
        //        timelineView.usesAutomaticRowHeights = true
        let tc = NSTableColumn() ※ {
            $0.identifier = NSUserInterfaceItemIdentifier(rawValue: "Status")
            $0.title = ""
        }
        timelineView.addTableColumn(tc)
        timelineView.register(NSNib(nibNamed: NSNib.Name(rawValue: "StatusCellView"), bundle: nil), forIdentifier: tc.identifier)
        viewModel.filteredTimeline.combinePrevious([]).producer.startWithValues { [unowned self] in
            self.timelineView.animateRowAndSectionChanges(
                oldData: $0.map {$0.id.value},
                newData: $1.map {$0.id.value})
        }

        let autolayout = view.northLayoutFormat([:], ["search": searchField, "sv": scrollView])
        autolayout("H:|[search]|")
        autolayout("H:|[sv(>=128)]|")
        autolayout("V:|[search][sv(>=128)]|")

        var req = URLRequest(url: URL(string: instanceAccount.instance.baseURL!.absoluteString + "/api/v1/streaming/public/local")!)
        req.addValue("Bearer \(instanceAccount.accessToken)", forHTTPHeaderField: "Authorization")
        ReactiveSSE(urlRequest: req).producer
            .on(starting: {NSLog("%@", "starting ReactiveSSE for \(self.instanceAccount.instance.title)")},
                started: {NSLog("%@", "started ReactiveSSE for \(self.instanceAccount.instance.title)")},
                completed: {NSLog("%@", "completed ReactiveSSE for \(self.instanceAccount.instance.title)")},
                terminated: {NSLog("%@", "terminated ReactiveSSE for \(self.instanceAccount.instance.title)")})
            .filter {$0.type == "update"}
            .filterMap {$0.data.data(using: .utf8)}
            .filterMap {try? JSONDecoder().decode(Status.self, from: $0)}
            .observe(on: UIScheduler())
            .retry(upTo: 10, interval: 5, on: QueueScheduler.main)
            .startWithResult { [unowned self] r in
                switch r {
                case .success(let s):
                    // NSLog("%@", "\(s.textContent)")
                    self.viewModel.insert(status: s)
                case .failure(let e):
                    NSLog("%@", "\(e)")
                }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.initialFirstResponder = timelineView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        timelineView.noteHeightOfRows(withIndexesChanged: NSIndexSet(indexesIn: timelineView.rows(in: scrollView.contentView.bounds)) as IndexSet)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.filteredTimeline.value.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let s = viewModel.filteredTimeline.value[row]
        let cellView = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! StatusTableCellView
        cellView.setStatus(s, baseURL: instanceAccount.instance.baseURL!)
        return cellView
    }

    private lazy var layoutCell = StatusTableCellView() ※ {$0.awakeFromNib()}

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        layoutCell.setStatus(viewModel.filteredTimeline.value[row], baseURL: nil, widthConstraintConstant: scrollView.contentView.bounds.width)
        return layoutCell.fittingSize.height
    }

    @objc private func tableViewDidDoubleClick(_ sender: Any?) {
        let s = viewModel.filteredTimeline.value[timelineView.clickedRow]
        guard let url = ((s.mainContentStatus.url ?? s.url).flatMap {URL(string: $0)}) else { return }
        NSWorkspace.shared.open(url)
    }

    @IBAction func filter(_ sender: Any?) {
        view.window?.makeFirstResponder(searchField)
    }

    @IBAction func post(_ sender: Any?) {
        guard let sheet = postWindowController.window else { return }
        view.window?.beginSheet(sheet)
    }
}
