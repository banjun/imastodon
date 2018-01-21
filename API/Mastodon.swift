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


public struct GetInstance: APIBlueprintRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public var path: String {return "/api/v1/instance"}

    public enum Responses {
        case http200_(Instance)
    }

    // public memberwise init
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetAccount: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/accounts/{id}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String

        // public memberwise init
        public init(id: String) {
            self.id = id
        }
    }

    public enum Responses {
        case http200_(Account)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetCurrentUser: APIBlueprintRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public var path: String {return "/api/v1/accounts/verify_credentials"}

    public enum Responses {
        case http200_(Account)
    }

    // public memberwise init
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetAccountsStatuses: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/accounts/{id}/statuses{?only_media,pinned,exclude_replies,max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String
        /// Only return statuses that have media attachments
        public var only_media: String?
        /// Only return statuses that are pinned to the account
        public var pinned: String?
        /// Skip statuses that reply to other statuses
        public var exclude_replies: String?
        /// Get a list of statuses with ID less than this value
        public var max_id: String?
        /// Get a list of statuses with ID greater than this value
        public var since_id: String?
        /// Maximum number of statuses to get (Default 20, Max 40)
        public var limit: String?

        // public memberwise init
        public init(id: String, only_media: String?, pinned: String?, exclude_replies: String?, max_id: String?, since_id: String?, limit: String?) {
            self.id = id
            self.only_media = only_media
            self.pinned = pinned
            self.exclude_replies = exclude_replies
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Timelines)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetFollowers: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/accounts/{id}/followers{?max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String
        /// Get a list of followings with ID less than this value
        public var max_id: String?
        /// Get a list of followings with ID greater than this value
        public var since_id: String?
        /// Maximum number of followings to get (Default 40, Max 80)
        public var limit: String?

        // public memberwise init
        public init(id: String, max_id: String?, since_id: String?, limit: String?) {
            self.id = id
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Accounts)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetFollowings: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/accounts/{id}/following{?max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String
        /// Get a list of followings with ID less than this value
        public var max_id: String?
        /// Get a list of followings with ID greater than this value
        public var since_id: String?
        /// Maximum number of followings to get (Default 40, Max 80)
        public var limit: String?

        // public memberwise init
        public init(id: String, max_id: String?, since_id: String?, limit: String?) {
            self.id = id
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Accounts)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct RegisterApp: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/apps{?client_name,redirect_uris,scopes,website}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// Name of your application
        public var client_name: String
        /// Where the user should be redirected after authorization (for no redirect, use `urn:ietf:wg:oauth:2.0:oob`)
        public var redirect_uris: String
        /// This can be a space-separated list of the following items: "read", "write" and "follow" (see [this page](OAuth-details.md) for details on what the scopes do)
        public var scopes: String
        /// URL to the homepage of your app
        public var website: String?

        // public memberwise init
        public init(client_name: String, redirect_uris: String, scopes: String, website: String?) {
            self.client_name = client_name
            self.redirect_uris = redirect_uris
            self.scopes = scopes
            self.website = website
        }
    }

    public enum Responses {
        case http200_(ClientApplication)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}

/// Fetching a user's favourites
/// 
/// > Note: max_id and since_id for next and previous pages are provided in the Link header. It is not possible to use the id of the returned objects to construct your own URLs, because the results are sorted by an internal key.
public struct GetFavourites: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/favourites{?max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// Get a list of favourites with ID less than this value
        public var max_id: String?
        /// Get a list of favourites with ID greater than this value
        public var since_id: String?
        /// Maximum number of favourites to get (Default 20, Max 40)
        public var limit: String?

        // public memberwise init
        public init(max_id: String?, since_id: String?, limit: String?) {
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Timelines)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}

/// Fetching a user's notifications
/// 
/// > Note: max_id and since_id for next and previous pages are provided in the Link header. However, it is possible to use the id of the returned objects to construct your own URLs.
public struct GetNotifications: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/notifications{?max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// Get a list of notifications with ID less than this value
        public var max_id: String?
        /// Get a list of notifications with ID greater than this value
        public var since_id: String?
        /// Maximum number of notifications to get (Default 15, Max 30)
        public var limit: String?

        // public memberwise init
        public init(max_id: String?, since_id: String?, limit: String?) {
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Notifications)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct LoginSilent: APIBlueprintRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public var path: String {return "/oauth/token"}

    public let param: Param
    public var bodyParameters: BodyParameters? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? JSONBodyParameters(JSONObject: JSONSerialization.jsonObject(with: encoder.encode(param)))
    }
    public struct Param: Codable { 
        /// 
        public var client_id: String
        /// 
        public var client_secret: String
        /// 
        public var scope: String
        /// 
        public var grant_type: String
        /// 
        public var username: String
        /// 
        public var password: String
    
        // public memberwise init
        public init(client_id: String, client_secret: String, scope: String, grant_type: String, username: String, password: String) {
            self.client_id = client_id
            self.client_secret = client_secret
            self.scope = scope
            self.grant_type = grant_type
            self.username = username
            self.password = password
        }
    }
    public enum Responses {
        case http200_(LoginSettings)
    }

    // public memberwise init
    public init(baseURL: URL, param: Param) {
        self.baseURL = baseURL
        self.param = param
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetHomeTimeline: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/timelines/home{?max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// Get a list of timelines with ID less than this value
        public var max_id: String?
        /// Get a list of timelines with ID greater than this value
        public var since_id: String?
        /// Maximum number of statuses on the requested timeline to get (Default 20, Max 40)
        public var limit: String?

        // public memberwise init
        public init(max_id: String?, since_id: String?, limit: String?) {
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Timelines)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetPublicTimeline: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/timelines/public{?local,max_id,since_id,limit}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// Only return statuses originating from this instance (public and tag timelines only)
        public var local: String?
        /// Get a list of timelines with ID less than this value
        public var max_id: String?
        /// Get a list of timelines with ID greater than this value
        public var since_id: String?
        /// Maximum number of statuses on the requested timeline to get (Default 20, Max 40)
        public var limit: String?

        // public memberwise init
        public init(local: String?, max_id: String?, since_id: String?, limit: String?) {
            self.local = local
            self.max_id = max_id
            self.since_id = since_id
            self.limit = limit
        }
    }

    public enum Responses {
        case http200_(Timelines)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct Boost: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}/reblog"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String

        // public memberwise init
        public init(id: String) {
            self.id = id
        }
    }

    public enum Responses {
        case http200_(Status)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetStatus: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String

        // public memberwise init
        public init(id: String) {
            self.id = id
        }
    }

    public enum Responses {
        case http200_(Status)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct GetStatusContext: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .get}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}/context"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String

        // public memberwise init
        public init(id: String) {
            self.id = id
        }
    }

    public enum Responses {
        case http200_(Context)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct Favorite: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses/{id}/favourite"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// 
        public var id: String

        // public memberwise init
        public init(id: String) {
            self.id = id
        }
    }

    public enum Responses {
        case http200_(Status)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try decodeJSON(from: object, urlResponse: urlResponse))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}


