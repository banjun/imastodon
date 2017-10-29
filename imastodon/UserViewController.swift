import UIKit
import Eureka
import Ikemen

final class UserViewController: UIViewController, ClientContainer {
    var client: Client {
        switch fetcher {
        case let .fetch(c, _), let .account(c, _): return c
        }
    }
    enum Fetcher {
        case fetch(client: Client, account: ID)
        case account(client: Client, account: Account)
    }
    let fetcher: Fetcher
    private var account: Account? {
        didSet {
            headerView.setAccount(account, baseURL: client.baseURL)

            if let currentUserSection = currentUserSection {
                currentUserSection.removeAll()
                currentUserSection.append(LabelRow {
                    $0.title = (account.map {String($0.following_count)} ?? "-") + " Followings"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self, let account = self.account else { return }
                        self.show(FollowingsViewController(client: self.client, subject: account), sender: nil)}
                })
                currentUserSection.append(LabelRow {
                    $0.title = (account.map {String($0.followers_count)} ?? "-") + " Followers"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self, let account = self.account else { return }
                        self.show(FollowersViewController(client: self.client, subject: account), sender: nil)}
                })
                currentUserSection.append(LabelRow {
                    $0.title = "⭐️ Favorites"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self else { return }
                        self.show(FavoritesViewController(client: self.client), sender: nil)}
                })
                currentUserSection.append(LabelRow {
                    $0.title = "🔔 Notifications"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self else { return }
                        self.show(NotificationsViewController(client: self.client), sender: nil)}
                })
                timelineView.reloadSections([0], with: .automatic)
            }

            timelineView.layoutTableHeaderView()
        }
    }
    var isCurrentUser: Bool {return currentUserSection != nil}
    private var currentUserSection: Section?

    private let headerView: UserHeaderView
    private let timelineView: UITableView
    private var toots: [(Status, NSAttributedString?)] = [] // cache heavy attributed strings

    init(fetcher: Fetcher, isCurrentUser: Bool = false) {
        self.fetcher = fetcher
        self.currentUserSection = isCurrentUser ? Section {
            $0.header = HeaderFooterView(title: " ")
            $0.footer = HeaderFooterView(title: " ")
            } : nil
        self.headerView = UserHeaderView()
        self.timelineView = UITableView(frame: .zero, style: .plain)
        super.init(nibName: nil, bundle: nil)
    }

    convenience init?(_ instanceAccount: InstanceAccout) {
        guard let client = Client(instanceAccount) else { return nil }
        self.init(fetcher: .fetch(client: client, account: instanceAccount.account.id),
                  isCurrentUser: true)
    }

    override func loadView() {
        view = timelineView
        loadTimelineView()

        switch fetcher {
        case let .fetch(client, id):
            fetchAccount(client: client, id: id)
            fetchAccountStatuses(client: client, id: id)
        case let .account(client, account):
            self.account = account
            fetchAccountStatuses(client: client, id: account.id)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        timelineView.layoutTableHeaderView()
    }

    private func fetchAccount(client: Client, id: ID) -> Void {
        client.run(GetAccount(baseURL: client.baseURL, pathVars: .init(id: id.value)))
            .onSuccess {
                switch $0 {
                case let .http200_(a):
                    UIView.animate(withDuration: 0.2) {
                        self.account = a
                        self.view.layoutIfNeeded()
                    }
                }
        }
    }

    private func fetchAccountStatuses(client: Client, id: ID) -> Void {
        client.run(GetAccountsStatuses(baseURL: client.baseURL,pathVars: .init(id: id.value, only_media: nil, exclude_replies: nil, max_id: nil, since_id: nil, limit: nil)))
            .onSuccess {
                switch $0 {
                case let .http200_(toots):
                    self.toots = toots.map {($0, $0.mainContentStatus.attributedTextContent)}
                    self.timelineView.reloadData()
                }
        }
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}
}

extension UserViewController: UITableViewDataSource, UITableViewDelegate {
    fileprivate func loadTimelineView() {
        timelineView.dataSource = self
        timelineView.delegate = self
        timelineView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusTableViewCell")

        timelineView.separatorStyle = .none
        timelineView.showsVerticalScrollIndicator = false
        timelineView.tableHeaderView = headerView
        timelineView.backgroundView = UILabel() ※ {
            $0.text = "Loading..."
            $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
            $0.textAlignment = .center
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return currentUserSection != nil ? 2 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let currentUserSection = currentUserSection, section == 0 { return currentUserSection.count }
        return toots.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let currentUserSection = currentUserSection, section == 0 { return currentUserSection.header?.title }
        return nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let currentUserSection = currentUserSection, section == 0 { return currentUserSection.footer?.title }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let currentUserSection = currentUserSection, indexPath.section == 0 {
            return currentUserSection[indexPath.row].baseCell ※ {$0.update()}
        }
        let cell = timelineView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let status = toots[indexPath.row]
        cell.statusView.setStatus(status.0, attributedText: status.1, baseURL: nil)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let currentUserSection = currentUserSection, indexPath.section == 0 {
            currentUserSection[indexPath.row].didSelect()
            return
        }
        let s = toots[indexPath.row].0
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

extension UITableView {
    func layoutTableHeaderView() {
        guard let v = tableHeaderView else { return }
        let h = v.systemLayoutSizeFitting(frame.size, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        guard h != v.frame.height else { return }
        v.frame.size.height = h
        tableHeaderView = v
    }
}

