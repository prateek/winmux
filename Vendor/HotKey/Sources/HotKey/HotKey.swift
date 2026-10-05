#if !targetEnvironment(macCatalyst) && canImport(AppKit) && canImport(Carbon)
import AppKit
import Carbon

public final class HotKey {

	// MARK: - Types

	public typealias Handler = () -> Void

	// MARK: - Properties

	let identifier = UUID()

	public internal(set) var registrationError: OSStatus = noErr
	public let keyCombo: KeyCombo
	public var keyDownHandler: Handler?
    public var keyDownWithTimeHandler: ((Double) -> Void)?
	public var keyUpHandler: Handler?
    public var isPaused = false {
        didSet {
            if isPaused {
                HotKeysController.unregister(self)
            } else {
                HotKeysController.register(self)
            }
        }
    }

	// MARK: - Initializers

	public init(keyCombo: KeyCombo, keyDownHandler: Handler? = nil, keyUpHandler: Handler? = nil) {
		self.keyCombo = keyCombo
		self.keyDownHandler = keyDownHandler
		self.keyUpHandler = keyUpHandler

		HotKeysController.register(self)
	}

	public convenience init(carbonKeyCode: UInt32, carbonModifiers: UInt32, keyDownHandler: Handler? = nil, keyUpHandler: Handler? = nil) {
		let keyCombo = KeyCombo(carbonKeyCode: carbonKeyCode, carbonModifiers: carbonModifiers)
		self.init(keyCombo: keyCombo, keyDownHandler: keyDownHandler, keyUpHandler: keyUpHandler)
	}

	public convenience init(key: Key, modifiers: NSEvent.ModifierFlags, keyDownHandler: Handler? = nil, keyUpHandler: Handler? = nil, keyDownWithTimeHandler: ((Double) -> Void)? = nil) {
		let keyCombo = KeyCombo(key: key, modifiers: modifiers)
		self.init(keyCombo: keyCombo, keyDownHandler: keyDownHandler, keyUpHandler: keyUpHandler)
        self.keyDownWithTimeHandler = keyDownWithTimeHandler
	}

	deinit {
		HotKeysController.unregister(self)
	}
}
#endif
