import UIKit
import Kingfisher
import NorthLayout
import Ikemen
import API

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

        let headerLayout = northLayoutFormat([:], ["image": imageView, "bg": bg, "bio": bioLabel])
        headerLayout("H:|[image]|")
        headerLayout("H:[bg]|")
        headerLayout("H:||[bio]||")
        headerLayout("V:|[image]-[bio]||")
        headerLayout("V:|[bg]-[bio]||")
        bg.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.4).isActive = true
        bringSubview(toFront: bg)

        let iconWidth: CGFloat = 48
        iconView.layer.cornerRadius = iconWidth / 2
        let bgLayout = bg.northLayoutFormat(["iconWidth": iconWidth], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": usernameLabel,
            ])
        bgLayout("H:||-(>=0)-[icon(==iconWidth)]-(>=0)-||")
        bgLayout("H:||[dname]||")
        bgLayout("H:||[uname]||")
        bgLayout("V:||[icon(==iconWidth)]-[dname]-[uname]-(>=0)-||")
        bg.layoutMarginsGuide.centerXAnchor.constraint(equalTo: iconView.centerXAnchor).isActive = true

        bioLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentHuggingPriority(.required, for: .vertical)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    func setAccount(_ account: Account?, baseURL: URL) {
        _ = account.flatMap {URL(string: $0.header)}.map {imageView.imageView.kf.setImage(with: $0)}
        _ = account?.avatarURL(baseURL: baseURL).map {iconView.kf.setImage(with: $0)}
        displayNameLabel.text = account?.display_name
        usernameLabel.text = account.map {"@" + $0.acct}
        bioLabel.attributedText = account.flatMap {NSAttributedString(html: $0.note)}
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return imageView.hitTest(point, with: event) // pass through label flick to parent scroll event
    }
}

