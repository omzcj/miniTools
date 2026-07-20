import AppKit
import Combine

@MainActor
final class SpotlightInputSourceCoordinator {
    private static let focusStabilizationDelay = Duration.milliseconds(20)
    private static let inputSourceVerificationDelay = Duration.milliseconds(400)
    private static let closeResolutionDelay = Duration.milliseconds(250)

    private let settings: AppSettings
    private let session: SpotlightEnglishSession
    private lazy var monitor: SpotlightAccessibilityMonitor = {
        let monitor = SpotlightAccessibilityMonitor()
        monitor.onSearchFocusChanged = { [weak self] isFocused in
            self?.spotlightSearchFocusChanged(isFocused)
        }
        return monitor
    }()

    private var workspaceObservers: [NSObjectProtocol] = []
    private var settingsObservation: AnyCancellable?
    private var focusActivationTask: Task<Void, Never>?
    private var inputSourceVerificationTask: Task<Void, Never>?
    private var closeResolutionTask: Task<Void, Never>?
    private var helperPrewarmTask: Task<Void, Never>?
    private var lastExternalApplication: NSRunningApplication?
    private var isStarted = false

    init(
        settings: AppSettings,
        englishInputSources: EnglishInputSourceCoordinator
    ) {
        self.settings = settings
        session = SpotlightEnglishSession(englishInputSources: englishInputSources)
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        helperPrewarmTask = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return }
            InputSourceHelperPrewarmer.prewarm()
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            workspaceObservers.append(
                workspaceCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.workspaceApplicationChanged()
                    }
                }
            )
        }

        settingsObservation = settings.$spotlightUsesEnglishInputSource
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                Task { @MainActor in
                    self?.setEnabled(isEnabled)
                }
            }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        focusActivationTask?.cancel()
        focusActivationTask = nil
        inputSourceVerificationTask?.cancel()
        inputSourceVerificationTask = nil
        closeResolutionTask?.cancel()
        closeResolutionTask = nil
        helperPrewarmTask?.cancel()
        helperPrewarmTask = nil
        settingsObservation?.cancel()
        settingsObservation = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers = []
        monitor.stop()
        session.stop()
    }

    private func setEnabled(_ isEnabled: Bool) {
        focusActivationTask?.cancel()
        focusActivationTask = nil
        inputSourceVerificationTask?.cancel()
        inputSourceVerificationTask = nil
        closeResolutionTask?.cancel()
        closeResolutionTask = nil

        guard isEnabled else {
            monitor.stop()
            session.stop()
            return
        }

        if !AccessibilityAuthorization.isTrusted {
            _ = AccessibilityAuthorization.requestPermission()
        }
        monitor.startIfPossible()
    }

    private func workspaceApplicationChanged() {
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        guard settings.spotlightUsesEnglishInputSource else { return }
        monitor.startIfPossible()
    }

    private func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard
            let application,
            application.bundleIdentifier != SpotlightAccessibilityMonitor.bundleIdentifier,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }
        lastExternalApplication = application
    }

    private func spotlightSearchFocusChanged(_ isFocused: Bool) {
        focusActivationTask?.cancel()
        focusActivationTask = nil
        inputSourceVerificationTask?.cancel()
        inputSourceVerificationTask = nil
        closeResolutionTask?.cancel()
        closeResolutionTask = nil

        guard settings.spotlightUsesEnglishInputSource else {
            session.stop()
            return
        }

        if isFocused {
            guard !session.isActive else { return }
            focusActivationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: Self.focusStabilizationDelay)
                guard let self, !Task.isCancelled else { return }
                guard monitor.searchFieldIsFocusedNow() else { return }
                session.begin(originApplication: currentExternalApplicationIdentity())
                focusActivationTask = nil
                scheduleInputSourceVerification()
            }
            return
        }

        guard session.isActive else { return }
        closeResolutionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.closeResolutionDelay)
            guard let self, !Task.isCancelled else { return }
            if monitor.searchFieldIsFocusedNow() {
                spotlightSearchFocusChanged(true)
                return
            }
            session.finish(destinationApplication: currentExternalApplicationIdentity())
            closeResolutionTask = nil
        }
    }

    private func scheduleInputSourceVerification() {
        inputSourceVerificationTask?.cancel()
        inputSourceVerificationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.inputSourceVerificationDelay)
            guard let self, !Task.isCancelled else { return }
            guard monitor.searchFieldIsFocusedNow() else { return }
            session.ensureEnglish()
            inputSourceVerificationTask = nil
        }
    }

    private func currentExternalApplicationIdentity() -> ApplicationIdentity? {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        rememberExternalApplication(frontmostApplication)
        guard let application = lastExternalApplication else { return nil }
        return ApplicationIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier
        )
    }
}
