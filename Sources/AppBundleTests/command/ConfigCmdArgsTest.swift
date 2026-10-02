@testable import AppBundle
import Common
import XCTest

final class ConfigCmdArgsTest: XCTestCase {
    private func mode(_ args: [String]) -> ConfigCmdArgs.Mode? {
        (parseCmdArgs((["config"] + args).slice).cmdOrNil as? ConfigCmdArgs)?.mode
    }

    private func error(_ args: [String]) -> String? {
        parseCmdArgs((["config"] + args).slice).errorOrNil
    }

    func testHelperActions() {
        guard case .status = mode(["status"]) else { return XCTFail("status") }
        guard case .check(file: nil) = mode(["check"]) else { return XCTFail("check") }
        guard case .check(file: "a.ncl") = mode(["check", "a.ncl"]) else { return XCTFail("check <file>") }
        guard case .convert(file: nil) = mode(["convert"]) else { return XCTFail("convert") }
        guard case .convert(file: "a.toml") = mode(["convert", "a.toml"]) else { return XCTFail("convert <file>") }
        guard case .schema(json: false) = mode(["schema"]) else { return XCTFail("schema") }
        guard case .schema(json: true) = mode(["schema", "--json"]) else { return XCTFail("schema --json") }
    }

    func testExistingFlagsStillParse() {
        guard case .configPath = mode(["--config-path"]) else { return XCTFail("--config-path") }
        guard case .getKey(key: "mode") = mode(["--get", "mode"]) else { return XCTFail("--get") }
    }

    func testBadUsage() {
        assertEquals(error([]), "Specify one of: status, check, convert, schema, --get, --major-keys, --all-keys, --config-path")
        assertEquals(error(["status", "a.ncl"]), "Only check and convert take a file")
        assertEquals(error(["schema", "a.ncl"]), "Only check and convert take a file")
        assertEquals(error(["status", "--json"]), "--json flag requires --get flag or schema")
        assertEquals(error(["check", "a.ncl", "b.ncl"]), "ERROR: Unknown argument 'b.ncl'")
        XCTAssertNotNil(error(["status", "--all-keys"]))
        XCTAssertNotNil(error(["frobnicate"]))
    }
}
