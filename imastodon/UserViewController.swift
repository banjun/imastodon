import UIKit
import Ikemen
import NorthLayout
import Kingfisher

final class UserViewController: UIViewController, ClientContainer {
    let client: Client
    var account: Account {
        didSet {
            _ = URL(string: account.header).map {headerView.kf.setImage(with: $0)}

            _ = account.avatarURL(baseURL: client.baseURL).map {iconView.kf.setImageWithStub($0)}
            displayNameLabel.text = account.display_name
            usernameLabel.text = "@" + account.acct
            bioLabel.attributedText = account.note.data(using: .utf8).flatMap {try? NSAttributedString(data: $0, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil)}
        }
    }

    private let headerView = UIImageView() ※ {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
        $0.backgroundColor = .lightGray
    }
    private let iconView = UIImageView() ※ {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }
    private let displayNameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.textAlignment = .center
        $0.textColor = .white
    }
    private let usernameLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.textAlignment = .center
        $0.textColor = .white
    }
    private let bioLabel = UILabel() ※ {
        $0.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        $0.numberOfLines = 0
        $0.textColor = .black
        $0.textAlignment = .center
    }

    init(instanceAccount: InstanceAccout) {
        self.client = Client(instanceAccount)!
        self.account = instanceAccount.account // initial value to load
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        super.loadView()

        view.backgroundColor = .white
        bioLabel.text = "Loading..."

        let bg = MinView() ※ {$0.backgroundColor = UIColor(white: 0, alpha: 0.8)}

        client.run(GetAccount(baseURL: client.baseURL, pathVars: .init(id: account.id.value)))
            .onSuccess {
                switch $0 {
                case let .http200_(a):
                    UIView.animate(withDuration: 0.2) {
                        self.account = a
                        self.view.layoutIfNeeded()
                    }
                }
        }

        let autolayout = northLayoutFormat(["p": 8], [
            "header": headerView,
            "bg": bg,
            "bio": bioLabel,
            ])
        autolayout("H:|[header]|")
        autolayout("H:[bg]|")
        autolayout("V:|[header(>=144)]")
        autolayout("V:|[bg(==header)]-p-[bio]-(>=p)-|")
        autolayout("H:|-p-[bio]-p-|")
        view.addConstraint(NSLayoutConstraint(item: bg, attribute: .width, relatedBy: .lessThanOrEqual, toItem: view, attribute: .width, multiplier: 0.4, constant: 0))
        view.bringSubview(toFront: bg)

        let iconWidth: CGFloat = 48
        iconView.layer.cornerRadius = iconWidth / 2
        let bgLayout = bg.northLayoutFormat(["p": 8, "iconWidth": iconWidth], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": usernameLabel,
            ])
        bgLayout("H:[icon(==iconWidth)]")
        bgLayout("H:|-p-[dname]-p-|")
        bgLayout("H:|-p-[uname]-p-|")
        bgLayout("V:|-p-[icon(==iconWidth)]-p-[dname]-p-[uname]-(>=p)-|")
        bg.addConstraint(NSLayoutConstraint(item: iconView, attribute: .centerX, relatedBy: .equal, toItem: bg, attribute: .centerX, multiplier: 1, constant: 0))

        headerView.setContentCompressionResistancePriority(UILayoutPriorityFittingSizeLevel, for: .vertical)
        displayNameLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        usernameLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        bioLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)

        bg.bringSubview(toFront: iconView)
        bg.bringSubview(toFront: displayNameLabel)
        bg.bringSubview(toFront: usernameLabel)
        view.bringSubview(toFront: bioLabel)
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}
}
