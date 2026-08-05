import Foundation

enum ClosedLidStopReason: String, Codable, Equatable, Sendable {
    case manual
    case lidOpened
    case lowBattery
    case thermalPressure
    case timeLimit
    case serviceRecovery

    var title: String {
        switch self {
        case .manual: "手动关闭"
        case .lidOpened: "开盖后自动关闭"
        case .lowBattery: "电量过低后自动关闭"
        case .thermalPressure: "温度过高后自动关闭"
        case .timeLimit: "达到运行时长后自动关闭"
        case .serviceRecovery: "后台服务已恢复系统睡眠"
        }
    }
}

struct ClosedLidSessionHistory: Codable, Equatable, Sendable {
    let startedAt: Date
    let stoppedAt: Date?
    let stopReason: ClosedLidStopReason?
    let duration: ClosedLidRunDuration?

    var isActive: Bool {
        stoppedAt == nil
    }

    var stopSummary: String? {
        guard let stoppedAt, let stopReason else { return nil }
        let timestamp = stoppedAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
        )
        return "\(timestamp) · \(stopReason.title)"
    }
}

private struct ClosedLidSessionHistoryArchive: Codable {
    let activeSession: ClosedLidSessionHistory?
    let recentClosedSessions: [ClosedLidSessionHistory]
}

@MainActor
final class ClosedLidSessionHistoryStore {
    static let maximumRecentSessionCount = 5

    private static let storageKey = "closedLidSessionHistoryArchiveV2"
    private static let legacyStorageKey = "closedLidSessionHistory"

    private let defaults: UserDefaults
    private(set) var activeSession: ClosedLidSessionHistory?
    private(set) var recentClosedSessions: [ClosedLidSessionHistory]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.storageKey),
           let archive = try? JSONDecoder().decode(
               ClosedLidSessionHistoryArchive.self,
               from: data
           ) {
            activeSession = archive.activeSession?.isActive == true
                ? archive.activeSession
                : nil
            recentClosedSessions = Array(
                archive.recentClosedSessions
                    .filter { !$0.isActive && $0.stopReason != nil }
                    .prefix(Self.maximumRecentSessionCount)
            )
            return
        }

        let legacyHistory = defaults.data(forKey: Self.legacyStorageKey).flatMap {
            try? JSONDecoder().decode(ClosedLidSessionHistory.self, from: $0)
        }
        if legacyHistory?.isActive == true {
            activeSession = legacyHistory
            recentClosedSessions = []
        } else {
            activeSession = nil
            recentClosedSessions = legacyHistory.map { [$0] } ?? []
        }
        persist()
    }

    @discardableResult
    func recordStarted(
        duration: ClosedLidRunDuration,
        at date: Date = Date()
    ) -> ClosedLidSessionHistory {
        let session = ClosedLidSessionHistory(
            startedAt: date,
            stoppedAt: nil,
            stopReason: nil,
            duration: duration
        )
        activeSession = session
        persist()
        return session
    }

    @discardableResult
    func recordStopped(
        reason: ClosedLidStopReason,
        at date: Date = Date()
    ) -> ClosedLidSessionHistory? {
        guard let current = activeSession else {
            return recentClosedSessions.first
        }
        let session = ClosedLidSessionHistory(
            startedAt: current.startedAt,
            stoppedAt: date,
            stopReason: reason,
            duration: current.duration
        )
        activeSession = nil
        recentClosedSessions.insert(session, at: 0)
        if recentClosedSessions.count > Self.maximumRecentSessionCount {
            recentClosedSessions.removeLast(
                recentClosedSessions.count - Self.maximumRecentSessionCount
            )
        }
        persist()
        return session
    }

    private func persist() {
        let archive = ClosedLidSessionHistoryArchive(
            activeSession: activeSession,
            recentClosedSessions: recentClosedSessions
        )
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
