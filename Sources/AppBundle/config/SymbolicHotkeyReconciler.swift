import Foundation

struct SymbolicHotkeyChord: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt64
}
struct SymbolicHotkey: Equatable {
    var keyCode: UInt16
    var modifiers: UInt64
    var enabled: Bool
    var chord: SymbolicHotkeyChord { SymbolicHotkeyChord(keyCode: keyCode, modifiers: modifiers) }
}
protocol SymbolicHotkeyTable {
    func read(_ id: Int) -> SymbolicHotkey?
    func setEnabled(_ id: Int, _ enabled: Bool) -> Bool
}
protocol SymbolicHotkeyMarkerStore {
    func load() -> [Int: SymbolicHotkeyChord]
    func save(_ value: [Int: SymbolicHotkeyChord])
}
enum SymbolicHotkeyRepair { case launch, wake, unlock }

// Restoration also runs synchronously from the exception and exit hooks.
final class SymbolicHotkeyReconciler: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let table: any SymbolicHotkeyTable
    private let marker: any SymbolicHotkeyMarkerStore
    private var errors: [String] = []
    private var candidates: [Int: SymbolicHotkeyChord]?
    var failures: [String] { lock.withLock { errors } }
    var markerIds: [Int] { lock.withLock { marker.load().keys.sorted() } }
    var heldIds: [Int] { lock.withLock { marker.load().filter { table.read($0.key)?.enabled == false && table.read($0.key)?.chord == $0.value }.keys.sorted() } }

    init(table: any SymbolicHotkeyTable, marker: any SymbolicHotkeyMarkerStore) {
        self.table = table; self.marker = marker
    }

    func reconcile(_ listening: Set<SymbolicHotkeyChord>) {
        lock.withLock {
            errors = []
            reconcileLocked(Self.takeoverChords(listening))
        }
    }

    private func reconcileLocked(_ wanted: Set<SymbolicHotkeyChord>) {
        var owned = marker.load()
        guard !wanted.isEmpty || !owned.isEmpty else { return }
        var changed: Set<Int> = []
        for (id, chord) in owned {
            guard let live = table.read(id), live.chord == chord else {
                owned[id] = nil
                candidates?[id] = nil
                changed.insert(id)
                continue
            }
            if live.enabled { owned[id] = nil }
            else if !wanted.contains(chord), set(id, enabled: true) { owned[id] = nil }
        }
        saveIfChanged(owned)
        guard !wanted.isEmpty else { return }
        if candidates == nil {
            candidates = [:]
            for id in 0...symbolicHotkeyTableLimit {
                if let live = table.read(id), Self.takeoverChords([live.chord]).contains(live.chord) {
                    candidates?[id] = live.chord
                }
            }
        }
        for (id, chord) in candidates ?? [:] where owned[id] == nil && !changed.contains(id) && wanted.contains(chord) {
            guard let live = table.read(id), live.chord == chord, live.enabled else { continue }
            owned[id] = live.chord
            saveIfChanged(owned)
            if !set(id, enabled: false), table.read(id)?.enabled == true {
                owned[id] = nil
                saveIfChanged(owned)
            }
        }
    }

    func restore() {
        lock.withLock {
            errors = []
            restoreLocked()
        }
    }

    private func restoreLocked() {
        var owned = marker.load()
        for (id, chord) in owned {
            guard let live = table.read(id), live.chord == chord, !live.enabled else { owned[id] = nil; continue }
            if set(id, enabled: true) { owned[id] = nil }
        }
        saveIfChanged(owned)
    }

    func repair(_ reason: SymbolicHotkeyRepair, wanted: Set<SymbolicHotkeyChord>) {
        lock.withLock {
            errors = []
            restoreLocked()
            candidates = nil
            reconcileLocked(Self.takeoverChords(wanted))
        }
    }

    private func saveIfChanged(_ owned: [Int: SymbolicHotkeyChord]) {
        if owned != marker.load() { marker.save(owned) }
    }

    private func set(_ id: Int, enabled: Bool) -> Bool {
        let accepted = table.setEnabled(id, enabled)
        let verified = table.read(id)?.enabled == enabled
        if !accepted || !verified { errors.append("id \(id): could not \(enabled ? "restore" : "disable")") }
        return accepted && verified
    }

    static func takeoverChords(_ listening: Set<SymbolicHotkeyChord>) -> Set<SymbolicHotkeyChord> {
        let command: UInt64 = 0x100000, shift: UInt64 = 0x20000
        let tab = listening.filter { $0.keyCode == 48 && ($0.modifiers == command || $0.modifiers == command | shift) }
        return Set(tab.flatMap { [SymbolicHotkeyChord(keyCode: $0.keyCode, modifiers: command), SymbolicHotkeyChord(keyCode: $0.keyCode, modifiers: command | shift)] })
    }
}

let symbolicHotkeyTableLimit = 1024

final class DefaultsSymbolicHotkeyMarker: SymbolicHotkeyMarkerStore {
    static let key = "WinMux.symbolicHotkeyMarker.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> [Int: SymbolicHotkeyChord] {
        guard let data = defaults.data(forKey: Self.key) else { return [:] }
        return (try? JSONDecoder().decode([Int: SymbolicHotkeyChord].self, from: data)) ?? [:]
    }
    func save(_ value: [Int: SymbolicHotkeyChord]) {
        if value.isEmpty { defaults.removeObject(forKey: Self.key) }
        else { defaults.set(try? JSONEncoder().encode(value), forKey: Self.key) }
        defaults.synchronize()
    }
}
