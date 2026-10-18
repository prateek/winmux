@testable import AppBundle
import AppKit

final class TestWindow: Window, CustomStringConvertible {
    private var _rect: Rect?
    private var _isHiddenInCorner: Bool = false
    // Mutating the fake native state models a real state transition, which in production is
    // always accompanied by an AX event that invalidates the last-known-native-state cache.
    @MainActor var nativeIsMacosFullscreen: Bool = false {
        didSet { invalidateLastKnownNativeState() }
    }
    @MainActor var nativeIsMacosMinimized: Bool = false {
        didSet { invalidateLastKnownNativeState() }
    }

    @MainActor
    private init(_ id: UInt32, _ parent: NonLeafTreeNodeObject, _ adaptiveWeight: CGFloat, _ rect: Rect?, app: TestApp) {
        _rect = rect
        super.init(id: id, app, lastFloatingSize: nil, parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
        recordAuthoritativeActualRect(rect)
    }

    @discardableResult
    @MainActor
    static func new(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil, app: TestApp = .shared) -> TestWindow {
        let wi = TestWindow(id, parent, adaptiveWeight, rect, app: app)
        // A test's window stands for one WinMux already manages, not one it has just found.
        wi.wasSeenUnminimized = true
        app._windows.append(wi)
        return wi
    }

    nonisolated var description: String { "TestWindow(\(windowId))" }

    @MainActor
    override func nativeFocus() {
        let app = self.app as! TestApp
        appForTests = app
        app.focusedWindow = self
    }

    @MainActor var closeResult: WindowCloseResult = .closed
    /// Runs after a close that succeeded, as an app closing a companion window along with this one.
    @MainActor var onClose: (@MainActor () -> Void)?
    @MainActor private(set) var closeAttempts = 0
    @MainActor var closeRequestStays = false
    @MainActor var closeRequestHasSheet = false
    @MainActor var beforeCloseRequest: (@MainActor () async -> Void)?

    @MainActor
    override func requestClose(timeout: TimeInterval, tabStripSession: RunSessionGuard? = nil) async -> WindowCloseConfirmation {
        await windowCloseSession(tabStripSession) { self.closeAttempts += 1 }
        await beforeCloseRequest?()
        guard closeResult == .closed else { return .refused }
        if closeRequestHasSheet { return .sheetSeen }
        guard !closeRequestStays else { return .timedOut }
        await windowCloseSession(tabStripSession) {
            self.unbindAndFocusAfterClosure()
            self.onClose?()
        }
        return .gone
    }

    @MainActor
    override func closeAxWindow() async -> WindowCloseResult {
        closeAttempts += 1
        guard closeResult == .closed else { return closeResult }
        unbindFromParent()
        onClose?()
        return .closed
    }

    override var title: String {
        get async { // redundant async. todo create bug report to Swift
            description
        }
    }

    @MainActor var testNativeWindowType: AxUiElementWindowType?
    @MainActor override var nativeWindowType: AxUiElementWindowType { get async { testNativeWindowType ?? (parent === macosPopupWindowsContainer ? .popup : .window) } }
    @MainActor override func setNativeFullscreen(_ value: Bool) { nativeIsMacosFullscreen = value }

    @MainActor var testCgWindowLevel = 0
    @MainActor override var cgWindowLevel: Int { testCgWindowLevel }

    @MainActor var beforeAxRecord: (() async -> Void)?
    @MainActor var testAxRecordAttributes: WindowAxRecordAttributes? = nil
    @MainActor var testAxRecordError: (any Error)? = nil
    @MainActor var testAxElementIsGone = false
    @MainActor override func readAxRecordAttributes(buttons: Bool) async throws -> WindowAxRecordAttributes? {
        await beforeAxRecord?()
        if let testAxRecordError { throw testAxRecordError }
        if testAxElementIsGone { return nil }
        var attributes = testAxRecordAttributes ?? WindowAxRecordAttributes(title: description, subrole: "", hasCloseButton: false, document: "")
        if !buttons { attributes.buttons = nil }
        return attributes
    }

    @MainActor var testAxRectError: (any Error)?
    @MainActor var beforeAxRect: (() async -> Void)?
    @MainActor var testAxRectUnavailable = false

    @MainActor override func getAxRect() async throws -> Rect? { // todo change to not Optional
        await beforeAxRect?()
        if let testAxRectError { throw testAxRectError }
        if testAxRectUnavailable { return nil }
        recordAuthoritativeActualRect(_rect)
        return _rect
    }

    @MainActor override func getAxSize() async throws -> CGSize? { _rect?.size }

    @MainActor private(set) var nativeStateFetchCount = 0

    @MainActor override var isMacosFullscreen: Bool {
        get async throws {
            nativeStateFetchCount += 1
            return nativeIsMacosFullscreen
        }
    }

    @MainActor override var isMacosMinimized: Bool {
        get async throws {
            nativeStateFetchCount += 1
            return nativeIsMacosMinimized
        }
    }

    var testSavedProportionalPosition: CGPoint?
    override var savedProportionalPosition: CGPoint? { testSavedProportionalPosition }
    override var isHiddenInCorner: Bool { testSavedProportionalPosition != nil || _isHiddenInCorner }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        let currentRect = _rect ?? Rect(topLeftX: topLeft?.x ?? 0, topLeftY: topLeft?.y ?? 0, width: size?.width ?? 0, height: size?.height ?? 0)
        _rect = Rect(
            topLeftX: topLeft?.x ?? currentRect.topLeftX,
            topLeftY: topLeft?.y ?? currentRect.topLeftY,
            width: size?.width ?? currentRect.width,
            height: size?.height ?? currentRect.height,
        )
        let windowId = self.windowId
        let rect = _rect
        Task { @MainActor in
            Window.get(byId: windowId)?.recordAuthoritativeActualRect(rect)
        }
        _isHiddenInCorner = false
    }
}
