import Common
import CoreServices
import Foundation

/// The files whose change reloads the config, and the directories that hold them.
struct ConfigWatchList: Equatable {
    /// Every path an event for a watched file may carry: the path as written, and the path with
    /// its symbolic links resolved, which is the one macOS reports.
    let files: Set<String>
    let directories: Set<String>

    /// - Parameter configFile: Where the config file is, or would be if it does not exist yet.
    /// - Parameter library: The shipped library. Its files change only when WinMux is replaced,
    ///   so they are left out.
    init(configFile: URL, imports: [URL], library: URL?) {
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
        paths.contains(where: files.contains)
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
    private var list: ConfigWatchList?
    private var stream: DirectoryEventStream?

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    /// Watches the files of `list`, or nothing when it is nil.
    func watch(_ list: ConfigWatchList?) {
        let directoriesBefore = self.list?.directories
        self.list = list
        guard let list else {
            stream = nil
            return
        }
        // The stream is kept while it covers the same directories, so no change is lost between
        // stopping one stream and starting the next.
        if stream != nil && directoriesBefore == list.directories { return }
        stream = DirectoryEventStream(directories: list.directories) { [weak self] paths, mustRescan in
            guard let self, let list = self.list else { return }
            if mustRescan || list.holds(anyOf: paths) { self.onChange() }
        }
    }
}

/// An FSEvents stream over a set of directories that reports the path of each file that changes.
private final class DirectoryEventStream {
    private let stream: FSEventStreamRef
    private let handler: Unmanaged<Handler>

    private final class Handler: Sendable {
        let onEvents: @MainActor (_ paths: [String], _ mustRescan: Bool) -> Void
        init(_ onEvents: @escaping @MainActor ([String], Bool) -> Void) { self.onEvents = onEvents }
    }

    init?(directories: Set<String>, onEvents: @escaping @MainActor (_ paths: [String], _ mustRescan: Bool) -> Void) {
        let handler = Unmanaged.passRetained(Handler(onEvents))
        var context = FSEventStreamContext(version: 0, info: handler.toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let handler = Unmanaged<Handler>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
            // macOS sets these when it dropped events and cannot say which files changed.
            let rescan = kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
            let mustRescan = (0 ..< count).contains { flags[$0] & UInt32(rescan) != 0 }
            MainActor.checkIsolated { handler.onEvents(paths, mustRescan) }
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
        FSEventStreamSetDispatchQueue(stream, .main)
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
        handler.release()
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

/// Where the config file is, or would be if it does not exist yet.
@MainActor func watchedConfigFileUrl() -> URL {
    serverArgs.configLocation.map { URL(filePath: $0) } ?? generatedConfigUrl()
}

/// Watches the config file and the files it imported when it last loaded. Called after every
/// load, so a newly imported file is watched, and a failed load keeps the files of the last
/// successful one.
@MainActor func syncConfigFileWatcher(loaded: LoadedNickelConfig? = nil) {
    if let loaded { lastLoadedFiles = (loaded.imports, loaded.library) }
    guard config.reloadOnSave else { return configFileWatcher.watch(nil) }
    configFileWatcher.watch(ConfigWatchList(
        configFile: watchedConfigFileUrl(),
        imports: lastLoadedFiles.imports,
        library: lastLoadedFiles.library,
    ))
}
