@testable import AppBundle
import Common
import Clocks
import CoreServices
import XCTest

private func eventually(_ what: String, _ condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(20)
    while await !condition() {
        if ContinuousClock.now > deadline { return XCTFail("Timed out waiting until \(what)") }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
final class ConfigWatchListTest: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "winmux-watch-list-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ path: String) throws -> URL {
        let url = dir.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: url, atomically: false, encoding: .utf8)
        return url
    }

    func testHoldsTheConfigFileAndItsImportsAndWatchesTheirDirectories() throws {
        let config = try write("config/winmux.ncl")
        let imported = try write("shared/keys.ncl")

        let list = ConfigWatchList(configFile: config, imports: [config, imported], library: nil)

        XCTAssertTrue(list.holds(anyOf: [realPath(config.path)]))
        XCTAssertTrue(list.holds(anyOf: [realPath(imported.path)]))
        XCTAssertFalse(list.holds(anyOf: [realPath(dir.appending(path: "config/other.ncl").path)]))
        XCTAssertTrue(list.directories.contains(realPath(dir.appending(path: "config").path)))
        XCTAssertTrue(list.directories.contains(realPath(dir.appending(path: "shared").path)))
    }

    func testLeavesOutTheShippedLibrary() throws {
        let config = try write("config/winmux.ncl")
        let contract = try write("library/winmux/winmux.ncl")
        let defaults = try write("library/winmux/defaults.ncl")

        let list = ConfigWatchList(configFile: config, imports: [config, contract, defaults], library: dir.appending(path: "library"))

        XCTAssertTrue(list.holds(anyOf: [realPath(config.path)]))
        XCTAssertFalse(list.holds(anyOf: [realPath(contract.path), realPath(defaults.path)]))
        assertEquals(list.directories.filter { $0.contains("/library") }, [])
    }

    func testHoldsAConfigFileThatDoesNotExistYet() throws {
        let config = dir.appending(path: "not-yet/winmux.ncl")

        let list = ConfigWatchList(configFile: config, imports: [], library: nil)

        // The directory that exists is resolved, and the part that does not is kept as written.
        let expected = realPath(dir.path) + "/not-yet/winmux.ncl"
        XCTAssertTrue(list.holds(anyOf: [expected]))
        XCTAssertTrue(list.directories.contains(realPath(dir.path) + "/not-yet"))
    }

    func testAfterAFailedLoadAnyNickelFileInTheDirectoriesCounts() throws {
        let config = try write("config/winmux.ncl")
        let unseenImport = realPath(dir.appending(path: "config/keys.ncl").path)
        let notImportable = realPath(dir.appending(path: "config/notes.swift").path)

        let loaded = ConfigWatchList(configFile: config, imports: [config], library: nil)
        let failed = ConfigWatchList(configFile: config, imports: [config], library: nil, anyNickelFile: true)

        let inASubdirectory = realPath(dir.appending(path: "config").path) + "/lib/keys.ncl"
        let json = realPath(dir.appending(path: "config").path) + "/colors.json"
        let elsewhere = realPath(dir.path) + "/other/keys.ncl"

        XCTAssertFalse(loaded.holds(anyOf: [unseenImport]))
        XCTAssertTrue(failed.holds(anyOf: [unseenImport]))
        XCTAssertTrue(failed.holds(anyOf: [inASubdirectory]))
        XCTAssertTrue(failed.holds(anyOf: [json]), "Nickel imports JSON too")
        XCTAssertFalse(failed.holds(anyOf: [notImportable]))
        XCTAssertFalse(failed.holds(anyOf: [elsewhere]))
    }

    func testOnlyAChangeToAWatchedFilesContentsCounts() throws {
        let config = try write("config/winmux.ncl")
        let path = realPath(config.path)
        let list = ConfigWatchList(configFile: config, imports: [], library: nil)
        func flags(_ value: Int) -> FSEventStreamEventFlags { FSEventStreamEventFlags(value) }

        XCTAssertTrue(list.isChanged(by: [(path, flags(kFSEventStreamEventFlagItemModified | kFSEventStreamEventFlagItemIsFile))]))
        XCTAssertTrue(list.isChanged(by: [(path, flags(kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemIsFile))]))
        XCTAssertFalse(list.isChanged(by: [(path, flags(kFSEventStreamEventFlagItemXattrMod | kFSEventStreamEventFlagItemIsFile))]), "an attribute only")
        XCTAssertFalse(list.isChanged(by: [(path, flags(kFSEventStreamEventFlagItemInodeMetaMod | kFSEventStreamEventFlagItemIsFile))]), "metadata only")
        XCTAssertFalse(list.isChanged(by: [(realPath(dir.path) + "/config/other.ncl", flags(kFSEventStreamEventFlagItemModified))]))
        XCTAssertTrue(list.isChanged(by: [(realPath(dir.path), flags(kFSEventStreamEventFlagMustScanSubDirs))]), "dropped events")
    }

    func testHoldsBothTheLinkAndTheFileALinkedConfigPointsTo() throws {
        let target = try write("dotfiles/winmux.ncl")
        let link = dir.appending(path: "config/winmux.ncl")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let list = ConfigWatchList(configFile: link, imports: [link], library: nil)

        XCTAssertTrue(list.holds(anyOf: [realPath(target.path)]), "the file the link points to")
        XCTAssertTrue(list.holds(anyOf: [realPath(dir.path) + "/config/winmux.ncl"]), "the link itself")
    }
}

