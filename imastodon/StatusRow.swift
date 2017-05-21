import Eureka
import MastodonKit
import Kingfisher

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

final class StatusCell: Cell<Status>, CellType {
    required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        imageView?.clipsToBounds = true
        imageView?.layer.cornerRadius = 4
        selectionStyle = .none
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func update() {
        super.update()

        let attrText = NSMutableAttributedString(attributedString: row.value?.attributedTextContent ?? NSAttributedString(string: row.value?.textContent ?? ""))
        attrText.insert(NSAttributedString(string: (row.value?.account.displayName ?? "") + "\n", attributes: [NSForegroundColorAttributeName: UIColor.darkGray]), at: 0)
        textLabel?.attributedText = attrText
        detailTextLabel?.text = nil

        if let avatarURL = (row.value.flatMap {URL(string: $0.account.avatar)}) {
            imageView?.kf.setImage(
                with: avatarURL,
                placeholder: stubIcon,
                options: [.scaleFactor(2), .processor(iconResizer)],
                progressBlock: nil,
                completionHandler: nil)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel?.attributedText = nil
        imageView?.kf.cancelDownloadTask()
        imageView?.image = nil
    }
}

final class StatusRow: Row<StatusCell>, RowType {
    required init(tag: String?) {
        super.init(tag: tag)
    }
}
