import Foundation
import XCTest
@testable import MiniTools

@MainActor
final class ClosedLidSessionHistoryTests: XCTestCase {
    func testPersistsStartedAndStoppedSession() throws {
        let suiteName = "ClosedLidSessionHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let startedAt = Date(timeIntervalSince1970: 100)
        let stoppedAt = Date(timeIntervalSince1970: 200)
        let store = ClosedLidSessionHistoryStore(defaults: defaults)

        XCTAssertEqual(store.recordStarted(at: startedAt), ClosedLidSessionHistory(
            startedAt: startedAt,
            stoppedAt: nil,
            stopReason: nil
        ))
        XCTAssertEqual(
            store.recordStopped(reason: .thermalPressure, at: stoppedAt),
            ClosedLidSessionHistory(
                startedAt: startedAt,
                stoppedAt: stoppedAt,
                stopReason: .thermalPressure
            )
        )

        let restoredStore = ClosedLidSessionHistoryStore(defaults: defaults)
        XCTAssertEqual(restoredStore.history, store.history)
    }

    func testDoesNotReplaceCompletedSessionWithoutANewStart() throws {
        let suiteName = "ClosedLidSessionHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ClosedLidSessionHistoryStore(defaults: defaults)
        store.recordStarted(at: Date(timeIntervalSince1970: 100))
        let completed = store.recordStopped(
            reason: .manual,
            at: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(
            store.recordStopped(reason: .serviceRecovery, at: Date(timeIntervalSince1970: 300)),
            completed
        )
    }
}
