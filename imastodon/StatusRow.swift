import Kingfisher
import Ikemen
import NorthLayout

extension Status: Equatable {
    public static func == (lhs: Status, rhs: Status) -> Bool {
        return lhs.id == rhs.id && lhs.reblog?.value.id == rhs.reblog?.value.id
    }
}

func stubImage(_ size: CGSize = CGSize(width: 44, height: 44), _ color: UIColor = .lightGray) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer {UIGraphicsEndImageContext()}
    color.setFill()
    UIRectFill(CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext()!
}

private let stubIcon = stubImage(CGSize(width: 32, height: 32))
private let iconResizer = ResizingImageProcessor(referenceSize: stubIcon.size, mode: .aspectFill)

extension Kingfisher where Base: UIImageView {
    func setImageWithStub(_ url: URL) {
        let size = base.frame.size
        let resizer = ResizingImageProcessor(referenceSize: size.width * size.height > 0 ? size : stubIcon.size, mode: .aspectFill)
        setImage(
            with: url,
            placeholder: stubIcon,
            options: [.scaleFactor(2), .processor(resizer), .cacheOriginalImage],
            progressBlock: nil,
            completionHandler: nil)
    }
}

import SafariServices

extension UIAlertController {
    convenience init(actionFor status: Status, safari: @escaping (SFSafariViewController) -> Void, showAccount: (() -> Void)?, boost: (() -> Void)? = nil, favorite: (() -> Void)? = nil) {
        self.init(title: "Action to \(status.visibility) toot", message: String(status.textContent.characters.prefix(20)), preferredStyle: .actionSheet)

        if let at = status.mainContentStatus.attributedTextContent {
            at.enumerateAttribute(.link, in: NSRange(location: 0, length: at.length), options: []) { value, _, _ in
                switch value {
                case let url as URL:
                    addAction(UIAlertAction(title: url.absoluteString, style: .default) { _ in
                        safari(SFSafariViewController(url: url))
                    })
                default:
                    NSLog("%@", "attributed value = \(String(describing: value))")
                }
            }
        }

        [("Show \(status.mainContentStatus.account.display_name)", showAccount),
         ("🔁", boost),
         ("⭐️", favorite)]
            .flatMap {r in r.1.map {(r.0, $0)}}.forEach { title, action in
                addAction(UIAlertAction(title: title, style: .default) {_ in action()})
        }
        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass {return CAGradientLayer.self}
    var gradientLayer: CAGradientLayer {return layer as! CAGradientLayer}
    init(colors: [UIColor]) {
        super.init(frame: .zero)
        gradientLayer.colors = colors.map {$0.cgColor}
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}
}

final class AttachmentsCollectionView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var attachments: [Attachment] = [] {
        didSet {
            isHidden = attachments.isEmpty
            collectionView.reloadData()
        }
    }
    let collectionView: UICollectionView
    let layout = UICollectionViewFlowLayout() ※ { l in
        l.minimumLineSpacing = 4
        l.minimumInteritemSpacing = 0
        l.scrollDirection = .horizontal
    }
    var didSelect: ((Attachment) -> Void)?
    
    init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "Cell")
        let autolayout = northLayoutFormat([:], ["cv": collectionView])
        autolayout("H:|[cv]|")
        autolayout("V:|[cv]|")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0)
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func layoutSubviews() {
        super.layoutSubviews()
        layout.itemSize = CGSize(width: (bounds.width - collectionView.contentInset.left) * 0.9, height: bounds.height)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attachments.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let url = URL(string: attachments[indexPath.row].preview_url) else { return }
        (cell as? ImageCell)?.setImageURL(url)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelect?(attachments[indexPath.row])
    }
}

final class ImageCell: UICollectionViewCell {
    let imageView = UIImageView() ※ { iv in
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
    }
    private lazy var resizer: ResizingImageProcessor = ResizingImageProcessor(referenceSize: self.frame.size, mode: .aspectFill)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let autolayout = contentView.northLayoutFormat([:], ["image": imageView])
        autolayout("H:|[image]|")
        autolayout("V:|[image]|")
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resizer = ResizingImageProcessor(referenceSize: frame.size, mode: .aspectFill)
    }

    func setImageURL(_ url: URL) {
        imageView.kf.setImageWithStub(url)
    }
}

