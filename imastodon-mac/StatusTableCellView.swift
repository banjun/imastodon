import Cocoa
import Ikemen
import NorthLayout
import Kingfisher
import API
import ReactiveCocoa
import ReactiveSwift

final class StatusTableCellView: NSTableCellView, NibLessLoadable {
    private let spoilerText = MutableProperty<String>("")
    private lazy var hasSpoiler = Property<Bool>(capturing: spoilerText.map {!$0.isEmpty})
    private let showsSpoiler = MutableProperty<Bool>(false)

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
    let spoilerLabel = AutolayoutLabel() ※ { l in
        l.wantsLayer = false // draw to cellview layer
        l.font = .systemFont(ofSize: 15)
        l.isBezeled = false
        l.drawsBackground = false
        l.lineBreakMode = .byWordWrapping
        l.cell?.truncatesLastVisibleLine = true
        l.maximumNumberOfLines = 0
    }
    let spoilerButton = NSButton() ※ { b in
        b.wantsLayer = false // draw to cellview layer
        b.title = "More"
        b.alternateTitle = "Hide"
        b.setButtonType(.toggle)
        b.bezelStyle = .recessed
        b.isBordered = true
    }
    let bodyLabel = AutolayoutLabel() ※ { l in
        l.wantsLayer = false // draw to cellview layer
        l.font = .systemFont(ofSize: 15)
        l.isBezeled = false
        l.drawsBackground = false
        l.lineBreakMode = .byWordWrapping
        l.cell?.truncatesLastVisibleLine = true
        l.maximumNumberOfLines = 0
        l.cell?.isScrollable = false
    }
    let contentStackView = NSStackView() ※ { s in
        s.wantsLayer = false // draw to cellview layer
        s.orientation = .vertical
        s.alignment = .left
        s.distribution = .equalSpacing
        s.spacing = 4
        s.edgeInsets.bottom = s.spacing
    }
    let attachmentStackView = NSStackView() ※ { s in
        s.wantsLayer = false // draw to cellview layer
        s.orientation = .horizontal
        s.distribution = .fillEqually
        s.spacing = 4
        s.heightAnchor.constraint(equalToConstant: 128).isActive = true
    }

    init() {
        super.init(frame: .zero)

        // draw contents into single layer
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        canDrawSubviewsIntoLayer = true

        let autolayout = northLayoutFormat([:], [
            "icon": iconView,
            "content": contentStackView ※ { s in
                ([nameLabel, spoilerLabel, spoilerButton, bodyLabel, attachmentStackView] as [NSView]).forEach {
                    s.addArrangedSubview($0)
                    $0.setContentCompressionResistancePriority(.required, for: .vertical)
                    $0.setContentHuggingPriority(.required, for: .vertical)
                }
                [nameLabel, spoilerLabel, bodyLabel, attachmentStackView].forEach {
                    s.widthAnchor.constraint(equalTo: $0.widthAnchor).isActive = true
                }
                s.setHuggingPriority(.required, for: .vertical)
            },
            "spacer": MinView() ※ {$0.setContentHuggingPriority(.init(rawValue: 751) , for: .vertical)}]) // should cause shrink on click more/hide
        autolayout("H:|-4-[icon(==48)]-4-[content]|")
        autolayout("V:|-4-[icon(==48)]-(>=4)-|")
        autolayout("V:|[content][spacer]|")
        autolayout("H:|[spacer]|") // suppress ambiguous warning in view debugger

        spoilerLabel.reactive.stringValue <~ spoilerText
        spoilerLabel.reactive[\.isHidden] <~ hasSpoiler.negate()
        spoilerButton.reactive[\.isHidden] <~ hasSpoiler.negate()
        spoilerButton.reactive.state <~ showsSpoiler.map {$0 ? .on : .off}
        showsSpoiler <~ spoilerButton.reactive.boolValues
        bodyLabel.reactive[\.isHidden] <~ hasSpoiler.and(showsSpoiler.negate())
    }

    required init?(coder decoder: NSCoder) {fatalError()}

    func setStatus(_ status: Status, baseURL: URL?) {
        nameLabel.stringValue = status.account.displayNameOrUserName
        bodyLabel.stringValue = status.textContent
        spoilerText.value = status.spoiler_text
        showsSpoiler.value = false
        if let avatarURL = (baseURL.flatMap {status.account.avatarURL(baseURL: $0)}) {
            iconView.kf.setImage(with: avatarURL)
        }

        let attachments = status.media_attachments
        attachmentStackView.isHidden = attachments.isEmpty
        attachmentStackView.views.reversed().forEach { v in
            attachmentStackView.removeView(v)
        }
        attachments
            .flatMap {URL(string: $0.preview_url)}
            .map {url in LayerImageView(contentMode: .scaleAspectFill) ※ {
                $0.layer?.cornerRadius = 4
                $0.layer?.masksToBounds = true
                $0.kf.setImage(with: url)
                }}
            .forEach { v in
                attachmentStackView.addArrangedSubview(v)
                v.heightAnchor.constraint(equalTo: attachmentStackView.heightAnchor).isActive = true
                v.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
                v.setContentHuggingPriority(.fittingSizeCompression, for: .vertical)
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            switch backgroundStyle {
            case .dark:
                [nameLabel, spoilerLabel, bodyLabel].forEach {$0.textColor = .white}
            case .light:
                nameLabel.textColor = .gray
                spoilerLabel.textColor = .black
                bodyLabel.textColor = .black
            case .raised, .lowered:
                break
            }
        }
    }
}
