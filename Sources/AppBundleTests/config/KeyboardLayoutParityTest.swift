import Foundation
import HotKey
import Common
import XCTest
@testable import AppBundle

final class KeyboardLayoutParityTest: XCTestCase {
    func testLayoutsMatchSharedFixture() throws {
        let url = projectRootUrl.appending(path: "nickel-helper/tests/fixtures/keyboard-layouts.json")
        let fixture = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        XCTAssertEqual(Set(fixture.keys), ["dvorak", "colemak"])
        for (layout, map) in [("dvorak", dvorakMap), ("colemak", colemakMap)] {
            let expected = try XCTUnwrap(fixture[layout])
            let changed = map.filter { keyNotationToKeyCode[$0.key] != $0.value }
            XCTAssertEqual(Set(changed.keys), Set(expected.keys), layout)
            for notation in expected.keys.sorted() {
                let physical = try XCTUnwrap(keyNotationToKeyCode[expected[notation]!], "Unknown physical notation in \(layout): \(expected[notation]!)")
                XCTAssertEqual(map[notation], physical, "\(layout): \(notation)")
            }
        }
    }
}