/// Watches real files through FSEvents.
@MainActor
final class ConfigFileWatcherTest: XCTestCase {
    private var dir: URL!
    private var changes = 0
    private var watcher: ConfigFileWatcher!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "winmux-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        changes = 0
        watcher = ConfigFileWatcher { [weak self] in self?.changes += 1 }
    }

    override func tearDown() async throws {
        watcher = nil
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ text: String, to path: String) throws -> URL {
        let url = dir.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: false, encoding: .utf8)
        return url
    }

    /// Starts the watch, then lets macOS deliver what it still has to say about the files the
    /// test wrote first, so those reports are not taken for the change under test.
    private func watch(configFile: URL, imports: [URL] = []) async throws {
        watcher.watch(ConfigWatchList(configFile: configFile, imports: imports, library: nil))
        try await Task.sleep(for: .milliseconds(300))
        changes = 0
    }

    func testReportsAFileWrittenInPlace() async throws {
        let config = try write("a", to: "winmux.ncl")
        try await watch(configFile: config)

        let handle = try FileHandle(forWritingTo: config)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("b".utf8))
        try handle.close()

        try await eventually("the write is reported") { self.changes > 0 }
    }

    func testReportsAFileReplacedByARenameAndTheSavesAfterIt() async throws {
        let config = try write("a", to: "winmux.ncl")
        try await watch(configFile: config)

        try "b".write(to: config, atomically: true, encoding: .utf8)
        try await eventually("the first replacement is reported") { self.changes > 0 }
        try await Task.sleep(for: .milliseconds(300))
        changes = 0
        try "c".write(to: config, atomically: true, encoding: .utf8)

        try await eventually("the second replacement is reported") { self.changes > 0 }
    }

    func testReportsAConfigFileCreatedAfterTheWatchStarted() async throws {
        let config = dir.appending(path: "winmux/winmux.ncl")
        try await watch(configFile: config)

        _ = try write("a", to: "winmux/winmux.ncl")

        try await eventually("the new file is reported") { self.changes > 0 }
    }

    func testReportsAnImportedFileInAnotherDirectory() async throws {
        let config = try write("a", to: "config/winmux.ncl")
        let imported = try write("a", to: "shared/keys.ncl")
        try await watch(configFile: config, imports: [config, imported])

        try "b".write(to: imported, atomically: false, encoding: .utf8)

        try await eventually("the imported file is reported") { self.changes > 0 }
    }

    func testReportsAFileReachedThroughALinkedDirectory() async throws {
        let target = try write("a", to: "dotfiles/winmux/winmux.ncl")
        let linkedDirectory = dir.appending(path: "config")
        try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: target.deletingLastPathComponent())
        try await watch(configFile: linkedDirectory.appending(path: "winmux.ncl"))

        try "b".write(to: target, atomically: false, encoding: .utf8)

        try await eventually("the write behind the link is reported") { self.changes > 0 }
    }

    func testStartsReportingANewlyImportedFileOnceItIsWatched() async throws {
        let config = try write("a", to: "config/winmux.ncl")
        let imported = try write("a", to: "config/keys.ncl")
        try await watch(configFile: config, imports: [config])

        // The same directory, so the stream is kept and only the files it answers for change.
        try await watch(configFile: config, imports: [config, imported])
        try "b".write(to: imported, atomically: false, encoding: .utf8)

        try await eventually("the newly watched file is reported") { self.changes > 0 }
    }
}

