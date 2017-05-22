import Foundation
import Eureka
import SVProgressHUD
import MastodonKit
import IKEventSource
import Ikemen
import SafariServices
import BouncyLayout

private let statusCellID = "Status"

class LocalViewController: UICollectionViewController {
    let instanceAccount: InstanceAccout
    private var eventSource: EventSource?
//    let layout = BouncyLayout() // BouncyLayout can corrupt layout size in animation
    let layout = UICollectionViewFlowLayout()
    fileprivate var statuses: [(Status, NSAttributedString?)] // as creating attributed text is heavy, cache it

    init(instanceAccount: InstanceAccout, statuses: [Status] = []) {
        self.instanceAccount = instanceAccount
        self.statuses = statuses.map {($0, $0.attributedTextContent)}
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        super.init(collectionViewLayout: layout)
        title = "Local@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        toolbarItems = [UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showPost))]
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        eventSource?.close()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView?.backgroundColor = .white
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.register(StatusCollectionViewCell.self, forCellWithReuseIdentifier: statusCellID)
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
        if eventSource == nil {
            reconnectEventSource()
        }
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        layout.invalidateLayout()
        collectionView?.reloadData()
    }

    private func append(_ statuses: [Status]) {
        statuses.reversed().forEach {
            self.statuses.insert(($0, $0.attributedTextContent), at: 0)
            self.collectionView?.insertItems(at: [IndexPath(item: 0, section: 0)])
        }

        if self.statuses.count > 100 {
            self.statuses.removeLast(self.statuses.count - 80)
            collectionView?.reloadData()
        }
    }

    private func reconnectEventSource() {
        eventSource?.close()
        let host: String = {
            let h = instanceAccount.instance.uri
            switch h {
            case "mstdn.jp": return "streaming." + h
            default: return h
            }
        }()
        eventSource = EventSource(url: "https://" + host + "/api/v1/streaming/public/local", headers: ["Authorization": "Bearer \(instanceAccount.accessToken)"]) ※ { es in
            es.onOpen { [weak es] in
                NSLog("%@", "EventSource opened: \(String(describing: es?.readyState))")
            }
            es.onError { [weak es, weak self] e in
                NSLog("%@", "EventSource error: \(String(describing: e))")
                es?.invalidate()
                self?.eventSource = nil

                guard e?.code != NSURLErrorCancelled else { return }
                DispatchQueue.main.async {
                    let ac = UIAlertController(title: "Stream Error", message: e?.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(ac, animated: true)
                }
            }
            es.onMessage { _ in // [weak self] id, event, data in
                // NSLog("%@", "EventSource onMessage: \(id), \(event), \(data)")
            }
            es.addEventListener("update") { [weak self] id, event, data in
                do {
                    let j = try JSONSerialization.jsonObject(with: data?.data(using: .utf8) ?? Data())
                    let status = try Status.decodeValue(j)
                    DispatchQueue.main.async {
                        self?.append([status])
                    }
                    // NSLog("%@", "EventSource event update: \(status)")
                } catch {
                    NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
                    DispatchQueue.main.async {
                        // for debug, append error message
                        let errorAccount = Account(id: 0, username: "", acct: "", displayName: "error", note: "", url: "", avatar: "", avatarStatic: "", header: "", headerStatic: "", locked: false, createdAt: Date(), followersCount: 0, followingCount: 0, statusesCount: 0)
                        let errorStatus = Status(id: 0, uri: "", url: URL(string: "")!, account: errorAccount, inReplyToID: nil, inReplyToAccountID: nil, content: error.localizedDescription, createdAt: Date(), reblogsCount: 0, favouritesCount: 0, reblogged: nil, favourited: nil, sensitive: nil, spoilerText: "", visibility: .public, mediaAttachments: [], mentions: [], tags: [], application: nil, reblogWrapper: [])
                        self?.append([errorStatus])
                    }
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

    private func didTap(status: Status, cell: BaseCell, row: BaseRow) {
        let ac = UIAlertController(actionFor: status,
                                   safari: {[unowned self] in self.show($0, sender: nil)},
                                   boost: {},
                                   favorite: {})
        present(ac, animated: true)
    }

    @objc private func showPost() {
        let vc = PostViewController(client: Client(instanceAccount))
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true)
    }
}

extension LocalViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return statuses.count
    }

    fileprivate func status(_ indexPath: IndexPath) -> (Status, NSAttributedString?) {
        return statuses[indexPath.row]
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: statusCellID, for: indexPath) as! StatusCollectionViewCell
        let s = status(indexPath)
        cell.setStatus(s.0, attributedText: s.1)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let s = status(indexPath).0
        let ac = UIAlertController(actionFor: s,
                                   safari: {[unowned self] in self.show($0, sender: nil)},
                                   boost: {},
                                   favorite: {})
        present(ac, animated: true)
    }
}

private let layoutCell = StatusCollectionViewCell(frame: .zero)

extension LocalViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = collectionView.bounds.size
        let s = status(indexPath)
        layoutCell.setStatus(s.0, attributedText: s.1)
        let layoutSize = layoutCell.systemLayoutSizeFitting(size, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
        return CGSize(width: collectionView.bounds.width, height: layoutSize.height)
    }
}
