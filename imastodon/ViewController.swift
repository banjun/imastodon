import UIKit
import NorthLayout
import Ikemen
import Eureka

class ViewController: FormViewController {
    private var defaultTimelinesSection = Section()

    init() {
        super.init(style: .grouped)
        title = "iM@STODON"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "⚙️", style: .plain, target: self, action: #selector(showInstances))
        form +++ defaultTimelinesSection
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
    }

    @objc private func showInstances() {
        let vc = InstanceListViewController(instances: Store.shared.instanceAccounts)
        vc.onNewInstance = { instanceAccount in
            var store = Store.shared
            store.instanceAccounts.append(instanceAccount)
            store.writeToShared()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        let s = Store.shared

        defaultTimelinesSection.removeAll(keepingCapacity: true)
        defaultTimelinesSection.append(contentsOf: s.instanceAccounts.flatMap { i in
            [
                LabelRow {
                    $0.cellStyle = .subtitle
                    $0.title = "Home"
                    $0.value = "\(i.instance.title) \(i.account.displayName)"
                    }.onCellSelection {[unowned self] _ in self.showHomeTimeline(i)},
                LabelRow {
                    $0.cellStyle = .subtitle
                    $0.title = "Local"
                    $0.value = "\(i.instance.title) \(i.account.displayName)"
                    }.onCellSelection {[unowned self] _ in self.showLocalTimeline(i)}]
        })
    }

    private func showHomeTimeline(_ instanceAccount: InstanceAccout) {
        let vc = HomeViewController(instanceAccount: instanceAccount)
        show(vc, sender: self)
    }

    private func showLocalTimeline(_ instanceAccount: InstanceAccout) {
        let vc = LocalViewController(instanceAccount: instanceAccount)
        show(vc, sender: self)
    }
}
