import Foundation
import XCTest
@testable import MiniTools

@MainActor
final class ClosedLidSessionHistoryTests: XCTestCase {
    func testPersistsActiveSessionAndCompletedHistory() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let startedAt = Date(timeIntervalSince1970: 100)
        let stoppedAt = Date(timeIntervalSince1970: 200)
        let store = ClosedLidSessionHistoryStore(defaults: defaults)

        let activeSession = ClosedLidSessionHistory(
            startedAt: startedAt,
            stoppedAt: nil,
            stopReason: nil,
            duration: .twoHours
        )
        XCTAssertEqual(
            store.recordStarted(duration: .twoHours, at: startedAt),
            activeSession
        )
        XCTAssertEqual(store.activeSession, activeSession)

        let completedSession = ClosedLidSessionHistory(
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            stopReason: .thermalPressure,
            duration: .twoHours
        )
        XCTAssertEqual(
            store.recordStopped(reason: .thermalPressure, at: stoppedAt),
            completedSession
        )
        XCTAssertNil(store.activeSession)
        XCTAssertEqual(store.recentClosedSessions, [completedSession])

        let restoredStore = ClosedLidSessionHistoryStore(defaults: defaults)
        XCTAssertNil(restoredStore.activeSession)
        XCTAssertEqual(restoredStore.recentClosedSessions, [completedSession])
    }

    func testKeepsOnlyFiveMostRecentClosedSessions() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ClosedLidSessionHistoryStore(defaults: defaults)
        let reasons: [ClosedLidStopReason] = [
            .manual,
            .lidOpened,
            .lowBattery,
            .thermalPressure,
            .timeLimit,
            .serviceRecovery,
            .manual
        ]

        for (index, reason) in reasons.enumerated() {
            store.recordStarted(
                duration: .oneHour,
                at: Date(timeIntervalSince1970: TimeInterval(index * 10))
            )
            store.recordStopped(
                reason: reason,
                at: Date(timeIntervalSince1970: TimeInterval(index * 10 + 5))
            )
        }

        XCTAssertEqual(
            store.recentClosedSessions.count,
            ClosedLidSessionHistoryStore.maximumRecentSessionCount
        )
        XCTAssertEqual(
            store.recentClosedSessions.compactMap(\.stoppedAt),
            [65, 55, 45, 35, 25].map(Date.init(timeIntervalSince1970:))
        )
        XCTAssertEqual(
            store.recentClosedSessions.compactMap(\.stopReason),
            [.manual, .serviceRecovery, .timeLimit, .thermalPressure, .lowBattery]
        )
        XCTAssertEqual(
            ClosedLidSessionHistoryStore(defaults: defaults).recentClosedSessions,
            store.recentClosedSessions
        )
    }

    func testMigratesLegacySingleSession() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacySession = ClosedLidSessionHistory(
            startedAt: Date(timeIntervalSince1970: 100),
            stoppedAt: Date(timeIntervalSince1970: 200),
            stopReason: .lowBattery,
            duration: nil
        )
        defaults.set(
            try JSONEncoder().encode(legacySession),
            forKey: "closedLidSessionHistory"
        )

        let store = ClosedLidSessionHistoryStore(defaults: defaults)

        XCTAssertNil(store.activeSession)
        XCTAssertEqual(store.recentClosedSessions, [legacySession])
        XCTAssertEqual(
            ClosedLidSessionHistoryStore(defaults: defaults).recentClosedSessions,
            [legacySession]
        )
    }

    func testDoesNotReplaceCompletedSessionsWithoutANewStart() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ClosedLidSessionHistoryStore(defaults: defaults)
        store.recordStarted(
            duration: .unlimited,
            at: Date(timeIntervalSince1970: 100)
        )
        let completed = store.recordStopped(
            reason: .manual,
            at: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(
            store.recordStopped(
                reason: .serviceRecovery,
                at: Date(timeIntervalSince1970: 300)
            ),
            completed
        )
        XCTAssertEqual(store.recentClosedSessions.count, 1)
        XCTAssertEqual(store.recentClosedSessions.first, completed)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "ClosedLidSessionHistoryTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suiteName)), suiteName)
    }
}
