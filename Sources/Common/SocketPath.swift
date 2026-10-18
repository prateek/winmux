import Darwin
import Foundation

private struct SocketPathError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

public func darwinUserTemporaryDirectory() throws -> String {
    let size = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
    guard size > 1 else { throw SocketPathError("confstr(_CS_DARWIN_USER_TEMP_DIR) returned no directory") }
    var buffer = [CChar](repeating: 0, count: size)
    let written = confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, size)
    guard written > 1, written <= size else {
        throw SocketPathError("confstr(_CS_DARWIN_USER_TEMP_DIR) failed to read the directory")
    }
    return String(decoding: buffer.prefix(written - 1).map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

private func socketDirectoryPath(baseDirectory: String, appId: String) -> String {
    (baseDirectory as NSString).appendingPathComponent(appId)
}

public func socketPath(appId: String = winMuxAppId) throws -> String {
    let path = (socketDirectoryPath(baseDirectory: try darwinUserTemporaryDirectory(), appId: appId) as NSString)
        .appendingPathComponent("winmux.sock")
    guard path.utf8.count + 1 <= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
        throw SocketPathError("Socket path exceeds sun_path (104 bytes including terminator): \(path)")
    }
    return path
}

/// Refuse unsafe entries before binding; never follow a link or chmod someone else's directory.
@discardableResult
public func prepareSocketDirectory(
    baseDirectory: String, appId: String = winMuxAppId, expectedOwner: uid_t
) throws -> String {
    let path = socketDirectoryPath(baseDirectory: baseDirectory, appId: appId)
    if mkdir(path, 0o700) != 0, errno != EEXIST {
        throw SocketPathError("Cannot create socket directory \(path): \(String(cString: strerror(errno)))")
    }
    var info = stat()
    guard lstat(path, &info) == 0 else {
        throw SocketPathError("Cannot lstat socket directory \(path): \(String(cString: strerror(errno)))")
    }
    guard info.st_mode & S_IFMT != S_IFLNK else { throw SocketPathError("Socket directory \(path) is a symlink") }
    guard info.st_mode & S_IFMT == S_IFDIR else { throw SocketPathError("Socket directory \(path) is not a directory") }
    guard info.st_uid == expectedOwner else {
        throw SocketPathError("Socket directory \(path) has owner uid \(info.st_uid), expected \(expectedOwner)")
    }
    let fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    guard fd >= 0 else { throw SocketPathError("Cannot open socket directory \(path): \(String(cString: strerror(errno)))") }
    defer { close(fd) }
    var opened = stat()
    guard fstat(fd, &opened) == 0, opened.st_dev == info.st_dev, opened.st_ino == info.st_ino else {
        throw SocketPathError("Socket directory changed while checking \(path)")
    }
    if opened.st_mode & 0o7777 != 0o700, fchmod(fd, 0o700) != 0 {
        throw SocketPathError("Cannot make socket directory private \(path): \(String(cString: strerror(errno)))")
    }
    return path
}

/// Remove when "The legacy `/tmp` socket stops answering" lands.
public func legacySocketPath(appId: String = winMuxAppId) -> String {
    "/tmp/\(appId)-\(unixUserName).sock"
}

public func removeLegacySocketEntry(path: String, expectedOwner: uid_t) {
    var info = stat()
    if lstat(path, &info) == 0, info.st_uid == expectedOwner, info.st_mode & S_IFMT == S_IFSOCK {
        _ = unlink(path)
    }
}

public func socketConnectionFailureMessage(_ reason: String, legacyPath: String = legacySocketPath()) -> String {
    let message = "Can't connect to WinMux server. Is WinMux.app running?\n\(reason)"
    // The entry outlives every app that bound it, so only a listener there counts.
    return unixSocketAnswers(path: legacyPath)
        ? message + "\nWinMux answers only on the legacy socket: an app from before the move is running, or this one lost its socket. Restart WinMux.app."
        : message
}

private func unixSocketAnswers(path: String) -> Bool {
    var address = sockaddr_un()
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard path.utf8.count < capacity else { return false }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutablePointer(to: &address.sun_path) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { buffer in
            _ = path.withCString { strlcpy(buffer, $0, capacity) }
        }
    }
    return withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
        }
    }
}
