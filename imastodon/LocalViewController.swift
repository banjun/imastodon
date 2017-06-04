import Foundation
import Eureka
import SVProgressHUD
import MastodonKit
import SafariServices

private let statusCellID = "Status"

class LocalViewController: UICollectionViewController {
    let instanceAccount: InstanceAccout
    private var stream: Stream?
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
        stream?.close()
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
        if stream == nil {
            reconnectStream()
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
