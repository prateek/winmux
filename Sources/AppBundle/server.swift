import AppKit
import Common
import Network

func startUnixSocketServer() {
    try? FileManager.default.removeItem(atPath: socketPath)
    let params = NWParameters.tcp
    params.requiredLocalEndpoint = .unix(path: socketPath)
    let listener = Result { try NWListener(using: params) }.getOrDie()
    listener.newConnectionHandler = { connection in
        Task {
            defer { connection.cancel() }
            connection.start(queue: .global())
            await newConnection(connection)
        }
    }
    listener.start(queue: .global())
}

func toggleReleaseServerIfDebug(_ state: EnableCmdArgs.State) async {
    if serverArgs.isReadOnly { return }
    if !isDebug { return }
    let socketFile = "/tmp/\(stableWinMuxAppId)-\(unixUserName).sock"
    let connection = NWConnection(to: NWEndpoint.unix(path: socketFile), using: .tcp)
    defer { connection.cancel() }
    if await connection.startBlocking().error != nil { // Can't connect, WinMux.app is not running
        return
    }

    let req = ClientRequest(args: ["enable", state.rawValue], stdin: "", windowId: nil, workspace: nil)
    _ = await connection.writeAtomic(req)
    _ = await connection.readNonAtomic()
}

private let serverVersionAndHash = "\(winMuxAppVersion) \(gitHash)"

@MainActor
func executeExternalCommand(
    _ arguments: [String], stdin: String, windowId: UInt32?, workspace: String?,
    traceOrigin: LensTraceOrigin, event: (any CmdArgs) -> RefreshSessionEvent = { .socketServer($0) },
    gate: (@MainActor (any Command) -> String?)? = nil, refuseHelp: Bool = false,
    setup: FirstRunSetup = .shared,
    didRun: ((ServerAnswer) -> ServerAnswer)? = nil
) async -> ServerAnswer {
    func answer(_ exitCode: Int32, stdout: String = "", stderr: String = "") -> ServerAnswer {
        ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
    }
    let (command, help, err) = parseCommand(arguments).unwrap()
    guard let token: RunSessionGuard = .isServerEnabled(orIsEnableCommand: command) else {
        return answer(1, stderr: "\(winMuxAppName) server is disabled and doesn't accept commands. " +
            "You can use 'winmux enable on' to enable the server")
    }
    if let help {
        return refuseHelp
            ? answer(1, stderr: "\(arguments.first ?? "command") help is refused in a URL: it prints a result")
            : answer(0, stdout: help)
    }
    if let err { return answer(parseFailureExitCode(arguments.slice), stderr: err) }
    guard let command else { die("Unreachable") }
    if let refusal = gate?(command) { return answer(1, stderr: refusal) }
    if let result = await setup.answerBeforeStartup(command) {
        return answer(result.exitCode, stdout: result.stdout.joined(separator: "\n"), stderr: result.stderr.joined(separator: "\n"))
    }
    if command.isExec { return answer(1, stderr: "exec-and-forget is prohibited in CLI") }
    do {
        let result = try await runLightSession(event(command.args), token,
                                  shouldSchedulePostRefresh: !command.canSkipPostCommandRefresh) {
            // Only the URL caller passes a gate.
            let env = CmdEnv(windowId: windowId, workspaceName: workspace, isFromURL: gate != nil)
            let result = try await $lensTraceOrigin.withValue(traceOrigin) { try await command.run(env, CmdStdin(stdin)) }
            return answer(result.exitCode, stdout: result.stdout.joined(separator: "\n"), stderr: result.stderr.joined(separator: "\n"))
        }
        return didRun?(result) ?? result
    } catch {
        let result = answer(1, stderr: "Fail to await main thread. \(error.localizedDescription)")
        return didRun?(result) ?? result
    }
}

private func newConnection(_ connection: NWConnection) async { // todo add exit codes
    func answerToClient(exitCode: Int32, stdout: String = "", stderr: String = "") async {
        let ans = ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
        await answerToClient(ans)
    }
    func answerToClient(_ ans: ServerAnswer) async {
        _ = await connection.writeAtomic(ans)
    }
    while true {
        let rawRequest: Data
        switch await connection.readNonAtomic() {
            case .success(let _rawRequest): rawRequest = _rawRequest
            case .failure(let error):
                await answerToClient(exitCode: 1, stderr: "Error: \(error)")
                return
        }
        let request: ClientRequest
        switch ClientRequest.decodeJson(rawRequest) {
            case .success(let _request): request = _request
            case .failure(let error):
                await answerToClient(
                    exitCode: 1,
                    stderr: """
                        Can't parse request '\(String(describing: String(data: rawRequest, encoding: .utf8)).singleQuoted)'.
                        Error: \(error)
                        """,
                )
                continue
        }
        // Handle subscribe before parseCommand (subscribe doesn't have a Command impl)
        if request.args.first == "subscribe" {
            switch parseSubscribeCmdArgs(request.args.slice(1...).orDie()) {
                case .cmd(let subscribeArgs):
                    if let refusal = await FirstRunSetup.shared.refusal {
                        await answerToClient(exitCode: 1, stderr: refusal)
                        return
                    }
                    await handleSubscribeAndWaitTillError(connection, subscribeArgs)
                case .help(let help): await answerToClient(exitCode: 0, stdout: help)
                case .failure(let err): await answerToClient(exitCode: 1, stderr: err)
            }
            continue
        }
        let traceOrigin = LensTraceOrigin(start: request.sentAt ?? LensTimebase.now(), received: LensTimebase.now(), source: "CLI")
        let answer = await executeExternalCommand(request.args, stdin: request.stdin,
                                                  windowId: request.windowId.flatMap { $0 }, workspace: request.workspace.flatMap { $0 },
                                                  traceOrigin: traceOrigin, didRun: { result in
            var answer = result
            if request.windowId == nil || request.workspace == nil {
                answer.stderr += "\n\nWinMux client has sent incomplete JSON request. 'windowId' or/and 'workspace' fields are missing. Please forward WINMUX_WINDOW_ID and WINMUX_WORKSPACE to these JSON fields. If the appropriate environment variables are empty, pass explicit 'null' in the JSON."
            }
            return answer
        })
        await answerToClient(answer)
        continue
    }
}
