import Foundation
import MiniToolsPowerSupport

final class PowerHelperClient: @unchecked Sendable {
    private let lock = NSLock()
    private var connection: NSXPCConnection?
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    func setSleepDisabled(_ disabled: Bool) -> PowerHelperResult {
        let rawResult = LockedValue<Int32>(PowerHelperResult.commandFailed.rawValue)
        let replied = call { proxy, finish in
            proxy.setSleepDisabled(disabled) { result in
                rawResult.value = result
                finish()
            }
        }
        guard replied else { return .commandFailed }
        return PowerHelperResult(rawValue: rawResult.value) ?? .commandFailed
    }

    func currentState() -> (PowerHelperResult, Bool) {
        let rawResult = LockedValue<Int32>(PowerHelperResult.commandFailed.rawValue)
        let enabled = LockedValue(false)
        let replied = call { proxy, finish in
            proxy.currentState { result, currentState in
                rawResult.value = result
                enabled.value = currentState
                finish()
            }
        }
        guard replied else { return (.commandFailed, false) }
        return (
            PowerHelperResult(rawValue: rawResult.value) ?? .commandFailed,
            enabled.value
        )
    }

    func invalidate() {
        lock.lock()
        let existingConnection = connection
        connection = nil
        lock.unlock()
        existingConnection?.invalidate()
    }

    private func call(
        _ body: (
            PowerHelperProtocol,
            @escaping @Sendable () -> Void
        ) -> Void
    ) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let completion = OneShotCompletion {
            semaphore.signal()
        }
        guard let proxy = proxy(errorHandler: {
            completion.finish()
        }) else {
            return false
        }
        body(proxy) {
            completion.finish()
        }
        return semaphore.wait(timeout: .now() + timeout) == .success
    }

    private func proxy(
        errorHandler: @escaping @Sendable () -> Void
    ) -> PowerHelperProtocol? {
        let connection = activeConnection()
        return connection.remoteObjectProxyWithErrorHandler { _ in
            errorHandler()
        } as? PowerHelperProtocol
    }

    private func activeConnection() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }
        if let connection { return connection }

        let newConnection = NSXPCConnection(
            machServiceName: PowerHelperIPC.machServiceName,
            options: .privileged
        )
        newConnection.setCodeSigningRequirement(
            PowerHelperIPC.peerRequirement(
                identifier: PowerHelperIPC.helperCodeSignIdentifier
            )
        )
        newConnection.remoteObjectInterface = NSXPCInterface(
            with: PowerHelperProtocol.self
        )
        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            guard let self, let newConnection else { return }
            self.lock.lock()
            if self.connection === newConnection {
                self.connection = nil
            }
            self.lock.unlock()
        }
        newConnection.resume()
        connection = newConnection
        return newConnection
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

private final class OneShotCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var hasFinished = false
    private let completion: @Sendable () -> Void

    init(completion: @escaping @Sendable () -> Void) {
        self.completion = completion
    }

    func finish() {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        lock.unlock()
        completion()
    }
}
