// due to SwiftBeaker not supporting some parameter structures, add below by hand
typealias Timelines = [Status]

import APIKit

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
