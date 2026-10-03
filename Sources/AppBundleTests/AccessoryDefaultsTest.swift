@testable import AppBundle
import AppKit
import Common
import XCTest

private final class AccessoryAxElement: AxUiElementMock {
    var values: [String: Any] = [:]
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? { values[attr.key] as? Attr.T }
    func containingWindowId() -> CGWindowID? { 1 }

    static func standard(close: Bool = true) -> AccessoryAxElement {
        let window = AccessoryAxElement()
        let button = AccessoryAxElement()
        button.values[Ax.enabledAttr.key] = true
        window.values[Ax.subroleAttr.key] = kAXStandardWindowSubrole
        window.values[Ax.fullscreenButtonAttr.key] = button
        if close { window.values[Ax.closeButtonAttr.key] = button }
        return window
    }
}

@MainActor
final class AccessoryDefaultsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBundleDeclarationAcceptsPlistRepresentationsAndMissingBundles() throws {
        for value: Any in [true, NSNumber(value: 1), "1"] {
            XCTAssertTrue(accessoryApp(infoDictionary: ["LSUIElement": value]), "\(value)")
        }
        for value: Any in [false, NSNumber(value: 0), "0"] {
            XCTAssertFalse(accessoryApp(infoDictionary: ["LSUIElement": value]), "\(value)")
        }
        XCTAssertFalse(accessoryApp(infoDictionary: [:]))
        XCTAssertFalse(accessoryApp(infoDictionary: nil))
    }

    func testStandardFullscreenCapableAccessoryWindowFloatsUnderEitherPolicy() {
        let window = AccessoryAxElement.standard()
        let app = AccessoryAxElement()
        for policy: NSApplication.ActivationPolicy in [.regular, .accessory] {
            XCTAssertEqual(window.getWindowType(axApp: app, nil, policy, .normalWindow, accessory: true), .dialog)
            XCTAssertEqual(window.getWindowType(axApp: app, nil, policy, .normalWindow, accessory: false), .window)
        }
    }

    func testCloseButtonlessWindowUsesLivePolicyBeforeFloatingDefault() {
        let window = AccessoryAxElement.standard(close: false)
        let app = AccessoryAxElement()
        XCTAssertEqual(window.getWindowType(axApp: app, nil, .accessory, .normalWindow, accessory: true), .popup)
        XCTAssertEqual(window.getWindowType(axApp: app, nil, .regular, .normalWindow, accessory: true), .dialog)
    }

    func testDockAppHeuristicsKeepTheirExceptions() {
        let app = AccessoryAxElement()
        let standard = AccessoryAxElement.standard()
        XCTAssertEqual(standard.getWindowType(axApp: app, nil, .regular, .normalWindow, accessory: false), .window)
        standard.values[Ax.fullscreenButtonAttr.key] = nil
        XCTAssertEqual(standard.getWindowType(axApp: app, nil, .regular, .normalWindow, accessory: false), .dialog)
        XCTAssertEqual(standard.getWindowType(axApp: app, .chrome, .regular, .normalWindow, accessory: false), .window)
        let popup = AccessoryAxElement()
        popup.values[Ax.subroleAttr.key] = "AXUnknown"
        XCTAssertEqual(popup.getWindowType(axApp: app, nil, .regular, .normalWindow, accessory: false), .popup)
        let withClose = AccessoryAxElement.standard()
        withClose.values[Ax.subroleAttr.key] = "AXUnknown"
        XCTAssertEqual(withClose.getWindowType(axApp: app, nil, .accessory, .normalWindow, accessory: true), .popup)
    }

    func testRecordsKeepBundleIdentityWhilePolicyAndPopupClassChange() async throws {
        let app = TestApp(pid: 10, accessory: true)
        let popup = TestWindow.new(id: 1, parent: macosPopupWindowsContainer, app: app)
        for (policy, expectedPolicy, expectedClass): (NSApplication.ActivationPolicy, AppActivationPolicy, WindowClass) in [
            (.regular, .regular, .appPopup), (.accessory, .accessory, .accessoryPopup), (.prohibited, .prohibited, .appPopup),
        ] {
            app.activationPolicy = policy
            let read = try await popup.windowRecord()
            let record = try XCTUnwrap(read)
            XCTAssertTrue(record.app.accessory)
            XCTAssertEqual(record.app.activationPolicy, expectedPolicy)
            XCTAssertEqual(record.windowClass, expectedClass)
            XCTAssertEqual(record.workspace, "")
        }
    }

    func testRecordSnapshotsPolicyAndPopupClassBeforeTheAxRoundTrip() async throws {
        let app = TestApp(pid: 10, accessory: true, activationPolicy: .accessory)
        let popup = TestWindow.new(id: 1, parent: macosPopupWindowsContainer, app: app)
        popup.beforeAxRecord = { app.activationPolicy = .regular }
        let first = try await popup.windowRecord()
        let next = try await popup.windowRecord()
        XCTAssertEqual(first?.windowClass, .accessoryPopup)
        XCTAssertEqual(first?.app.activationPolicy, .accessory)
        XCTAssertEqual(next?.windowClass, .appPopup)
        XCTAssertEqual(next?.app.activationPolicy, .regular)
    }

    func testPopupGatesSeparateLiveClassesRegardlessOfCloseButton() async throws {
        let accessory = TestApp(pid: 10, accessory: true, activationPolicy: .accessory)
        let regular = TestApp(pid: 11)
        let popup = TestWindow.new(id: 1, parent: macosPopupWindowsContainer, app: accessory)
        popup.testAxRecordAttributes = WindowAxRecordAttributes(title: "Popup", subrole: "AXUnknown", hasCloseButton: true, document: "")
        _ = TestWindow.new(id: 2, parent: macosPopupWindowsContainer, app: regular)
        let accessoryOnly = try await lensWindows(popups: ["accessory-popup"])
        let regularOnly = try await lensWindows(popups: ["app-popup"])
        let neither = try await lensWindows(popups: [])
        XCTAssertEqual(accessoryOnly.map { $0.record.id }, [1])
        XCTAssertEqual(regularOnly.map { $0.record.id }, [2])
        XCTAssertTrue(neither.isEmpty)
    }

    func testPopupRowEnterRaisesAndShiftEnterRefusesForBothLiveClasses() async throws {
        for policy: NSApplication.ActivationPolicy in [.regular, .accessory] {
            let app = TestApp(pid: 10, activationPolicy: policy)
            let popup = TestWindow.new(id: 1, parent: macosPopupWindowsContainer, app: app)
            let session = LensSession(name: "popup", settings: LensConfig(), items: [
                SwitcherPaletteItem(id: 1, title: "Popup", appName: "Demo", icon: nil, workspaceName: "", isFocused: false),
            ], search: "")
            let enter = try await runLensAction(session.commands(for: "enter"), session: session, io: CmdIo(stdin: .emptyStdin))
            XCTAssertTrue(enter)
            XCTAssertTrue(app.focusedWindow === popup)
            let io = CmdIo(stdin: .emptyStdin)
            let summon = try await runLensAction(session.commands(for: "shift-enter"), session: session, io: io)
            XCTAssertFalse(summon)
            XCTAssertEqual(io.stderr, ["Cannot Summon a popup window"])
            XCTAssertTrue(popup.parent === macosPopupWindowsContainer)
            popup.unbindFromParent()
        }
    }

    func testDefaultFloatingLensAndFiltersThroughCLI() async throws {
        guard nickelHelperUrl() != nil else { throw XCTSkip("make helper first") }
        NickelSupervisor.shared.adopt(try await NickelSupervisor.shared.load(nil).get())
        let app = TestApp(pid: 10, accessory: true)
        let first = TestWindow.new(id: 1, parent: Workspace.get(byName: "one"), app: app)
        let second = TestWindow.new(id: 2, parent: Workspace.get(byName: "two"), app: app)
        _ = TestWindow.new(id: 3, parent: Workspace.get(byName: "one").rootTilingContainer)
        _ = TestWindow.new(id: 4, parent: macosPopupWindowsContainer, app: app)
        first.testAxRecordAttributes = WindowAxRecordAttributes(title: "Dialog", subrole: "AXStandardWindow", hasCloseButton: false, document: "")
        first.recordConfirmedFocus()
        second.recordConfirmedFocus()
        func ids(_ args: [String]) async throws -> [Int] {
            let result = try await XCTUnwrap(parseCommand(args).cmdOrNil).run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 0, result.stderr.joined())
            let json = try JSONDecoder().decode(JSONValue.self, from: Data(result.stdout.joined().utf8))
            return (json.arrayOrNil ?? []).compactMap { row in
                if case .int(let id) = row["window-id"] { return id }
                return nil
            }
        }
        let floating = try await ids(["list-windows", "--lens", "floating", "--json"])
        XCTAssertEqual(floating, [2, 1])
        let identity = try await ids(["list-windows", "--filter", "w.app.accessory", "--json"])
        XCTAssertEqual(identity, [2, 1])
        let before = try await ids(["list-windows", "--filter", "w.app.activationPolicy == 'accessory", "--json"])
        XCTAssertEqual(before, [])
        app.activationPolicy = .accessory
        let after = try await ids(["list-windows", "--filter", "w.app.activationPolicy == 'accessory", "--json"])
        XCTAssertEqual(after, [2, 1])
        let result = try await XCTUnwrap(parseCommand("list-lenses --json").cmdOrNil).run(.defaultEnv, .emptyStdin)
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(result.stdout.joined().utf8))
        XCTAssertEqual(json["floating"]?["filter"], .string("lenses.floating.filter"))
        XCTAssertEqual(json["floating"]?["presentation"], .string("list"))
        XCTAssertEqual(json["floating"]?["popups"], .array([]))
        XCTAssertEqual(config.lenses["floating"]?.keys["enter"], ["focus"])
        XCTAssertEqual(config.lenses["floating"]?.keys["shift-enter"], ["summon"])
    }
}
