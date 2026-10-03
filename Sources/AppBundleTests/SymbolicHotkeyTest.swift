@testable import AppBundle
import XCTest
import Common

private final class FakeSymbolicTable: SymbolicHotkeyTable {
    var entries: [Int: SymbolicHotkey] = [
        1: SymbolicHotkey(keyCode: 48, modifiers: 0x100000, enabled: true),
        2: SymbolicHotkey(keyCode: 48, modifiers: 0x120000, enabled: true),
        27: SymbolicHotkey(keyCode: 50, modifiers: 0x100000, enabled: true),
        220: SymbolicHotkey(keyCode: 50, modifiers: 0x120000, enabled: true),
    ]
    var beforeDisable: ((Int) -> Void)?
    var fail = false
    func read(_ id: Int) -> SymbolicHotkey? { entries[id] }
    func setEnabled(_ id: Int, _ enabled: Bool) -> Bool {
        if !enabled { beforeDisable?(id) }
        guard !fail else { return false }
        entries[id]?.enabled = enabled
        return true
    }
}
private final class MemorySymbolicMarker: SymbolicHotkeyMarkerStore {
    var entries: [Int: SymbolicHotkeyChord] = [:]
    func load() -> [Int: SymbolicHotkeyChord] { entries }
    func save(_ value: [Int: SymbolicHotkeyChord]) { entries = value }
}
final class SymbolicHotkeyTest: XCTestCase {
    private let tab = SymbolicHotkeyChord(keyCode: 48, modifiers: 0x100000)
    func testWriteAheadOnlyEnabledCandidatesAndBacktickStaysOn() {
        let table = FakeSymbolicTable(), marker = MemorySymbolicMarker()
        table.entries[2]?.enabled = false
        table.beforeDisable = { id in XCTAssertNotNil(marker.entries[id]) }
        let reconciler = SymbolicHotkeyReconciler(table: table, marker: marker)
        reconciler.reconcile([tab, SymbolicHotkeyChord(keyCode: 50, modifiers: 0x100000)])
        XCTAssertEqual(Set(marker.entries.keys), [1])
        XCTAssertEqual(table.read(1)?.enabled, false)
        XCTAssertEqual(table.read(27)?.enabled, true)
        XCTAssertEqual(table.read(220)?.enabled, true)
        reconciler.reconcile([])
        XCTAssertTrue(marker.entries.isEmpty)
        XCTAssertEqual(table.read(1)?.enabled, true)
        XCTAssertEqual(table.read(2)?.enabled, false)
    }
    func testShiftPartnerAndOnlyMarkerIdsAreRestored() {
        let table = FakeSymbolicTable(), marker = MemorySymbolicMarker()
        let reconciler = SymbolicHotkeyReconciler(table: table, marker: marker)
        reconciler.reconcile([tab])
        XCTAssertEqual(Set(marker.entries.keys), [1, 2])
        table.entries[27]?.enabled = false
        reconciler.restore()
        XCTAssertEqual(table.read(1)?.enabled, true)
        XCTAssertEqual(table.read(2)?.enabled, true)
        XCTAssertEqual(table.read(27)?.enabled, false)
    }
    func testUserChangedIdIsLeftAloneAndDropped() {
        let table = FakeSymbolicTable(), marker = MemorySymbolicMarker()
        let reconciler = SymbolicHotkeyReconciler(table: table, marker: marker)
        reconciler.reconcile([tab])
        table.entries[1]?.keyCode = 40
        table.entries[2]?.enabled = true
        reconciler.reconcile([])
        XCTAssertEqual(table.read(1)?.enabled, false)
        XCTAssertEqual(table.read(2)?.enabled, true)
        XCTAssertTrue(marker.entries.isEmpty)
    }
    func testFailedDisableAndRestoreKeepRecoveryEvidence() {
        let table = FakeSymbolicTable(), marker = MemorySymbolicMarker()
        let reconciler = SymbolicHotkeyReconciler(table: table, marker: marker)
        table.fail = true
        reconciler.reconcile([tab])
        XCTAssertTrue(marker.entries.isEmpty)
        XCTAssertFalse(reconciler.failures.isEmpty)
        table.fail = false
        reconciler.reconcile([tab]); table.fail = true
        reconciler.restore()
        XCTAssertEqual(Set(marker.entries.keys), [1, 2])
    }
    func testRepairOnLaunchWakeAndUnlockRestoresThenRetakesLiveTable() {
        for reason in [SymbolicHotkeyRepair.launch, .wake, .unlock] {
            let table = FakeSymbolicTable(), marker = MemorySymbolicMarker()
            marker.entries[1] = tab; table.entries[1]?.enabled = false
            let reconciler = SymbolicHotkeyReconciler(table: table, marker: marker)
            reconciler.repair(reason, wanted: [tab])
            XCTAssertEqual(table.read(1)?.enabled, false)
            XCTAssertEqual(Set(marker.entries.keys), [1, 2])
            table.entries[1]?.enabled = true
            reconciler.repair(reason, wanted: [tab])
            XCTAssertEqual(table.read(1)?.enabled, false)
            reconciler.restore(); XCTAssertTrue(marker.entries.isEmpty)
        }
    }
}

@MainActor
final class SymbolicHotkeyBindingStateTest: XCTestCase {
    func testActiveModeSuspensionAndDisableDetermineListeningChords() async throws {
        setUpWorkspacesForTests()
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("{\"mode\":{\"main\":{\"binding\":{\"cmd-tab\":\"lens recent\"}},\"plain\":{\"binding\":{}}}}".utf8))
        let parsed = parseConfig(value)
        XCTAssertTrue(parsed.errors.isEmpty, "\(parsed.errors)")
        config = parsed.config
        resetHotKeys()
        defer { resetHotKeys() }
        try await activateMode("main")
        XCTAssertEqual(listeningHotkeyChords(), [SymbolicHotkeyChord(keyCode: 48, modifiers: 0x100000)])
        setHotkeysSuspended(true); XCTAssertTrue(listeningHotkeyChords().isEmpty)
        setHotkeysSuspended(false); XCTAssertEqual(listeningHotkeyChords().count, 1)
        try await activateMode("plain"); XCTAssertTrue(listeningHotkeyChords().isEmpty)
        try await activateMode(nil); XCTAssertTrue(listeningHotkeyChords().isEmpty)
    }
}
