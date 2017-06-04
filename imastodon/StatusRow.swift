import MastodonKit
import Kingfisher
import Ikemen

extension Status: Equatable {
    public static func == (lhs: Status, rhs: Status) -> Bool {
        return lhs.id == rhs.id
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
        self.init(title: "Action", message: String(status.textContent.characters.prefix(20)), preferredStyle: .actionSheet)

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

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        isOpaque = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        let autolayout = northLayoutFormat(["s": 4, "p": 8], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel])
        autolayout("H:|-p-[icon(==32)]")
        autolayout("H:[icon]-s-[name]-p-|")
        autolayout("H:[icon]-s-[body]-p-|")
        autolayout("V:|-p-[icon(==32)]-(>=p)-|")
        autolayout("V:|-p-[name]-2-[body]-p-|")
        nameLabel.setContentHuggingPriority(UILayoutPriorityRequired, for: .vertical)
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.kf.cancelDownloadTask()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }

    func setStatus(_ status: Status, attributedText: NSAttributedString?, baseURL: URL?) {
        if let avatarURL = (baseURL.map {status.account.avatarURL(baseURL: $0)} ?? URL(string: status.account.avatar) ?? URL(string: status.account.avatarStatic)) {
            iconView.kf.setImage(
                with: avatarURL,
                placeholder: stubIcon,
                options: [.scaleFactor(2), .processor(iconResizer)],
                progressBlock: nil,
                completionHandler: nil)
        }
        nameLabel.text = status.account.displayName
        bodyLabel.attributedText = attributedText ?? NSMutableAttributedString(attributedString: status.attributedTextContent ?? NSAttributedString(string: status.textContent))
    }
}
