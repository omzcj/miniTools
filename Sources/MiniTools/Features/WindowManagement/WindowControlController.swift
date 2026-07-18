import AppKit

@MainActor
final class WindowControlController {
    private let cursorHighlightController = CursorHighlightController()
    private let feedbackController = WindowActionFeedbackController()

    func perform(
        _ id: WindowControlID,
        cursorHighlightStyles: Set<CursorHighlightStyle>
    ) {
        if let command = WindowControlCatalog.layoutCommand(for: id) {
            performWindowAction { try await WindowLayoutService.applyLayout(command) }
            return
        }

        switch id {
        case .moveWindowToNextScreen:
            performWindowAction { try await WindowLayoutService.moveFocusedWindowToNextScreen() }
        case .movePointerToNextScreen:
            movePointerToNextScreen(cursorHighlightStyles: cursorHighlightStyles)
        case .centerWindow:
            performWindowAction { try await WindowLayoutService.centerFocusedWindow() }
        default:
            break
        }
    }

    private func movePointerToNextScreen(
        cursorHighlightStyles: Set<CursorHighlightStyle>
    ) {
        Task { [weak self] in
            do {
                let target = try await PointerMover.moveToNextScreen()
                self?.cursorHighlightController.show(
                    atAccessibilityPoint: target,
                    enabledStyles: cursorHighlightStyles
                )
            } catch {
                self?.report(error)
            }
        }
    }

    private func performWindowAction(_ action: @escaping () async throws -> Void) {
        Task { [weak self] in
            do {
                try await action()
            } catch {
                self?.report(error)
            }
        }
    }

    private func report(_ error: Error) {
        NSSound.beep()
        let message = error.localizedDescription
        feedbackController.showError(message)
    }
}
