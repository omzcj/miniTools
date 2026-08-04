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

    func testRejectsMissingOrUnexpectedState() {
        XCTAssertNil(PowerSettingsParser.sleepDisabled(from: "sleep 1\n"))
        XCTAssertNil(PowerSettingsParser.sleepDisabled(from: "SleepDisabled 2\n"))
    }
}
