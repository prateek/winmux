@testable import AppBundle
import Common
import XCTest

@MainActor
final class SectionsParsingTest: XCTestCase {
    func testBadGroupingMessagesListOnlyAcceptedValues() {
        XCTAssertEqual(parseCommand("sections spiral").errorOrNil,
                       "Possible sections values: next, none, workspace, project, monitor, app")
        for value in ["spiral", "next"] {
            XCTAssertEqual(parseCommand("lens recent --sections \(value)").errorOrNil,
                           "Possible sections values: none, workspace, project, monitor, app")
        }
    }

    func testGenericSectionsErrorsKeepTheirPrefix() {
        XCTAssertEqual(parseCommand("sections").errorOrNil, "ERROR: Argument '<grouping>' is mandatory")
        XCTAssertEqual(parseCommand("sections app extra").errorOrNil, "ERROR: Unknown argument 'extra'")
        XCTAssertEqual(parseCommand("sections --bogus").errorOrNil,
                       "ERROR: Unknown flag '--bogus'\nERROR: Argument '<grouping>' is mandatory")
    }

    func testConfigBindingRejectsBadGroupingWithTheSameMessage() {
        let (_, errors) = parseConfig("""
            [mode.main.binding]
            cmd-g = 'sections spiral'
            """)
        XCTAssertEqual(errors.descriptions, [
            "mode.main.binding.cmd-g: Possible sections values: next, none, workspace, project, monitor, app",
        ])
    }
}