@MainActor
final class ConfigReloadSchedulerTest: SerialClockTestCase {
    func testSeveralChangesWithinTheDelayCauseOneReloadAndNeverFireEarly() async throws {
        let clock = TestClock<Duration>()
        let probe = ReloadProbe()
        let owner = probe.owner()
        let scheduler = ConfigReloadScheduler(delay: .milliseconds(300), clock: clock) { await owner.fileChanged() }
        for _ in 0 ..< 5 {
            scheduler.fileChanged()
            await clock.advance(by: .milliseconds(20))
        }
        await clock.advance(by: .milliseconds(280) - .nanoseconds(1))
        XCTAssertTrue(probe.adopted.isEmpty, "debounce must not fire one tick before its delay")
        XCTAssertEqual(probe.activeConfig, "serving")
        XCTAssertEqual(probe.activeHelper, "serving")
        XCTAssertTrue(probe.events.isEmpty)
        await clock.advance(by: .nanoseconds(1))
        await probe.completions.wait()
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(probe.activeConfig, "save")
        XCTAssertEqual(probe.activeHelper, "save")
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/save.ncl")])
        XCTAssertEqual(probe.adopted, ["save"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertEqual(probe.events.map(\.eventType), [.configReloaded])
        XCTAssertEqual(probe.watches, 1)
        XCTAssertEqual(probe.sessions, 1)
    }

    func testChangeDuringAReloadCausesOneMoreAfterIt() async throws {
        let clock = TestClock<Duration>()
        let probe = ReloadProbe(), gate = ReloadGate()
        let owner = probe.owner()
        probe.applyGates["save"] = gate
        let scheduler = ConfigReloadScheduler(delay: .milliseconds(300), clock: clock) { await owner.fileChanged() }
        scheduler.fileChanged()
        await clock.advance(by: .milliseconds(300))
        await gate.entered.wait()
        probe.nextSave = "followup"
        for _ in 0 ..< 5 { scheduler.fileChanged() }
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(probe.adopted, ["save"])
        XCTAssertTrue(probe.events.isEmpty)
        XCTAssertEqual(probe.activeHelper, "save")
        XCTAssertEqual(probe.activeConfig, "serving")
        gate.release()
        await probe.completions.wait(for: 2)
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(probe.activeConfig, "followup")
        XCTAssertEqual(probe.activeHelper, "followup")
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/followup.ncl")])
        XCTAssertEqual(probe.adopted, ["save", "followup"])
        XCTAssertTrue(probe.disposed.isEmpty)
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertFalse(probe.overlapped)
        XCTAssertEqual(probe.events.map(\.eventType), [.configReloaded, .configReloaded])
        XCTAssertEqual(probe.watches, 2)
        XCTAssertEqual(probe.sessions, 2)
    }
}

@MainActor
final class ConfigReloadSaveEntryTest: SerialClockTestCase {
    func testSaveBeforeRuntimeReadyIsDeferredUntilStartupAndRunsOnce() async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        probe.runtimeReady = false
        await owner.fileChanged()
        await owner.fileChanged()
        XCTAssertEqual(probe.activeConfig, "serving")
        XCTAssertEqual(probe.activeHelper, "serving")
        XCTAssertTrue(probe.adopted.isEmpty)
        XCTAssertTrue(probe.events.isEmpty)
        probe.runtimeReady = true
        await owner.startupFinished()
        await owner.startupFinished()
        XCTAssertEqual(probe.activeConfig, "save")
        XCTAssertEqual(probe.activeHelper, "save")
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/save.ncl")])
        XCTAssertEqual(probe.adopted, ["save"])
        XCTAssertEqual(probe.sessions, 1)
        XCTAssertEqual(probe.events.map(\.eventType), [.configReloaded])
        XCTAssertEqual(probe.watches, 1)
        XCTAssertTrue(probe.shown.isEmpty)
        XCTAssertTrue(probe.disposed.isEmpty)
    }

    func testMissingFileAndDisabledServerKeepTheServingConfig() async throws {
        for missing in [true, false] {
            let probe = ReloadProbe()
            let owner = probe.owner()
            probe.exists = !missing
            probe.enabled = missing
            await owner.fileChanged()
            XCTAssertEqual(probe.activeConfig, "serving")
            XCTAssertEqual(probe.activeHelper, "serving")
            XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/serving.ncl")])
            XCTAssertTrue(probe.adopted.isEmpty)
            XCTAssertTrue(probe.disposed.isEmpty)
            XCTAssertTrue(probe.events.isEmpty)
            XCTAssertTrue(probe.shown.isEmpty)
            XCTAssertEqual(probe.sessions, 0)
            XCTAssertEqual(probe.watches, 0)
        }
    }

    func testTwoIdenticalBrokenSavesThroughSessionRunnerNotifyOnceButEmitTwice() async throws {
        let probe = ReloadProbe()
        let owner = probe.owner()
        probe.failures["save"] = "broken save"
        await owner.fileChanged()
        await owner.fileChanged()
        XCTAssertEqual(probe.activeConfig, "serving")
        XCTAssertEqual(probe.activeHelper, "serving")
        XCTAssertEqual(probe.watchedImports, [URL(filePath: "/imports/serving.ncl")])
        XCTAssertEqual(probe.shown, ["broken save"])
        XCTAssertEqual(probe.recordedFailures, ["broken save", "broken save"])
        XCTAssertEqual(probe.sessions, 2)
        XCTAssertEqual(probe.events.map(\.eventType), [.configReloaded, .configReloaded])
        XCTAssertEqual(probe.watches, 2)
        XCTAssertTrue(probe.adopted.isEmpty)
        XCTAssertTrue(probe.disposed.isEmpty)
    }
}

@MainActor
final class ConfigReloadNotificationsTest: XCTestCase {
    func testSaveThatFailsTheSameWayIsNotNotifiedAgain() {
        var notifications = ConfigReloadNotifications()

        let first = notifications.shouldNotify("extra field `gapz`", trigger: .fileChange)
        let same = notifications.shouldNotify("extra field `gapz`", trigger: .fileChange)
        let different = notifications.shouldNotify("extra field `gapzz`", trigger: .fileChange)

        assertEquals([first, same, different], [true, false, true])
    }

