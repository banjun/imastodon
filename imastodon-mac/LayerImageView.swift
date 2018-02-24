import Cocoa
import Kingfisher

/// NSImageView alternative supporting content mode
final class LayerImageView: NSView, KingfisherCompatible {
    enum ContentMode {
        case scaleAspectFill

        var rawValue: String {
            switch self {
            case .scaleAspectFill: return kCAGravityResizeAspectFill
            }
        }
    }

    var image: NSImage? {
        get {return layer?.contents as? NSImage}
        set {layer?.contents = newValue}
    }

    init(contentMode: ContentMode) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contentsGravity = contentMode.rawValue
    }

    required init?(coder decoder: NSCoder) {fatalError("init(coder:) has not been implemented")}
}

extension Kingfisher where Base: LayerImageView {
    func setImage(with resource: Resource) {
        KingfisherManager.shared.retrieveImage(with: resource, options: nil, progressBlock: nil, completionHandler: { [weak base] image, error, cacheType, url in
            base?.layer?.contents = image
        })
    }
}

