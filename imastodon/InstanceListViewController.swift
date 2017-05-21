import Foundation
import Eureka
import MastodonKit
import pencil

struct InstanceAccout: CustomReadWriteElement {
    var instance: Instance
    var account: Account

    static func read(from components: Components) -> InstanceAccout? {
        do {
            return try InstanceAccout(
                instance: components.component(for: "instance"),
                account: components.component(for: "account"))
        } catch {
            return nil
        }
    }
}

struct Instance {
    let uri: String
    let title: String
    let description: String
    let email: String
    let version: String?
}
extension Instance: CustomReadWriteElement {
    init(_ instance: MastodonKit.Instance) {
        self.init(
            uri: instance.uri,
            title: instance.title,
            description: instance.description,
            email: instance.email,
            version: instance.version)
    }

    public static func read(from components: Components) -> Instance? {
        do {
            return try Instance(
                uri: components.component(for: "uri"),
                title: components.component(for: "title"),
                description: components.component(for: "description"),
                email: components.component(for: "email"),
                version: components.component(for: "version"))
        } catch {
            return nil
        }
    }
}

public struct Account {
    let id: Int
    let username: String
    let acct: String
    let displayName: String
    let note: String
    let url: String
    let avatar: String
    let avatarStatic: String
    let header: String
    let headerStatic: String
    let locked: Bool
    let createdAt: Date
    let followersCount: Int
    let followingCount: Int
    let statusesCount: Int
}
extension Account: CustomReadWriteElement {
    init(_ account: MastodonKit.Account) {
        self.init(
            id: account.id,
            username: account.username,
            acct: account.acct,
            displayName: account.displayName,
            note: account.displayName,
            url: account.username,
            avatar: account.avatar,
            avatarStatic: account.avatarStatic,
            header: account.header,
            headerStatic: account.headerStatic,
            locked: account.locked,
            createdAt: account.createdAt,
            followersCount: account.followersCount,
            followingCount: account.followingCount,
            statusesCount: account.statusesCount)
    }

    public static func read(from components: Components) -> Account? {
        do {
            return try Account(
                id: components.component(for: "id"),
                username: components.component(for: "username"),
                acct: components.component(for: "acct"),
                displayName: components.component(for: "displayName"),
                note: components.component(for: "note"),
                url: components.component(for: "url"),
                avatar: components.component(for: "avatar"),
                avatarStatic: components.component(for: "avatarStatic"),
                header: components.component(for: "header"),
                headerStatic: components.component(for: "headerStatic"),
                locked: components.component(for: "locked"),
                createdAt: components.component(for: "createdAt"),
                followersCount: components.component(for: "followersCount"),
                followingCount: components.component(for: "followingCount"),
                statusesCount: components.component(for: "statusesCount"))
        } catch {
            return nil
        }
    }
}

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
