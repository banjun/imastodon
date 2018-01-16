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
        return StoreFile(file: sharedURL,
                         store: (try? JSONDecoder().decode(Store.self, from: Data(contentsOf: sharedURL)))
                            ?? Store(instanceAccounts: []))
    }()
}

struct Store: Codable {
    var instanceAccounts: [InstanceAccout]
}
