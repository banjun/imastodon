import UIKit
import Ikemen
import UserNotifications
import Kingfisher

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupNotifications()

        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 120 * 120 // avatar * 100

        guard #available(iOS 13, *) else {
            window = UIWindow() ※ { w in
                let vc = ViewController()
                w.rootViewController = UINavigationController(rootViewController: vc)
                w.makeKeyAndVisible()
            }
            return true
        }
        return true
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: nil, sessionRole: .windowApplication) ※ {$0.delegateClass = SceneDelegate.self}
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {_,_  in}
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}

