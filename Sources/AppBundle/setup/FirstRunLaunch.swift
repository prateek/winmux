import Common
import Darwin
import Foundation
import PrivateApi

let setupResumeTokenKey = "WINMUX_SETUP_RESUME_TOKEN"
@MainActor var firstRunLaunchWasResumed = false
// Quit & Reopen drops launch options. Volatile memory survives that process exit;
// the pending marker remains the only persistent setup file.
private let setupContextName = "/winmux-setup-\(getuid())-\(isDebug ? "d" : "r")"
private let setupContextLimit = 1_048_576
private let setupContextHeaderSize = MemoryLayout<UInt32>.size

struct FirstRunLaunchContext: Codable, Equatable {
    let arguments: [String]
    var environment: [String: String]
    let stateURL: URL
    let stateWasSaved: Bool
    let token: String
}

enum FirstRunLaunchAction: Equatable {
    case normal, resume, reexecute(FirstRunLaunchContext)
}

func firstRunLaunchAction(context: FirstRunLaunchContext?, currentEnvironment: [String: String], pendingState: Bool) -> FirstRunLaunchAction {
    guard let context, !context.stateWasSaved || pendingState else { return .normal }
    if currentEnvironment.contains(where: { $0.key.hasPrefix("XDG_") && context.environment[$0.key] != $0.value }) { return .resume }
    if currentEnvironment[setupResumeTokenKey] == context.token { return .resume }
    return .reexecute(context)
}

@MainActor
func resumeFirstRunLaunchIfNeeded() throws {
    let context = readFirstRunLaunchContext()
    let pending = context.map { readFirstRunState(from: $0.stateURL).pending } ?? false
    switch firstRunLaunchAction(context: context, currentEnvironment: ProcessInfo.processInfo.environment, pendingState: pending) {
        case .normal:
            if let context, context.stateWasSaved && !pending { clearFirstRunLaunchContext() }
        case .resume: firstRunLaunchWasResumed = true
        case .reexecute(let context):
            try reexecuteFirstRunLaunch(context, executable: Bundle.main.executableURL?.path ?? CommandLine.arguments[0])
    }
}

func reexecuteFirstRunLaunch(_ context: FirstRunLaunchContext, executable: String,
                            execute: (String, [String], [String: String]) throws -> Void = executeSetupLaunch) throws {
    var environment = context.environment
    environment[setupResumeTokenKey] = context.token
    try execute(executable, [executable] + context.arguments.dropFirst(), environment)
    throw POSIXError(.EIO)
}

private func executeSetupLaunch(_ executable: String, _ arguments: [String], _ environment: [String: String]) throws {
    let argv = arguments.map { strdup($0) } + [nil]
    let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
    guard argv.dropLast().allSatisfy({ $0 != nil }), envp.dropLast().allSatisfy({ $0 != nil }) else { throw POSIXError(.ENOMEM) }
    argv.withUnsafeBufferPointer { args in
        envp.withUnsafeBufferPointer { env in
            _ = executable.withCString { execve($0, args.baseAddress!, env.baseAddress!) }
        }
    }
    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
}

func writeFirstRunLaunchContext(_ context: FirstRunLaunchContext, name: String = setupContextName) throws {
    let data = try JSONEncoder().encode(context)
    guard data.count <= setupContextLimit else { throw POSIXError(.E2BIG) }
    let count = setupContextHeaderSize + data.count
    clearFirstRunLaunchContext(name: name)
    let descriptor = winMuxOpenSetupMemory(name, O_CREAT | O_EXCL | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer { close(descriptor) }
    guard ftruncate(descriptor, off_t(count)) == 0 else {
        let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        clearFirstRunLaunchContext(name: name)
        throw failure
    }
    let mapping = mmap(nil, count, PROT_READ | PROT_WRITE, MAP_SHARED, descriptor, 0)
    guard let mapping, mapping != MAP_FAILED else {
        let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        clearFirstRunLaunchContext(name: name)
        throw failure
    }
    defer { munmap(mapping, count) }
    data.copyBytes(to: mapping.advanced(by: setupContextHeaderSize).assumingMemoryBound(to: UInt8.self), count: data.count)
    mapping.storeBytes(of: UInt32(data.count).littleEndian, as: UInt32.self)
}

func readFirstRunLaunchContext(name: String = setupContextName) -> FirstRunLaunchContext? {
    let descriptor = winMuxOpenSetupMemory(name, O_RDONLY, 0)
    guard descriptor >= 0 else { return nil }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0, info.st_size >= setupContextHeaderSize,
          info.st_size <= setupContextLimit + Int(getpagesize()) else { return nil }
    let count = Int(info.st_size)
    let mapping = mmap(nil, count, PROT_READ, MAP_SHARED, descriptor, 0)
    guard let mapping, mapping != MAP_FAILED else { return nil }
    defer { munmap(mapping, count) }
    // Darwin rounds the object size to a page; decode only the recorded payload.
    let payloadCount = Int(mapping.load(as: UInt32.self).littleEndian)
    guard payloadCount > 0, payloadCount <= setupContextLimit, setupContextHeaderSize + payloadCount <= count else { return nil }
    return try? JSONDecoder().decode(FirstRunLaunchContext.self, from: Data(bytes: mapping.advanced(by: setupContextHeaderSize), count: payloadCount))
}

func clearFirstRunLaunchContext(name: String = setupContextName) {
    _ = shm_unlink(name)
}
