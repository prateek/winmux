import AppKit
import Common
import Darwin
import os

final class CGSSymbolicHotkeyTable: SymbolicHotkeyTable {
    private typealias Get = @convention(c) (Int32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt32>) -> Int32
    private typealias IsEnabled = @convention(c) (Int32) -> Bool
    private typealias SetEnabled = @convention(c) (Int32, Bool) -> Int32
    private let get: Get?
    private let isEnabled: IsEnabled?
    private let set: SetEnabled?
    init() {
        let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        get = handle.flatMap { dlsym($0, "CGSGetSymbolicHotKeyValue") }.map { unsafeBitCast($0, to: Get.self) }
        isEnabled = handle.flatMap { dlsym($0, "CGSIsSymbolicHotKeyEnabled") }.map { unsafeBitCast($0, to: IsEnabled.self) }
        set = handle.flatMap { dlsym($0, "CGSSetSymbolicHotKeyEnabled") }.map { unsafeBitCast($0, to: SetEnabled.self) }
    }
    func read(_ id: Int) -> SymbolicHotkey? {
        guard let get, let isEnabled else { return nil }
        var character: UInt16 = 0, key: UInt16 = 0, modifiers: UInt32 = 0
        guard get(Int32(id), &character, &key, &modifiers) == 0 else { return nil }
        return SymbolicHotkey(keyCode: key, modifiers: UInt64(modifiers), enabled: isEnabled(Int32(id)))
    }
    func setEnabled(_ id: Int, _ enabled: Bool) -> Bool { set?(Int32(id), enabled) == 0 }
}

let systemSymbolicHotkeys = SymbolicHotkeyReconciler(table: CGSSymbolicHotkeyTable(), marker: DefaultsSymbolicHotkeyMarker())
@MainActor private var symbolicHotkeysArmed = false
@MainActor private var symbolicSignalSources: [DispatchSourceSignal] = []
private let symbolicTermination = SignalTermination()
private let symbolicLog = Logger(subsystem: winMuxAppId, category: "symbolic-hotkeys")

@MainActor func armSymbolicHotkeyRestoration() {
    guard !symbolicHotkeysArmed else { return }
    symbolicHotkeysArmed = true
    for number in [SIGTERM, SIGINT, SIGHUP] {
        signal(number) { @Sendable _ in }
        let source = DispatchSource.makeSignalSource(signal: number, queue: .global(qos: .userInitiated))
        source.setEventHandler(handler: symbolicTermination.eventHandler(
            restore: { systemSymbolicHotkeys.restoreAndShutDown() },
            cleanup: { finish in
                Task { @MainActor in
                    defer { finish() }
                    try await terminationHandler.beforeTermination()
                }
            },
            terminate: { _exit(number) }
        ))
        source.resume()
        symbolicSignalSources.append(source)
    }
    NSSetUncaughtExceptionHandler { @Sendable _ in systemSymbolicHotkeys.restoreAndShutDown() }
    atexit { @Sendable in systemSymbolicHotkeys.restoreAndShutDown() }
    systemSymbolicHotkeys.repair(.launch, wanted: [])
}

@MainActor func reconcileSystemSymbolicHotkeys(repair: SymbolicHotkeyRepair? = nil) {
    guard symbolicHotkeysArmed else { return }
    let chords = listeningHotkeyChords()
    if let repair { systemSymbolicHotkeys.repair(repair, wanted: chords) }
    else { systemSymbolicHotkeys.reconcile(chords) }
    for error in systemSymbolicHotkeys.failures { symbolicLog.error("\(error, privacy: .public)") }
}
