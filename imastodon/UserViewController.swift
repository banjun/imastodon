import UIKit
import Ikemen
import NorthLayout
import Kingfisher

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

    private let headerView: UserHeaderView
    private let timelineView: UITableView
    private var toots: [(Status, NSAttributedString?)] = [] // cache heavy attributed strings

    init(fetcher: Fetcher) {
        self.fetcher = fetcher
        self.headerView = UserHeaderView()
        self.timelineView = UITableView(frame: .zero, style: .plain)
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = timelineView
        loadTimelineView()

        switch fetcher {
        case let .fetch(client, id):
            fetchAccount(client: client, id: id)
            fetchAccountStatuses(client: client, id: id)
        case let .account(client, account):
            setAccount(client.baseURL, account)
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

    private func setAccount(_ baseURL: URL, _ account: Account) {
        _ = URL(string: account.header).map {headerView.imageView.imageView.kf.setImage(with: $0)}
        _ = account.avatarURL(baseURL: baseURL).map {headerView.iconView.kf.setImageWithStub($0)}
        headerView.displayNameLabel.text = account.display_name
        headerView.usernameLabel.text = "@" + account.acct
        headerView.bioLabel.attributedText = account.note.data(using: .utf8).flatMap {try? NSAttributedString(data: $0, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)}
        timelineView.layoutTableHeaderView()
    }

    private func fetchAccount(client: Client, id: ID) -> Void {
        client.run(GetAccount(baseURL: client.baseURL, pathVars: .init(id: id.value)))
            .onSuccess {
                switch $0 {
                case let .http200_(a):
                    UIView.animate(withDuration: 0.2) {
                        self.setAccount(client.baseURL, a)
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return toots.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = timelineView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let status = toots[indexPath.row]
        cell.statusView.setStatus(status.0, attributedText: status.1, baseURL: nil)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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

final class UserHeaderView: UIView {
    fileprivate let imageView = HeaderImageView() ※ {
        $0.backgroundColor = .lightGray
    }
    fileprivate let iconView = UIImageView() ※ {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }
    fileprivate let displayNameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .white
    }
    fileprivate let usernameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .white
    }
    fileprivate let bioLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textColor = .black
        $0.textAlignment = .center
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        isOpaque = true

        let bg = MinView() ※ {$0.backgroundColor = UIColor(white: 0, alpha: 0.8)}

        let headerLayout = northLayoutFormat(["p": 8], ["image": imageView, "bg": bg, "bio": bioLabel])
        headerLayout("H:|[image]|")
        headerLayout("H:[bg]|")
        headerLayout("H:|-p-[bio]-p-|")
        headerLayout("V:|[image]-p-[bio]")
        headerLayout("V:|[bg(==image)]-p-[bio]")
        headerLayout("V:[bio]-p-|")
        addConstraint(NSLayoutConstraint(item: bg, attribute: .width, relatedBy: .lessThanOrEqual, toItem: self, attribute: .width, multiplier: 0.4, constant: 0))
        bringSubview(toFront: bg)

        let iconWidth: CGFloat = 48
        iconView.layer.cornerRadius = iconWidth / 2
        let bgLayout = bg.northLayoutFormat(["p": 8, "iconWidth": iconWidth], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": usernameLabel,
            ])
        bgLayout("H:|-(>=p)-[icon(==iconWidth)]-(>=p)-|")
        bgLayout("H:|-p-[dname]-p-|")
        bgLayout("H:|-p-[uname]-p-|")
        bgLayout("V:|-p-[icon(==iconWidth)]-p-[dname]-p-[uname]-(>=p)-|")
        bg.addConstraint(NSLayoutConstraint(item: iconView, attribute: .centerX, relatedBy: .equal, toItem: bg, attribute: .centerX, multiplier: 1, constant: 0))

        imageView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        displayNameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        usernameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentHuggingPriority(.required, for: .vertical)

        self.frame.size.height = max(frame.height, systemLayoutSizeFitting(UILayoutFittingCompressedSize).height)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}
}
