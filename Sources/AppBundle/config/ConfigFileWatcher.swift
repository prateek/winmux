import Common
import CoreServices
import Foundation
import Synchronization

/// The files whose change reloads the config, and the directories that hold them.
struct ConfigWatchList: Equatable, Sendable {
    /// Every path an event for a watched file may carry: the path as written, and the path with
    /// its symbolic links resolved, which is the one macOS reports.
    let files: Set<String>
    let directories: Set<String>
    /// Whether any Nickel file in the directories counts. After a failed load WinMux does not know
    /// what the config imports, and the file that failed may be one it has not seen.
    let anyNickelFile: Bool

    /// - Parameter configFile: Where the config file is, or would be if it does not exist yet.
    /// - Parameter library: The shipped library. Its files change only when WinMux is replaced,
    ///   so they are left out.
    init(configFile: URL, imports: [URL], library: URL?, anyNickelFile: Bool = false) {
        self.anyNickelFile = anyNickelFile
        let libraryPrefix = library.map { realPath($0.standardizedFileURL.path) + "/" }
        var files: Set<String> = []
        for file in [configFile] + imports {
            let written = file.standardizedFileURL.path as NSString
            let real = realPath(written as String)
            if let libraryPrefix, real.hasPrefix(libraryPrefix) { continue }
            // A file that is itself a link changes when the link is replaced and when the file it
            // points to is written.
            let link = (realPath(written.deletingLastPathComponent) as NSString).appendingPathComponent(written.lastPathComponent)
            files.formUnion([written as String, real, link])
        }
        self.files = files
        directories = Set(files.map { ($0 as NSString).deletingLastPathComponent })
    }

    /// Whether any of `paths`, as macOS reports changed files, is a watched file.
    func holds(anyOf paths: [String]) -> Bool {
        paths.contains { path in
            files.contains(path)
                || anyNickelFile && path.hasSuffix(".ncl") && directories.contains((path as NSString).deletingLastPathComponent)
        }
    }

    /// Whether FSEvents' `events` change a watched file's contents. A change to a file's
    /// attributes alone, such as macOS recording when it was last opened, does not.
    func isChanged(by events: [(path: String, flags: FSEventStreamEventFlags)]) -> Bool {
        let content = kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved
            | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemModified
        // macOS sets these when it dropped events and cannot say which files changed.
        let dropped = kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
        return events.contains { event in
            event.flags & UInt32(dropped) != 0
                || event.flags & UInt32(content) != 0 && holds(anyOf: [event.path])
        }
    }
}

/// `path` with its symbolic links resolved. The part of the path that does not exist is kept as
/// written.
func realPath(_ path: String) -> String {
    if let resolved = realpath(path, nil) {
        defer { free(resolved) }
        return String(cString: resolved)
    }
    let parent = (path as NSString).deletingLastPathComponent
    if parent == path || parent.isEmpty { return path }
    return (realPath(parent) as NSString).appendingPathComponent((path as NSString).lastPathComponent)
}

/// Reports changes to the files of a `ConfigWatchList`. It watches their directories, so it sees
/// a file that is written in place, one that is replaced by a rename, and one that did not exist.
@MainActor
final class ConfigFileWatcher {
    private let onChange: @MainActor () -> Void
    /// Read by the stream off the main thread, where it filters events.
    private let list = WatchedList()
    private var stream: DirectoryEventStream?

    private final class WatchedList: Sendable {
        let value = Mutex<ConfigWatchList?>(nil)
    }

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    /// Watches the files of `list`, or nothing when it is nil.
    func watch(_ list: ConfigWatchList?) {
        let directoriesBefore = self.list.value.withLock { old in
            defer { old = list }
            return old?.directories
        }
        guard let list else {
            stream = nil
            return
        }
        // The stream is kept while it covers the same directories, so no change is lost between
        // stopping one stream and starting the next.
        if stream != nil && directoriesBefore == list.directories { return }
        let watched = self.list
        stream = DirectoryEventStream(
            directories: list.directories,
            matches: { events in watched.value.withLock { $0?.isChanged(by: events) ?? false } },
            onMatch: { [weak self] in self?.onChange() },
        )
    }
}

