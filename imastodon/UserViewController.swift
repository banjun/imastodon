import UIKit
import Eureka
import Ikemen
import Dwifft
import API

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

            currentUserSection = isCurrentUser ? [
                LabelRow {
                    $0.title = (account.map {String($0.following_count)} ?? "-") + " Followings"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self, let account = self.account else { return }
                        self.show(FollowingsViewController(client: self.client, subject: account), sender: nil)}
                },
                LabelRow {
                    $0.title = (account.map {String($0.followers_count)} ?? "-") + " Followers"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self, let account = self.account else { return }
                        self.show(FollowersViewController(client: self.client, subject: account), sender: nil)}
                },LabelRow {
                    $0.title = "⭐️ Favorites"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self else { return }
                        self.show(FavoritesViewController(client: self.client), sender: nil)}
                },LabelRow {
                    $0.title = "🔔 Notifications"
                    $0.cell.accessoryType = .disclosureIndicator
                    $0.onCellSelection {[weak self] _, _ in
                        guard let `self` = self else { return }
                        self.show(NotificationsViewController(client: self.client), sender: nil)}
                }] : nil

            updateHeaderHeight()
        }
    }
    var isCurrentUser: Bool {return currentUserSection != nil}
    private var currentUserSection: [BaseRow]? {didSet {applyDwifft()}}

    private let headerView: UserHeaderView
    private lazy var headerTop = headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0) ※ {$0.isActive = true}
    private lazy var headerHeight = headerView.heightAnchor.constraint(equalToConstant: 256) ※ {$0.isActive = true}
    private var headerViewMinHeight: CGFloat = 0
    private let timelineView: UITableView
    private var toots: [(Status, NSAttributedString?)] = [] {didSet {applyDwifft()}} // cache heavy attributed strings
    private lazy var tootsDiff: TableViewDiffCalculator<Int, String> = .init(tableView: self.timelineView)
    fileprivate func applyDwifft() {
        tootsDiff.sectionedValues = SectionedValues([
            currentUserSection.map {(0, $0.enumerated().map {"currentUserSection.\($0)"})},
            (1, toots.map {$0.0.id.value})]
            .compactMap {$0})
    }

    private lazy var previewingDelegate: StatusPreviewingDelegate = StatusPreviewingDelegate(vc: self, client: self.client, context: { [weak self] p in
        guard let indexPath = self?.timelineView.indexPathForRow(at: p),
            self?.currentUserSection == nil || indexPath.section != 0,
            let t = self?.toots[indexPath.row],
            let sourceRect = self?.timelineView.rectForRow(at: indexPath) else { return nil }
        return (t.0, t.1, sourceRect)
    })

    init(fetcher: Fetcher, isCurrentUser: Bool = false) {
        self.fetcher = fetcher
        self.currentUserSection = isCurrentUser ? [] : nil
        self.headerView = UserHeaderView()
        self.timelineView = UITableView(frame: .zero, style: .grouped)
        super.init(nibName: nil, bundle: nil)
    }

    convenience init?(_ instanceAccount: InstanceAccout) {
        guard let client = Client(instanceAccount) else { return nil }
        self.init(fetcher: .fetch(client: client, account: instanceAccount.account.id),
                  isCurrentUser: true)
    }

    override func loadView() {
        super.loadView()
        let autolayout = northLayoutFormat([:], ["header": headerView, "timeline": timelineView])
        autolayout("H:|[header]|")
        autolayout("H:|[timeline]|")
        autolayout("V:|[timeline]|")
        view.bringSubviewToFront(headerView)
        loadTimelineView()
        registerForPreviewing(with: previewingDelegate, sourceView: timelineView)

        switch fetcher {
        case let .fetch(client, id):
            updateHeaderHeight()
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

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: {_ in self.updateHeaderHeight(viewSize: size)})
    }

    private func updateHeaderHeight(viewSize: CGSize? = nil) {
        let constraints = [headerTop, headerHeight]
        constraints.forEach {$0.isActive = false}
        defer {constraints.forEach {$0.isActive = true}}
        headerViewMinHeight = headerView.systemLayoutSizeFitting(viewSize ?? view.frame.size, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height - headerView.safeAreaInsets.top
        timelineView.contentInset.top = headerViewMinHeight
        scrollViewDidScroll(timelineView)
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
        client.accountStatuses(accountID: id, includesPinnedStatuses: true).onSuccess {
            self.toots = $0.map {($0, $0.mainContentStatus.attributedTextContent)}
        }
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}
}

extension UserViewController: UITableViewDataSource, UITableViewDelegate {
    fileprivate func loadTimelineView() {
        timelineView.dataSource = self
        timelineView.delegate = self
        timelineView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusTableViewCell")
        applyDwifft()
        timelineView.insetsContentViewsToSafeArea = false

        timelineView.separatorStyle = .none
        timelineView.showsVerticalScrollIndicator = false
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let currentUserSection = currentUserSection, indexPath.section == 0 {
            return currentUserSection[indexPath.row].baseCell ※ {$0.update()}
        }
        let cell = timelineView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let status = toots[indexPath.row]
        cell.statusView.setStatus(status.0, attributedText: status.1, baseURL: client.baseURL)
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
                                   showAccount: {[unowned self] in self.show(UserViewController(fetcher: .account(client: self.client, account: s.mainContentStatus.account)), sender: nil)},
                                   boost: {[unowned self] in self.boost(s)},
                                   favorite: {[unowned self] in self.favorite(s)})
        ac.popoverPresentationController?.sourceView = tableView
        ac.popoverPresentationController?.permittedArrowDirections = .any
        if let cell = tableView.cellForRow(at: indexPath) as? StatusTableViewCell {
            ac.popoverPresentationController?.sourceRect = tableView.convert(cell.statusView.iconView.bounds, from: cell.statusView.iconView)
        }
        present(ac, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let extend = -scrollView.contentOffset.y - scrollView.adjustedContentInset.top
        headerTop.constant = min(0, extend) // allow scroll out from top bounds
        headerHeight.constant = headerViewMinHeight + headerView.safeAreaInsets.top + max(0, extend) // allow extend height while bouncing scrolling down
    }
}
