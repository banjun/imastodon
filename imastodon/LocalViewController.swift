import Foundation
import SVProgressHUD
import MastodonKit

class LocalViewController: TimelineViewController {
    let instanceAccount: InstanceAccout
    private var stream: Stream?

    init(instanceAccount: InstanceAccout, statuses: [Status] = []) {
        self.instanceAccount = instanceAccount
        super.init(statuses: statuses)
        title = "Local@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        toolbarItems = [UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))]
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        stream?.close()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if statuses.isEmpty {
            fetch()
        }
        if stream == nil {
            reconnectStream()
        }
    }

    private func reconnectStream() {
        stream?.close()
        stream = Stream(localTimelineForHost: instanceAccount.instance.uri, token: instanceAccount.accessToken)
        stream?.signal.observeResult { [weak self] r in
            DispatchQueue.main.async {
                switch r {
                case let .success(s): self?.append([s])
                case let .failure(e): self?.append([e.errorStatus])
                }
            }
        }
    }

    private func fetch() {
        SVProgressHUD.show()
        Client(instanceAccount).local()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.append(statuses)
                self.collectionView?.reloadData()
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    @objc private func showPost() {
        let vc = PostViewController(client: Client(instanceAccount))
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true)
    }
}