    func testSameFailureFromAnotherHelperProcessIsTheSame() {
        var notifications = ConfigReloadNotifications()
        let first = "extra field `gapz`\n25 │ │   workspace-sidebar = %<closure@0x16d7f71a8>,"
        let second = "extra field `gapz`\n25 │ │   workspace-sidebar = %<closure@0x16cef31a8>,"

        _ = notifications.shouldNotify(first, trigger: .fileChange)

        XCTAssertFalse(notifications.shouldNotify(second, trigger: .fileChange))
    }

    func testLoadThatSucceedsMakesTheSameFailureNewAgain() {
        var notifications = ConfigReloadNotifications()
        _ = notifications.shouldNotify("extra field `gapz`", trigger: .fileChange)

        notifications.loaded()

        XCTAssertTrue(notifications.shouldNotify("extra field `gapz`", trigger: .fileChange))
    }

    func testReloadConfigCommandAlwaysNotifiesAndASaveAfterItDoesNotRepeatIt() {
        var notifications = ConfigReloadNotifications()
        _ = notifications.shouldNotify("extra field `gapz`", trigger: .fileChange)

        let command = notifications.shouldNotify("extra field `gapz`", trigger: .command)
        let saveAfterIt = notifications.shouldNotify("extra field `gapz`", trigger: .fileChange)

        assertEquals([command, saveAfterIt], [true, false])
    }
}

@MainActor
final class ConfigModeAfterReloadTest: XCTestCase {
    func testModeIsKeptWhileTheConfigStillHasIt() {
        var config = Config()
        config.modes = [mainModeId: Mode(bindings: [:], tapBindings: [:]), "resize": Mode(bindings: [:], tapBindings: [:])]

        assertEquals(config.modeToKeep("resize"), "resize")
    }

    func testModeTheConfigNoLongerHasGivesWayToMain() {
        var config = Config()
        config.modes = [mainModeId: Mode(bindings: [:], tapBindings: [:])]

        assertEquals(config.modeToKeep("resize"), mainModeId)
    }

    func testDisabledWinMuxStaysWithoutAMode() {
        var config = Config()
        config.modes = [mainModeId: Mode(bindings: [:], tapBindings: [:])]

        XCTAssertNil(config.modeToKeep(nil))
    }
}
