import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: KeyboardShortcut
    let onChange: (KeyboardShortcut) -> Bool

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = onChange
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        guard !button.isRecording else { return }
        button.shortcut = shortcut
        button.updateTitle()
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: KeyboardShortcut = .panelDefault
    var onChange: ((KeyboardShortcut) -> Bool)?
    private(set) var isRecording = false
    nonisolated(unsafe) private var keyEventMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .glass
        target = self
        action = #selector(beginRecording)
        updateTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "请按下新快捷键…"
        window?.makeFirstResponder(self)
        startKeyEventMonitor()
    }

    override func keyDown(with event: NSEvent) {
        record(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        record(event)
        return true
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == 53 {
            finishRecording()
            return
        }

        guard let value = KeyboardShortcut(event: event) else {
            NSSound.beep()
            title = "快捷键需包含修饰键"
            return
        }
        if onChange?(value) != false {
            shortcut = value
        }
        finishRecording()
    }

    private func startKeyEventMonitor() {
        stopKeyEventMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.record(event)
            return nil
        }
    }

    private func stopKeyEventMonitor() {
        guard let keyEventMonitor else { return }
        NSEvent.removeMonitor(keyEventMonitor)
        self.keyEventMonitor = nil
    }

    private func finishRecording() {
        isRecording = false
        stopKeyEventMonitor()
        updateTitle()
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        stopKeyEventMonitor()
        updateTitle()
        return super.resignFirstResponder()
    }

    deinit {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
    }

    func updateTitle() {
        title = shortcut.displayName
    }
}