public struct PostStatus: APIBlueprintRequest, URITemplateRequest {
    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public let path = "" // see intercept(urlRequest:)
    static let pathTemplate: URITemplate = "/api/v1/statuses{?status,in_reply_to_id,media_ids,sensitive,spoiler_text,visibility}"
    public var pathVars: PathVars
    public struct PathVars: URITemplateContextConvertible {
        /// The text of the status
        public var status: String
        /// local ID of the status you want to reply to
        public var in_reply_to_id: String?
        /// Array of media IDs to attach to the status (maximum 4)
        public var media_ids: String?
        /// Set this to mark the media of the status as NSFW
        public var sensitive: String?
        /// Text to be shown as a warning before the actual content
        public var spoiler_text: String?
        /// Either "direct", "private", "unlisted" or "public"
        public var visibility: String?

        // public memberwise init
        public init(status: String, in_reply_to_id: String?, media_ids: String?, sensitive: String?, spoiler_text: String?, visibility: String?) {
            self.status = status
            self.in_reply_to_id = in_reply_to_id
            self.media_ids = media_ids
            self.sensitive = sensitive
            self.spoiler_text = spoiler_text
            self.visibility = visibility
        }
    }

    public enum Responses {
        case http200_(Status)
    }

    // public memberwise init
    public init(baseURL: URL, pathVars: PathVars) {
        self.baseURL = baseURL
        self.pathVars = pathVars
    }

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
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

public struct Instance: Codable { 
    /// URI of the current instance
    public var uri: String
    /// The instance's title
    public var title: String
    /// A description for the instance
    public var description: String
    /// An email address which can be used to contact the instance administrator
    public var email: String
    /// The Mastodon version used by instance
    public var version: String?