/// An FSEvents stream over a set of directories. Events are filtered on a queue of its own, so a
/// busy directory costs WinMux's main thread nothing until a watched file changes.
private final class DirectoryEventStream {
    private let stream: FSEventStreamRef
    private let handler: Unmanaged<Handler>
    private static let queue = DispatchQueue(label: "winmux.config-file-watcher")

    private final class Handler: Sendable {
        let matches: @Sendable ([(path: String, flags: FSEventStreamEventFlags)]) -> Bool
        let onMatch: @MainActor () -> Void
        init(_ matches: @escaping @Sendable ([(path: String, flags: FSEventStreamEventFlags)]) -> Bool, _ onMatch: @escaping @MainActor () -> Void) {
            self.matches = matches
            self.onMatch = onMatch
        }
    }

    init?(
        directories: Set<String>,
        matches: @escaping @Sendable ([(path: String, flags: FSEventStreamEventFlags)]) -> Bool,
        onMatch: @escaping @MainActor () -> Void,
    ) {
        let handler = Unmanaged.passRetained(Handler(matches, onMatch))
        var context = FSEventStreamContext(version: 0, info: handler.toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let handler = Unmanaged<Handler>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
            let events = zip(paths, UnsafeBufferPointer(start: flags, count: count)).map { (path: $0, flags: $1) }
            if handler.matches(events) {
                Task { @MainActor in handler.onMatch() }
            }
        }
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            directories.sorted() as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.01,
            FSEventStreamCreateFlags(flags),
        ) else {
            handler.release()
            return nil
        }
        FSEventStreamSetDispatchQueue(stream, DirectoryEventStream.queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            handler.release()
            return nil
        }
        self.stream = stream
        self.handler = handler
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        // A callback may still be running on the queue. The queue is serial, so this runs after it.
        let handler = handler
        DirectoryEventStream.queue.async { handler.release() }
    }
}

/// Turns a burst of file changes into one reload, and runs one reload at a time.
@MainActor
final class ConfigReloadScheduler {
    private let delay: Duration
    private let reload: @MainActor () async -> Void
    private var debounce: Task<Void, Never>?
    private var isReloading = false
    private var changedDuringReload = false

    init(delay: Duration, reload: @escaping @MainActor () async -> Void) {
        self.delay = delay
        self.reload = reload
    }

    /// Reloads once `delay` has passed with no further change.
    func fileChanged() {
        debounce?.cancel()
        debounce = Task {
            do { try await Task.sleep(for: delay) } catch { return }
            startReload()
        }
    }

    // Only the wait is cancelled by a later change. A reload under way finishes, and a change
    // that arrives during it causes one more.
    private func startReload() {
        if isReloading {
            changedDuringReload = true
            return
        }
        isReloading = true
        Task {
            repeat {
                changedDuringReload = false
                await reload()
            } while changedDuringReload
            isReloading = false
        }
    }
}

private let reloadDebounceDelay: Duration = .milliseconds(300)

@MainActor private let reloadScheduler = ConfigReloadScheduler(delay: reloadDebounceDelay) { await reloadConfigAfterFileChange() }
@MainActor private let configFileWatcher = ConfigFileWatcher { reloadScheduler.fileChanged() }
@MainActor private var lastLoadedFiles: (imports: [URL], library: URL?) = ([], nil)
@MainActor private var lastLoadFailed = false

enum ConfigLoadOutcome {
    case loaded(LoadedNickelConfig)
    case failed
}

/// Watches the config file and the files it imported when it last loaded. Called after every
/// load, so a newly imported file is watched. A failed load keeps the files of the last
/// successful one, and any Nickel file in their directories counts until a load succeeds.
@MainActor func syncConfigFileWatcher(after outcome: ConfigLoadOutcome? = nil) {
    switch outcome {
        case .loaded(let loaded):
            lastLoadedFiles = (loaded.imports, loaded.library)
            lastLoadFailed = false
        case .failed: lastLoadFailed = true
        case nil: break
    }
    guard config.reloadOnSave else { return configFileWatcher.watch(nil) }
    configFileWatcher.watch(ConfigWatchList(
        configFile: preferredEditableConfigUrl(),
        imports: lastLoadedFiles.imports,
        library: lastLoadedFiles.library,
        anyNickelFile: lastLoadFailed,
    ))
}
