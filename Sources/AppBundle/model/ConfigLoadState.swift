import Foundation

struct ConfigLoadState: Equatable {
    struct Loaded: Equatable {
        let file: URL
        let time: Date
        let shippedDefaults: Bool
    }
    struct Failure: Equatable {
        let diagnostic: String
        let file: URL
        let time: Date
        var applying = false
    }
    var loaded: Loaded?
    var failure: Failure?
    var defaultsFile: URL?
}
