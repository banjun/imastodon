import Cocoa
import Differ

public struct BatchUpdate {
    public let deletions: IndexSet
    public let insertions: IndexSet

    public init(
        diff: ExtendedDiff,
        indexTransform: (Int) -> Int = { $0 }
        ) {
        deletions = IndexSet(diff.flatMap { element -> Int? in
            switch element {
            case let .delete(at):
                return indexTransform(at)
            default: return nil
            }
        })
        insertions = IndexSet(diff.flatMap { element -> Int? in
            switch element {
            case let .insert(at):
                return indexTransform(at)
            default: return nil
            }
        })
    }
}

extension NSTableView {
    public func animateRowAndSectionChanges<T: Collection>(
        oldData: T,
        newData: T,
        rowDeletionAnimation: AnimationOptions = .effectFade,
        rowInsertionAnimation: AnimationOptions = .effectFade,
        indexTransform: (Int) -> Int = { $0 }
        )
        where T.Iterator.Element: Equatable {
            apply(
                oldData.extendedDiff(newData),
                rowDeletionAnimation: rowDeletionAnimation,
                rowInsertionAnimation: rowInsertionAnimation,
                indexTransform: indexTransform
            )
    }

    public func apply(
        _ diff: ExtendedDiff,
        rowDeletionAnimation: AnimationOptions = .effectFade,
        rowInsertionAnimation: AnimationOptions = .effectFade,
        indexTransform: (Int) -> Int
        ) {

        let update = BatchUpdate(diff: diff, indexTransform: indexTransform)
        beginUpdates()
        removeRows(at: update.deletions, withAnimation: rowDeletionAnimation)
        insertRows(at: update.insertions, withAnimation: rowInsertionAnimation)
        endUpdates()
    }
}
