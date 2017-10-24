import UIKit
import Ikemen
import NorthLayout
import Kingfisher

final class UserViewController: UIViewController {
    enum Fetcher {
        case fetch(client: Client, account: ID)
        case account(baseURL: URL, account: Account)
    }
    let fetcher: Fetcher

    private let headerView = HeaderImageView() ※ {
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

    init(fetcher: Fetcher) {
        self.fetcher = fetcher
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        super.loadView()

        view.backgroundColor = .white
        bioLabel.text = "Loading..."

        switch fetcher {
        case let .fetch(client, id):
            client.run(GetAccount(baseURL: client.baseURL, pathVars: .init(id: id.value)))
                .onSuccess {
                    switch $0 {
                    case let .http200_(a):
                        UIView.animate(withDuration: 0.2) {
                            self.setAccount(client.baseURL, a)
                            self.view.layoutIfNeeded()
                        }
                    }
            }
        case let .account(baseURL, account):
            setAccount(baseURL, account)
        }

        let bg = MinView() ※ {$0.backgroundColor = UIColor(white: 0, alpha: 0.8)}

        let headerLayout = view.northLayoutFormat([:], ["header": headerView])
        headerLayout("H:|[header]|")
        headerLayout("V:|[header(>=144)]")

        let autolayout = northLayoutFormat(["p": 8], [
            "bg": bg,
            "bio": bioLabel,
            ])
        autolayout("H:[bg]|")
        autolayout("V:|[bg]-p-[bio]-(>=p)-|")
        autolayout("H:|-p-[bio]-p-|")
        view.addConstraint(NSLayoutConstraint(item: bg, attribute: .bottom, relatedBy: .equal, toItem: headerView, attribute: .bottom, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: bg, attribute: .width, relatedBy: .lessThanOrEqual, toItem: view, attribute: .width, multiplier: 0.4, constant: 0))
        view.bringSubview(toFront: bg)

        let iconWidth: CGFloat = 48
        iconView.layer.cornerRadius = iconWidth / 2
        let bgLayout = bg.northLayoutFormat(["p": 8, "iconWidth": iconWidth], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": usernameLabel,
            ])
        bgLayout("H:|-(>=p)-[icon(==iconWidth)]-(>=p)-|")
        bgLayout("H:|-p-[dname]-p-|")
        bgLayout("H:|-p-[uname]-p-|")
        bgLayout("V:|-p-[icon(==iconWidth)]-p-[dname]-p-[uname]-(>=p)-|")
        bg.addConstraint(NSLayoutConstraint(item: iconView, attribute: .centerX, relatedBy: .equal, toItem: bg, attribute: .centerX, multiplier: 1, constant: 0))

        headerView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        displayNameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        usernameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bioLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        bg.bringSubview(toFront: iconView)
        bg.bringSubview(toFront: displayNameLabel)
        bg.bringSubview(toFront: usernameLabel)
        view.bringSubview(toFront: bioLabel)
    }

    private func setAccount(_ baseURL: URL, _ account: Account) {
        _ = URL(string: account.header).map {headerView.imageView.kf.setImage(with: $0)}
        _ = account.avatarURL(baseURL: baseURL).map {iconView.kf.setImageWithStub($0)}
        displayNameLabel.text = account.display_name
        usernameLabel.text = "@" + account.acct
        bioLabel.attributedText = account.note.data(using: .utf8).flatMap {try? NSAttributedString(data: $0, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)}
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}
}
