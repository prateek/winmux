import AppKit

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid) else { fatalError("expected running pid") }
print("terminate accepted: \(app.terminate())")
