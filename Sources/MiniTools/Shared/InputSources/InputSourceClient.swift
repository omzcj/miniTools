import Carbon
import Foundation
import OSLog

struct EnglishInputSourceOverride {
    let previousIdentifier: String
    let selectedIdentifier: String
}

enum InputSourceHelperPrewarmer {
    static func prewarm() {
        FocusedApplicationInputSources.prewarm()
    }
}

@MainActor
struct InputSourceClient {
    var currentIdentifier: () -> String?
    var preferredEnglishIdentifier: () -> String?
    var select: (String) -> Bool
    var beginEnglishOverride: (() -> EnglishInputSourceOverride?)? = nil

    static var currentProcess: InputSourceClient {
        InputSourceClient(
            currentIdentifier: {
                SystemInputSources.currentIdentifier()
            },
            preferredEnglishIdentifier: {
                SystemInputSources.preferredEnglishIdentifier()
            },
            select: { identifier in
                SystemInputSources.select(identifier: identifier)
            }
        )
    }

    static var focusedApplication: InputSourceClient {
        InputSourceClient(
            currentIdentifier: {
                FocusedApplicationInputSources.currentIdentifier()
            },
            preferredEnglishIdentifier: {
                FocusedApplicationInputSources.preferredEnglishIdentifier()
            },
            select: { identifier in
                FocusedApplicationInputSources.select(identifier: identifier)
            },
            beginEnglishOverride: {
                FocusedApplicationInputSources.beginEnglishOverride()
            }
        )
    }
}

private enum SystemInputSources {
    static func currentIdentifier() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return identifier(for: source)
    }

    static func preferredEnglishIdentifier() -> String? {
        let source = TISCopyCurrentASCIICapableKeyboardInputSource()
            .takeRetainedValue()
        return identifier(for: source)
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

    private static func identifier(for source: TISInputSource) -> String? {
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
}

private enum FocusedApplicationInputSources {
    private static let helperName = "MiniToolsInputSourceHelper"
    private static let logger = Logger(
        subsystem: "com.omzcj.minitools",
        category: "InputSource"
    )

    static func prewarm() {
        guard helperURL != nil else { return }
        _ = runHelper(arguments: ["preferred-english"])
    }

    static func beginEnglishOverride() -> EnglishInputSourceOverride? {
        guard helperURL != nil else {
            guard
                let currentIdentifier = SystemInputSources.currentIdentifier(),
                let englishIdentifier = SystemInputSources.preferredEnglishIdentifier(),
                currentIdentifier != englishIdentifier,
                SystemInputSources.select(identifier: englishIdentifier)
            else {
                return nil
            }
            return EnglishInputSourceOverride(
                previousIdentifier: currentIdentifier,
                selectedIdentifier: englishIdentifier
            )
        }

        guard let output = runHelper(arguments: ["begin-english"]) else {
            return nil
        }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first == "changed", lines.count == 3 else {
            return nil
        }
        return EnglishInputSourceOverride(
            previousIdentifier: String(lines[1]),
            selectedIdentifier: String(lines[2])
        )
    }

    static func currentIdentifier() -> String? {
        guard helperURL != nil else {
            return SystemInputSources.currentIdentifier()
        }
        return runHelper(arguments: ["current"])
    }

    static func preferredEnglishIdentifier() -> String? {
        guard helperURL != nil else {
            return SystemInputSources.preferredEnglishIdentifier()
        }
        return runHelper(arguments: ["preferred-english"])
    }

    static func select(identifier: String) -> Bool {
        guard helperURL != nil else {
            return SystemInputSources.select(identifier: identifier)
        }
        return runHelper(arguments: ["select", identifier]) != nil
    }

    private static var helperURL: URL? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers", isDirectory: true)
            .appendingPathComponent(helperName, isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: candidate.path) else {
            return nil
        }
        return candidate
    }

    private static func runHelper(arguments: [String]) -> String? {
        guard let helperURL else { return nil }

        let process = Process()
        let output = Pipe()
        process.executableURL = helperURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("Unable to launch input source helper: \(error.localizedDescription)")
            return nil
        }

        guard process.terminationStatus == 0 else {
            logger.error(
                "Input source helper failed with status \(process.terminationStatus)"
            )
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
