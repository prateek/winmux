@testable import AppBundle
import Common
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
        let notNickel = realPath(dir.appending(path: "config/notes.txt").path)

        let loaded = ConfigWatchList(configFile: config, imports: [config], library: nil)
        let failed = ConfigWatchList(configFile: config, imports: [config], library: nil, anyNickelFile: true)

        XCTAssertFalse(loaded.holds(anyOf: [unseenImport]))
        XCTAssertTrue(failed.holds(anyOf: [unseenImport]))
        XCTAssertFalse(failed.holds(anyOf: [notNickel]))
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
final class ConfigReloadSchedulerTest: XCTestCase {
    func testSeveralChangesWithinTheDelayCauseOneReload() async throws {
        var reloads = 0
        // The delay is far longer than the gaps between changes, so a slow runner cannot let it
        // run out between two of them.
        let scheduler = ConfigReloadScheduler(delay: .milliseconds(800)) { reloads += 1 }

        for _ in 0 ..< 5 {
            scheduler.fileChanged()
            try await Task.sleep(for: .milliseconds(20))
        }
        try await eventually("the reload runs") { reloads > 0 }
        // Long enough for a second reload to have run if one had been scheduled.
        try await Task.sleep(for: .milliseconds(1200))

        assertEquals(reloads, 1)
    }

    func testChangeDuringAReloadCausesOneMoreAfterIt() async throws {
        var started = 0
        var running = 0
        var overlapped = false
        var release: [CheckedContinuation<Void, Never>] = []
        let scheduler = ConfigReloadScheduler(delay: .milliseconds(20)) {
            started += 1
            running += 1
            if running > 1 { overlapped = true }
            await withCheckedContinuation { release.append($0) }
            running -= 1
        }

        scheduler.fileChanged()
        try await eventually("the first reload starts") { started == 1 }
        scheduler.fileChanged()
        scheduler.fileChanged()
        // Past the delay, so the changes have asked for their reload while the first still runs.
        try await Task.sleep(for: .milliseconds(200))
        let startedWhileTheFirstRan = started
        release.removeFirst().resume()
        try await eventually("the second reload starts") { started == 2 }
        release.removeFirst().resume()
        try await Task.sleep(for: .milliseconds(200))

        assertEquals(startedWhileTheFirstRan, 1)
        assertEquals(started, 2)
        XCTAssertFalse(overlapped)
    }
}

@MainActor
final class ConfigReloadErrorsTest: XCTestCase {
    func testSaveThatFailsTheSameWayIsNotNotifiedAgain() {
        var errors = ConfigReloadErrors()

        let first = errors.shouldNotify("extra field `gapz`", trigger: .fileChange)
        let same = errors.shouldNotify("extra field `gapz`", trigger: .fileChange)
        let different = errors.shouldNotify("extra field `gapzz`", trigger: .fileChange)

        assertEquals([first, same, different], [true, false, true])
    }

    func testLoadThatSucceedsMakesTheSameFailureNewAgain() {
        var errors = ConfigReloadErrors()
        _ = errors.shouldNotify("extra field `gapz`", trigger: .fileChange)

        errors.loaded()

        XCTAssertTrue(errors.shouldNotify("extra field `gapz`", trigger: .fileChange))
    }

    func testReloadConfigCommandAlwaysNotifiesAndASaveAfterItDoesNotRepeatIt() {
        var errors = ConfigReloadErrors()
        _ = errors.shouldNotify("extra field `gapz`", trigger: .fileChange)

        let command = errors.shouldNotify("extra field `gapz`", trigger: .command)
        let saveAfterIt = errors.shouldNotify("extra field `gapz`", trigger: .fileChange)

        assertEquals([command, saveAfterIt], [true, false])
    }

    func testLastErrorIsTheLastFailureUntilALoadSucceeds() {
        var errors = ConfigReloadErrors()

        errors.failed("first")
        errors.failed("second")
        let afterFailures = errors.last
        errors.loaded()

        assertEquals(afterFailures, "second")
        XCTAssertNil(errors.last)
    }

    func testConfigStatusShowsAFailedReloadBeforeTheHelpersOwnError() {
        func status(helperError: String?) -> NickelStatus {
            NickelStatus(state: .ready, pid: 1, rss: 0, recycles: 0, lastError: helperError, configPath: "/config/winmux.ncl")
        }

        let reloadFailed = ConfigHelperStatus(status(helperError: nil), reloadError: "extra field `gapz`")
        let helperFailed = ConfigHelperStatus(status(helperError: "The config helper exited unexpectedly"), reloadError: "extra field `gapz`")
        let fine = ConfigHelperStatus(status(helperError: nil), reloadError: nil)

        let helperOnly = ConfigHelperStatus(status(helperError: "The config helper exited unexpectedly"), reloadError: nil)

        assertEquals(reloadFailed.lastError, "extra field `gapz`")
        // The helper keeps its error after it restarts, so it may be older than the reload.
        assertEquals(helperFailed.lastError, "extra field `gapz`")
        assertEquals(helperOnly.lastError, "The config helper exited unexpectedly")
        XCTAssertNil(fine.lastError)
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
