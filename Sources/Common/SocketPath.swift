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

public func socketPath(appId: String = winMuxAppId) throws -> String {
    let path = (try darwinUserTemporaryDirectory() as NSString).appendingPathComponent(appId + "/winmux.sock")
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
    let path = (baseDirectory as NSString).appendingPathComponent(appId)
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
    var message = "Can't connect to WinMux server. Is WinMux.app running?\n\(reason)"
    var info = stat()
    if lstat(legacyPath, &info) == 0 {
        message += "\nA WinMux.app from before this change may be running and needs a restart."
    }
    return message
}
