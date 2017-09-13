import Kingfisher
import Ikemen
import NorthLayout

extension Status: Equatable {
    public static func == (lhs: Status, rhs: Status) -> Bool {
        return lhs.id == rhs.id && lhs.reblog?.value.id == rhs.reblog?.value.id
    }
}

private func stubImage(_ size: CGSize = CGSize(width: 44, height: 44), _ color: UIColor = .lightGray) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer {UIGraphicsEndImageContext()}
    color.setFill()
    UIRectFill(CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext()!
}

private let stubIcon = stubImage(CGSize(width: 32, height: 32))
private let iconResizer = ResizingImageProcessor(referenceSize: stubIcon.size, mode: .aspectFill)

import SafariServices

extension UIAlertController {
    convenience init(actionFor status: Status, safari: @escaping (SFSafariViewController) -> Void, boost: @escaping () -> Void, favorite: @escaping () -> Void) {
        self.init(title: "Action to \(status.visibility) toot", message: String(status.textContent.characters.prefix(20)), preferredStyle: .actionSheet)

        if let at = status.attributedTextContent {
            status.attributedTextContent?.enumerateAttribute(NSLinkAttributeName, in: NSRange(location: 0, length: at.length), options: []) { value, _, _ in
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

        addAction(UIAlertAction(title: "🔁", style: .default) {_ in boost()})
        addAction(UIAlertAction(title: "⭐️", style: .default) {_ in favorite()})
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

final class StatusCollectionViewCell: UICollectionViewCell {
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
    let leftShadow = GradientView(colors: [.init(white: 0, alpha: 0.3), .clear]) ※ {$0.isHidden = true}
    let rightShadow = GradientView(colors: [.clear, .init(white: 0, alpha: 0.3)]) ※ {$0.isHidden = true}
    var showInnerShadow: Bool {
        get {return leftShadow.isHidden == false}
        set {leftShadow.isHidden = !newValue; rightShadow.isHidden = !newValue}
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
            "shadowL": leftShadow,
            "shadowR": rightShadow])
        autolayout("H:|-p-[icon(==32)]")
        autolayout("H:[icon]-s-[name]-p-|")
        autolayout("H:[icon]-s-[body]-p-|")
        autolayout("V:|-p-[icon(==32)]-(>=p)-|")
        autolayout("V:|-p-[name]-2-[body]-p-|")
        autolayout("H:|[shadowL(==8)]")
        autolayout("H:[shadowR(==shadowL)]|")
        autolayout("V:|[shadowL]|")
        autolayout("V:|[shadowR]|")
        nameLabel.setContentHuggingPriority(UILayoutPriorityRequired, for: .vertical)
        bringSubview(toFront: leftShadow)
        bringSubview(toFront: rightShadow)
        bringSubview(toFront: iconView)
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

    func setStatus(_ status: Status, text: String?, baseURL: URL?) {
        let boosted = status.reblog?.value
        let mainStatus = status.mainContentStatus
        if let avatarURL = mainStatus.account.avatarURL(baseURL: baseURL) {
            iconView.kf.setImage(
                with: avatarURL,
                placeholder: stubIcon,
                options: [.scaleFactor(2), .processor(iconResizer)],
                progressBlock: nil,
                completionHandler: nil)
        }
        nameLabel.text = boosted.map {status.account.displayNameOrUserName + "🔁" + $0.account.displayNameOrUserName} ?? status.account.displayNameOrUserName
        bodyLabel.text = text ?? mainStatus.textContent
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
        nameLabel.setContentHuggingPriority(UILayoutPriorityRequired, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        targetLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
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
            iconView.kf.setImage(
                with: avatarURL,
                placeholder: stubIcon,
                options: [.scaleFactor(2), .processor(iconResizer)],
                progressBlock: nil,
                completionHandler: nil)
        }
        nameLabel.text = notification.account.displayNameOrUserName
        bodyLabel.text = notification.type
        targetLabel.text = text ?? notification.status?.textContent ?? "you"
    }
}
