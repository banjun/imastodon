import Cocoa
import Kingfisher

/// NSImageView alternative supporting content mode
final class LayerImageView: NSView, KingfisherCompatible {
    var image: NSImage? {
        get {return layer?.contents as? NSImage}
        set {layer?.contents = newValue}
    }

    init(contentMode: CALayerContentsGravity) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contentsGravity = contentMode
    }

    required init?(coder decoder: NSCoder) {fatalError("init(coder:) has not been implemented")}
}

extension KingfisherWrapper where Base: LayerImageView {
    func setImage(with resource: Resource) {
        KingfisherManager.shared.retrieveImage(with: resource) { [weak base] r in
            base?.layer?.contents = r.value?.image
        }
    }
}
