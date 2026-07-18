import AppKit
import CoreGraphics

private enum MouseBindingMonitorStatus: Equatable {
    case inactive
    case accessibilityPermissionRequired
    case inputMonitoringPermissionRequired
    case active
    case unavailable
}

@MainActor
final class MouseBindingCoordinator: ObservableObject {
    @Published private var status: MouseBindingMonitorStatus = .inactive

    private let settings: AppSettings
    private let performCommand: (AppCommand) -> Void
    private let feedbackController = MouseGestureFeedbackController()
    private var recognizer = MouseGestureRecognizer()
    private var pendingSingleClickTasks: [MouseSideButton: Task<Void, Never>] = [:]
    private var pendingDragPreview: PendingDragPreview?
    private var dragPreviewTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?

    private struct PendingDragPreview {
        let origin: CGPoint
        let current: CGPoint
        let direction: MouseDragDirection
        let hasAssignedAction: Bool
    }

    private lazy var eventMonitor = MouseEventMonitor { [weak self] event in
        self?.handle(event) ?? false
    }

    init(
        settings: AppSettings,
        performCommand: @escaping (AppCommand) -> Void
    ) {
        self.settings = settings
        self.performCommand = performCommand
    }

    func start() {
        if activationObserver == nil {
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    func stop() {
        eventMonitor.stop()
        cancelRecognition()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    func command(
        for button: MouseSideButton,
        gesture: MouseButtonGesture
    ) -> AppCommand? {
        settings.mouseCommand(for: button, gesture: gesture)
    }

    func updateCommand(
        _ command: AppCommand?,
        for button: MouseSideButton,
        gesture: MouseButtonGesture
    ) {
        settings.updateMouseCommand(command, for: button, gesture: gesture)
        if command != nil {
            if !AccessibilityAuthorization.isTrusted {
                _ = AccessibilityAuthorization.requestPermission()
            } else if !CGPreflightListenEventAccess() {
                _ = CGRequestListenEventAccess()
            }
        }
        refresh()
    }

    func refresh() {
        eventMonitor.stop()
        cancelRecognition()

        guard !settings.mouseBindings.isEmpty else {
            status = .inactive
            return
        }
        guard AccessibilityAuthorization.isTrusted else {
            status = .accessibilityPermissionRequired
            return
        }
        guard CGPreflightListenEventAccess() else {
            status = .inputMonitoringPermissionRequired
            return
        }
        status = eventMonitor.start() ? .active : .unavailable
    }

    private func handle(_ event: MouseButtonEvent) -> Bool {
        guard settings.hasMouseBindings(for: event.button) else { return false }

        let recognitions = recognizer.handle(
            event,
            supportsDoubleClick: command(for: event.button, gesture: .doubleClick) != nil,
            doubleClickInterval: NSEvent.doubleClickInterval,
            dragThresholdRatio: settings.mouseDragThresholdRatio,
            screenSize: event.phase == .down
                ? screenSize(containingAccessibilityPoint: event.location)
                : .zero
        )
        process(recognitions)
        return true
    }

    private func screenSize(containingAccessibilityPoint point: CGPoint) -> CGSize {
        let screens = WindowGeometry.screenGeometries()
        guard !screens.isEmpty else { return MouseGestureRecognizer.referenceScreenSize }
        let index = WindowGeometry.screenIndex(containing: point, geometries: screens)
        return screens[index].fullFrame.size
    }

    private func process(_ recognitions: [MouseGestureRecognition]) {
        for recognition in recognitions {
            switch recognition {
            case let .gesture(button, gesture):
                guard let command = command(for: button, gesture: gesture) else { continue }
                Task { @MainActor [weak self] in
                    self?.performCommand(command)
                }

            case let .dragPreview(button, direction, origin, current):
                pendingDragPreview = PendingDragPreview(
                    origin: origin,
                    current: current,
                    direction: direction,
                    hasAssignedAction: command(for: button, gesture: direction.gesture) != nil
                )
                scheduleDragPreviewUpdate()

            case .dismissDragPreview:
                pendingDragPreview = nil
                dragPreviewTask?.cancel()
                dragPreviewTask = nil
                Task { @MainActor [weak self] in
                    self?.feedbackController.dismiss()
                }

            case let .scheduleSingleClick(button, token, deadline):
                pendingSingleClickTasks[button]?.cancel()
                let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
                pendingSingleClickTasks[button] = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled, let self else { return }
                    self.pendingSingleClickTasks[button] = nil
                    guard let recognition = self.recognizer.completePendingSingleClick(
                        for: button,
                        token: token
                    ) else {
                        return
                    }
                    self.process([recognition])
                }

            case let .cancelSingleClick(button, token):
                _ = token
                pendingSingleClickTasks[button]?.cancel()
                pendingSingleClickTasks[button] = nil
            }
        }
    }

    private func cancelRecognition() {
        pendingSingleClickTasks.values.forEach { $0.cancel() }
        pendingSingleClickTasks.removeAll()
        pendingDragPreview = nil
        dragPreviewTask?.cancel()
        dragPreviewTask = nil
        process(recognizer.reset())
        feedbackController.dismiss()
    }

    private func scheduleDragPreviewUpdate() {
        guard dragPreviewTask == nil else { return }
        dragPreviewTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            let preview = self.pendingDragPreview
            self.pendingDragPreview = nil
            self.dragPreviewTask = nil
            guard let preview else { return }
            self.feedbackController.updatePath(
                fromAccessibilityPoint: preview.origin,
                toAccessibilityPoint: preview.current,
                direction: preview.direction,
                hasAssignedAction: preview.hasAssignedAction
            )
        }
    }
}
