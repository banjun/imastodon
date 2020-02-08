import UIKit

enum ThemeColor {
    static let background: UIColor = {
        guard #available(iOS 13.0, *) else { return .white }
        return .systemBackground
    }()

    static let secondaryBackground: UIColor = {
        guard #available(iOS 13.0, *) else { return .lightGray }
        return .secondarySystemBackground
    }()

    static let label: UIColor = {
        guard #available(iOS 13.0, *) else { return .black }
        return .label
    }()

    static let secondaryLabel: UIColor = {
        guard #available(iOS 13.0, *) else { return .darkGray }
        return .secondaryLabel
    }()
}
