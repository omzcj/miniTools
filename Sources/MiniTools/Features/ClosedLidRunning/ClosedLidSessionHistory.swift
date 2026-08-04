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
        case .timeLimit: "达到最长时长后自动关闭"
        case .serviceRecovery: "后台服务已恢复系统睡眠"
        }
    }
}

struct ClosedLidSessionHistory: Codable, Equatable, Sendable {
    let startedAt: Date
    let stoppedAt: Date?
    let stopReason: ClosedLidStopReason?

    var isActive: Bool {
        stoppedAt == nil
    }
}

@MainActor
final class ClosedLidSessionHistoryStore {
    private static let storageKey = "closedLidSessionHistory"

    private let defaults: UserDefaults
    private(set) var history: ClosedLidSessionHistory?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        history = defaults.data(forKey: Self.storageKey).flatMap {
            try? JSONDecoder().decode(ClosedLidSessionHistory.self, from: $0)
        }
    }

    @discardableResult
    func recordStarted(at date: Date = Date()) -> ClosedLidSessionHistory {
        let history = ClosedLidSessionHistory(
            startedAt: date,
            stoppedAt: nil,
            stopReason: nil
        )
        persist(history)
        return history
    }

    @discardableResult
    func recordStopped(
        reason: ClosedLidStopReason,
        at date: Date = Date()
    ) -> ClosedLidSessionHistory? {
        guard let current = history, current.isActive else { return history }
        let history = ClosedLidSessionHistory(
            startedAt: current.startedAt,
            stoppedAt: date,
            stopReason: reason
        )
        persist(history)
        return history
    }

    private func persist(_ history: ClosedLidSessionHistory) {
        self.history = history
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
