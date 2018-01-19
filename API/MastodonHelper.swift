// due to SwiftBeaker not supporting some parameter structures, add below by hand
typealias Timelines = [Status]
typealias Accounts = [Account]
typealias Notifications = [Notification]

import APIKit

// Codable
extension ID {
    init(from decoder: Decoder) throws {
        // v2: String, v1: Int
        do {
            self.init(value: try String(from: decoder))
        } catch {
            guard let i = try? Int(from: decoder) else { throw error }
            self.init(value: String(i))
        }
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension ID: Equatable {
    static func == (lhs: ID, rhs: ID) -> Bool {
        return lhs.value == rhs.value
    }
}

extension ID: ExpressibleByStringLiteral {
    typealias StringLiteralType = String

    init(stringLiteral value: String) {
        self.init(value: value)
    }
}

extension Status {
    var createdAt: Date? { // should be non-nil checked at decode
        return ISO8601DateFormatter().date(from: created_at)
    }
}

struct LoginSilentFormURLEncoded: APIBlueprintRequest {
    let baseURL: URL
    var method: HTTPMethod {return .post}

    var path: String {return "/oauth/token"}

    let param: Param
    var bodyParameters: BodyParameters? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let form = (try? JSONSerialization.jsonObject(with: encoder.encode(param))) as? [String: Any]
        return form.map {FormURLEncodedBodyParameters(formObject: $0)}
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
            return .http200_(try JSONDecoder().decode(LoginSettings.self, from: object as! Data))
        default:
            throw ResponseError.undefined(urlResponse.statusCode, contentType)
        }
    }
}

enum Visibility: String {
    case `public`, `unlisted`, `private`, `direct`
}
