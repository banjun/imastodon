import UIKit
import Ikemen
import SVProgressHUD

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        SVProgressHUD.setDefaultMaskType(.black)

        window = UIWindow() ※ { w in
            let vc = ViewController()
            w.rootViewController = UINavigationController(rootViewController: vc)
            w.makeKeyAndVisible()
        }
        return true
    }
}

