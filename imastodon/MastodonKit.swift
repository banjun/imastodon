import MastodonKit
import BrightFutures
import pencil

// stupid wrapper for MastodonKit

enum AppError: Error {
    case mastodonKit(Error)
    case mastodonKitNullPo
}

struct InstanceAccout: CustomReadWriteElement {
    var instance: Instance
    var account: Account
    var accessToken: String

    static func read(from components: Components) -> InstanceAccout? {
        do {
            return try InstanceAccout(
                instance: components.component(for: "instance"),
                account: components.component(for: "account"),
                accessToken: components.component(for: "accessToken"))
        } catch {
            return nil
        }
    }
}

// NOTE: MastodonKit.ClientApplication is not initializable. copied same members.
struct ClientApplication {
    let id: Int
    let redirectURI: String
    let clientID: String
    let clientSecret: String
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

extension Status {
    var textContent: String {
        return attributedTextContent?.string ?? content
    }

    var attributedTextContent: NSAttributedString? {
        guard let data = ("<style>body{font-size: 16px;} p {margin:0;padding:0;display:inline;}</style>" + content).data(using: .utf8),
            let at = try? NSMutableAttributedString(
                data: data,
                options: [
                    NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                    NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue],
                documentAttributes: nil) else { return nil }
        return at
    }
}

extension Client {
    convenience init(_ instanceAccount: InstanceAccout) {
        self.init(baseURL: "https://" + instanceAccount.instance.uri, accessToken: instanceAccount.accessToken)
    }
}

extension Client {
    func registerApp() -> Future<MastodonKit.ClientApplication, AppError> {
        let promise = Promise<MastodonKit.ClientApplication, AppError>()
        run(Clients.register(
            clientName: "iM@STODON-banjun",
            scopes: [.read, .write, .follow],
            website: "https://imastodon.banjun.jp/")) { app, error in
                if let error = error {
                    promise.failure(.mastodonKit(error))
                    return
                }
                guard let app = app else {
                    promise.failure(.mastodonKitNullPo)
                    return
                }

                print("id: \(app.id)")
                print("redirect uri: \(app.redirectURI)")
                print("client id: \(app.clientID)")
                print("client secret: \(app.clientSecret)")

                promise.success(app)
        }
        return promise.future
    }

    func login(app: MastodonKit.ClientApplication, email: String, password: String) -> Future<LoginSettings, AppError> {
        let promise = Promise<LoginSettings, AppError>()
        run(Login.silent(
            clientID: app.clientID,
            clientSecret: app.clientSecret,
            scopes: [.read, .write, .follow],
            username: email,
            password: password)) { settings, error in
                if let error = error {
                    promise.failure(.mastodonKit(error))
                    return
                }
                guard let settings = settings else {
                    promise.failure(.mastodonKitNullPo)
                    return
                }

                // update token on self
                self.accessToken = settings.accessToken
                promise.success(settings)
        }
        return promise.future
    }

    func currentUser() -> Future<Account, AppError> {
        let promise = Promise<Account, AppError>()
        run(Accounts.currentUser()) { account, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let account = account else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(Account(account))
        }
        return promise.future
    }

    func currentInstance() -> Future<Instance, AppError> {
        let promise = Promise<Instance, AppError>()
        run(Instances.current()) { instance, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let instance = instance else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(Instance(instance))
        }
        return promise.future
    }
}

extension Client {
    func home() -> Future<[Status], AppError> {
        let promise = Promise<[Status], AppError>()
        run(Timelines.home()) { statuses, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let statuses = statuses else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(statuses)
        }
        return promise.future
    }
}
