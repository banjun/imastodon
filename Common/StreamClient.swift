import Foundation
import ReactiveSwift
import ReactiveCocoa
import ReactiveSSE
import Ikemen
import API

final class StreamClient {
    private let instanceAccount: InstanceAccout
    private var activeSignals: ActiveSignals = .init()
    private struct ActiveSignals {
        weak var local: Signal<SSEvent, Never>?
        weak var localToots: Signal<Status, Never>?
        weak var user: Signal<SSEvent, Never>?
        weak var homeToots: Signal<Status, Never>?
        weak var notifications: Signal<API.Notification, Never>?
        var hashtags: [String: Signal<Status, Never>] = [:]
    }

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
    }

    private func producer(relativeURL: String) -> SignalProducer<SSEvent, SSError> {
        var req = URLRequest(url: URL(string: instanceAccount.instance.baseURL!.absoluteString + relativeURL)!)
        req.addValue("Bearer \(instanceAccount.accessToken)", forHTTPHeaderField: "Authorization")
        return ReactiveSSE(urlRequest: req).producer
            .logEvents(identifier: instanceAccount.instance.title,
                       events: [.starting, .started, .completed, .interrupted, .terminated, .disposed], logger: timestampEventLog)
            .retry(throttling: 10)
            .take(duringLifetimeOf: self)
    }

    private func signal(relativeURL: String) -> Signal<SSEvent, Never> {
        return .init { observer, lifetime in
            producer(relativeURL: relativeURL)
                .startIntoDownstreamIgnoringError(observer, lifetime)
        }
    }

    // local events signal sharing underlying network connection
    func local(during lifetime: Lifetime) -> Signal<SSEvent, Never> {
        defer {lifetime += SignalRetainingDisposable(activeSignals.local)}
        return (activeSignals.local?.signal ?? (
            signal(relativeURL: "/api/v1/streaming/public/local")
                ※ {activeSignals.local = $0}))
    }

    // local toots signal sharing results of Codable decodes
    func localToots(during lifetime: Lifetime) -> Signal<Status, Never> {
        defer {lifetime += SignalRetainingDisposable(activeSignals.localToots)}
        return (activeSignals.localToots?.signal ?? (
            local(during: lifetime)
                .filter {$0.type == "update" || $0.type == "status.update"}
                .compactMap {$0.data.data(using: .utf8)}
                .compactMap {try? JSONDecoder().decode(Status.self, from: $0)}
                ※ {activeSignals.localToots = $0}))
    }

    // local deleted ids signal that is not sharing results of Codable decodes, sharing underlying networks
    func localDeletedIDs(during lifetime: Lifetime) -> Signal<ID, Never> {
        return local(during: lifetime)
            .filter {$0.type == "delete"}
            .map {ID(stringLiteral: $0.data)}
    }

    // user events signal sharing underlying network connection
    func user(during lifetime: Lifetime) -> Signal<SSEvent, Never> {
        defer {lifetime += SignalRetainingDisposable(activeSignals.user)}
        return (activeSignals.user?.signal ?? (
            signal(relativeURL: "/api/v1/streaming/user")
                ※ {activeSignals.user = $0}))
    }

    // home toots signal sharing results of Codable decodes
    func homeToots(during lifetime: Lifetime) -> Signal<Status, Never> {
        defer {lifetime += SignalRetainingDisposable(activeSignals.homeToots)}
        return (activeSignals.homeToots?.signal ?? (
            user(during: lifetime)
                .filter {$0.type == "update" || $0.type == "status.update"}
                .compactMap {$0.data.data(using: .utf8)}
                .compactMap {try? JSONDecoder().decode(Status.self, from: $0)}
                ※ {activeSignals.homeToots = $0}))
    }

    // home deleted ids signal that is not sharing results of Codable decodes, sharing underlying networks
    func homeDeletedIDs(during lifetime: Lifetime) -> Signal<ID, Never> {
        return user(during: lifetime)
            .filter {$0.type == "delete"}
            .map {ID(stringLiteral: $0.data)}
    }

    // user notifications signal sharing results of Codable decodes
    func notifications(during lifetime: Lifetime) -> Signal<API.Notification, Never> {
        defer {lifetime += SignalRetainingDisposable(activeSignals.notifications)}
        return (activeSignals.notifications?.signal ?? (
            user(during: lifetime)
                .filter {$0.type == "notification"}
                .compactMap {$0.data.data(using: .utf8)}
                .compactMap {try? JSONDecoder().decode(Notification.self, from: $0)}
                ※ {activeSignals.notifications = $0}))
    }
}

private extension SignalProducer {
    func startIntoDownstreamIgnoringError(_ observer: Signal<Value, Never>.Observer, _ lifetime: Lifetime) -> Void {
        flatMapError {_ in SignalProducer<Value, Never>.empty}
            .startWithSignal {s, d in
                lifetime += AnyDisposable {NSLog("%@", "disposing directly produced by Stream SignalProducer")}
                lifetime += d
                lifetime += s.observe(observer)}
    }
}

/// retain strong ref to the signal and release it on dispose
/// can be used for appending to the underlying lifetime by `lifetime += SignalRetainingDisposable(signal to be retained)`
final class SignalRetainingDisposable<Value, Error: Swift.Error>: Disposable {
    private var signal: Signal<Value, Error>?
    private lazy var base: AnyDisposable = .init {self.signal = nil}
    init(_ signal: Signal<Value, Error>?) {
        self.signal = signal
    }
    var isDisposed: Bool {return base.isDisposed}
    func dispose() {base.dispose()}
}
