import Foundation
import IKEventSource
import ReactiveSwift

struct Stream {
    let source: EventSource
    let updateSignal: Signal<Event, AppError>
    private let updateObserver: Signal<Event, AppError>.Observer
    let notificationSignal: Signal<Notification, AppError>
    private let notificationObserver: Signal<Notification, AppError>.Observer
    
    enum Event {
        case open
        case update(Status)

        var status: Status? {
            switch self {
            case .open: return nil
            case let .update(s): return s
            }
        }
    }

    init(endpoint: URL, token: String) {
        (updateSignal, updateObserver) = Signal<Event, AppError>.pipe()
        (notificationSignal, notificationObserver) = Signal<Notification, AppError>.pipe()
        source = EventSource(url: endpoint.absoluteString, headers: ["Authorization": "Bearer \(token)"])
        source.onOpen { [weak source, weak updateObserver] in
            NSLog("%@", "EventSource opened: \(String(describing: source))")
            updateObserver?.send(value: .open)
        }
        source.onError { [weak source, weak updateObserver, weak notificationObserver] e in
            NSLog("%@", "EventSource error: \(String(describing: e))")
            source?.invalidate()
            updateObserver?.send(error: .eventstream(e))
            notificationObserver?.send(error: .eventstream(e))
        }
        source.addEventListener("update") { [weak updateObserver] id, event, data in
            do {
                let status = try JSONDecoder().decode(Status.self, from: data?.data(using: .utf8) ?? Data())
                updateObserver?.send(value: .update(status))
            } catch {
                NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
                updateObserver?.send(error: .eventstream(error))
            }
        }
        source.addEventListener("notification") { [weak notificationObserver] id, event, data in
            do {
                let notification = try JSONDecoder().decode(Notification.self, from: data?.data(using: .utf8) ?? Data())
                notificationObserver?.send(value: notification)
            } catch {
                NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
                notificationObserver?.send(error: .eventstream(error))
            }
        }
    }

    func close() {
        source.close()
        updateObserver.sendInterrupted()
        notificationObserver.sendInterrupted()
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
        let errorAccount = Account(id: "0", username: "", acct: "", display_name: "imastodon.AppError", locked: false, created_at: ISO8601DateFormatter().string(from: Date()), followers_count: 0, following_count: 0, statuses_count: 0, note: "", url: "", avatar: "", avatar_static: "", header: "", header_static: "")
        return Status(id: "0", uri: "", url: "https://localhost/", account: errorAccount, in_reply_to_id: nil, in_reply_to_account_id: nil, reblog: nil, content: localizedDescription, created_at: ISO8601DateFormatter().string(from: Date()), reblogs_count: 0, favourites_count: 0, reblogged: nil, favourited: nil, sensitive: nil, spoiler_text: "", visibility: "public", media_attachments: [], mentions: [], tags: [], application: nil, language: "", pinned: false)
    }
}
