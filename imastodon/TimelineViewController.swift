import Foundation
import SafariServices
import Ikemen
import Dwifft
import API

enum TimelineEvent {
    case home(Status, NSAttributedString?) // as creating attributed text is heavy, cache it
    case local(Status, NSAttributedString?) // as creating attributed text is heavy, cache it
    case notification(API.Notification, String?) // as creating attributed text is buggy, cache it

    var cached: TimelineEvent {
        switch self {
        case let .home(s, nil): return .home(s, s.mainContentStatus.attributedTextContent)
        case let .local(s, nil): return .local(s, s.mainContentStatus.attributedTextContent)
        case let .notification(n, nil) where n.status != nil: return .notification(n, n.status?.textContent)
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

extension TimelineEvent: Equatable {
    static func == (lhs: TimelineEvent, rhs: TimelineEvent) -> Bool {
        switch (lhs, rhs) {
        case (.home(let l, _), .home(let r, _)): return l.id == r.id
        case (.local(let l, _), .local(let r, _)): return l.id == r.id
        case (.notification(let l, _), .notification(let r, _)): return l.id == r.id
        case (.home, _), (.local, _), (.notification, _): return false
        }
    }
}

class TimelineViewController: UICollectionViewController {
    var baseURL: URL? // base url for images such as /avatars/original/missing.png
    var timelineEvents: [TimelineEvent] {didSet {applyDwifft()}}
    private(set) lazy var timelineDiff: CollectionViewDiffCalculator<Int, TimelineEvent> = .init(collectionView: self.collectionView)
    private func applyDwifft() {
        timelineDiff.sectionedValues = SectionedValues([(0, timelineEvents)])
    }
    let layout = UICollectionViewFlowLayout() ※ { l in
        l.minimumLineSpacing = 0
        l.minimumInteritemSpacing = 0
    }
    private lazy var previewingDelegate: StatusPreviewingDelegate? = (self as? ClientContainer).map {StatusPreviewingDelegate(vc: self, client: $0.client, context: { [weak self] p in
        guard let collectionView = self?.collectionView,
            let indexPath = collectionView.indexPathForItem(at: p),
            let event = self?.timelineDiff.value(atIndexPath: indexPath),
            let sourceRect = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { return nil }
        switch event {
        case let .home(s, a): return (s, a, sourceRect)
        case let .local(s, a): return (s, a, sourceRect)
        case .notification: return nil
        }
    })}

    private var layoutCell = StatusCollectionViewCell(frame: .zero)
    private let notificationLayoutCell = NotificationCollectionViewCell(frame: .zero)

    init(timelineEvents: [TimelineEvent] = [], baseURL: URL? = nil) {
        self.baseURL = baseURL
        self.timelineEvents = timelineEvents
        super.init(collectionViewLayout: layout)

        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            // for NSAttributedString, label cannot be adjusted for size calculation corresponding to Dynamic Type Change.
            // as a workaround, we re-create a cell.
            self?.layoutCell = StatusCollectionViewCell(frame: .zero)
        }
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let collectionView = collectionView else { return }
        collectionView.backgroundColor = ThemeColor.background
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(StatusCollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.homeCellID)
        collectionView.register(StatusCollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.localCellID)
        collectionView.register(NotificationCollectionViewCell.self, forCellWithReuseIdentifier: TimelineEvent.notificationCellID)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        layout.invalidateLayout()
    }

    func append(_ events: [TimelineEvent]) {
            events.reversed().forEach { e in
                autoreleasepool {
                    guard !(self.timelineEvents.enumerated().contains { old in
                        guard e.status != nil else { return false }
                        guard old.element.status == e.status else { return false }
                        switch (old.element, e) {
                        case (.home, .local):
                            // upgrade from home to local. (more public)
                            self.timelineEvents[old.offset] = e.cached
                        default: break
                        }
                        return true
                    }) else { return }
                    self.timelineEvents.insert(e.cached, at: 0)
                }
            }

        if self.timelineEvents.count > 100 {
            self.timelineEvents.removeLast(self.timelineEvents.count - 80)
        }
    }
}

protocol ClientContainer {
    var client: Client { get }
}

extension TimelineViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return timelineDiff.numberOfSections()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return timelineDiff.numberOfObjects(inSection: section)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let e = timelineDiff.value(atIndexPath: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: e.cellID, for: indexPath)
        switch e {
        case let .home(s, a):
            (cell as? StatusCollectionViewCell)?.statusView.setStatus(s, attributedText: a, baseURL: baseURL) { [weak self] a in self?.showAttachment(a) }
        case let .local(s, a):
            (cell as? StatusCollectionViewCell)?.statusView.setStatus(s, attributedText: a, baseURL: baseURL) { [weak self] a in self?.showAttachment(a) }
        case let .notification(n, s):
            (cell as? NotificationCollectionViewCell)?.notificationView.setNotification(n, text: s, baseURL: baseURL)
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let s = timelineDiff.value(atIndexPath: indexPath).status else { return }
        let ac = UIAlertController(actionFor: s,
                                   safari: {[unowned self] in self.present($0, animated: true)},
                                   showAccount: {[unowned self] in _ = (self as? ClientContainer).map {self.show(UserViewController(fetcher: .account(client: $0.client, account: s.mainContentStatus.account)), sender: nil)}},
                                   boost: {[unowned self] in (self as? ClientContainer & UIViewController)?.boost(s)},
                                   favorite: {[unowned self] in (self as? ClientContainer & UIViewController)?.favorite(s)})
        ac.addAction(UIAlertAction(title: "Show Toot", style: .default) {[unowned self] _ in (self as? ClientContainer).map {self.show(StatusViewController(client: $0.client, status: (s, s.mainContentStatus.attributedTextContent)), sender: nil)}})
        ac.popoverPresentationController?.sourceView = collectionView
        ac.popoverPresentationController?.permittedArrowDirections = .any
        if let cell = collectionView.cellForItem(at: indexPath) as? StatusCollectionViewCell {
            ac.popoverPresentationController?.sourceRect = collectionView.convert(cell.statusView.iconView.bounds, from: cell.statusView.iconView)
        }
        present(ac, animated: true)
    }

    func showAttachment(_ a: Attachment) {
        let vc = AttachmentViewController(attachment: a)
        present(vc, animated: true)
    }

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: point as NSCopying, previewProvider: { [weak self] in self?.previewingDelegate?.preview(for: point) }, actionProvider: nil)
    }

    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let self = self,
                  let point = configuration.identifier as? CGPoint,
                  let vc = self.previewingDelegate?.preview(for: point) else { return }
            self.show(vc, sender: nil)
        }
    }
}

