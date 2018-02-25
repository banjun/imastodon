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
    let attachmentStackView = AttachmentStackView() ※ { s in
        s.orientation = .horizontal
        s.distribution = .fillEqually
        s.spacing = 2
        s.edgeInsets.right = 2
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
        attachmentStackView.reactive.attachmentURLs.action(
            attachments.flatMap {URL(string: $0.preview_url)})
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

final class AttachmentStackView: NSStackView {
    let attachmentViews: [LayerImageView] = [.init(contentMode: .scaleAspectFill),
                                             .init(contentMode: .scaleAspectFill),
                                             .init(contentMode: .scaleAspectFill),
                                             .init(contentMode: .scaleAspectFill)]
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        canDrawSubviewsIntoLayer = true
        attachmentViews.forEach { v in
            v.isHidden = true
            addArrangedSubview(v)
            v.layer?.cornerRadius = 4
            v.layer?.masksToBounds = true
            v.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
            v.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
        }
    }
    required init?(coder decoder: NSCoder) {fatalError("init(coder:) has not been implemented")}
}

extension Reactive where Base: AttachmentStackView {
    var attachmentURLs: BindingTarget<[URL]> {
        return makeBindingTarget { base, urls in
            base.attachmentViews.enumerated().forEach { i, v in
                if let url = i < urls.count ? urls[i] : nil {
                    v.kf.setImage(with: url)
                    v.isHidden = false
                } else {
                    v.image = nil
                    v.isHidden = true
                }
            }
        }
    }
}
