import UIKit
import Kingfisher
import NorthLayout
import Ikemen

final class UserHeaderView: UIView {
    private let imageView = HeaderImageView() ※ {
        $0.backgroundColor = .lightGray
    }
    private let iconView = UIImageView() ※ {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }
    private let displayNameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .white
    }
    private let usernameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .white
    }
    private let bioLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textColor = .black
        $0.textAlignment = .center
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        isOpaque = true

        let bg = MinView() ※ {$0.backgroundColor = UIColor(white: 0, alpha: 0.8)}

        let headerLayout = northLayoutFormat(["p": 8], ["image": imageView, "bg": bg, "bio": bioLabel])
        headerLayout("H:|[image]|")
        headerLayout("H:[bg]|")
        headerLayout("H:[bio]")
        headerLayout("V:|[image]-p-[bio]")
        headerLayout("V:|[bg(==image)]-p-[bio]")
        headerLayout("V:[bio]-p-|")
        addConstraint(NSLayoutConstraint(item: bioLabel, attribute: .left, relatedBy: .equal, toItem: safeAreaLayoutGuide, attribute: .left, multiplier: 1, constant: 8))
        addConstraint(NSLayoutConstraint(item: bioLabel, attribute: .right, relatedBy: .equal, toItem: safeAreaLayoutGuide, attribute: .right, multiplier: 1, constant: -8))
        addConstraint(NSLayoutConstraint(item: bg, attribute: .width, relatedBy: .lessThanOrEqual, toItem: self, attribute: .width, multiplier: 0.4, constant: 0))
        bringSubview(toFront: bg)

        let iconWidth: CGFloat = 48
        iconView.layer.cornerRadius = iconWidth / 2
        let bgLayout = bg.northLayoutFormat(["p": 8, "iconWidth": iconWidth], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": usernameLabel,
            ])
        bgLayout("H:[icon(==iconWidth)]-(>=p)-|")
        bgLayout("H:|-p-[dname]-p-|")
        bgLayout("H:|-p-[uname]-p-|")
        bgLayout("V:|-p-[icon(==iconWidth)]-p-[dname]-p-[uname]-(>=p)-|")
        addConstraint(NSLayoutConstraint(item: iconView, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: safeAreaLayoutGuide, attribute: .top, multiplier: 1, constant: 8))
        bg.addConstraint(NSLayoutConstraint(item: iconView, attribute: .centerX, relatedBy: .equal, toItem: bg, attribute: .centerX, multiplier: 1, constant: 0))

        imageView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        displayNameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        usernameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentHuggingPriority(.required, for: .vertical)

        self.frame.size.height = max(frame.height, systemLayoutSizeFitting(UILayoutFittingCompressedSize).height)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    func setAccount(_ account: Account?, baseURL: URL) {
        _ = account.flatMap {URL(string: $0.header)}.map {imageView.imageView.kf.setImage(with: $0)}
        _ = account?.avatarURL(baseURL: baseURL).map {iconView.kf.setImage(with: $0)}
        displayNameLabel.text = account?.display_name
        usernameLabel.text = account.map {"@" + $0.acct}
        bioLabel.attributedText = account.flatMap {NSAttributedString(html: $0.note)}
    }
}

@IBDesignable
extension UserHeaderView {
    @IBInspectable private var headerImage: UIImage? {
        get {return imageView.imageView.image}
        set {imageView.imageView.image = newValue}
    }

    @IBInspectable private var icon: UIImage? {
        get {return iconView.image}
        set {iconView.image = newValue}
    }

    @IBInspectable private var displayName: String? {
        get {return displayNameLabel.text}
        set {displayNameLabel.text = newValue}
    }

    @IBInspectable private var username: String? {
        get {return usernameLabel.text}
        set {usernameLabel.text = newValue}
    }

    @IBInspectable private var bio: String? {
        get {return bioLabel.text}
        set {bioLabel.attributedText = newValue?.data(using: .utf8).flatMap {try? NSAttributedString(data: $0, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)}}
    }
}

