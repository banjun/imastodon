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
    private let timelineView = NSTableView(frame: .zero)
    private lazy var timelineDiff: TableViewDiffCalculator<ID> = .init(tableView: self.timelineView)
    private var timeline: [Status] = [] {didSet {applyDwifft()}}
    private func applyDwifft() {
        timelineDiff.rows = timeline.map {$0.id}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false

        timelineView.dataSource = self
        timelineView.delegate = self
        timelineView.usesAutomaticRowHeights = true
        let tc = NSTableColumn() ※ {
            $0.identifier = NSUserInterfaceItemIdentifier(rawValue: "Status")
            $0.maxWidth = 1024
        }
        timelineView.addTableColumn(tc)
        timelineView.register(NSNib(nibNamed: NSNib.Name(rawValue: "StatusCellView"), bundle: nil), forIdentifier: tc.identifier)
        applyDwifft()

        let autolayout = view.northLayoutFormat([:], ["timeline": timelineView])
        autolayout("H:|[timeline(>=128)]|")
        autolayout("V:|[timeline(>=512,<=1024)]|")

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

    override func viewDidLayout() {
        super.viewDidLayout()
        timelineView.tableColumns.first?.width = timelineView.frame.width
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return timelineDiff.rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let s = timeline[row]
        let cellView = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! StatusTableCellView
        cellView.bodyLabel.stringValue = s.textContent
        cellView.nameLabel.stringValue = s.account.displayNameOrUserName
        if let avatarURL = s.account.avatarURL(baseURL: URL(string: baseURL)!) {
            cellView.iconView.kf.setImage(with: avatarURL)
        }
        return cellView
    }

//    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
//        let s = timeline[row]
//        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Status"), owner: self) as! StatusTableCellView
//        cellView.bodyLabel.stringValue = s.textContent
//        cellView.layoutSubtreeIfNeeded()
//        return cellView.frame.height
//    }
}

@objc class StatusTableCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameLabel = NSTextField() ※ { l in
        l.maximumNumberOfLines = 1
        l.textColor = .gray
        l.isBezeled = false
    }
    let bodyLabel = NSTextField() ※ { l in
        l.maximumNumberOfLines = 0
        l.textColor = .black
        l.isBezeled = false
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        bodyLabel.textColor = .black

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel])
        autolayout("H:|[icon(==32)]-[name]|")
        autolayout("H:|[body]|")
        autolayout("V:|[icon(==32)][body]|")
        autolayout("V:|[name][body]|")
    }
}
