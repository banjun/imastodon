import MastodonKit
import BrightFutures
import pencil
import Himotoki
import Foundation

// stupid wrapper for MastodonKit

enum AppError: Error {
    case mastodonKit(Error)
    case eventstream(Error?)
    case mastodonKitNullPo

    var localizedDescription: String {
        switch self {
        case let .mastodonKit(e): return "AppError.mastodonKit(\(e.localizedDescription))"
        case let .eventstream(e): return "AppError.eventstream(\(e?.localizedDescription ?? ""))"
        case .mastodonKitNullPo: return "AppError.mastodonKitNullPo"
        }
    }
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
extension Instance {
    var baseURL: URL? {return URL(string: "https://" + uri)}
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
            note: account.note,
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
extension Account: Decodable {
    public static func decode(_ e: Extractor) throws -> Account {
        return try Account(
            id: e <| "id",
            username: e <| "username",
            acct: e <| "acct",
            displayName: e <| "display_name",
            note: e <| "note",
            url: e <| "url",
            avatar: e <| "avatar",
            avatarStatic: e <| "avatar_static",
            header: e <| "header",
            headerStatic: e <| "header_static",
            locked: e <| "locked",
            createdAt: DateTransformer.apply(e <| "created_at"),
            followersCount: e <| "followers_count",
            followingCount: e <| "following_count",
            statusesCount: e <| "statuses_count")
    }
}
extension Account {
    func avatarURL(baseURL: URL) -> URL? {
        return URL(string: avatar, relativeTo: baseURL)
    }
}

// copy and paste -ed for visibility issue at MastodonKit
struct Status {
    /// The ID of the status.
    public let id: Int
    /// A Fediverse-unique resource ID.
    public let uri: String
    /// URL to the status page (can be remote).
    public let url: URL
    /// The Account which posted the status.
    public let account: Account
    /// null or the ID of the status it replies to.
    public let inReplyToID: Int?
    /// null or the ID of the account it replies to.
    public let inReplyToAccountID: Int?
    /// Body of the status; this will contain HTML (remote HTML already sanitized).
    public let content: String
    /// The time the status was created.
    public let createdAt: Date
    /// The number of reblogs for the status.
    public let reblogsCount: Int
    /// The number of favourites for the status.
    public let favouritesCount: Int
    /// Whether the authenticated user has reblogged the status.
    public let reblogged: Bool?
    /// Whether the authenticated user has favourited the status.
    public let favourited: Bool?
    /// Whether media attachments should be hidden by default.
    public let sensitive: Bool?
    /// If not empty, warning text that should be displayed before the actual content.
    public let spoilerText: String
    /// The visibility of the status.
    public let visibility: Visibility
    /// An array of attachments.
    public let mediaAttachments: [Attachment]
    /// An array of mentions.
    public let mentions: [Mention]
    /// An array of tags.
    public let tags: [Tag]
    /// Application from which the status was posted.
    public let application: Application?
    /// The reblogged Status
    public var reblog: Status? {
        return reblogWrapper.first?.flatMap { $0 }
    }

