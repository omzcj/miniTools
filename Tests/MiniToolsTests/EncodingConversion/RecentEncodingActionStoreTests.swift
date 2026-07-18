import Foundation
import XCTest
@testable import MiniTools

final class RecentEncodingActionStoreTests: XCTestCase {
    func testRecordsUniqueActionsInMostRecentOrderAndPersistsThem() throws {
        let suiteName = "MiniToolsTests.RecentActions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentEncodingActionStore(defaults: defaults)

        for index in 0..<22 {
            store.record("action.\(index)")
        }
        store.record("action.10")

        XCTAssertEqual(store.actionIDs.count, 20)
        XCTAssertEqual(store.actionIDs.first, "action.10")
        XCTAssertEqual(store.actionIDs.filter { $0 == "action.10" }.count, 1)
        XCTAssertEqual(RecentEncodingActionStore(defaults: defaults).actionIDs, store.actionIDs)
    }
}
