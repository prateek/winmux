import AppKit
import Common

@MainActor func urlCommandRefusal(_ command: any Command) -> String? {
    guard let command = unwrappedLensRun(command) else { return "lens run is refused in a URL: invalid command" }
    guard let trigger = command as? TriggerBindingCommand else {
        return urlCommandRefusal(kind: command.info.kind, args: command.args)
    }
    // Checked here too so a refused binding is answered before the first-run checks and the session,
    // like every other refusal. A missing binding runs and reports itself.
    return urlBindingRefusal(trigger.args.binding.val, trigger.bindingCommands ?? [])
}

private func unwrappedLensRun(_ command: any Command) -> (any Command)? {
    var command = command
    while let lens = command as? LensCommand, lens.args.verb == "run" {
        guard case .cmd(let inner) = parseCommand(lens.args.operands) else { return nil }
        command = inner
    }
    return command
}

/// A binding's commands run past the runner's gate, so a URL may trigger only a binding whose every
/// command a URL could run directly. TriggerBindingCommand.run checks again with the commands it runs.
func urlBindingRefusal(_ binding: String, _ commands: [any Command]) -> String? {
    for inner in commands {
        let reason = unwrappedLensRun(inner) is TriggerBindingCommand
            ? "its binding runs another binding"
            : urlCommandRefusal(kind: inner.info.kind, args: inner.args).map { refusal in
                let parts = refusal.components(separatedBy: " is refused in a URL: ")
                return "its binding runs \(parts[0]) (\(parts.last ?? refusal))"
            }
        if let reason { return "trigger-binding \(binding) is refused in a URL: \(reason)" }
    }
    return nil
}

@MainActor
struct URLCommandService {
    var enabled: () -> Bool
    var waitForStartup: () async -> Void
    var execute: ([String]) async -> ServerAnswer

    func handle(_ text: String) async -> ServerAnswer {
        func refuse(_ reason: String) -> ServerAnswer {
            ServerAnswer(exitCode: 1, stderr: reason, serverVersionAndHash: "")
        }
        await waitForStartup()
        guard enabled() else { return refuse("url-scheme is false; URL commands are disabled") }
        guard let url = URL(string: text) else { return refuse("Malformed URL") }
        let arguments: [String]
        switch parseCommandURL(url) {
            case .success(let words): arguments = words
            case .failure(let reason): return refuse(reason.description)
        }
        if arguments.first == "subscribe" {
            switch parseSubscribeCmdArgs(arguments.slice(1...).orDie()) {
                case .help: return refuse("subscribe help is refused in a URL: it prints a result")
                case .failure(let reason): return refuse(reason)
                case .cmd: return refuse(urlCommandRefusal(kind: .subscribe, args: nil)!)
            }
        }
        return await execute(arguments)
    }
}

@MainActor
final class URLStartupSignal {
    enum State { case starting, waitingForPerson, ready }
    private(set) var state: State = .starting
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func set(_ state: State) {
        self.state = state
        if state != .starting {
            let pending = waiters
            waiters.removeAll()
            for waiter in pending { waiter.resume() }
        }
    }

    func wait() async {
        guard state == .starting else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

@MainActor
final class URLCommandQueue {
    private let continuation: AsyncStream<String>.Continuation
    private let consumer: Task<Void, Never>

    init(handle: @escaping (String) async -> Void) {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.continuation = continuation
        consumer = Task {
            for await url in stream { await handle(url) }
        }
    }

    func enqueue(_ url: String) { continuation.yield(url) }
    func finish() async { continuation.finish(); await consumer.value }
}

@MainActor let urlStartupSignal = URLStartupSignal()

@MainActor
final class URLAppleEventHandler: NSObject {
    static let shared = URLAppleEventHandler()
    private let service: URLCommandService

    init(service: URLCommandService? = nil) {
        self.service = service ?? URLCommandService(enabled: { config.urlScheme }, waitForStartup: { await urlStartupSignal.wait() }, execute: { arguments in
            let now = LensTimebase.now()
            return await executeExternalCommand(arguments, stdin: "", windowId: nil, workspace: nil,
                traceOrigin: LensTraceOrigin(start: now, received: now, source: "URL"), event: { .url($0) }, gate: urlCommandRefusal, refuseHelp: true)
        })
        super.init()
    }

    private lazy var queue = URLCommandQueue { [self] text in
        let result = await service.handle(text)
        if result.exitCode == 0 {
            urlLog.info("URL \(text, privacy: .public) finished with exit 0: \(result.stdout, privacy: .public)")
        } else {
            urlLog.error("URL \(text, privacy: .public) refused or failed with exit \(result.exitCode). stderr: \(result.stderr, privacy: .public)\(result.stdout.isEmpty ? "" : " stdout: \(result.stdout)", privacy: .public)")
        }
    }

    func register() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(receive(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func receive(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            urlLog.error("URL event has no URL string")
            return
        }
        urlLog.info("Received URL \(text, privacy: .public)")
        queue.enqueue(text)
    }
}
