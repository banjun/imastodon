import Foundation
import ReactiveSSE
import ReactiveSwift
import API

class Stream {
    let source: ReactiveSSE
    var lifetimeToken: Lifetime.Token?
    let updateSignal: Signal<Event, AppError>
    private let updateObserver: Signal<Event, AppError>.Observer
    let notificationSignal: Signal<API.Notification, AppError>
    private let notificationObserver: Signal<API.Notification, AppError>.Observer
    
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
        (notificationSignal, notificationObserver) = Signal<API.Notification, AppError>.pipe()

        let (lifetime, lifetimeToken) = Lifetime.make()
        self.lifetimeToken = lifetimeToken
        var req = URLRequest(url: endpoint)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        source = ReactiveSSE(urlRequest: req)
        source.producer
            .take(during: lifetime)
            .compactMap {e in e.data.data(using: .utf8).map {(e.type, $0)}}
            .mapError {AppError.eventstream($0)}
            .observe(on: QueueScheduler.main)
            .startWithSignal { signal, disposable in
                signal
                    .take(first: 1)
                    .on(value: {[weak self] _ in self?.updateObserver.send(value: .open)})
                    .observe {_ in}

                signal.filter {$0.0 == "update" || $0.0 == "status.update"}
                    .flatMap(.concat) { _, d -> SignalProducer<Stream.Event, AppError> in
                        do {
                            return .init(value: .update(try JSONDecoder().decode(Status.self, from: d)))
                        } catch {
                            NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: String(data: d, encoding: .utf8)))")
                            return .init(error: .eventstream(error))
                        }
                    }
                    .observe(updateObserver)

                signal.filter {$0.0 == "notification"}
                    .flatMap(.concat) { _, d -> SignalProducer<API.Notification, AppError> in
                        do {
                            return .init(value: try JSONDecoder().decode(API.Notification.self, from: d))
                        } catch {
                            NSLog("%@", "EventSource event notification, failed to parse with error \(error): \(String(describing: String(data: d, encoding: .utf8)))")
                            return .init(error: .eventstream(error))
                        }
                    }
                    .observe(notificationObserver)
        }
    }

    func close() {
        lifetimeToken = nil
        updateObserver.sendInterrupted()
        notificationObserver.sendInterrupted()
    }
}

extension Stream {
    private convenience init(mastodonForHost host: String, path: String, token: String) {
        self.init(endpoint: URL(string: "https://" + host + path)!, token: token)
    }

    convenience init(userTimelineForHost host: String, token: String) {
        self.init(mastodonForHost: host, path: "/api/v1/streaming/user", token: token)
    }

    convenience init(localTimelineForHost host: String, token: String) {
        self.init(mastodonForHost: host, path: "/api/v1/streaming/public/local", token: token)
    }
}

extension AppError {
    var errorStatus: Status {
        let errorAccount = Account(id: "0", username: "", acct: "", display_name: "imastodon.AppError", locked: false, created_at: ISO8601DateFormatter().string(from: Date()), followers_count: 0, following_count: 0, statuses_count: 0, note: "", url: "", avatar: "", avatar_static: "", header: "", header_static: "")
        return Status(id: "0", uri: "", url: "https://localhost/", account: errorAccount, in_reply_to_id: nil, in_reply_to_account_id: nil, reblog: nil, content: localizedDescription, created_at: ISO8601DateFormatter().string(from: Date()), reblogs_count: 0, favourites_count: 0, reblogged: nil, favourited: nil, sensitive: nil, spoiler_text: "", visibility: "public", media_attachments: [], mentions: [], tags: [], application: nil, language: "", pinned: false)
    }
}
