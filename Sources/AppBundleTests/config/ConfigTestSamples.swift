@testable import AppBundle
import Foundation
import XCTest

extension ConfigTest {
    /// Every shipped `docs/samples/*.toml` must be a valid config-version-3 config: the docs promise
    /// they are parse-checked, and a launcher/README points users straight at them.
    func testAllDocsSamplesParseCleanAtV3() throws {
        let samplesDir = projectRoot.appending(path: "docs/samples")
        let samples = try FileManager.default
            .contentsOfDirectory(at: samplesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "toml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(samples.isEmpty, "No docs/samples/*.toml files found at \(samplesDir.path)")

        for sample in samples {
            let toml = try String(contentsOf: sample, encoding: .utf8)
            let (parsed, errors) = parseConfig(toml)
            assertEquals(errors, [], additionalMsg: "Sample \(sample.lastPathComponent) should parse with zero errors")
            assertEquals(parsed.configVersion, 3, additionalMsg: "Sample \(sample.lastPathComponent) should declare config-version 3")
        }
    }
}
