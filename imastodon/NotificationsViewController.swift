import UIKit
import Ikemen

final class NotificationsViewController: UITableViewController, ClientContainer {
    let client: Client
    private var notifications: [Notification] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    init(client: Client) {
        self.client = client
        super.init(style: .plain)
        title = "Notifications"
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(NotificationTableViewCell.self, forCellReuseIdentifier: "NotificationTableViewCell")
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func loadView() {
        super.loadView()

        refreshControl = UIRefreshControl() ※ {$0.addTarget(self, action: #selector(fetch), for: .valueChanged)}
        refreshControl?.beginRefreshing()
        fetch()
    }

    @objc private func fetch() {
        client.run(GetNotifications(baseURL: client.baseURL, pathVars: .init(max_id: nil, since_id: nil, limit: String(30))))
            .onComplete {_ in self.refreshControl?.endRefreshing()}
            .onSuccess {
                switch $0 {
                case let .http200_(ns): self.notifications = ns
                }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationTableViewCell", for: indexPath) as! NotificationTableViewCell
        let n = notifications[indexPath.row]
        cell.notificationView.setNotification(n, text: nil, baseURL: client.baseURL)
        cell.notificationView.backgroundColor = .white
        cell.notificationView.nameLabel.textColor = .black
        cell.notificationView.bodyLabel.textColor = .black
        cell.notificationView.targetLabel.textColor = .black
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let n = notifications[indexPath.row]
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Show \(n.account.displayNameOrUserName)", style: .default) {[unowned self] _ in
            self.show(UserViewController(fetcher: .account(client: self.client, account: n.account)), sender: nil)})
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.popoverPresentationController?.sourceView = tableView
        ac.popoverPresentationController?.permittedArrowDirections = .any
        if let cell = tableView.cellForRow(at: indexPath) as? NotificationTableViewCell {
            ac.popoverPresentationController?.sourceRect = tableView.convert(cell.notificationView.iconView.bounds, from: cell.notificationView.iconView)
        }
        present(ac, animated: true)
    }
}