final class StatusView: UIView {
    let iconView = UIImageView() ※ { iv in
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
    }
    let nameLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 12)
        l.textColor = .darkGray
        l.numberOfLines = 0
        l.lineBreakMode = .byTruncatingTail
    }
    let bodyLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 16)
        l.textColor = .black
        l.numberOfLines = 0
        l.lineBreakMode = .byTruncatingTail
    }
    private let thumbnailView = AttachmentsCollectionView()
    private var thumbnailViewHeight: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        isOpaque = true

        let autolayout = northLayoutFormat(["s": 4, "p": 8], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel,
            "thumbs": thumbnailView])
        autolayout("H:|-p-[icon(==32)]")
        autolayout("H:[icon]-s-[name]-p-|")
        autolayout("H:[icon]-s-[body]-p-|")
        autolayout("H:|[thumbs]|")
        autolayout("V:|-p-[icon(==32)]-(>=p)-|")
        autolayout("V:|-p-[name]-2-[body]-s-[thumbs]-s-|")
        nameLabel.setContentHuggingPriority(.required, for: .vertical)
        let thumbnailViewHeight = NSLayoutConstraint(item: thumbnailView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        self.thumbnailViewHeight = thumbnailViewHeight
        thumbnailViewHeight.priority = .required
        thumbnailView.addConstraint(thumbnailViewHeight)
        bringSubview(toFront: iconView)
        thumbnailView.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    func prepareForReuse() {
        iconView.kf.cancelDownloadTask()
        iconView.image = nil
    }

    func setStatus(_ status: Status, attributedText: NSAttributedString?, baseURL: URL?, didSelectAttachment: ((Attachment) -> Void)? = nil) {
        let boosted = status.reblog?.value
        let mainStatus = status.mainContentStatus
        if let avatarURL = mainStatus.account.avatarURL(baseURL: baseURL) {
            iconView.kf.setImageWithStub(avatarURL)
        }
        nameLabel.text = boosted.map {status.account.displayNameOrUserName + "🔁" + $0.account.displayNameOrUserName} ?? status.account.displayNameOrUserName
        bodyLabel.attributedText = attributedText ?? mainStatus.attributedTextContent ?? NSAttributedString(string: mainStatus.textContent)

        thumbnailView.attachments = mainStatus.media_attachments
        thumbnailViewHeight?.constant = mainStatus.media_attachments.isEmpty ? 0 : 128
        thumbnailView.didSelect = didSelectAttachment
    }
}

final class StatusCollectionViewCell: UICollectionViewCell {
    let statusView: StatusView

    private let leftShadow = GradientView(colors: [.init(white: 0, alpha: 0.3), .clear]) ※ {$0.isHidden = true}
    private let rightShadow = GradientView(colors: [.clear, .init(white: 0, alpha: 0.3)]) ※ {$0.isHidden = true}
    var showInnerShadow: Bool {
        get {return leftShadow.isHidden == false}
        set {leftShadow.isHidden = !newValue; rightShadow.isHidden = !newValue}
    }

    override init(frame: CGRect) {
        self.statusView = StatusView(frame: frame)
        super.init(frame: frame)

        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.frame = self.bounds

        let autolayout = contentView.northLayoutFormat(["s": 4, "p": 8], [
            "shadowL": leftShadow,
            "shadowR": rightShadow,
            "status": statusView])
        autolayout("H:|[status]|")
        autolayout("V:|[status]|")
        autolayout("H:|[shadowL(==8)]")
        autolayout("H:[shadowR(==shadowL)]|")
        autolayout("V:|[shadowL]|")
        autolayout("V:|[shadowR]|")
        bringSubview(toFront: leftShadow)
        bringSubview(toFront: rightShadow)
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func prepareForReuse() {
        super.prepareForReuse()
        statusView.prepareForReuse()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }
}

final class StatusTableViewCell: UITableViewCell {
    let statusView: StatusView

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        self.statusView = StatusView(frame: .zero)
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.frame = self.bounds

        let autolayout = contentView.northLayoutFormat([:], [
            "status": statusView])
        autolayout("H:|[status]|")
        autolayout("V:|[status]|")
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func prepareForReuse() {
        super.prepareForReuse()
        statusView.prepareForReuse()
    }
}

final class NotificationCell: UICollectionViewCell {
    let iconView = UIImageView() ※ { iv in
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
    }
    let nameLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 12)
        l.textColor = .white
        l.lineBreakMode = .byTruncatingTail
    }
    let bodyLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 16)
        l.textColor = .white
        l.lineBreakMode = .byTruncatingTail
        l.textAlignment = .center
    }
    let targetLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 16)
        l.textColor = .white
        l.lineBreakMode = .byTruncatingTail
        l.textAlignment = .center
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        isOpaque = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        let autolayout = northLayoutFormat(["s": 4, "p": 8], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel,
            "target": targetLabel,
            "L": MinView(),
            "R": MinView()])
        autolayout("H:|[L][icon(==24)]-s-[name][R(==L)]|")
        autolayout("H:|-p-[body]-p-|")
        autolayout("H:|-p-[target]-p-|")
        autolayout("V:|-p-[icon(==24)]-s-[body]-s-[target]-p-|")
        autolayout("V:|-p-[name(==icon)]-s-[body]")
        nameLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
        targetLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
    }
    
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.kf.cancelDownloadTask()
        iconView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }

    func setNotification(_ notification: Notification, text: String?, baseURL: URL?) {
        if let avatarURL = notification.account.avatarURL(baseURL: baseURL) {
            iconView.kf.setImageWithStub(avatarURL)
        }
        nameLabel.text = notification.account.displayNameOrUserName
        bodyLabel.text = notification.type
        targetLabel.text = text ?? notification.status?.textContent ?? "you"
    }
}
