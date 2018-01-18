import Cocoa
import NorthLayout
import Ikemen
import Differ
import ReactiveSSE
import ReactiveSwift

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

final class LocalTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let instanceAccount: InstanceAccout
    private lazy var scrollView = NSScrollView() ※ { sv in
        sv.hasVerticalScroller = true
        sv.documentView = timelineView
    }
    private let timelineView = NSTableView(frame: .zero)
    private var timeline: [Status] = [] {
        didSet {
            timelineView.animateRowAndSectionChanges(
                oldData: oldValue.map {$0.id.value},
                newData: timeline.map {$0.id.value})
        }
    }

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

        let autolayout = view.northLayoutFormat([:], ["sv": scrollView])
        autolayout("H:|[sv(>=128)]|")
        autolayout("V:|[sv(>=128)]|")

        var req = URLRequest(url: URL(string: instanceAccount.instance.baseURL!.absoluteString + "/api/v1/streaming/public/local")!)
        req.addValue("Bearer \(instanceAccount.accessToken)", forHTTPHeaderField: "Authorization")
        ReactiveSSE(urlRequest: req).producer
            .filter {$0.type == "update"}
            .filterMap {$0.data.data(using: .utf8)}
            .filterMap {try? JSONDecoder().decode(Status.self, from: $0)}
            .observe(on: UIScheduler())
            .startWithResult { [unowned self] r in
                switch r {
                case .success(let s):
                    // NSLog("%@", "\(s.textContent)")
                    self.timeline.insert(s, at: 0)
                case .failure(let e):
                    NSLog("%@", "\(e)")
                }
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        timelineView.noteHeightOfRows(withIndexesChanged: NSIndexSet(indexesIn: timelineView.rows(in: scrollView.contentView.bounds)) as IndexSet)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return timeline.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let s = timeline[row]
        let cellView = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! StatusTableCellView
        cellView.setStatus(s, baseURL: instanceAccount.instance.baseURL!)
        return cellView
    }

    private lazy var layoutCell = StatusTableCellView() ※ {$0.awakeFromNib()}

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        layoutCell.setStatus(timeline[row], baseURL: nil, widthConstraintConstant: scrollView.contentView.bounds.width)
        return layoutCell.fittingSize.height
    }

    @objc private func tableViewDidDoubleClick(_ sender: Any?) {
        let s = timeline[timelineView.clickedRow]
        guard let url = ((s.mainContentStatus.url ?? s.url).flatMap {URL(string: $0)}) else { return }
        NSWorkspace.shared.open(url)
    }
}
