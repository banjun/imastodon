import Foundation
import Eureka
import SVProgressHUD
import MastodonKit

class HomeViewController: FormViewController {
    let instanceAccount: InstanceAccout
    private var timelineSection = Section()

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(style: .plain)
        title = "Home@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        form +++ timelineSection
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.showsVerticalScrollIndicator = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        fetch()
    }

    private func fetch() {
        SVProgressHUD.show()
        Client(instanceAccount).home()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.timelineSection.removeAll(keepingCapacity: true)
                self.timelineSection.append(contentsOf: statuses.map { s in
                    StatusRow {$0.value = s}
                        .onCellSelection { [unowned self] cell, row in self.didTap(status: s, cell: cell, row: row)}
                })
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    private func didTap(status: Status, cell: BaseCell, row: BaseRow) {
        let ac = UIAlertController(actionFor: status,
                                   safari: {[unowned self] in self.show($0, sender: nil)},
                                   boost: {},
                                   favorite: {})
        present(ac, animated: true)
    }
}
