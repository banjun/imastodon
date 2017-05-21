import Foundation
import Eureka
import SVProgressHUD
import MastodonKit

class LocalViewController: FormViewController {
    let instanceAccount: InstanceAccout
    private var timelineSection = Section()

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(style: .plain)
        title = "Local@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        form +++ timelineSection
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        fetch()
    }

    private func fetch() {
        SVProgressHUD.show()
        Client(instanceAccount).local()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.timelineSection.removeAll(keepingCapacity: true)
                self.timelineSection.append(contentsOf: statuses.map { s in
                    StatusRow {$0.value = s}
                })
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }
}
