import UIKit
import MBProgressHUD

enum HUD {
    static func show(inWindowFor vc: UIViewController) {
        guard let window = vc.view.window else { return }
        MBProgressHUD.showAdded(to: window, animated: true)
    }

    static func hide(inWindowFor vc: UIViewController) {
        guard let window = vc.view.window else { return }
        MBProgressHUD.hide(for: window, animated: true)
    }
}

extension UIViewController {
    func showHUD() {
        HUD.show(inWindowFor: self)
    }

    func dismissHUD() {
        HUD.hide(inWindowFor: self)
    }
}
