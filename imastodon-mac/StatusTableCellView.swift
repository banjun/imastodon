import Cocoa
import Ikemen
import NorthLayout
import Kingfisher

// instantiated from xib
@objc class StatusTableCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameLabel = AutolayoutLabel() ※ { l in
        l.textColor = .gray
        l.isBezeled = false
    }
    let bodyLabel = AutolayoutLabel() ※ { l in
        l.textColor = .black
        l.isBezeled = false
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel])
        autolayout("H:|-4-[icon(==32)]-4-[name]|")
        autolayout("H:[icon]-4-[body]|")
        autolayout("V:|-4-[icon(==32)]-(>=4)-|")
        autolayout("V:|-4-[name][body]-(>=4)-|")
    }

    func setStatus(_ status: Status, baseURL: URL?, widthConstraintConstant: CGFloat? = nil) {
        _ = widthConstraintConstant.map {bodyLabel.preferredMaxLayoutWidth = $0 - 40}

        bodyLabel.stringValue = status.textContent
        nameLabel.stringValue = status.account.displayNameOrUserName
        if let avatarURL = (baseURL.flatMap {status.account.avatarURL(baseURL: $0)}) {
            iconView.kf.setImage(with: avatarURL)
        }
    }
}
