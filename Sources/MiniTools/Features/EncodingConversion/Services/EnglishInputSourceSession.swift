import Carbon
import Foundation

@MainActor
final class EnglishInputSourceSession {
    private var previousInputSource: TISInputSource?

    func begin() {
        guard previousInputSource == nil else { return }

        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let ascii = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
        guard !CFEqual(current, ascii), TISSelectInputSource(ascii) == noErr else {
            return
        }
        previousInputSource = current
    }

    func end() {
        guard let previousInputSource else { return }
        _ = TISSelectInputSource(previousInputSource)
        self.previousInputSource = nil
    }
}
