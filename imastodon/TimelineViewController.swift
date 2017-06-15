import Foundation
import SVProgressHUD
import SafariServices
import Ikemen

enum TimelineEvent {
    case home(Status, NSAttributedString?) // as creating attributed text is heavy, cache it
    case local(Status, NSAttributedString?) // as creating attributed text is heavy, cache it
    case notification(Notification)

    var cached: TimelineEvent {
        switch self {
        case let .home(s, nil): return .home(s, s.mainContentStatus.attributedTextContent)
        case let .local(s, nil): return .local(s, s.mainContentStatus.attributedTextContent)
        default: return self
        }
    }

    static let homeCellID = "Home"
    static let localCellID = "Local"
    static let notificationCellID = "Notification"

    var cellID: String {
        switch self {
        case .home: return TimelineEvent.homeCellID
        case .local: return TimelineEvent.localCellID
        case .notification: return TimelineEvent.notificationCellID
        }
    }

    var status: Status? {
        switch self {
        case let .home(s, _): return s
        case let .local(s, _): return s
        case .notification: return nil
        }
    }

    var mainContentStatus: Status? {return status?.mainContentStatus}
}

class TimelineViewController: UICollectionViewController {
    var baseURL: URL? // base url for images such as /avatars/original/missing.png
    var timelineEvents: [TimelineEvent]
    let layout = UICollectionViewFlowLayout() ※ { l in
        l.minimumLineSpacing = 0
        l.minimumInteritemSpacing = 0
    }

    init(timelineEvents: [TimelineEvent] = [], baseURL: URL? = nil) {
        self.baseURL = baseURL
        self.timelineEvents = timelineEvents
        super.init(collectionViewLayout: layout)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView?.backgroundColor = .white
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.register(StatusCollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.homeCellID)
        collectionView?.register(StatusCollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.localCellID)
        collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.notificationCellID)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        layout.invalidateLayout()
        collectionView?.reloadData()
    }

    func append(_ events: [TimelineEvent]) {
        events.reversed().forEach { e in
            autoreleasepool {
                self.timelineEvents.insert(e.cached, at: 0)
                self.collectionView?.insertItems(at: [IndexPath(item: 0, section: 0)])
            }
        }

        if self.timelineEvents.count > 100 {
            self.timelineEvents.removeLast(self.timelineEvents.count - 80)
            collectionView?.reloadData()
        }
    }

    func timelineEvent(_ indexPath: IndexPath) -> TimelineEvent {
        return timelineEvents[indexPath.row]
    }
}

protocol ClientContainer {
    var client: Client { get }
}

extension TimelineViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return timelineEvents.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let e = timelineEvent(indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: e.cellID, for: indexPath)
        switch e {
        case let .home(s, a):
            (cell as? StatusCollectionViewCell)?.mode = .home
            (cell as? StatusCollectionViewCell)?.setStatus(s, attributedText: a, baseURL: baseURL)
        case let .local(s, a):
            (cell as? StatusCollectionViewCell)?.mode = .local
            (cell as? StatusCollectionViewCell)?.setStatus(s, attributedText: a, baseURL: baseURL)
        case .notification:
            cell.contentView.backgroundColor = .blue
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let s = timelineEvent(indexPath).status else { return }
        let ac = UIAlertController(actionFor: s,
                                   safari: {[unowned self] in self.show($0, sender: nil)},
                                   boost: {[unowned self] in self.boost(s)},
                                   favorite: {[unowned self] in self.favorite(s)})
        present(ac, animated: true)
    }
    
    func boost(_ s: Status) {
        guard let client = (self as? ClientContainer)?.client else { return }
        SVProgressHUD.show()
        client.boost(s)
            .onComplete {_ in SVProgressHUD.dismiss()}
    }
    
    func favorite(_ s: Status) {
        guard let client = (self as? ClientContainer)?.client else { return }
        SVProgressHUD.show()
        client.favorite(s)
            .onComplete {_ in SVProgressHUD.dismiss()}
    }
}

private let layoutCell = StatusCollectionViewCell(frame: .zero) ※ {$0.mode = .home}

extension TimelineViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = collectionView.bounds.size

        func statusSize(_ s: Status, _ a: NSAttributedString?) -> CGSize {
            layoutCell.setStatus(s, attributedText: a, baseURL: nil)
            let layoutSize = layoutCell.systemLayoutSizeFitting(size, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
            return CGSize(width: collectionView.bounds.width, height: layoutSize.height)
        }

        let e = timelineEvent(indexPath)
        switch e {
        case let .home(s, a): return statusSize(s, a)
        case let .local(s, a): return statusSize(s, a)
        case .notification: return CGSize(width: size.width, height: 25)
        }
    }
}