    var reblogWrapper: [Status?]
}

let URLTransformer = Transformer<String, URL> { URLString throws -> URL in
    if let URL = URL(string: URLString) {
        return URL
    }

    throw customError("Invalid URL string: \(URLString)")
}

let DateTransformer = Transformer<String, Date> { dateString throws -> Date in
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime] // handle milliseconds
    guard let date = formatter.date(from: dateString) else {
        throw customError("Invalid date string: \(dateString)")
    }
    return date
}

let VisibilityTransformer = Transformer<String, Visibility> { s throws -> Visibility in
    guard let v = Visibility(rawValue: s) else {
        throw customError("Invalid Visibility string: \(s)")
    }
    return v
}

let AttachmentTypeTransformer = Transformer<String, AttachmentType> { s throws -> AttachmentType in
    switch s {
    case "image": return .image
    case "video": return .video
    case "gifv": return .gifv
    default: return .unknown
    }
}

let NotificationTypeTransformer = Transformer<String, NotificationType> { s throws -> NotificationType in
    switch s {
    case "mention": return .mention
    case "reblog": return .reblog
    case "favourite": return .favourite
    case "follow": return .follow
    default: return .unknown
    }
}

struct Attachment {
    /// ID of the attachment.
    public let id: Int
    /// Type of the attachment.
    public let type: AttachmentType
    /// URL of the locally hosted version of the image.
    public let url: String
    /// For remote images, the remote URL of the original image.
    public let remoteURL: String?
    /// URL of the preview image.
    public let previewURL: String
    /// Shorter URL for the image, for insertion into text (only present on local images).
    public let textURL: String?
}
extension Attachment: Decodable {
    public static func decode(_ e: Extractor) throws -> Attachment {
        return try Attachment(
            id: e <| "id",
            type: AttachmentTypeTransformer.apply(e <| "type"),
            url: e <| "url",
            remoteURL: e <|? "remote_url",
            previewURL: e <| "preview_url",
            textURL: e <|? "text_url")
    }
    init(_ a: MastodonKit.Attachment) {
        self.init(id: a.id, type: a.type, url: a.url, remoteURL: a.remoteURL, previewURL: a.previewURL, textURL: a.textURL)
    }
}

public struct Mention {
    /// Account ID.
    public let id: Int
    /// The username of the account.
    public let username: String
    /// Equals username for local users, includes @domain for remote ones.
    public let acct: String
    /// URL of user's profile (can be remote).
    public let url: String
}
extension Mention: Decodable {
    public static func decode(_ e: Extractor) throws -> Mention {
        return try Mention(
            id: e <| "id",
            username: e <| "username",
            acct: e <| "acct",
            url: e <| "url")
    }
    init(_ m: MastodonKit.Mention) {
        self.init(id: m.id, username: m.username, acct: m.acct, url: m.url)
    }
}

public struct Tag {
    /// The hashtag, not including the preceding #.
    public let name: String
    /// The URL of the hashtag.
    public let url: String
}
extension Tag: Decodable {
    public static func decode(_ e: Extractor) throws -> Tag {
        return try Tag(
            name: e <| "name",
            url: e <| "url")
    }
    init(_ t: MastodonKit.Tag) {
        self.init(name: t.name, url: t.url)
    }
}

public struct Application {
    /// Name of the app.
    public let name: String
    /// Homepage URL of the app.
    public let website: String?
}
extension Application: Decodable {
    public static func decode(_ e: Extractor) throws -> Application {
        return try Application(
            name: e <| "name",
            website: e <|? "website")
    }
    init(_ a: MastodonKit.Application) {
        self.init(name: a.name, website: a.website)
    }
}

struct Notification {
    /// The notification ID.
    public let id: Int
    /// The notification type.
    public let type: NotificationType
    /// The time the notification was created.
    public let createdAt: Date
    /// The Account sending the notification to the user.
    public let account: Account
    /// The Status associated with the notification, if applicable.
    public let status: Status?
}
extension Notification: Decodable {
    public static func decode(_ e: Extractor) throws -> Notification {
        return try Notification(
            id: e <| "id",
            type: NotificationTypeTransformer.apply(e <| "type"),
            createdAt: DateTransformer.apply(e <| "created_at"),
            account: e <| "account",
            status: e <|? "status")
    }
    init(_ n: MastodonKit.Notification) {
        self.init(id: n.id, type: n.type, createdAt: n.createdAt, account: Account(n.account), status: n.status.map {Status($0)})
    }
}

extension Status: Decodable {
    static func decode(_ e: Extractor) throws -> Status {
        return try Status(
            id: e <| "id",
            uri: e <| "uri",
            url: URLTransformer.apply(e <| "url"),
            account: e <| "account",
            inReplyToID: e <|? "in_reply_to_id",
            inReplyToAccountID: e <|? "in_reply_to_account_id",
            content: e <| "content",
            createdAt: DateTransformer.apply(e <| "created_at"),
            reblogsCount: e <| "reblogs_count",
            favouritesCount: e <| "favourites_count",
            reblogged: e <|? "reblogged",
            favourited: e <|? "favourited",
            sensitive: e <|? "sensitive",
            spoilerText: e <| "spoiler_text",
            visibility: VisibilityTransformer.apply(e <| "visibility"),
            mediaAttachments: e <|| "media_attachments",
            mentions: e <|| "mentions",
            tags: e <|| "tags",
            application: e <|? "application",
            reblogWrapper: [])
    }
}
extension Status {
    init(_ status: MastodonKit.Status) {
        self.init(id: status.id, uri: status.uri, url: status.url, account: Account(status.account), inReplyToID: status.inReplyToID, inReplyToAccountID: status.inReplyToAccountID, content: status.content, createdAt: status.createdAt, reblogsCount: status.reblogsCount, favouritesCount: status.favouritesCount, reblogged: status.reblogged, favourited: status.favourited, sensitive: status.sensitive, spoilerText: status.spoilerText, visibility: status.visibility, mediaAttachments: status.mediaAttachments.map {Attachment($0)}, mentions: status.mentions.map {Mention($0)}, tags: status.tags.map {Tag($0)}, application: status.application.map {Application($0)}, reblogWrapper: [])
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
        self.init(baseURL: instanceAccount.instance.baseURL?.absoluteString ?? "", accessToken: instanceAccount.accessToken)
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
            promise.success(statuses.map {Status($0)})
        }
        return promise.future
    }

    func local() -> Future<[Status], AppError> {
        let promise = Promise<[Status], AppError>()
        run(Timelines.public(local: true)) { statuses, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let statuses = statuses else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(statuses.map {Status($0)})
        }
        return promise.future
    }
}

extension Client {
    func post(message: String) -> Future<Status, AppError> {
        let promise = Promise<Status, AppError>()
        run(Statuses.create(
            status: message,
            replyToID: nil,
            mediaIDs: [],
            sensitive: false,
            spoilerText: nil,
            visibility: .`public`)) { status, error in
                if let error = error {
                    promise.failure(.mastodonKit(error))
                    return
                }
                guard let status = status else {
                    promise.failure(.mastodonKitNullPo)
                    return
                }
                promise.success(Status(status))
        }
        return promise.future
    }
}
