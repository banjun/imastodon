import Foundation
import Eureka

class InstanceListViewController: FormViewController {
    private var instances: [InstanceAccout] {didSet {reload()}}
    var onNewInstance: ((InstanceAccout) -> Void)?

    private var instancesSection = Section()

    init(instances: [InstanceAccout]) {
        self.instances = instances
        super.init(style: .grouped)
        title = "Instances"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        form +++ instancesSection +++ Section()
            <<< ButtonRow() {$0.title = "Login to Another Instance"}
                .onCellSelection {[unowned self] _ in self.login()}
        reload()
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    private func reload() {
        instancesSection.removeAll(keepingCapacity: true)
        instancesSection.append(contentsOf: instances.map { i in
            LabelRow() {
                $0.title = i.instance.title
                $0.value = i.account.username
            }
        })
        instancesSection.footer = HeaderFooterView(title: "\(instances.count) instances")
        instancesSection.reload()
    }

    private func login() {
        let vc = LoginViewController()
        vc.onNewInstance = { [unowned self] in
            self.instances.append($0)
            self.onNewInstance?($0)
            self.dismiss(animated: true)
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func done() {
        self.dismiss(animated: true)
    }
}
