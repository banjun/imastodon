import Foundation
import ReactiveSwift

func timestampEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
    NSLog("%@", "[\(identifier)] \(event) fileName: \(fileName), functionName: \(functionName), lineNumber: \(lineNumber)")
}

extension SignalProducer {
    /// immediate retry on error if elapsed at least interval after starting
    public func retry(throttling interval: TimeInterval, on scheduler: DateScheduler = QueueScheduler.main) -> SignalProducer<Value, Error> {
        var last = Date.distantPast
        return on(starting: {last = Date()})
            .flatMapError { error in
                let now = Date()
                let elapsed = now.timeIntervalSince(last)
                return SignalProducer.empty
                    .delay(max(0, interval - elapsed), on: scheduler)
                    .concat(SignalProducer<Value, Error>(error: error))
            }
            .retry(upTo: Int.max)
    }
}
