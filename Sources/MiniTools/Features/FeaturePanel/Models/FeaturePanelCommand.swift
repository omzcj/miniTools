import AppKit
import Carbon

enum FeaturePanelCommand: Equatable {
    case openSettings
    case switchPanel
    case moveSelection(Int)
    case execute
    case cancel
    case directAction(Int)
    case character(String)
}

enum FeaturePanelCommandRouter {
    static func command(for event: NSEvent) -> FeaturePanelCommand? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers == .command, event.charactersIgnoringModifiers == "," {
            return .openSettings
        }

        if Int(event.keyCode) == kVK_Tab {
            let blocked: NSEvent.ModifierFlags = [.command, .control, .option]
            if modifiers.intersection(blocked).isEmpty {
                return .switchPanel
            }
        }

        switch Int(event.keyCode) {
        case kVK_UpArrow:
            return .moveSelection(-1)
        case kVK_DownArrow:
            return .moveSelection(1)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return .execute
        case kVK_Escape:
            return .cancel
        default:
            break
        }

        if modifiers.contains(.command),
           let key = event.charactersIgnoringModifiers,
           let number = Int(key),
           (1...9).contains(number) {
            return .directAction(number - 1)
        }

        let blockedCharacterModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard modifiers.intersection(blockedCharacterModifiers).isEmpty,
              let key = event.charactersIgnoringModifiers?.lowercased(),
              key.count == 1 else {
            return nil
        }
        return .character(key)
    }
}
