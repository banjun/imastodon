import Cocoa
import API
import ReactiveSSE
import ReactiveSwift
import Ikemen

final class HomeTLWindowController: TimelineWindowController {
    init(instanceAccount: InstanceAccout) {
        super.init(
            title: "HomeTL @ \(instanceAccount.instance.title)",
            content: HomeTLViewController(instanceAccount: instanceAccount))
    }
    required init?(coder: NSCoder) {fatalError()}
}

final class HomeTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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

    private lazy var postWindowController: PostWindowController = PostWindowController(instanceAccount: instanceAccount, visibility: .unlisted)

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {fatalError()}
    deinit {NSLog("%@", "deinit \(self)")}

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

        var req = URLRequest(url: URL(string: instanceAccount.instance.baseURL!.absoluteString + "/api/v1/streaming/user")!)
        req.addValue("Bearer \(instanceAccount.accessToken)", forHTTPHeaderField: "Authorization")
        ReactiveSSE(urlRequest: req).producer
            .logEvents(identifier: instanceAccount.instance.title,
                       events: [.starting, .started, .completed, .interrupted, .terminated, .disposed], logger: timestampEventLog)
            .retry(throttling: 10)
            .take(duringLifetimeOf: self)
            .startWithSignal { signal, disposable in
                signal.filter {$0.type == "update"}
                    .filterMap {$0.data.data(using: .utf8)}
                    .filterMap {try? JSONDecoder().decode(Status.self, from: $0)}
                    .observe(on: UIScheduler())
                    .observeResult { [unowned self] r in
                        switch r {
                        case .success(let s):
                            // NSLog("%@", "\(s.textContent)")
                            self.viewModel.insert(status: s)
                        case .failure(let e):
                            NSLog("%@", "\(e)")
                        }
                }
                signal.filter {$0.type == "delete"}
                    .map {ID(stringLiteral: $0.data)}
                    .observe(on: UIScheduler())
                    .observeResult { [unowned self] r in
                        switch r {
                        case .success(let id):
                            self.viewModel.delete(id: id)
                        case .failure: break
                        }
                }
                signal.filter {$0.type == "notification"}
                    .filterMap {$0.data.data(using: .utf8)}
                    .filterMap {try? JSONDecoder().decode(Notification.self, from: $0)}
                    .observe(on: UIScheduler())
                    .observeResult { [unowned self] r in
                        switch r {
                        case .success(let n):
                            // TODO: post as user notification
                            NSLog("%@", String(describing: n))
                        case .failure(let e):
                            NSLog("%@", "\(e)")
                        }
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
