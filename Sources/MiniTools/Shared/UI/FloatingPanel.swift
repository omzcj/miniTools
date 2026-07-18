import AppKit

final class FloatingPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Let the input method consume arrows/Return while a composed character is active.
            if let editor = firstResponder as? NSTextView, editor.hasMarkedText() {
                super.sendEvent(event)
                return
            }
            if keyHandler?(event) == true { return }
        }
        super.sendEvent(event)
    }
}
