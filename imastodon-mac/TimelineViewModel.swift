import ReactiveSwift
import API
import Ikemen
import BrightFutures

final class TimelineViewModel {
    let timeline = MutableProperty<[Status]>([])
    let filterText = MutableProperty<String>("")
    var filterPredicate: Property<((Status) -> Bool)?> {return filterText.map { t in t.isEmpty ? nil
        : {$0.mainContentStatus.textContent.range(
            of: t,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current) != nil}
        }}
    private let backgroundQueue = QueueScheduler(name: "TimelineViewModel.background")
    private(set) lazy var filteredTimeline = Property<[Status]>(initial: timeline.value, then:
        filterPredicate.producer
            .debounce(0.1, on: backgroundQueue)
            .combineLatest(with: timeline)
            .throttle(0.1, on: backgroundQueue)
            // TODO: consider scan to apply filter only on inserted toots
            .map {filterPredicate, timeline in filterPredicate.map {timeline.filter($0)} ?? timeline}
            .observe(on: UIScheduler()))

    func insert(statuses: [Status]) {
        timeline.value = statuses + timeline.value.prefix(346 - statuses.count)
    }

    func delete(id: ID) {
        timeline.value = timeline.value.filter {$0.id != id}
    }

    func toggleFavorite(status: Status, client: Client) -> Future<Void, AppError> {
        let toggle = status.favourited == true ? client.unfavorite(status) : client.favorite(status)
        return toggle.onComplete {
            let newStatus: Status
            switch $0 {
            case .success(let s): newStatus = s
            case .failure: newStatus = status
            }

            self.timeline.value = self.timeline.value.map { s in
                guard s.id == status.id else { return s }
                return newStatus
            }
        }.asVoid()
    }
}

struct TimelineStatus: Equatable {
    let status: Status

    static func == (lhs: TimelineStatus, rhs: TimelineStatus) -> Bool {
        return lhs.status.id.value == rhs.status.id.value
            && lhs.status.favourited == rhs.status.favourited
    }
}