    // public memberwise init
    public init(uri: String, title: String, description: String, email: String, version: String?) {
        self.uri = uri
        self.title = title
        self.description = description
        self.email = email
        self.version = version
    }
}

public struct Account: Codable { 
    /// The ID of the account  ex. ID
    public var id: ID
    /// The username of the account
    public var username: String
    /// Equals `username` for local users, includes `@domain` for remote ones
    public var acct: String
    /// The account's display name
    public var display_name: String
    /// Boolean for when the account cannot be followed without waiting for approval first  ex. boolean
    public var locked: Bool
    /// The time the account was created
    public var created_at: String
    /// The number of followers for the account
    public var followers_count: Int
    /// The number of accounts the given account is following
    public var following_count: Int
    /// The number of statuses the account has made
    public var statuses_count: Int
    /// Biography of user
    public var note: String
    /// URL of the user's profile page (can be remote)
    public var url: String
    /// URL to the avatar image
    public var avatar: String
    /// URL to the avatar static image (gif)
    public var avatar_static: String
    /// URL to the header image
    public var header: String
    /// URL to the header static image (gif)
    public var header_static: String

    // public memberwise init
    public init(id: ID, username: String, acct: String, display_name: String, locked: Bool, created_at: String, followers_count: Int, following_count: Int, statuses_count: Int, note: String, url: String, avatar: String, avatar_static: String, header: String, header_static: String) {
        self.id = id
        self.username = username
        self.acct = acct
        self.display_name = display_name
        self.locked = locked
        self.created_at = created_at
        self.followers_count = followers_count
        self.following_count = following_count
        self.statuses_count = statuses_count
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatar_static = avatar_static
        self.header = header
        self.header_static = header_static
    }
}

public struct Status: Codable { 
    /// The ID of the status  ex. ID
    public var id: ID
    /// A Fediverse-unique resource ID
    public var uri: String
    /// URL to the status page (can be remote). NOTE: non-optional. occasionaly null in real world (around mastodon 2?). should be fatal bug in server.
    public var url: String?
    /// The [Account](#account) which posted the status  ex. Account
    public var account: Account
    /// `null` or the ID of the status it replies to  ex. ID
    public var in_reply_to_id: ID?
    /// `null` or the ID of the account it replies to  ex. ID
    public var in_reply_to_account_id: ID?
    /// `null` or the reblogged [Status](#status)  ex. Status
    public var reblog: Indirect<Status>?
    /// Body of the status; this will contain HTML (remote HTML already sanitized)
    public var content: String
    /// The time the status was created
    public var created_at: String
    /// The number of reblogs for the status
    public var reblogs_count: Int
    /// The number of favourites for the status
    public var favourites_count: Int
    /// Whether the authenticated user has reblogged the status  ex. boolean
    public var reblogged: Bool?
    /// Whether the authenticated user has favourited the status  ex. boolean
    public var favourited: Bool?
    /// Whether media attachments should be hidden by default  ex. boolean
    public var sensitive: Bool?
    /// If not empty, warning text that should be displayed before the actual content
    public var spoiler_text: String
    /// One of: `public`, `unlisted`, `private`, `direct`
    public var visibility: String
    /// An array of [Attachments](#attachment)  ex. []
    public var media_attachments: [Attachment]
    /// An array of [Mentions](#mention)  ex. []
    public var mentions: [Mention]
    /// An array of [Tags](#tag)  ex. []
    public var tags: [Tag]
    /// [Application](#application) from which the status was posted  ex. Application
    public var application: Application?
    /// The detected language for the status (default: en)
    public var language: String?
    /// Whether the authenticated user has pinned the status in API response. app may use app level mark as pinned  ex. boolean
    public var pinned: Bool?

