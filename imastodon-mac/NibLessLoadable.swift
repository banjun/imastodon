import Cocoa

protocol NibLessLoadable: AnyObject {
    init(identifier: NSUserInterfaceItemIdentifier)
}
extension NibLessLoadable where Self: NSTableCellView {
    init(identifier: NSUserInterfaceItemIdentifier) {
        self.init()
        self.identifier = identifier
    }
}

extension NSTableView {
    func makeView<T: NibLessLoadable>(type: T.Type, identifier: NSUserInterfaceItemIdentifier, owner: Any?) -> T {
        return (makeView(withIdentifier: identifier, owner: owner) as? T) ?? T(identifier: identifier)
    }
}
