import AppKit
import Foundation
import MiniToolsPowerSupport
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
    static let batteryFloorPercent = 20

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var helperState: ClosedLidHelperState = .unavailable
    @Published private(set) var lastError: String?

    var onStateChanged: (() -> Void)?

    private let settings: AppSettings
    private let client: PowerHelperClient
    private let service: SMAppService
    private var monitorTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var approvalTask: Task<Void, Never>?
    private var enabledAt: Date?
    private var hasObservedClosedLid = false
    private var enableAfterApproval = false

    init(
        settings: AppSettings,
        client: PowerHelperClient = PowerHelperClient()
    ) {
        self.settings = settings
        self.client = client
        service = SMAppService.daemon(plistName: PowerHelperIPC.plistName)
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

    func toggle() {
        guard !isBusy else { return }
        if isEnabled {
            disable()
        } else if helperState == .enabled {
            enable()
        } else {
            enableHelper(startSessionWhenReady: true)
        }
    }

    func enableHelper(startSessionWhenReady: Bool = false) {
        guard managesHelper else {
            helperState = .unavailable
            notifyStateChanged()
            return
        }
        enableAfterApproval = startSessionWhenReady
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
            enableAfterApproval = false
        case .enabled where startSessionWhenReady:
            enableAfterApproval = false
            enable()
        default:
            break
        }
        notifyStateChanged()
    }

    func openHelperApproval() {
        SMAppService.openSystemSettingsLoginItems()
        pollForApproval()
    }

    private func enable() {
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
                enabledAt = Date()
                hasObservedClosedLid = ClosedLidSafetyMonitor.snapshot().isLidClosed == true
                startMonitoring()
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

    private func disable() {
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
                setDisabledState()
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
            if result.1 != isEnabled {
                isEnabled = result.1
                if result.1 {
                    enabledAt = Date()
                    hasObservedClosedLid = ClosedLidSafetyMonitor.snapshot().isLidClosed == true
                    startMonitoring()
                } else {
                    setDisabledState()
                    client.invalidate()
                }
            } else if !result.1 {
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
                evaluateSafety()
            }
        }
    }

    private func evaluateSafety() {
        let snapshot = ClosedLidSafetyMonitor.snapshot()
        if snapshot.isLidClosed == true {
            hasObservedClosedLid = true
        } else if snapshot.isLidClosed == false, hasObservedClosedLid {
            disable()
            return
        }

        if snapshot.isOnBattery,
           let batteryPercent = snapshot.batteryPercent,
           batteryPercent < Self.batteryFloorPercent {
            disable()
            return
        }

        if snapshot.thermalState == .serious || snapshot.thermalState == .critical {
            disable()
            return
        }

        if let maximumInterval = settings.closedLidMaximumDuration.interval,
           let enabledAt,
           Date().timeIntervalSince(enabledAt) >= maximumInterval {
            disable()
        }
    }

    private func setDisabledState() {
        isEnabled = false
        enabledAt = nil
        hasObservedClosedLid = false
        monitorTask?.cancel()
        monitorTask = nil
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
                    if helperState == .enabled, enableAfterApproval {
                        enableAfterApproval = false
                        enable()
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
