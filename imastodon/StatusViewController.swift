import UIKit
import Ikemen

final class StatusViewController: UITableViewController, ClientContainer {
    let client: Client
    let status: Status
    var context: Context? {
        didSet {tableView.reloadData()}
    }
    var form: [[Status]] {return [context?.ancestors, [status], context?.descendants].flatMap {$0}.filter {!$0.isEmpty}}

    init(client: Client, status: Status) {
        self.client = client
        self.status = status
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusTableViewCell")
        fetch()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    @objc func fetch() {
        client.run(GetStatusContext(baseURL: client.baseURL, pathVars: .init(id: status.id.value)))
            .onSuccess {
                switch $0 {
                case let .http200_(c): self.context = c
                }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return form.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return form[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let s = form[indexPath.section][indexPath.row]
        cell.statusView.setStatus(s, attributedText: nil, baseURL: client.baseURL) {[weak self] a in
            self?.present(AttachmentViewController(attachment: a), animated: true)}
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = form[indexPath.section][indexPath.row]
        let ac = UIAlertController(actionFor: s,
                                   safari: {[unowned self] in self.present($0, animated: true)},
                                   showAccount: {[unowned self] in _ = self.show(UserViewController(fetcher: .account(client: self.client, account: s.mainContentStatus.account)), sender: nil)},
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
