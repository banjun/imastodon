import Foundation
import APIKit
import URITemplate

protocol URITemplateContextConvertible: Encodable {}
extension URITemplateContextConvertible {
    var context: [String: String] {
        return ((try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self))) as? [String: String]) ?? [:]
    }
}

public enum RequestError: Error {
    case encode
}

public enum ResponseError: Error {
    case undefined(Int, String?)
    case invalidData(Int, String?)
}

struct RawDataParser: DataParser {
    var contentType: String? {return nil}
    func parse(data: Data) -> Any { return data }
}

struct TextBodyParameters: BodyParameters {
    let contentType: String
    let content: String
    func buildEntity() throws -> RequestBodyEntity {
        guard let r = content.data(using: .utf8) else { throw RequestError.encode }
        return .data(r)
    }
}

public protocol APIBlueprintRequest: Request {}
extension APIBlueprintRequest {
    public var dataParser: DataParser {return RawDataParser()}

    func contentMIMEType(in urlResponse: HTTPURLResponse) -> String? {
        return (urlResponse.allHeaderFields["Content-Type"] as? String)?.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
    }

    func data(from object: Any, urlResponse: HTTPURLResponse) throws -> Data {
        guard let d = object as? Data else {
            throw ResponseError.invalidData(urlResponse.statusCode, contentMIMEType(in: urlResponse))
        }
        return d
    }

    func string(from object: Any, urlResponse: HTTPURLResponse) throws -> String {
        guard let s = String(data: try data(from: object, urlResponse: urlResponse), encoding: .utf8) else {
            throw ResponseError.invalidData(urlResponse.statusCode, contentMIMEType(in: urlResponse))
        }
        return s
    }

    func decodeJSON<T: Decodable>(from object: Any, urlResponse: HTTPURLResponse) throws -> T {
        return try JSONDecoder().decode(T.self, from: data(from: object, urlResponse: urlResponse))
    }
}

protocol URITemplateRequest: Request {
    static var pathTemplate: URITemplate { get }
    associatedtype PathVars: URITemplateContextConvertible
    var pathVars: PathVars { get }
}
extension URITemplateRequest {
    // reconstruct URL to use URITemplate.expand. NOTE: APIKit does not support URITemplate format other than `path + query`
    public func intercept(urlRequest: URLRequest) throws -> URLRequest {
        var req = urlRequest
        req.url = URL(string: baseURL.absoluteString + type(of: self).pathTemplate.expand(pathVars.context))!
        return req
    }
}

/// indirect Codable Box-like container for recursive data structure definitions
public class Indirect<V: Codable>: Codable {
    public var value: V

    public init(_ value: V) {
        self.value = value
    }

