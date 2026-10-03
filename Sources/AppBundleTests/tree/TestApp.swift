@testable import AppBundle
import Common
import AppKit

final class TestApp: AbstractApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    @MainActor
    static let shared = TestApp()

    var accessory: Bool
    var activationPolicy: NSApplication.ActivationPolicy

    init(pid: Int32 = 0, accessory: Bool = false, activationPolicy: NSApplication.ActivationPolicy = .regular) {
        self.accessory = accessory
        self.activationPolicy = activationPolicy
        self.pid = pid
        self.rawAppBundleId = "bobko.WinMux.test-app"
        self.name = rawAppBundleId
    }

    var _windows: [Window] = []
    var windows: [Window] {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                check(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
    @MainActor func getFocusedWindow() -> Window? { _focusedWindow }
}
