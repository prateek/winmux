import Common
import XCTest

final class ParseFailureExitCodeTest: XCTestCase {
    func testEverySectionsParseFailureExitsTwo() {
        for raw in ["sections spiral", "sections", "sections app extra", "sections --bogus"] {
            let args = raw.split(separator: " ").map(String.init).slice
            XCTAssertNotNil(parseCmdArgs(args).errorOrNil, raw)
            XCTAssertEqual(parseFailureExitCode(args), 2, raw)
        }
    }

    func testExistingCommandsKeepTheirParseFailureExitCodes() {
        let cases: [(String, Int32)] = [
            ("lens --bogus", 2), ("list-lenses --bogus", 2), ("summon --bogus", 2),
            ("list-windows --lens", 2), ("list-windows --filter", 2), ("list-windows --search", 2),
            ("config check --bogus", 2), ("config convert --bogus", 2),
            ("config status --bogus", 2), ("config schema --bogus", 2),
            ("focus-column --bogus", 2), ("move-node-to-column --bogus", 2),
            ("column-width --bogus", 2), ("compact --bogus", 2),
            ("list-columns --bogus", 2), ("column-count --bogus", 2), ("place --bogus", 2),
            ("focus spiral", 1), ("workspace", 1), ("list-windows --bogus", 1),
            ("unknown-command", 1), ("config --bogus", 1),
        ]
        for (raw, expected) in cases {
            let args = raw.split(separator: " ").map(String.init).slice
            XCTAssertNotNil(parseCmdArgs(args).errorOrNil, raw)
            XCTAssertEqual(parseFailureExitCode(args), expected, raw)
        }
    }
}
