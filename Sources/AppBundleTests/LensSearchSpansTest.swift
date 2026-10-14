@testable import AppBundle
import XCTest
import SwiftUI

final class LensSearchSpansTest: XCTestCase {
    func testSpansComeFromTheScoringTierAndChosenFieldOnOriginalText() throws {
        let cases: [(String, String, String, [String], [String])] = [
            ("saf", "", "Safari", [], ["Saf"]),
            ("port", "Quarterly report", "", ["port"], []),
            ("rep saf", "Quarterly report", "Safari", ["rep"], ["Saf"]),
            ("arter", "Quarterly report", "", ["arter"], []),
            ("qr", "Quarterly report", "", ["Q", "r"], []),
            ("qrl", "Quarterly report", "", ["Q", "r", "l"], []),
            ("i̇st", "İstanbul Report", "", ["İst"], []),
            ("rep", "İstanbul Report", "", ["Rep"], []),
            ("report rep", "Report", "", ["Report"], []),
        ]
        for (query, title, app, titleSpans, appSpans) in cases {
            let match = try XCTUnwrap(LensSearchFields(title: title, app: app, workspace: "", project: "").match(query))
            XCTAssertEqual(substrings(title, match.titleRanges), titleSpans, query)
            XCTAssertEqual(substrings(app, match.appRanges), appSpans, query)
        }
        let workspace = try XCTUnwrap(LensSearchFields(title: "Other", app: "Demo", workspace: "Work", project: "").match("work"))
        XCTAssertEqual(workspace.titleRanges, [])
        XCTAssertEqual(workspace.appRanges, [])
    }

    private func substrings(_ text: String, _ ranges: [Range<Int>]) -> [String] {
        let characters = Array(text)
        return ranges.map { String(characters[$0]) }
    }
}
