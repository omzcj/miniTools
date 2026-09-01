import XCTest
@testable import MiniToolsPowerSupport

final class PowerSettingsParserTests: XCTestCase {
    func testParsesEnabledStateWithArbitraryWhitespace() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        """

        XCTAssertEqual(PowerSettingsParser.sleepDisabled(from: output), true)
    }

    func testParsesDisabledState() {
        XCTAssertEqual(
            PowerSettingsParser.sleepDisabled(from: " SleepDisabled 0\n"),
            false
        )
    }

    func testTreatsMissingStateAsSystemDefault() {
        let output = """
        System-wide power settings:
        Currently in use:
         sleep                1
        """

        XCTAssertEqual(PowerSettingsParser.sleepDisabled(from: output), false)
    }

    func testRejectsUnexpectedState() {
        XCTAssertNil(PowerSettingsParser.sleepDisabled(from: "SleepDisabled 2\n"))
    }
}