    // public memberwise init
    public init(id: ID, uri: String, url: String?, account: Account, in_reply_to_id: ID?, in_reply_to_account_id: ID?, reblog: Indirect<Status>?, content: String, created_at: String, reblogs_count: Int, favourites_count: Int, reblogged: Bool?, favourited: Bool?, sensitive: Bool?, spoiler_text: String, visibility: String, media_attachments: [Attachment], mentions: [Mention], tags: [Tag], application: Application?, language: String?, pinned: Bool?) {
        self.id = id
        self.uri = uri
        self.url = url
        self.account = account
        self.in_reply_to_id = in_reply_to_id
        self.in_reply_to_account_id = in_reply_to_account_id
        self.reblog = reblog
        self.content = content
        self.created_at = created_at
        self.reblogs_count = reblogs_count
        self.favourites_count = favourites_count
        self.reblogged = reblogged
        self.favourited = favourited
        self.sensitive = sensitive
        self.spoiler_text = spoiler_text
        self.visibility = visibility
        self.media_attachments = media_attachments
        self.mentions = mentions
        self.tags = tags
        self.application = application
        self.language = language
        self.pinned = pinned
    }
}

public struct Application: Codable { 
    /// Name of the app
    public var name: String
    /// Homepage URL of the app
    public var website: String?

    // public memberwise init
    public init(name: String, website: String?) {
        self.name = name
        self.website = website
    }
}

public struct Tag: Codable { 
    /// The hashtag, not including the preceding `#`
    public var name: String
    /// The URL of the hashtag
    public var url: String

    // public memberwise init
    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

public struct Mention: Codable { 
    /// URL of user's profile (can be remote)
    public var url: String
    /// The username of the account
    public var username: String
    /// Equals `username` for local users, includes `@domain` for remote ones
    public var acct: String
    /// Account ID  ex. ID
    public var id: ID

    // public memberwise init
    public init(url: String, username: String, acct: String, id: ID) {
        self.url = url
        self.username = username
        self.acct = acct
        self.id = id
    }
}

public struct Attachment: Codable { 
    /// ID of the attachment  ex. ID
    public var id: ID
    /// One of: "image", "video", "gifv"
    public var type: String
    /// URL of the locally hosted version of the image
    public var url: String
    /// For remote images, the remote URL of the original image
    public var remote_url: String?
    /// URL of the preview image
    public var preview_url: String
    /// Shorter URL for the image, for insertion into text (only present on local images)
    public var text_url: String?

    // public memberwise init
    public init(id: ID, type: String, url: String, remote_url: String?, preview_url: String, text_url: String?) {
        self.id = id
        self.type = type
        self.url = url
        self.remote_url = remote_url
        self.preview_url = preview_url
        self.text_url = text_url
    }
}

public struct Notification: Codable { 
    /// The notification ID  ex. ID
    public var id: ID
    /// One of: "mention", "reblog", "favourite", "follow"
    public var type: String
    /// The time the notification was created
    public var created_at: String
    /// The [Account](#account) sending the notification to the user  ex. Account
    public var account: Account
    /// The [Status](#status) associated with the notification, if applicable  ex. Status
    public var status: Status?

    // public memberwise init
    public init(id: ID, type: String, created_at: String, account: Account, status: Status?) {
        self.id = id
        self.type = type
        self.created_at = created_at
        self.account = account
        self.status = status
    }
}

public struct ClientApplication: Codable { 
    ///  ex. ID
    public var id: ID
    /// 
    public var redirect_uri: String
    /// 
    public var client_id: String
    /// 
    public var client_secret: String

    // public memberwise init
    public init(id: ID, redirect_uri: String, client_id: String, client_secret: String) {
        self.id = id
        self.redirect_uri = redirect_uri
        self.client_id = client_id
        self.client_secret = client_secret
    }
}

public struct LoginSettings: Codable { 
    /// 
    public var access_token: String
    /// 
    public var token_type: String
    /// 
    public var scope: String
    /// only here: UNIX timestamp
    public var created_at: Int

    // public memberwise init
    public init(access_token: String, token_type: String, scope: String, created_at: Int) {
        self.access_token = access_token
        self.token_type = token_type
        self.scope = scope
        self.created_at = created_at
    }
}

public struct Context: Codable { 
    /// The ancestors of the status in the conversation, as a list of Statuses  ex. []
    public var ancestors: [Status]
    /// The descendants of the status in the conversation, as a list of Statuses  ex. []
    public var descendants: [Status]

    // public memberwise init
    public init(ancestors: [Status], descendants: [Status]) {
        self.ancestors = ancestors
        self.descendants = descendants
    }
}

public struct ID: Codable { 
    /// actual id value
    public var value: String

    // public memberwise init
    public init(value: String) {
        self.value = value
    }
}