extension ClientContainer where Self: UIViewController {
    func boost(_ s: Status) {
        showHUD()
        client.boost(s)
            .onComplete {_ in self.dismissHUD()}
    }
    
    func favorite(_ s: Status) {
        showHUD()
        client.favorite(s)
            .onComplete {_ in self.dismissHUD()}
    }
}

extension TimelineViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = collectionView.bounds.size

        func statusSize(_ s: Status, _ a: NSAttributedString?, constraint: CGSize) -> CGSize {
            layoutCell.statusView.setStatus(s, attributedText: a, baseURL: nil)
            if let a = a, a.length < 24 && constraint.width < size.width {
                let preferredLabelMaxWidth = size.width / 2 - 52
                layoutCell.statusView.nameLabel.preferredMaxLayoutWidth = preferredLabelMaxWidth
                layoutCell.statusView.bodyLabel.preferredMaxLayoutWidth = preferredLabelMaxWidth
                let layoutSize = layoutCell.contentView.systemLayoutSizeFitting(constraint, withHorizontalFittingPriority: UILayoutPriority.fittingSizeLevel, verticalFittingPriority: UILayoutPriority.fittingSizeLevel)
                return CGSize(width: layoutSize.width, height: layoutSize.height)
            } else {
                let preferredLabelMaxWidth = size.width - 52
                layoutCell.statusView.nameLabel.preferredMaxLayoutWidth = preferredLabelMaxWidth
                layoutCell.statusView.bodyLabel.preferredMaxLayoutWidth = preferredLabelMaxWidth
                let layoutSize = layoutCell.contentView.systemLayoutSizeFitting(CGSize(width: size.width, height: constraint.height), withHorizontalFittingPriority: UILayoutPriority.required, verticalFittingPriority: UILayoutPriority.fittingSizeLevel)
                return CGSize(width: size.width, height: layoutSize.height)
            }
        }

        let e = timelineDiff.value(atIndexPath: indexPath)
        switch e {
        case let .home(s, a): return statusSize(s, a, constraint: size)
        case let .local(s, a): return statusSize(s, a, constraint: UIView.layoutFittingCompressedSize)
        case let .notification(n, s):
            notificationLayoutCell.notificationView.setNotification(n, text: s, baseURL: nil)
            let layoutSize = notificationLayoutCell.systemLayoutSizeFitting(size, withHorizontalFittingPriority: UILayoutPriority.required, verticalFittingPriority: UILayoutPriority.fittingSizeLevel)
            return CGSize(width: collectionView.bounds.width, height: layoutSize.height)
        }
    }
}
