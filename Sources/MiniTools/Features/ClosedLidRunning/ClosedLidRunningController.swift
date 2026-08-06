import AppKit
import Foundation
import MiniToolsPowerSupport
import OSLog
import ServiceManagement

enum ClosedLidHelperState: Equatable {
    case unavailable
    case notEnabled
    case awaitingApproval
    case enabled
    case missing

    var title: String {
        switch self {
        case .unavailable: "请从“应用程序”运行"
        case .notEnabled: "未启用"
        case .awaitingApproval: "等待批准"
        case .enabled: "已启用"
        case .missing: "组件缺失"
        }
    }
}

@MainActor
final class ClosedLidRunningController: ObservableObject {
    private static let logger = Logger(
        subsystem: "com.omzcj.minitools",
        category: "ClosedLidRunning"
    )

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var helperState: ClosedLidHelperState = .unavailable
    @Published private(set) var lastError: String?
    @Published private(set) var recentClosedSessions: [ClosedLidSessionHistory]
    @Published private(set) var activeDuration: ClosedLidRunDuration?

    var onStateChanged: (() -> Void)?

    private let settings: AppSettings
    private let client: PowerHelperClient
    private let historyStore: ClosedLidSessionHistoryStore
    private let service: SMAppService
    private var monitorTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var approvalTask: Task<Void, Never>?
    private var enabledAt: Date?
    private var hasObservedClosedLid = false
    private var enableAfterApprovalDuration: ClosedLidRunDuration?

    init(
        settings: AppSettings,
        client: PowerHelperClient = PowerHelperClient(),
        historyStore: ClosedLidSessionHistoryStore = ClosedLidSessionHistoryStore()
    ) {
        self.settings = settings
        self.client = client
        self.historyStore = historyStore
        recentClosedSessions = historyStore.recentClosedSessions
        service = SMAppService.daemon(plistName: PowerHelperIPC.plistName)
    }

    var lastStopSummary: String? {
        recentClosedSessions.first?.stopSummary
    }

    func start() {
        refreshHelperState()
        guard helperState == .enabled else { return }
        refreshActualState()
    }

    func stop() {
        monitorTask?.cancel()
        operationTask?.cancel()
        approvalTask?.cancel()
        monitorTask = nil
        operationTask = nil
        approvalTask = nil
        client.invalidate()
    }

    func refresh() {
        refreshHelperState()
        if helperState == .enabled, !isBusy {
            refreshActualState()
        }
    }

    func select(duration: ClosedLidRunDuration) {
        guard !isBusy else { return }
        if isEnabled {
            guard activeDuration != duration else { return }
            let startedAt = Date()
            activeDuration = duration
            enabledAt = startedAt
            historyStore.recordStarted(duration: duration, at: startedAt)
            notifyStateChanged()
        } else if helperState == .enabled {
            enable(duration: duration)
        } else {
            enableHelper(startSessionDuration: duration)
        }
    }

    func disable() {
        guard isEnabled, !isBusy else { return }
        disable(reason: .manual)
    }

    func enableHelper(startSessionDuration: ClosedLidRunDuration? = nil) {
        guard managesHelper else {
            helperState = .unavailable
            notifyStateChanged()
            return
        }
        enableAfterApprovalDuration = startSessionDuration
        lastError = nil
        do {
            try service.register()
        } catch {
            // A pending approval is reported through service.status below.
        }
        refreshHelperState()
        switch helperState {
        case .awaitingApproval:
            SMAppService.openSystemSettingsLoginItems()
            pollForApproval()
        case .notEnabled:
            lastError = "后台服务未能注册"
            enableAfterApprovalDuration = nil
        case .enabled:
            if let startSessionDuration {
                enableAfterApprovalDuration = nil
                enable(duration: startSessionDuration)
            }
        default:
            break
        }
        notifyStateChanged()
    }

    func openHelperApproval() {
        SMAppService.openSystemSettingsLoginItems()
        pollForApproval()
    }

    private func enable(duration: ClosedLidRunDuration) {
        isBusy = true
        lastError = nil
        notifyStateChanged()
        operationTask?.cancel()
        let client = client
        operationTask = Task { [weak self] in
            let result = await Task.detached {
                client.setSleepDisabled(true)
            }.value
            guard let self, !Task.isCancelled else { return }
            operationTask = nil
            isBusy = false
            switch result {
            case .success:
                isEnabled = true
                activeDuration = duration
                let startedAt = Date()
                enabledAt = startedAt
                historyStore.recordStarted(duration: duration, at: startedAt)
                hasObservedClosedLid = ClosedLidSafetyMonitor.snapshot().isLidClosed == true
                startMonitoring()
                Self.logger.notice("Closed-lid running session started")
            case .ownedByAnotherProcess:
                lastError = "其他应用正在控制系统睡眠"
                client.invalidate()
            case .recoveryStateFailed:
                lastError = "无法建立安全恢复状态"
                client.invalidate()
            case .commandFailed:
                lastError = "无法开启合盖运行"
                client.invalidate()
            }
            notifyStateChanged()
        }
    }

