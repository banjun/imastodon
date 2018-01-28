import Cocoa

final class VisibleLimitedTableView: NSTableView {
    override func prepareContent(in rect: NSRect) {
        // overdraw can cause corrupt balance of didAddRowView and didRemoveRowView,
        // that cause memory leak as like O(N), in constrast to logically O(1) tableview active rows.
        // https://stackoverflow.com/questions/23013990/nstableviews-viewfortablecolumnrow-called-for-more-rows-than-expected-in-mave
        super.prepareContent(in: visibleRect)
    }
}
