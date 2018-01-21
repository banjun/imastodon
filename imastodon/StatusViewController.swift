import UIKit
import Ikemen
import Dwifft
import API

struct AttributedStatus: Equatable {
    var status: Status
    var attributedString: NSAttributedString?

    static func == (lhs: AttributedStatus, rhs: AttributedStatus) -> Bool {
        return lhs.status == rhs.status
    }
}

final class StatusViewController: UITableViewController, ClientContainer {
    let client: Client
    let attributedStatus: AttributedStatus
    var context: Context? {didSet {applyDwifft()}}
    private lazy var formDiff: TableViewDiffCalculator<String, AttributedStatus> = .init(tableView: self.tableView) ※ {$0.insertionAnimation = .middle}
    private func applyDwifft() {
        formDiff.sectionedValues = SectionedValues([
            context.map {("ancestors", $0.ancestors.map {.init(status: $0, attributedString: nil)})},
            ("status", [attributedStatus]),
            context.map {("descendants", $0.descendants.map {.init(status: $0, attributedString: nil)})}
            ].flatMap {$0}.filter {!$0.1.isEmpty})
    }

    override var previewActionItems: [UIPreviewActionItem] {
        let s = attributedStatus.status.mainContentStatus
        return [
            UIPreviewAction(title: "Show \(s.account.displayNameOrUserName)", style: .default) {[weak self] _, _ in
                guard let `self` = self else { return }
                // showing another view controller requires some tricks, after dismissing, show on parent
                DispatchQueue.main.async {
                    self.showUserVC(on: self.previewActionParentViewController, s)
                }},
            UIPreviewAction(title: "🔁", style: .default) {[unowned self] _, _ in self.boost(s)},
            UIPreviewAction(title: "⭐️", style: .default) {[unowned self] _, _ in self.favorite(s)}]
    }
    weak var previewActionParentViewController: UIViewController?

    init(client: Client, status: (Status, NSAttributedString?), previewActionParentViewController: UIViewController? = nil) {
        self.client = client
        self.attributedStatus = AttributedStatus(status: status.0, attributedString: status.1)
        self.previewActionParentViewController = previewActionParentViewController
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusTableViewCell")
        applyDwifft()
        tableView.insetsContentViewsToSafeArea = false
        fetch()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    @objc func fetch() {
        client.run(GetStatusContext(baseURL: client.baseURL, pathVars: .init(id: attributedStatus.status.mainContentStatus.id.value)))
            .onSuccess {
                switch $0 {
                case let .http200_(c): self.context = c
                }
        }
    }

    func showUserVC(on vc: UIViewController? = nil, _ status: Status) {
        (vc ?? self).show(UserViewController(fetcher: .account(client: self.client, account: status.mainContentStatus.account)), sender: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return formDiff.numberOfSections()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return formDiff.numberOfObjects(inSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let a = formDiff.value(atIndexPath: indexPath)
        // taking attributedText during initial phase of peek-pop cause flickering & flash bug. maybe NSAttributedString uses html parser that causes UI blocking operations. as a workaround, we take pre-fetched attributed text if any.
        cell.statusView.setStatus(a.status, attributedText: a.attributedString, baseURL: client.baseURL) {[weak self] a in
            self?.present(AttachmentViewController(attachment: a), animated: true)}
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = formDiff.value(atIndexPath: indexPath).status
        let ac = UIAlertController(actionFor: s,
                                   safari: {[unowned self] in self.present($0, animated: true)},
                                   showAccount: {[unowned self] in _ = self.showUserVC(s)},
                                   boost: {[unowned self] in self.boost(s)},
                                   favorite: {[unowned self] in self.favorite(s)})
        ac.popoverPresentationController?.sourceView = tableView
        ac.popoverPresentationController?.permittedArrowDirections = .any
        if let cell = tableView.cellForRow(at: indexPath) as? StatusTableViewCell {
            ac.popoverPresentationController?.sourceRect = tableView.convert(cell.statusView.iconView.bounds, from: cell.statusView.iconView)
        }
        present(ac, animated: true)
    }
}
