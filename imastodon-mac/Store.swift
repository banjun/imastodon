import Foundation

struct StoreFile {
    let file: URL
    var store: Store {
        didSet {try! JSONEncoder().encode(store).write(to: file)}
    }

    static var shared: StoreFile = {
        let sharedURL = NSURL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents")!
            .appendingPathComponent("sharedStore.json")
        let data = try? Data(contentsOf: sharedURL)
        let store = (data.flatMap {try? JSONDecoder().decode(Store.self, from: $0)})
            ?? ((data.flatMap {try? JSONDecoder().decode(StoreV1.self, from: $0)}).flatMap {Store($0)})
            ?? Store(instanceAccounts: [], windowState: [:])
        return StoreFile(file: sharedURL,
                         store: store)
    }()
}

struct Store: Codable {
    var instanceAccounts: [IDAndInstanceAccount]
    struct IDAndInstanceAccount: Codable {
        var uuid: UUID
        var instanceAccount: InstanceAccout
    }

    var windowState: [UUID: Data]
}

struct StoreV1: Codable {
    var instanceAccounts: [InstanceAccout]
}

extension Store {
    init(_ v1: StoreV1) {
        self.init(instanceAccounts: v1.instanceAccounts.map {.init(uuid: UUID(), instanceAccount: $0)}, windowState: [:])
    }
}
