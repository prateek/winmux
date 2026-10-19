import CoreGraphics
import Foundation

let state: [String: Bool] = ["leftDown": CGEventSource.buttonState(.combinedSessionState, button: .left)]
let data = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
