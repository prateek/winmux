import AppKit
import CoreGraphics
import XCTest
@testable import AppBundle

final class WorkspaceSidebarInlineTextTest: XCTestCase {
    func testPlainSearchKeysAndDeleteEditsRemainOwned() {
        check(126, .moveUp)
        check(125, .moveDown)
        check(36, .commit)
        check(76, .commit)
        check(53, .cancel)
        check(51, .deleteBackward)
        check(117, .deleteForward)
        check(51, .deleteToBeginningOfLine, modifiers: .command)
        check(51, .deleteWordBackward, modifiers: .option)
        check(0, .text("A"), modifiers: .shift, text: "A")
        check(45, .ignored, modifiers: .command, text: "n")
    }

    func testSystemAndAppChordsPassThroughSearch() {
        for code: UInt16 in [126, 125, 123, 124, 36, 76, 53, 51, 117, 0] {
            check(code, .ignored, modifiers: .control, text: "a")
        }
        check(126, .ignored, modifiers: .command)
        check(125, .ignored, modifiers: .option)
        check(126, .ignored, modifiers: .option)
        check(36, .ignored, modifiers: .command)
        check(51, .ignored, modifiers: [.control, .command])
        check(51, .ignored, modifiers: [.control, .option])
        check(117, .ignored, modifiers: .command)
        check(53, .ignored, modifiers: .option)
    }

    func testHoverSearchLeavesModifiedDeleteToTheFocusedApp() {
        check(51, .ignored, modifiers: .command, keepsDeleteEdits: false)
        check(51, .ignored, modifiers: .option, keepsDeleteEdits: false)
        check(51, .ignored, modifiers: [.command, .shift], keepsDeleteEdits: false)
        check(51, .deleteBackward, keepsDeleteEdits: false)
        check(51, .deleteBackward, modifiers: .shift, keepsDeleteEdits: false)
    }

    func testGlobeLettersAndFunctionKeyGlyphsAreNotSearchText() {
        check(14, .ignored, modifiers: .function, text: "e")
        check(3, .ignored, modifiers: .function, text: "f")
        check(123, .ignored, modifiers: .function, text: "\u{F702}")
        check(124, .ignored, modifiers: .function, text: "\u{F703}")
        check(122, .ignored, modifiers: .function, text: "\u{F704}")
        check(126, .moveUp, modifiers: .function, text: "\u{F700}")
        check(117, .deleteForward, modifiers: .function, text: "\u{F728}")
    }

    func testControlUpThroughCGEventEntryPoint() throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 126, keyDown: true))
        event.flags = .maskControl
        XCTAssertEqual(workspaceSidebarInlineTextKey(from: event, keepsDeleteEdits: true), .ignored)
    }

    func testControlUpThroughNSEventEntryPoint() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0,
            windowNumber: 0, context: nil, characters: "\u{F700}",
            charactersIgnoringModifiers: "\u{F700}", isARepeat: false, keyCode: 126,
        ))
        XCTAssertEqual(WorkspaceSidebarPanel.inlineTextKey(from: event, keepsDeleteEdits: true), .ignored)
    }

    func testRenameAndCommandSearchStillOrderMakeKeyAndActivate() {
        for origin: WorkspaceSidebarInlineTextEditingOrigin in [.rename, .commandSearch] {
            XCTAssertEqual(preparationRequests(origin), ["orderFront", "makeKey", "activate"])
        }
    }

    func testHoverSearchOrdersFrontWithoutKeyWindowOrActivation() {
        XCTAssertEqual(preparationRequests(.hoverSearch), ["orderFront"])
    }

    private func preparationRequests(_ origin: WorkspaceSidebarInlineTextEditingOrigin) -> [String] {
        var requests: [String] = []
        origin.preparePanel(
            orderFront: { requests.append("orderFront") },
            makeKey: { requests.append("makeKey") },
            activate: { requests.append("activate") },
        )
        return requests
    }

    private func check(
        _ code: UInt16,
        _ expected: WorkspaceSidebarInlineTextKey,
        modifiers: NSEvent.ModifierFlags = [],
        text: String? = nil,
        keepsDeleteEdits: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        XCTAssertEqual(
            workspaceSidebarInlineTextKey(keyCode: code, modifiers: modifiers, text: text, keepsDeleteEdits: keepsDeleteEdits), expected,
            "keyCode=\(code), modifiers=\(modifiers.rawValue), keepsDeleteEdits=\(keepsDeleteEdits)", file: file, line: line,
        )
    }
}
