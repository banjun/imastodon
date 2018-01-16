import Cocoa

final class AutolayoutLabel: NSTextField {
    init() {
        super.init(frame: .zero)
        setupAutolayoutable()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAutolayoutable()
    }

    private func setupAutolayoutable() {
        // NOTE: preferredMaxLayoutWidth should be set as desired
        isEditable = false // makes multiline intrinsic content size work
        maximumNumberOfLines = 0 // multiline
    }
}
