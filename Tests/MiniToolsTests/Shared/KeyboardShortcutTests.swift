import AppKit
import Carbon
import XCTest
@testable import MiniTools

@MainActor
final class KeyboardShortcutTests: XCTestCase {
    func testCreatesFourModifierSpaceShortcutFromKeyEvent() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .option, .control, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: UInt16(kVK_Space)
        ))

        let shortcut = try XCTUnwrap(KeyboardShortcut(event: event))
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(
            shortcut.carbonModifiers,
            UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )
        XCTAssertEqual(shortcut.displayName, "⌃⌥⇧⌘Space")
    }

    func testSettingsShortcutIsRecognizedFromAFeaturePanel() throws {
        let commandComma = try makeCommaEvent(modifiers: .command)
        let commandShiftComma = try makeCommaEvent(modifiers: [.command, .shift])
        let plainComma = try makeCommaEvent(modifiers: [])

        XCTAssertEqual(
            FeaturePanelCommandRouter.command(for: commandComma),
            .openSettings
        )
        XCTAssertNotEqual(
            FeaturePanelCommandRouter.command(for: commandShiftComma),
            .openSettings
        )
        XCTAssertNotEqual(
            FeaturePanelCommandRouter.command(for: plainComma),
            .openSettings
        )
    }

    func testTabSwitchesFeaturePanelsWithoutConflictingModifiers() throws {
        let tab = try makeKeyEvent(keyCode: kVK_Tab, characters: "\t", modifiers: [])
        let shiftTab = try makeKeyEvent(keyCode: kVK_Tab, characters: "\t", modifiers: .shift)
        let controlTab = try makeKeyEvent(keyCode: kVK_Tab, characters: "\t", modifiers: .control)
        let returnKey = try makeKeyEvent(keyCode: kVK_Return, characters: "\r", modifiers: [])

        XCTAssertEqual(FeaturePanelCommandRouter.command(for: tab), .switchPanel)
        XCTAssertEqual(FeaturePanelCommandRouter.command(for: shiftTab), .switchPanel)
        XCTAssertNotEqual(FeaturePanelCommandRouter.command(for: controlTab), .switchPanel)
        XCTAssertNotEqual(FeaturePanelCommandRouter.command(for: returnKey), .switchPanel)
    }

    func testRoutesDirectAndCharacterCommandsWithoutModifierLeakage() throws {
        let commandOne = try makeKeyEvent(
            keyCode: kVK_ANSI_1,
            characters: "1",
            modifiers: .command
        )
        let shiftedA = try makeKeyEvent(
            keyCode: kVK_ANSI_A,
            characters: "A",
            modifiers: .shift
        )
        let commandA = try makeKeyEvent(
            keyCode: kVK_ANSI_A,
            characters: "a",
            modifiers: .command
        )

        XCTAssertEqual(FeaturePanelCommandRouter.command(for: commandOne), .directAction(0))
        XCTAssertEqual(FeaturePanelCommandRouter.command(for: shiftedA), .character("a"))
        XCTAssertNil(FeaturePanelCommandRouter.command(for: commandA))
    }

    private func makeCommaEvent(modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try makeKeyEvent(
            keyCode: kVK_ANSI_Comma,
            characters: ",",
            modifiers: modifiers
        )
    }

    private func makeKeyEvent(
        keyCode: Int,
        characters: String,
        modifiers: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ))
    }
}
