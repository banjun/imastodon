import Cocoa
import Ikemen
import NorthLayout
import Kingfisher
import API

// instantiated from xib
@objc class StatusTableCellView: NSTableCellView {
    let iconView = IconView()
    let nameLabel = AutolayoutLabel() ※ { l in
        l.wantsLayer = false // draw to cellview layer
        l.font = .systemFont(ofSize: 14)
        l.isBezeled = false
        l.drawsBackground = false
        l.lineBreakMode = .byCharWrapping
        l.cell?.truncatesLastVisibleLine = true
        l.maximumNumberOfLines = 2
    }
    let bodyLabel = AutolayoutLabel() ※ { l in
        l.wantsLayer = false // draw to cellview layer
        l.font = .systemFont(ofSize: 15)
        l.isBezeled = false
        l.drawsBackground = false
        l.lineBreakMode = .byWordWrapping
        l.cell?.truncatesLastVisibleLine = true
        l.maximumNumberOfLines = 0
    }
    override func awakeFromNib() {
        // draw contents into single layer
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        canDrawSubviewsIntoLayer = true
        super.awakeFromNib()

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "name": nameLabel,
            "body": bodyLabel])
        autolayout("H:|-4-[icon(==48)]-4-[name]|")
        autolayout("H:[icon]-4-[body]|")
        autolayout("V:|-4-[icon(==48)]-(>=4)-|")
        autolayout("V:|[name][body]-(>=4)-|")
    }

    func setStatus(_ status: Status, baseURL: URL?, widthConstraintConstant: CGFloat? = nil) {
        _ = widthConstraintConstant.map {
            nameLabel.preferredMaxLayoutWidth = ($0 - 2) - 56
            bodyLabel.preferredMaxLayoutWidth = ($0 - 2) - 56
        }

        bodyLabel.stringValue = status.textContent
        nameLabel.stringValue = status.account.displayNameOrUserName
        if let avatarURL = (baseURL.flatMap {status.account.avatarURL(baseURL: $0)}) {
            iconView.kf.setImage(with: avatarURL)
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        get {return super.backgroundStyle}
        set {
            super.backgroundStyle = newValue
            switch newValue {
            case .dark:
                nameLabel.textColor = .white
                bodyLabel.textColor = .white
            case .light:
                nameLabel.textColor = .gray
                bodyLabel.textColor = .black
            case .raised, .lowered:
                break
            }
        }
    }
}
