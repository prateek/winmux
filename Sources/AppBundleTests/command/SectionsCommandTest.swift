@testable import AppBundle
import Common
import XCTest

@MainActor
final class SectionsCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    func testParserValuesAndInvocationScope() {
        for value in ["none", "workspace", "project", "monitor", "app"] {
            XCTAssertNil(parseCommand("sections \(value)").errorOrNil)
            XCTAssertNil(parseCommand("lens search --sections \(value)").errorOrNil)
            XCTAssertNil(parseCommand("lens --filter true --sections \(value)").errorOrNil)
        }
        XCTAssertNil(parseCommand("sections next").errorOrNil)
        for raw in ["sections", "sections shape", "sections app extra", "lens search --sections shape", "lens --presentation list --sections app", "lens search --presentation miniatures --sections app"] {
            XCTAssertNotNil(parseCommand(raw).errorOrNil, raw)
        }
    }
    func testClosedLensAndResolvedMiniaturesRefuseWithoutOpening() async throws {
        SwitcherPalettePanel.shared.dismiss()
        var settings = LensConfig(); settings.presentation = "miniatures"
        config.lenses = ["overview": settings]
        for (raw, message) in [("sections next", "No Lens is open"), ("lens overview --sections app", "--sections is not allowed with miniatures")] {
            let command = try XCTUnwrap(parseCommand(raw).cmdOrNil)
            let result = try await command.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 2)
            XCTAssertEqual(result.stderr, [message])
            XCTAssertNil(SwitcherPalettePanel.shared.session)
        }
    }
    func testConfigResolvesArrangementAndDefaultBinding() {
        let settings = LensConfig(.object(["grid": .object(["sections-arrangement": .string("rows")]), "when": .object(["default": .object(["grid": .object(["sections-arrangement": .string("columns")])])])]))
        XCTAssertEqual(settings.json["grid"]?["sections-arrangement"], .string("columns"))
        XCTAssertEqual(settings.keys["cmd-g"], ["sections next"])
        XCTAssertTrue(parseConfig(.object(["lenses": .object(["demo": settings.json])])).errors.isEmpty)
    }
}
