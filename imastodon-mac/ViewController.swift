import Cocoa
import ReactiveSwift
import ReactiveSSE
import NorthLayout
import Dwifft
import Ikemen
import Kingfisher

private let baseURL = "https://imastodon.net"
private let token = ""

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private lazy var scrollView = NSScrollView() ※ { sv in
        sv.hasVerticalScroller = true
        sv.documentView = timelineView
    }
    private let timelineView = NSTableView(frame: .zero)
    private lazy var timelineDiff: TableViewDiffCalculator<ID> = .init(tableView: self.timelineView)
    private var timeline: [Status] = [] {didSet {applyDwifft()}}
    private func applyDwifft() {
        timelineDiff.rows = timeline.map {$0.id}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        timelineView.dataSource = self
        timelineView.delegate = self
//        timelineView.usesAutomaticRowHeights = true
        let tc = NSTableColumn() ※ {
            $0.identifier = NSUserInterfaceItemIdentifier(rawValue: "Status")
        }
        timelineView.addTableColumn(tc)
        timelineView.register(NSNib(nibNamed: NSNib.Name(rawValue: "StatusCellView"), bundle: nil), forIdentifier: tc.identifier)
        applyDwifft()

        let autolayout = view.northLayoutFormat([:], ["sv": scrollView])
        autolayout("H:|[sv(>=128)]|")
        autolayout("V:|[sv(>=128)]|")

        var req = URLRequest(url: URL(string: baseURL + "/api/v1/streaming/public/local")!)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        ReactiveSSE(urlRequest: req).producer
            .filter {$0.type == "update"}
            .filterMap {$0.data.data(using: .utf8)}
            .filterMap {try? JSONDecoder().decode(Status.self, from: $0)}
            .observe(on: UIScheduler())
            .startWithResult { [unowned self] r in
                switch r {
                case .success(let s):
                    NSLog("%@", "\(s.textContent)")
                    self.timeline.insert(s, at: 0)
                case .failure(let e):
                    NSLog("%@", "\(e)")
                }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // fake data
        let a = Account(id: "0", username: "banjun", acct: "banjun", display_name: "ばんじゅん🍓", locked: false, created_at: "2018-01-15T13:27:36Z", followers_count: 42, following_count: 42, statuses_count: 42, note: "note", url: "url", avatar: "https://cdn.imastodon.net/accounts/avatars/000/000/026/original/869612d5adbf136f.png", avatar_static: "avatar_static", header: "header", header_static: "header_static")
        let ss = (0..<10).map {Status(id: ID(stringLiteral: "\($0)"), uri: "uri", url: "url", account: a, in_reply_to_id: nil, in_reply_to_account_id: nil, reblog: nil, content: "このステージにいると…お腹が空きますね…いえ、なんでもありません", created_at: "2018-01-15T13:27:36Z", reblogs_count: 0, favourites_count: 0, reblogged: nil, favourited: false, sensitive: false, spoiler_text: "", visibility: "public", media_attachments: [], mentions: [], tags: [], application: nil, language: nil, pinned: false)}
        timeline.append(contentsOf: ss)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        timelineView.noteHeightOfRows(withIndexesChanged: NSIndexSet(indexesIn: timelineView.rows(in: scrollView.contentView.bounds)) as IndexSet)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return timelineDiff.rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let s = timeline[row]
        let cellView = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! StatusTableCellView
        cellView.setStatus(s)
        return cellView
    }

    private lazy var layoutCell = StatusTableCellView() ※ {$0.awakeFromNib()}

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        layoutCell.setStatus(timeline[row], widthConstraintConstant: scrollView.contentView.bounds.width)
        return layoutCell.fittingSize.height
    }
}

final class AutoLayoutLabel: NSTextField {
    init() {
        super.init(frame: .zero)
        setupAutolayoutable()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAutolayoutable()
    }

    private func setupAutolayoutable() {
        // NOTE: preferredMaxLayoutWidth should be set as desired
        isEditable = false // makes multiline intrinsic content size work
        maximumNumberOfLines = 0 // multiline
    }
}

@objc class StatusTableCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameLabel = AutoLayoutLabel() ※ { l in
        l.textColor = .gray
        l.isBezeled = false
    }
    let bodyLabel = AutoLayoutLabel() ※ { l in
        l.textColor = .black
        l.isBezeled = false
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel])
        autolayout("H:|[icon(==32)]-[name]|")
        autolayout("H:|[body]|")
        autolayout("V:|[icon(==32)][body]|")
        autolayout("V:|[name][body]|")
    }

    func setStatus(_ status: Status, widthConstraintConstant: CGFloat? = nil) {
        _ = widthConstraintConstant.map {bodyLabel.preferredMaxLayoutWidth = $0}

        bodyLabel.stringValue = status.textContent
        nameLabel.stringValue = status.account.displayNameOrUserName
        if let avatarURL = status.account.avatarURL(baseURL: URL(string: baseURL)!) {
            iconView.kf.setImage(with: avatarURL)
        }
    }
}
