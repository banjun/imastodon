import UIKit
import Ikemen
import MastodonKit
import SVProgressHUD

let imastodonBaseURL = "https://imastodon.net"

// NOTE: MastodonKit.ClientApplication is not initializable. copied same members.
struct ClientApplication {
    let id: Int
    let redirectURI: String
    let clientID: String
    let clientSecret: String
}
let imastodon_banjun_app = ClientApplication(
    id: 1231,
    redirectURI: "urn:ietf:wg:oauth:2.0:oob",
    clientID: "a2db619ba8742fdcd7e24c54b74d95466ba549daf67425201e5b91760530cb25",
    clientSecret: "2c0daeea7301ed87fa9b0514946a230891567b926ba1b5024b3f297610496db2")

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

