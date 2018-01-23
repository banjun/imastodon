import ReactiveSwift
import API

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

    func insert(status: Status) {
        timeline.value = [status] + timeline.value.prefix(345)
    }

    func delete(id: ID) {
        timeline.value = timeline.value.filter {$0.id != id}
    }
}