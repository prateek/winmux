import Common
import Darwin
import Foundation
import XCTest

final class SocketPathTest: XCTestCase {
    private func withBase(_ body: (String) throws -> Void) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: base) }
        try body(base)
    }

    private func attributes(_ path: String) throws -> stat {
        var info = stat()
        XCTAssertEqual(lstat(path, &info), 0)
        return info
    }

    func testMissingDirectoryIsPrivateAndOwnedByEffectiveUser() throws {
        try withBase { base in
            let directory = try prepareSocketDirectory(baseDirectory: base, appId: "test", expectedOwner: geteuid())
            let info = try attributes(directory)
            XCTAssertEqual(info.st_mode & 0o777, 0o700)
            XCTAssertEqual(info.st_uid, geteuid())
        }
    }

    func testExistingDirectoryIsTightened() throws {
        try withBase { base in
            let path = base + "/test"
            XCTAssertEqual(mkdir(path, 0o755), 0)
            XCTAssertEqual(chmod(path, 0o755), 0)
            XCTAssertEqual(try prepareSocketDirectory(baseDirectory: base, appId: "test", expectedOwner: geteuid()), path)
            XCTAssertEqual(try attributes(path).st_mode & 0o777, 0o700)
        }
    }

    func testSymlinkFileAndForeignOwnerAreRefusedWithReasonAndPath() throws {
        try withBase { base in
            let path = base + "/test"
            func refused(_ reason: String, owner: uid_t = geteuid()) {
                XCTAssertThrowsError(try prepareSocketDirectory(baseDirectory: base, appId: "test", expectedOwner: owner)) { error in
                    XCTAssertTrue(error.localizedDescription.contains(path), "\(error)")
                    XCTAssertTrue(error.localizedDescription.contains(reason), "\(error)")
                }
            }
            XCTAssertEqual(symlink(base, path), 0)
            refused("symlink")
            try FileManager.default.removeItem(atPath: path)
            XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data()))
            refused("not a directory")
            try FileManager.default.removeItem(atPath: path)
            XCTAssertEqual(mkdir(path, 0o700), 0)
            refused("owner", owner: geteuid() + 1)
        }
    }

    func testRealSocketPathIsPrivateUnderConfstrAndFitsUnixAddress() throws {
        let path = try socketPath()
        let directory = (path as NSString).deletingLastPathComponent
        _ = try prepareSocketDirectory(baseDirectory: try darwinUserTemporaryDirectory(), expectedOwner: geteuid())
        let info = try attributes(directory)
        XCTAssertEqual(info.st_mode & 0o777, 0o700)
        XCTAssertEqual(info.st_uid, geteuid())
        var buffer = [CChar](repeating: 0, count: Int(confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)))
        XCTAssertGreaterThan(confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count), 0)
        let base = String(decoding: buffer.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self)
        XCTAssertTrue(path.hasPrefix(base))
        XCTAssertFalse(path.hasPrefix("/tmp/"))
        XCTAssertLessThanOrEqual(path.utf8.count + 1, MemoryLayout.size(ofValue: sockaddr_un().sun_path))
        XCTAssertEqual((path as NSString).lastPathComponent, "winmux.sock")
        XCTAssertEqual((directory as NSString).lastPathComponent, winMuxAppId)
    }

    func testBothAppIdsIgnoreShellAndLaunchServicesEnvironment() throws {
        let keys = ["TMPDIR", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "HOME"]
        let saved = keys.map { getenv($0).map { String(cString: $0) } }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { setenv(key, value, 1) } else { unsetenv(key) }
            }
        }
        let ids = [stableWinMuxAppId, stableWinMuxAppId + ".debug"]
        let original = try ids.map { try socketPath(appId: $0) }
        for key in keys { setenv(key, "/some/other/location", 1) }
        XCTAssertEqual(try ids.map { try socketPath(appId: $0) }, original)
        XCTAssertNotEqual(original[0], original[1])
    }

    func testOverlongSocketPathNamesThePath() throws {
        let id = String(repeating: "x", count: 104)
        XCTAssertThrowsError(try socketPath(appId: id)) { error in
            XCTAssertTrue(error.localizedDescription.contains(id))
            XCTAssertTrue(error.localizedDescription.contains("sun_path"))
        }
    }

    func testLegacyPathsKeepExactOldFormForBothAppIds() {
        for id in [stableWinMuxAppId, stableWinMuxAppId + ".debug"] {
            XCTAssertEqual(legacySocketPath(appId: id), "/tmp/\(id)-\(NSUserName()).sock")
        }
    }

    func testConnectionFailureOnlyAddsRestartHintWhenLegacyEntryExists() throws {
        try withBase { base in
            let legacy = base + "/legacy.sock"
            let original = "Can't connect to WinMux server. Is WinMux.app running?\nconnection refused"
            XCTAssertEqual(socketConnectionFailureMessage("connection refused", legacyPath: legacy), original)
            XCTAssertTrue(FileManager.default.createFile(atPath: legacy, contents: Data()))
            XCTAssertEqual(socketConnectionFailureMessage("connection refused", legacyPath: legacy),
                           original + "\nA WinMux.app from before this change may be running and needs a restart.")
        }
    }

    func testLegacyCleanupOnlyRemovesAnOwnedSocket() throws {
        try withBase { base in
            let path = base + "/legacy.sock"
            XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data()))
            removeLegacySocketEntry(path: path, expectedOwner: geteuid())
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            try FileManager.default.removeItem(atPath: path)
            XCTAssertEqual(symlink(base, path), 0)
            removeLegacySocketEntry(path: path, expectedOwner: geteuid())
            XCTAssertEqual(try attributes(path).st_mode & S_IFMT, S_IFLNK)
            try FileManager.default.removeItem(atPath: path)

            // Use a short path even on hosts whose XCTest temporary directory is long.
            let socketFile = "/tmp/\(UUID().uuidString).sock"
            defer { unlink(socketFile) }
            let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            XCTAssertGreaterThanOrEqual(fd, 0)
            defer { close(fd) }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 104) { buffer in
                    _ = socketFile.withCString { strlcpy(buffer, $0, 104) }
                }
            }
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            XCTAssertEqual(result, 0)
            removeLegacySocketEntry(path: socketFile, expectedOwner: geteuid() + 1)
            XCTAssertEqual(try attributes(socketFile).st_mode & S_IFMT, S_IFSOCK)
            removeLegacySocketEntry(path: socketFile, expectedOwner: geteuid())
            var info = stat()
            XCTAssertEqual(lstat(socketFile, &info), -1)
            XCTAssertEqual(errno, ENOENT)
        }
    }
}
