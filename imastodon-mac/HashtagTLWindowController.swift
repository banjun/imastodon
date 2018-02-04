import Cocoa
import API
import ReactiveSSE
import ReactiveSwift
import Ikemen

final class HashtagTLWindowController: TimelineWindowController {
    init(instanceAccount: InstanceAccout, hashtag: String) {
        super.init(
            title: "#\(hashtag) @ \(instanceAccount.instance.title)",
            content: HashtagTLViewController(instanceAccount: instanceAccount, hashtag: hashtag))
    }
    required init?(coder: NSCoder) {fatalError()}
}

final class HashtagTLViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let instanceAccount: InstanceAccout
    private let viewModel = TimelineViewModel()
    private let hashtag: String
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

    init(instanceAccount: InstanceAccout, hashtag: String) {
        self.instanceAccount = instanceAccount
        self.hashtag = hashtag
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
        let tc = NSTableColumn() ※ {
            $0.identifier = NSUserInterfaceItemIdentifier(rawValue: "Status")
            $0.title = ""
        }
        timelineView.addTableColumn(tc)
        viewModel.filteredTimeline.combinePrevious([]).producer.startWithValues { [unowned self] in
            self.timelineView.animateRowAndSectionChanges(
                oldData: $0.map {$0.id.value},
                newData: $1.map {$0.id.value},
                rowDeletionAnimation: [], // fade cause memory issue (generates unreused cell views)
                rowInsertionAnimation: .slideDown)
        }

        let autolayout = view.northLayoutFormat([:], ["search": searchField, "sv": scrollView])
        autolayout("H:|[search]|")
        autolayout("H:|[sv(>=128)]|")
        autolayout("V:|[search][sv(>=128)]|")

        var req = URLRequest(url: URL(string: instanceAccount.instance.baseURL!.absoluteString + "/api/v1/streaming/hashtag/local?tag=\(hashtag.addingPercentEncoding(withAllowedCharacters: [])!)")!)
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
        let cellView = tableView.makeView(type: StatusTableCellView.self, identifier: tableColumn.identifier, owner: nil)
        cellView.setStatus(s, baseURL: instanceAccount.instance.baseURL!)
        return cellView
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
        postWindowController.setFooter(text: "#" + hashtag)
        view.window?.beginSheet(sheet)
    }
}
