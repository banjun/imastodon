import Foundation

struct Store: Codable {
    var instanceAccounts: [InstanceAccout]

    static private var sharedURL: URL {
        return NSURL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents")!
            .appendingPathComponent("sharedStore.json")
    }
    static var shared: Store {
        return (try? JSONDecoder().decode(Store.self, from: Data(contentsOf: sharedURL))) ?? Store(instanceAccounts: [])
    }
    func writeToShared() {
        _ = try? JSONEncoder().encode(self).write(to: Store.sharedURL)
    }
}
