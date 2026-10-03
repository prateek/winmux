import Foundation

func accessoryApp(infoDictionary: [String: Any]?) -> Bool {
    switch infoDictionary?["LSUIElement"] {
        case let value as NSNumber: value.boolValue
        case let value as String: (value as NSString).boolValue
        default: false
    }
}
