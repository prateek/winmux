import Foundation

struct ConfigLoadState: Equatable {
    struct Loaded: Equatable {
        let file: URL
        let time: Date
        let shippedDefaults: Bool
        /// False when applying these values threw part way: they are running, but not all of them.
        var finished = true
    }
    struct Failure: Equatable {
        let diagnostic: String
        let time: Date
        /// Whether this failure was in applying a loaded config, rather than in loading one.
        var applying = false
    }
    var loaded: Loaded?
    var failure: Failure?
}
