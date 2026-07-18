import Foundation

@MainActor
final class ApplicationContext: ObservableObject {
    let settings: AppSettings
    private let cursorHighlightPreviewController = CursorHighlightController()
    @Published private(set) var shortcutCoordinator: GlobalShortcutCoordinator?
    @Published private(set) var mouseBindingCoordinator: MouseBindingCoordinator?

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func install(shortcutCoordinator: GlobalShortcutCoordinator) {
        self.shortcutCoordinator = shortcutCoordinator
    }

    func install(mouseBindingCoordinator: MouseBindingCoordinator) {
        self.mouseBindingCoordinator = mouseBindingCoordinator
    }

    func previewCursorHighlight(_ style: CursorHighlightStyle) {
        cursorHighlightPreviewController.preview(style)
    }
}
