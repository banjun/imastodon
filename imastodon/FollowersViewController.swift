import UIKit
import Ikemen
import API

final class FollowersViewController: UITableViewController, ClientContainer {
    let client: Client
    let subject: Account
    private var followers: [Account] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    init(client: Client, subject: Account) {
        self.client = client
        self.subject = subject
        super.init(style: .grouped)
        title = "@\(subject.username) Followers"
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(AccountCell.self, forCellReuseIdentifier: "AccountCell")
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func loadView() {
        super.loadView()

        refreshControl = UIRefreshControl() ※ {$0.addTarget(self, action: #selector(fetch), for: .valueChanged)}
        refreshControl?.beginRefreshing()
        fetch()
    }

    @objc private func fetch() {
        client.run(GetFollowers(baseURL: client.baseURL, pathVars: .init(id: subject.id.value, max_id: nil, since_id: nil, limit: String(200))))
            .onComplete {_ in self.refreshControl?.endRefreshing()}
            .onSuccess {
                switch $0 {
                case let .http200_(followers): self.followers = followers
                }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return followers.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "\(followers.count) / \(subject.followers_count) total"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AccountCell
        let a = followers[indexPath.row]
        cell.setAccount(a, baseURL: client.baseURL)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let a = followers[indexPath.row]
        show(UserViewController(fetcher: UserViewController.Fetcher.account(client: client, account: a)), sender: nil)
    }
}

