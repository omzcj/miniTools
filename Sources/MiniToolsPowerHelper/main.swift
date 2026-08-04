import Darwin
import Foundation
import MiniToolsPowerSupport
import OSLog

private let logger = Logger(
    subsystem: "com.omzcj.minitools.power-helper",
    category: "PowerHelper"
)

private final class PowerState: @unchecked Sendable {
    let queue = DispatchQueue(label: "com.omzcj.minitools.power-helper.state")
    private let sentinelURL = URL(fileURLWithPath: PowerHelperIPC.sentinelPath)

    func ownsSleepDisable() -> Bool {
        var information = stat()
        guard lstat(PowerHelperIPC.sentinelPath, &information) == 0 else { return false }
        return information.st_uid == 0
            && (information.st_mode & S_IFMT) == S_IFREG
            && (information.st_mode & 0o022) == 0
    }

    func enable() -> PowerHelperResult {
        let settings = PowerCommandRunner.currentSettings()
        guard settings.exitCode == 0,
              let currentlyDisabled = PowerSettingsParser.sleepDisabled(from: settings.output) else {
            return .commandFailed
        }
        if currentlyDisabled, !ownsSleepDisable() {
            return .ownedByAnotherProcess
        }

        do {
            let directory = sentinelURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try FileManager.default.setAttributes(
                [.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: 0o755],
                ofItemAtPath: directory.path
            )
            try Data().write(to: sentinelURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: 0o600],
                ofItemAtPath: sentinelURL.path
            )
        } catch {
            logger.error("Unable to create recovery state: \(error.localizedDescription, privacy: .public)")
            return .recoveryStateFailed
        }

        let result = PowerCommandRunner.setSleepDisabled(true)
        guard result.exitCode == 0 else {
            try? FileManager.default.removeItem(at: sentinelURL)
            logger.error("Unable to disable sleep: \(result.output, privacy: .public)")
            return .commandFailed
        }
        logger.notice("Closed-lid running enabled")
        return .success
    }

    @discardableResult
    func restore(reason: String) -> PowerHelperResult {
        guard ownsSleepDisable() else { return .success }
        let result = PowerCommandRunner.setSleepDisabled(false)
        guard result.exitCode == 0 else {
            logger.error("Unable to restore sleep (\(reason, privacy: .public)): \(result.output, privacy: .public)")
            return .commandFailed
        }
        try? FileManager.default.removeItem(at: sentinelURL)
        logger.notice("Sleep restored (\(reason, privacy: .public))")
        return .success
    }

    func currentState() -> (PowerHelperResult, Bool) {
        guard ownsSleepDisable() else { return (.success, false) }
        let settings = PowerCommandRunner.currentSettings()
        guard settings.exitCode == 0,
              let disabled = PowerSettingsParser.sleepDisabled(from: settings.output) else {
            return (.commandFailed, false)
        }
        if !disabled {
            try? FileManager.default.removeItem(at: sentinelURL)
        }
        return (.success, disabled)
    }
}

private final class PowerService: NSObject, PowerHelperProtocol, @unchecked Sendable {
    private let state: PowerState

    init(state: PowerState) {
        self.state = state
    }

    func ping(reply: @escaping @Sendable (Int) -> Void) {
        reply(PowerHelperIPC.protocolVersion)
    }

    func setSleepDisabled(
        _ disabled: Bool,
        reply: @escaping @Sendable (Int32) -> Void
    ) {
        state.queue.async { [state] in
            let result = disabled ? state.enable() : state.restore(reason: "app request")
            reply(result.rawValue)
        }
    }

    func currentState(
        reply: @escaping @Sendable (Int32, Bool) -> Void
    ) {
        state.queue.async { [state] in
            let result = state.currentState()
            reply(result.0.rawValue, result.1)
        }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let state: PowerState
    private let service: PowerService
    private var connections = Set<ObjectIdentifier>()
    private var watchdog: DispatchWorkItem?

    init(state: PowerState) {
        self.state = state
        service = PowerService(state: state)
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.setCodeSigningRequirement(
            PowerHelperIPC.peerRequirement(
                identifier: PowerHelperIPC.appCodeSignIdentifier
            )
        )
        connection.exportedInterface = NSXPCInterface(with: PowerHelperProtocol.self)
        connection.exportedObject = service

        let identifier = ObjectIdentifier(connection)
        state.queue.sync {
            connections.insert(identifier)
            watchdog?.cancel()
            watchdog = nil
        }
        connection.invalidationHandler = { [weak self] in
            self?.connectionEnded(identifier)
        }
        connection.resume()
        return true
    }

    private func connectionEnded(_ identifier: ObjectIdentifier) {
        state.queue.async { [weak self] in
            guard let self else { return }
            connections.remove(identifier)
            guard connections.isEmpty, state.ownsSleepDisable() else { return }

            watchdog?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self, connections.isEmpty else { return }
                state.restore(reason: "app disconnected")
                watchdog = nil
            }
            watchdog = task
            state.queue.asyncAfter(
                deadline: .now() + PowerHelperIPC.watchdogGraceSeconds,
                execute: task
            )
        }
    }

    func retryRecoveryIfUnattended() {
        state.queue.async { [weak self] in
            guard let self,
                  connections.isEmpty,
                  watchdog == nil,
                  state.ownsSleepDisable() else {
                return
            }
            state.restore(reason: "recovery retry")
        }
    }

    func isIdle() -> Bool {
        state.queue.sync {
            connections.isEmpty
                && watchdog == nil
                && !state.ownsSleepDisable()
        }
    }
}

private let state = PowerState()
state.queue.sync {
    if state.ownsSleepDisable() {
        state.restore(reason: "helper launch recovery")
    }
}

private let delegate = ListenerDelegate(state: state)
let listener = NSXPCListener(machServiceName: PowerHelperIPC.machServiceName)
listener.delegate = delegate
listener.resume()

let recoveryTimer = DispatchSource.makeTimerSource(
    queue: DispatchQueue(label: "com.omzcj.minitools.power-helper.recovery")
)
recoveryTimer.schedule(
    deadline: .now() + PowerHelperIPC.recoveryRetrySeconds,
    repeating: PowerHelperIPC.recoveryRetrySeconds,
    leeway: .seconds(5)
)
recoveryTimer.setEventHandler {
    delegate.retryRecoveryIfUnattended()
    if delegate.isIdle() {
        exit(EXIT_SUCCESS)
    }
}
recoveryTimer.resume()

dispatchMain()
