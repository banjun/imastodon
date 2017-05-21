import Foundation
import pencil

struct Store: CustomReadWriteElement {
    var instanceAccounts: [InstanceAccout]

    static private var sharedURL: URL {return Directory.Documents!.append(path: "sharedStore.data")}
    static var shared: Store {
        return Store.value(from: sharedURL) ?? Store(instanceAccounts: [])
    }
    func writeToShared() {
        write(to: Store.sharedURL)
    }

    static func read(from components: Components) -> Store? {
        do {
            return try Store(
                instanceAccounts: components.component(for: "instanceAccounts"))
        } catch {
            return nil
        }
    }
}