    public required init(from decoder: Decoder) throws {
        self.value = try V(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - Transitions


struct GetInstance: APIBlueprintRequest {
    let baseURL: URL
    var method: HTTPMethod {return .get}

    var path: String {return "/api/v1/instance"}

    enum Responses {
        case http200_(Instance)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct GetCurrentUser: APIBlueprintRequest {
    let baseURL: URL
    var method: HTTPMethod {return .get}

    var path: String {return "/api/v1/accounts/verify_credentials"}

    enum Responses {
        case http200_(Account)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct RegisterApp: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/apps{?client_name,redirect_uris,scopes,website}"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// Name of your application
        var client_name: String
        /// Where the user should be redirected after authorization (for no redirect, use `urn:ietf:wg:oauth:2.0:oob`)
        var redirect_uris: String
        /// This can be a space-separated list of the following items: "read", "write" and "follow" (see [this page](OAuth-details.md) for details on what the scopes do)
        var scopes: String
        /// URL to the homepage of your app
        var website: String?
    }

    enum Responses {
        case http200_(ClientApplication)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct LoginSilent: APIBlueprintRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    var path: String {return "/oauth/token"}

    let param: Param
    var bodyParameters: BodyParameters? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? JSONBodyParameters(JSONObject: JSONSerialization.jsonObject(with: encoder.encode(param)))
    }
    struct Param: Codable { 
        /// 
        var client_id: String
        /// 
        var client_secret: String
        /// 
        var scope: String
        /// 
        var grant_type: String
        /// 
        var username: String
        /// 
        var password: String
    }
    enum Responses {
        case http200_(LoginSettings)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct GetHomeTimeline: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .get}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/timelines/home{?max_id,since_id,limit}"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// Get a list of timelines with ID less than this value
        var max_id: String?
        /// Get a list of timelines with ID greater than this value
        var since_id: String?
        /// Maximum number of statuses on the requested timeline to get (Default 20, Max 40)
        var limit: String?
    }

    enum Responses {
        case http200_(Timelines)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct GetPublicTimeline: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .get}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/timelines/public{?local,max_id,since_id,limit}"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// Only return statuses originating from this instance (public and tag timelines only)
        var local: String?
        /// Get a list of timelines with ID less than this value
        var max_id: String?
        /// Get a list of timelines with ID greater than this value
        var since_id: String?
        /// Maximum number of statuses on the requested timeline to get (Default 20, Max 40)
        var limit: String?
    }

    enum Responses {
        case http200_(Timelines)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct Boost: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}/reblog"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// 
        var id: String
    }

    enum Responses {
        case http200_(Status)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct Favorite: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}/favourite"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// 
        var id: String
    }

    enum Responses {
        case http200_(Status)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


struct PostStatus: APIBlueprintRequest, URITemplateRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses{?status,in_reply_to_id,media_ids,sensitive,spoiler_text,visibility}"
    var pathVars: PathVars
    struct PathVars: URITemplateContextConvertible {
        /// The text of the status
        var status: String
        /// local ID of the status you want to reply to
        var in_reply_to_id: String?
        /// Array of media IDs to attach to the status (maximum 4)
        var media_ids: String?
        /// Set this to mark the media of the status as NSFW
        var sensitive: String?
        /// Text to be shown as a warning before the actual content
        var spoiler_text: String?
        /// Either "direct", "private", "unlisted" or "public"
        var visibility: String?
    }

    enum Responses {
        case http200_(Status)
    }

    func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


// MARK: - Data Structures

struct Instance: Codable { 
    /// URI of the current instance
    var uri: String
    /// The instance's title
    var title: String
    /// A description for the instance
    var description: String
    /// An email address which can be used to contact the instance administrator
    var email: String
    /// The Mastodon version used by instance
    var version: String?
}

struct Account: Codable { 
    /// The ID of the account  ex. ID
    var id: ID
    /// The username of the account
    var username: String
    /// Equals `username` for local users, includes `@domain` for remote ones
    var acct: String
    /// The account's display name
    var display_name: String
    /// Boolean for when the account cannot be followed without waiting for approval first  ex. boolean
    var locked: Bool
    /// The time the account was created
    var created_at: String
    /// The number of followers for the account
    var followers_count: Int
    /// The number of accounts the given account is following
    var following_count: Int
    /// The number of statuses the account has made
    var statuses_count: Int
    /// Biography of user
    var note: String
    /// URL of the user's profile page (can be remote)
    var url: String
    /// URL to the avatar image
    var avatar: String
    /// URL to the avatar static image (gif)
    var avatar_static: String
    /// URL to the header image
    var header: String
    /// URL to the header static image (gif)
    var header_static: String
}

struct Status: Codable { 
    /// The ID of the status  ex. ID
    var id: ID
    /// A Fediverse-unique resource ID
    var uri: String
    /// URL to the status page (can be remote). NOTE: non-optional. occasionaly null in real world (around mastodon 2?). should be fatal bug in server.
    var url: String?
    /// The [Account](#account) which posted the status  ex. Account
    var account: Account
    /// `null` or the ID of the status it replies to  ex. ID
    var in_reply_to_id: ID?
    /// `null` or the ID of the account it replies to  ex. ID
    var in_reply_to_account_id: ID?
    /// `null` or the reblogged [Status](#status)  ex. Status
    var reblog: Indirect<Status>?
    /// Body of the status; this will contain HTML (remote HTML already sanitized)
    var content: String
    /// The time the status was created
    var created_at: String
    /// The number of reblogs for the status
    var reblogs_count: Int
    /// The number of favourites for the status
    var favourites_count: Int
    /// Whether the authenticated user has reblogged the status  ex. boolean
    var reblogged: Bool?
    /// Whether the authenticated user has favourited the status  ex. boolean
    var favourited: Bool?
    /// Whether media attachments should be hidden by default  ex. boolean
    var sensitive: Bool?
    /// If not empty, warning text that should be displayed before the actual content
    var spoiler_text: String
    /// One of: `public`, `unlisted`, `private`, `direct`
    var visibility: String
    /// An array of [Attachments](#attachment)  ex. []
    var media_attachments: [Attachment]
    /// An array of [Mentions](#mention)  ex. []
    var mentions: [Mention]
    /// An array of [Tags](#tag)  ex. []
    var tags: [Tag]
    /// [Application](#application) from which the status was posted  ex. Application
    var application: Application?
    /// The detected language for the status (default: en)
    var language: String?
}

struct Application: Codable { 
    /// Name of the app
    var name: String
    /// Homepage URL of the app
    var website: String?
}

struct Tag: Codable { 
    /// The hashtag, not including the preceding `#`
    var name: String
    /// The URL of the hashtag
    var url: String
}

struct Mention: Codable { 
    /// URL of user's profile (can be remote)
    var url: String
    /// The username of the account
    var username: String
    /// Equals `username` for local users, includes `@domain` for remote ones
    var acct: String
    /// Account ID  ex. ID
    var id: ID
}

struct Attachment: Codable { 
    /// ID of the attachment  ex. ID
    var id: ID
    /// One of: "image", "video", "gifv"
    var type: String
    /// URL of the locally hosted version of the image
    var url: String
    /// For remote images, the remote URL of the original image
    var remote_url: String?
    /// URL of the preview image
    var preview_url: String
    /// Shorter URL for the image, for insertion into text (only present on local images)
    var text_url: String?
}

struct Notification: Codable { 
    /// The notification ID  ex. ID
    var id: ID
    /// One of: "mention", "reblog", "favourite", "follow"
    var type: String
    /// The time the notification was created
    var created_at: String
    /// The [Account](#account) sending the notification to the user  ex. Account
    var account: Account
    /// The [Status](#status) associated with the notification, if applicable  ex. Status
    var status: Status?
}

struct ClientApplication: Codable { 
    ///  ex. ID
    var id: ID
    /// 
    var redirect_uri: String
    /// 
    var client_id: String
    /// 
    var client_secret: String
}

struct LoginSettings: Codable { 
    /// 
    var access_token: String
    /// 
    var token_type: String
    /// 
    var scope: String
    /// only here: UNIX timestamp
    var created_at: Int
}

struct ID: Codable { 
    /// actual id value
    var value: String
}

