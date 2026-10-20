@testable import AppBundle
import Common
import XCTest

@MainActor
final class LensConfigTest: XCTestCase {
    func testRemovedLensKeysNameModeBindingsIncludingFormerReservedKeys() throws {
        for key in ["esc", "tab", "up", "down", "left", "right", "cmd-tab", "shift-down"] {
            let settings = try JSONDecoder().decode(JSONValue.self, from: Data("{\"lenses\":{\"demo\":{\"keys\":{\"\(key)\":\"close\"}}}}".utf8))
            let errors = parseConfig(settings).errors
            XCTAssertTrue(errors.contains { String(describing: $0).contains("mode bindings") }, "\(key): \(errors)")
        }
    }

    func testSwiftLensDefaultsMatchTheContractDefaultsOfTheShippedSearchLens() throws {
        let builtIn = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))
        let parsed = parseConfig(builtIn)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        XCTAssertEqual(parsed.config.lenses["search"], LensConfig())
    }

    func testFilterIntrospectionUsesOnlyTheActiveProfilePath() throws {
        let settings = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"filter":"lenses.demo.filter","when":{"default":{"filter":"lenses.demo.when.default.filter"},"travel":{"filter":"lenses.demo.when.travel.filter"}}}
        """.utf8))
        let lens = LensConfig(settings)
        XCTAssertEqual(lens.json["filter"], .string("lenses.demo.when.default.filter"))
        XCTAssertEqual(LensConfig().json["filter"], .null)
    }

    func testDefaultProfileResolvesAndOtherProfilesNeverApply() throws {
        let settings = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"lenses":{"demo":{"presentation":"list","when":{"default":{"enabled":false,"sort":["title"]},"travel":{"presentation":"strip"}}}}}
        """.utf8))
        let parsed = parseConfig(settings)
        XCTAssertTrue(parsed.errors.isEmpty)
        XCTAssertEqual(parsed.config.lenses["demo"]?.sort, ["title"])
        XCTAssertEqual(parsed.config.lenses["demo"]?.presentation, "list")
        XCTAssertEqual(parsed.config.lenses["demo"]?.enabled, false)
        XCTAssertNil(parsed.config.lenses["demo"]?.json["keys"])
    }
}

@MainActor
final class MiniaturesConfigTest: XCTestCase {
    func testProfileMergesPartialMiniatureSettingsAndIntrospectionUsesHyphens() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"presentation":"miniatures","miniatures":{"fit":"page","backdrop":{"darkness":0.8,"blur":false}},"when":{"default":{"miniatures":{"arrow-keys":"by-workspace","backdrop":{"darkness":0.4}}},"travel":{"miniatures":{"fit":"shrink"}}}}
        """.utf8))
        let settings = LensConfig(value)
        XCTAssertEqual(settings.miniatures.fit, "page")
        XCTAssertEqual(settings.miniatures.arrowKeys, "by-workspace")
        XCTAssertEqual(settings.miniatures.darkness, 0.4)
        XCTAssertFalse(settings.miniatures.blur)
        XCTAssertEqual(settings.json["miniatures"]?["current-workspace"], .string("highlight"))
        XCTAssertEqual(settings.json["miniatures"]?["arrow-keys"], .string("by-workspace"))
        XCTAssertEqual(settings.json["frozen-thumbnail"], .string("dimmed"))
        XCTAssertEqual(settings.json["accessory-window"], .string("enlarged"))
    }

    func testShippedOverviewParsesIntoResolvedMiniatureDefaults() throws {
        let builtIn = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: defaultConfigUrl))
        let parsed = parseConfig(builtIn)
        XCTAssertTrue(parsed.errors.isEmpty)
        let overview = try XCTUnwrap(parsed.config.lenses["overview"])
        XCTAssertEqual(overview.presentation, "miniatures")
        XCTAssertEqual(overview.miniatures, MiniaturesConfig())
        XCTAssertEqual(overview.popups, [:])
        XCTAssertEqual(overview.summonHints, ["label", "landing-spot"])
    }
}

@MainActor
final class TileConfigTest: XCTestCase {
    func testResolvedTileAndBadgesIntrospectionIncludingDefaultProfile() throws {
        for (presentation, tile) in [("strip", "card"), ("list", "text"), ("miniatures", "picture")] {
            let value: JSONValue = .object(["presentation": .string(presentation)])
            XCTAssertEqual(LensConfig(value).json["tile"], .string(tile))
            XCTAssertEqual(LensConfig(value).json["badges"], .bool(true))
        }
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"presentation":"strip","tile":"card","badges":true,"when":{"default":{"tile":"text","badges":false}}}
        """.utf8))
        XCTAssertEqual(LensConfig(value).tile, "text")
        XCTAssertEqual(LensConfig(value).json["tile"], .string("text"))
        XCTAssertEqual(LensConfig(value).json["badges"], .bool(false))
    }
}

@MainActor
final class LensReleaseConfigTest: XCTestCase {
    func testUnsetReleaseResolvesFromOverriddenPresentationAndAppearanceReportsAuto() {
        var settings = LensConfig()
        for presentation in ["strip", "grid", "list", "miniatures"] {
            settings.presentation = presentation
            XCTAssertNil(settings.appearance)
            XCTAssertNil(settings.json["on-release"])
            XCTAssertEqual(settings.json["appearance"], .string("auto"))
        }
    }

    func testFieldsMergeFromDefaultProfileWithoutResolvingMissingValuesEarly() throws {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"presentation":"strip","appearance":"dark","when":{"default":{"appearance":"light"},"travel":{"appearance":"auto"}}}
        """.utf8))
        var settings = LensConfig(json)
        XCTAssertEqual(settings.appearance, "light")
        settings.presentation = "grid"
        XCTAssertNil(settings.json["on-release"])
        XCTAssertEqual(settings.json["appearance"], .string("light"))
    }
}
