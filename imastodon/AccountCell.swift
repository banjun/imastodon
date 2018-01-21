import UIKit
import Ikemen
import NorthLayout
import API

final class AccountCell: UITableViewCell {
    let iconView = UIImageView() ※ { iv in
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
    }
    let displayNameLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 12)
        l.textColor = .darkGray
        l.numberOfLines = 0
        l.lineBreakMode = .byTruncatingTail
    }
    let userNameLabel = UILabel() ※ { l in
        l.font = .systemFont(ofSize: 16)
        l.textColor = .black
        l.numberOfLines = 0
        l.lineBreakMode = .byTruncatingTail
    }
    private let thumbnailView = AttachmentsCollectionView()
    private var thumbnailViewHeight: NSLayoutConstraint?

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "dname": displayNameLabel,
            "uname": userNameLabel,
            "spacerT": MinView(),
            "spacerB": MinView()])
        autolayout("H:||[icon(==32)]")
        autolayout("H:[icon]-[dname]||")
        autolayout("H:[icon]-[uname]||")
        autolayout("V:||[icon(==32)]-(>=0)-||")
        autolayout("V:||[spacerT][dname][uname][spacerB(==spacerT)]||")
        displayNameLabel.setContentHuggingPriority(.required, for: .vertical)
        userNameLabel.setContentHuggingPriority(.required, for: .vertical)
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    func setAccount(_ account: Account, baseURL: URL?) {
        if let avatarURL = account.avatarURL(baseURL: baseURL) {
            iconView.kf.setImageWithStub(avatarURL)
        }
        displayNameLabel.text = "@" + account.acct
        userNameLabel.text = account.display_name
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.kf.cancelDownloadTask()
        iconView.image = nil
    }
}