    private func disable(reason: ClosedLidStopReason) {
        guard !isBusy else { return }
        isBusy = true
        notifyStateChanged()
        operationTask?.cancel()
        let client = client
        operationTask = Task { [weak self] in
            let result = await Task.detached {
                client.setSleepDisabled(false)
            }.value
            guard let self, !Task.isCancelled else { return }
            operationTask = nil
            isBusy = false
            if result == .success {
                lastError = nil
                setDisabledState(reason: reason)
                client.invalidate()
            } else {
                lastError = "无法关闭合盖运行，后台服务将自动重试"
            }
            notifyStateChanged()
        }
    }

    private func refreshActualState() {
        guard operationTask == nil || operationTask?.isCancelled == true else { return }
        let client = client
        operationTask = Task { [weak self] in
            let result = await Task.detached {
                client.currentState()
            }.value
            guard let self, !Task.isCancelled else { return }
            operationTask = nil
            guard result.0 == .success else {
                lastError = "无法读取合盖运行状态"
                client.invalidate()
                notifyStateChanged()
                return
            }
            lastError = nil
            if result.1 {
                if !isEnabled {
                    isEnabled = true
                    let recoveredSession = historyStore.activeSession
                    let recoveredDuration = recoveredSession?.duration ?? .oneHour
                    let startedAt = recoveredSession?.startedAt ?? Date()
                    enabledAt = startedAt
                    if recoveredSession == nil {
                        historyStore.recordStarted(
                            duration: recoveredDuration,
                            at: startedAt
                        )
                    }
                    activeDuration = recoveredDuration
                    hasObservedClosedLid = ClosedLidSafetyMonitor.snapshot().isLidClosed == true
                    startMonitoring()
                }
            } else {
                let reason: ClosedLidStopReason? = historyStore.activeSession != nil
                    ? .serviceRecovery
                    : nil
                setDisabledState(reason: reason)
                client.invalidate()
            }
            notifyStateChanged()
        }
    }

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled, isEnabled, !isBusy else { continue }
                await evaluateSafety()
            }
        }
    }

    private func evaluateSafety() async {
        let snapshot = ClosedLidSafetyMonitor.snapshot()
        if snapshot.isLidClosed == true {
            hasObservedClosedLid = true
        } else if snapshot.isLidClosed == false, hasObservedClosedLid {
            disable(reason: .lidOpened)
            return
        }

        if snapshot.isOnBattery,
           let batteryPercent = snapshot.batteryPercent,
           batteryPercent < settings.closedLidBatteryThreshold.rawValue {
            disable(reason: .lowBattery)
            return
        }

        if snapshot.thermalState == .serious || snapshot.thermalState == .critical {
            disable(reason: .thermalPressure)
            return
        }

        if let maximumInterval = activeDuration?.interval,
           let enabledAt,
           Date().timeIntervalSince(enabledAt) >= maximumInterval {
            disable(reason: .timeLimit)
            return
        }

        let state = await currentHelperStateWithRetry()
        guard !Task.isCancelled, isEnabled, !isBusy else { return }
        if state.0 == .success {
            if !state.1 {
                lastError = nil
                setDisabledState(reason: .serviceRecovery)
                client.invalidate()
                notifyStateChanged()
            } else if lastError == "后台服务连接异常，正在重试" {
                lastError = nil
                notifyStateChanged()
            }
        } else {
            lastError = "后台服务连接异常，正在重试"
            notifyStateChanged()
        }
    }

    private func currentHelperStateWithRetry() async -> (PowerHelperResult, Bool) {
        let client = client
        let firstResult = await Task.detached {
            client.currentState()
        }.value
        guard firstResult.0 != .success else { return firstResult }

        client.invalidate()
        return await Task.detached {
            client.currentState()
        }.value
    }

    private func setDisabledState(reason: ClosedLidStopReason? = nil) {
        isEnabled = false
        activeDuration = nil
        enabledAt = nil
        hasObservedClosedLid = false
        monitorTask?.cancel()
        monitorTask = nil
        if let reason {
            historyStore.recordStopped(reason: reason)
            recentClosedSessions = historyStore.recentClosedSessions
            Self.logger.notice("Closed-lid running session stopped: \(reason.rawValue, privacy: .public)")
        }
    }

    private func refreshHelperState() {
        guard managesHelper else {
            helperState = .unavailable
            return
        }
        helperState = switch service.status {
        case .notRegistered: .notEnabled
        case .enabled: .enabled
        case .requiresApproval: .awaitingApproval
        case .notFound: .missing
        @unknown default: .missing
        }
    }

    private func pollForApproval() {
        approvalTask?.cancel()
        approvalTask = Task { [weak self] in
            for _ in 0..<150 {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                refreshHelperState()
                notifyStateChanged()
                if helperState != .awaitingApproval {
                    if helperState == .enabled,
                       let duration = enableAfterApprovalDuration {
                        enableAfterApprovalDuration = nil
                        enable(duration: duration)
                    }
                    return
                }
            }
        }
    }

    private var managesHelper: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
                .standardizedFileURL.path + "/")
    }

    private func notifyStateChanged() {
        onStateChanged?()
    }
}
