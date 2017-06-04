import Foundation
import IKEventSource
import ReactiveSwift

struct Stream {
    let source: EventSource
    let signal: Signal<Status, AppError>
    private let observer: Observer<Status, AppError>

    init(endpoint: URL, token: String) {
        (signal, observer) = Signal<Status, AppError>.pipe()
        source = EventSource(url: endpoint.absoluteString, headers: ["Authorization": "Bearer \(token)"])
        source.onOpen { [weak source] in
            NSLog("%@", "EventSource opened: \(String(describing: source))")
        }
        source.onError { [weak source, weak observer] e in
            NSLog("%@", "EventSource error: \(String(describing: e))")
            source?.invalidate()
            observer?.send(error: .eventstream(e))
        }
        source.addEventListener("update") { [weak observer] id, event, data in
            do {
                let j = try JSONSerialization.jsonObject(with: data?.data(using: .utf8) ?? Data())
                let status = try Status.decodeValue(j)
                observer?.send(value: status)
            } catch {
                NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
                observer?.send(error: .eventstream(error))
            }
        }
    }

    func close() {
        source.close()
        observer.sendInterrupted()
    }
}

extension Stream {
    private init(mastodonForHost host: String, path: String, token: String) {
        let knownSeparatedHosts = [
            "mstdn.jp": "streaming."]
        let streamHost = knownSeparatedHosts[host].map {$0 + host} ?? host
        self.init(endpoint: URL(string: "https://" + streamHost + path)!, token: token)
    }

    init(userTimelineForHost host: String, token: String) {
        self.init(mastodonForHost: host, path: "/api/v1/streaming/user", token: token)
    }

    init(localTimelineForHost host: String, token: String) {
        self.init(mastodonForHost: host, path: "/api/v1/streaming/public/local", token: token)
    }
}

extension AppError {
    var errorStatus: Status {
        let errorAccount = Account(id: 0, username: "", acct: "", displayName: "imastodon.AppError", note: "", url: "", avatar: "", avatarStatic: "", header: "", headerStatic: "", locked: false, createdAt: Date(), followersCount: 0, followingCount: 0, statusesCount: 0)
        return Status(id: 0, uri: "", url: URL(string: "https://localhost/")!, account: errorAccount, inReplyToID: nil, inReplyToAccountID: nil, content: localizedDescription, createdAt: Date(), reblogsCount: 0, favouritesCount: 0, reblogged: nil, favourited: nil, sensitive: nil, spoilerText: "", visibility: .public, mediaAttachments: [], mentions: [], tags: [], application: nil, reblogWrapper: [])
    }
}
