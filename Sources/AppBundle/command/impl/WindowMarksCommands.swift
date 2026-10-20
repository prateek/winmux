import Common

struct FocusBackCommand: Command {
    let args: FocusBackCmdArgs
    let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let window = prevFocusedWindow else { return io.err("No previously focused window") }
        return try await focusLensWindow(window)
    }
}

struct MarkCommand: Command {
    let args: MarkCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else { return io.err(noWindowIsFocused) }
        if let register = args.register {
            WindowMarks.set(register, to: window)
            return true
        }
        let registers = WindowMarks.live.filter { $0.window.windowId == window.windowId }.map(\.register)
        return registers.isEmpty || io.out(registers.joined(separator: " "))
    }
}

struct JumpCommand: Command {
    let args: JumpCmdArgs
    let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let window = WindowMarks.window(for: args.register.val) else {
            return io.err("Register \(args.register.val) is empty")
        }
        return try await focusLensWindow(window)
    }
}

struct ListMarksCommand: Command {
    let args: ListMarksCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let marks = WindowMarks.live
        var objects: [FormatObject] = []
        for mark in marks {
            objects.append(.window(window: mark.window, title: try await mark.window.title))
        }
        let format = ListWindowsCmdArgs.defaultFormat
        if args.json {
            let fields: [[String: Primitive]] = marks.map { ["register": .string($0.register)] }
            return switch objects.formatToJson(format, ignoreRightPaddingVar: true, extraFields: fields) {
                case .success(let json): io.out(json)
                case .failure(let error): io.err(error)
            }
        }
        return switch objects.format(format) {
            case .success(let lines): io.out(zip(marks, lines).map { "\($0.0.register) | \($0.1)" })
            case .failure(let error): io.err(error)
        }
    }
}
