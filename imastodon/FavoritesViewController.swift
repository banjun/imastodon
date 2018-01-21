import UIKit
import Ikemen
import API

final class FavoritesViewController: UITableViewController, ClientContainer {
    let client: Client
    private var toots: [(Status, NSAttributedString?)] = [] { // cache heavy attributed strings
        didSet {
            tableView.reloadData()
        }
    }

    init(client: Client) {
        self.client = client
        super.init(style: .plain)
        title = "Favorites"
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: "StatusTableViewCell")
        tableView.insetsContentViewsToSafeArea = false
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func loadView() {
        super.loadView()

        refreshControl = UIRefreshControl() ※ {$0.addTarget(self, action: #selector(fetch), for: .valueChanged)}
        refreshControl?.beginRefreshing()
        fetch()
    }

    @objc private func fetch() {
        client.run(GetFavourites(baseURL: client.baseURL, pathVars: .init(max_id: nil, since_id: nil, limit: String(40))))
            .onComplete {_ in self.refreshControl?.endRefreshing()}
            .onSuccess {
                switch $0 {
                case let .http200_(toots): self.toots = toots.map {($0, $0.mainContentStatus.attributedTextContent)}
                }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return toots.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatusTableViewCell", for: indexPath) as! StatusTableViewCell
        let s = toots[indexPath.row]
        cell.statusView.setStatus(s.0, attributedText: s.1, baseURL: client.baseURL)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
