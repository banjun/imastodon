import Cocoa

final class IconView: NSImageView {
    init() {
        super.init(frame: .zero)
        animates = false // heavy GIF performance
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {fatalError()}

    override func updateLayer() {
        // just overriding cause better image interpolation quality
        super.updateLayer()
    }
}
