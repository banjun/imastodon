import UIKit
import Ikemen
import SVProgressHUD
import UserNotifications
import Kingfisher

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupNotifications()
        window = UIWindow() ※ { w in
            let vc = ViewController()
            w.rootViewController = UINavigationController(rootViewController: vc)
            w.makeKeyAndVisible()
        }
        SVProgressHUD.setDefaultMaskType(.black)

        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 120 * 120 // avatar * 100

        return true
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {_,_  in}
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}

