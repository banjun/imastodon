// due to SwiftBeaker not supporting some parameter structures, add below by hand
public typealias Timelines = [Status]
public typealias Accounts = [Account]
public typealias Notifications = [Notification]

import APIKit

// Codable
extension ID {
    public init(from decoder: Decoder) throws {
        // v2: String, v1: Int
        do {
            self.init(value: try String(from: decoder))
        } catch {
            guard let i = try? Int(from: decoder) else { throw error }
            self.init(value: String(i))
        }
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension ID: Equatable {
    public static func == (lhs: ID, rhs: ID) -> Bool {
        return lhs.value == rhs.value
    }
}

extension ID: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.init(value: value)
    }
}

extension Status {
    public var createdAt: Date? { // should be non-nil checked at decode
        return ISO8601DateFormatter().date(from: created_at)
    }
}

public struct LoginSilentFormURLEncoded: APIBlueprintRequest {
    public init(baseURL: URL, param: Param) {
        self.baseURL = baseURL
        self.param = param
    }

    public let baseURL: URL
    public var method: HTTPMethod {return .post}

    public var path: String {return "/oauth/token"}

    public let param: Param
    public var bodyParameters: BodyParameters? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let form = (try? JSONSerialization.jsonObject(with: encoder.encode(param))) as? [String: Any]
        return form.map {FormURLEncodedBodyParameters(formObject: $0)}
    }
    public struct Param: Codable {
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

        public init(client_id: String,
                    client_secret: String,
                    scope: String,
                    grant_type: String,
                    username: String,
                    password: String) {
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

    public func response(from object: Any, urlResponse: HTTPURLResponse) throws -> Responses {
        let contentType = contentMIMEType(in: urlResponse)
        switch (urlResponse.statusCode, contentType) {
        case (200, _):
            return .http200_(try JSONDecoder().decode(LoginSettings.self, from: object as! Data))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}

public enum Visibility: String {
    case `public`, `unlisted`, `private`, `direct`
}
