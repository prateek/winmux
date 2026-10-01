import Common
import Foundation

let nickelHelperEnvVariable = "WINMUX_NICKEL_HELPER"
private let nickelHelperName = "winmux-nickel"

/// Where `winmux-nickel` is: `WINMUX_NICKEL_HELPER`, then `Contents/Helpers` of the app bundle,
/// then next to the running executable.
func nickelHelperUrl() -> URL? {
    if let path = ProcessInfo.processInfo.environment[nickelHelperEnvVariable] {
        return URL(filePath: path)
    }
    var candidates = [Bundle.main.bundleURL.appending(path: "Contents/Helpers").appending(path: nickelHelperName)]
    if let executable = Bundle.main.executableURL {
        candidates.append(executable.deletingLastPathComponent().appending(path: nickelHelperName))
    }
    if isDebug || isUnitTest {
        // A build that is not an app bundle uses the helper built in the source tree.
        let crate = projectRootUrl.appending(path: "nickel-helper/target")
        candidates += [crate.appending(path: "release").appending(path: nickelHelperName), crate.appending(path: "debug").appending(path: nickelHelperName)]
    }
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
}
