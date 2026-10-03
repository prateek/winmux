@testable import AppBundle
import Common
import XCTest

@MainActor
final class LensConfigTest: XCTestCase {
    func testReservedNavigationKeysAreRejectedIncludingModifiers() throws {
        for key in ["esc", "tab", "up", "down", "left", "right", "cmd-tab", "shift-down"] {
            let settings = try JSONDecoder().decode(JSONValue.self, from: Data("{\"lenses\":{\"demo\":{\"keys\":{\"\(key)\":\"close\"}}}}".utf8))
            let errors = parseConfig(settings).errors
            XCTAssertTrue(errors.contains { String(describing: $0).contains("reserved") }, "\(key): \(errors)")
        }
    }

    func testSwiftLensDefaultsMatchTheContractDefaultsOfTheShippedSearchLens() throws {
        let builtIn = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))
        let parsed = parseConfig(builtIn)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        XCTAssertEqual(parsed.config.lenses["search"], LensConfig())
    }

    func testDefaultProfileResolvesAndOtherProfilesNeverApply() throws {
        let settings = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"lenses":{"demo":{"presentation":"list","keys":{"cmd-x":"close"},"when":{"default":{"enabled":false,"sort":["title"]},"travel":{"presentation":"strip"}}}}}
        """.utf8))
        let parsed = parseConfig(settings)
        XCTAssertTrue(parsed.errors.isEmpty)
        XCTAssertEqual(parsed.config.lenses["demo"]?.sort, ["title"])
        XCTAssertEqual(parsed.config.lenses["demo"]?.presentation, "list")
        XCTAssertEqual(parsed.config.lenses["demo"]?.enabled, false)
        XCTAssertEqual(parsed.config.lenses["demo"]?.keys["enter"], ["focus"])
        XCTAssertEqual(parsed.config.lenses["demo"]?.keys["cmd-x"], ["close"])
    }
}
