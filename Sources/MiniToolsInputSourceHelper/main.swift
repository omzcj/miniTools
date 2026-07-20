import Carbon
import Darwin
import Foundation

private enum InputSourceCommand: String {
    case beginEnglish = "begin-english"
    case current
    case preferredEnglish = "preferred-english"
    case select
}

private enum InputSourceHelper {
    static func identifier(for source: TISInputSource) -> String? {
        guard let rawIdentifier = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return nil
        }
        return Unmanaged<CFString>
            .fromOpaque(rawIdentifier)
            .takeUnretainedValue() as String
    }

    static func select(identifier: String) -> Bool {
        let properties = [
            kTISPropertyInputSourceID as String: identifier
        ] as CFDictionary
        let matches = TISCreateInputSourceList(properties, false)
            .takeRetainedValue() as NSArray
        guard matches.count > 0 else { return false }

        let value = matches.object(at: 0) as CFTypeRef
        guard CFGetTypeID(value) == TISInputSourceGetTypeID() else { return false }
        let source = unsafeDowncast(value, to: TISInputSource.self)
        return TISSelectInputSource(source) == noErr
    }
}

guard
    CommandLine.arguments.count >= 2,
    let command = InputSourceCommand(rawValue: CommandLine.arguments[1])
else {
    exit(64)
}

switch command {
case .beginEnglish:
    let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let englishSource = TISCopyCurrentASCIICapableKeyboardInputSource()
        .takeRetainedValue()
    guard
        let currentIdentifier = InputSourceHelper.identifier(for: currentSource),
        let englishIdentifier = InputSourceHelper.identifier(for: englishSource)
    else {
        exit(1)
    }
    guard currentIdentifier != englishIdentifier else {
        print("unchanged")
        break
    }
    guard InputSourceHelper.select(identifier: englishIdentifier) else {
        exit(1)
    }
    print("changed")
    print(currentIdentifier)
    print(englishIdentifier)

case .current:
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let identifier = InputSourceHelper.identifier(for: source) else {
        exit(1)
    }
    print(identifier)

case .preferredEnglish:
    let source = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
    guard let identifier = InputSourceHelper.identifier(for: source) else {
        exit(1)
    }
    print(identifier)

case .select:
    guard CommandLine.arguments.count == 3 else {
        exit(64)
    }
    guard InputSourceHelper.select(identifier: CommandLine.arguments[2]) else {
        exit(1)
    }
}
