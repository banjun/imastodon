import UIKit
import Ikemen

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow() ※ { w in
            let vc = ViewController()
            w.rootViewController = UINavigationController(rootViewController: vc)
            w.makeKeyAndVisible()
        }
        return true
    }
}

