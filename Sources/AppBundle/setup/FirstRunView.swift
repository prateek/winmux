import SwiftUI

struct FirstRunView: View {
    static let contentSize = CGSize(width: 560, height: 480)
    @ObservedObject var model: FirstRunSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(model.step == .go ? "Ready to arrange your windows?" : "Welcome to WinMux")
                .font(.title2.bold())
            if model.step == .go {
                Text("WinMux will arrange the windows on this screen into its layout when you start it.")
                Text(firstRunQuitExplanation(restore: config.restoreWindowsOnQuit))
                Spacer()
                HStack {
                    quit
                    Spacer()
                    Button("Start WinMux") { model.go() }.buttonStyle(.borderedProminent)
                }
            } else {
                Text("Give WinMux access below. Your windows stay where they are until you choose to start.")
                    .fixedSize(horizontal: false, vertical: true)
                permission("Accessibility", state: model.permissions.accessibility,
                           reason: "WinMux uses Accessibility to move, resize and focus your windows.", action: model.requestAccessibility)
                permission("Screen Recording", state: model.permissions.screenRecording,
                           reason: "WinMux uses Screen Recording for window pictures and previews.", action: model.requestScreenRecording)
                if model.snapshot.screenRecordingAfterRelaunch {
                    Text("Screen Recording is granted. Relaunch WinMux to finish; your windows will stay in place.")
                } else if model.screenRequested && model.snapshot.accessibility {
                    Text("If you enabled Screen Recording, relaunch WinMux to finish. It will check again before arranging anything.")
                }
                Spacer(minLength: 0)
                HStack {
                    quit
                    Spacer()
                    if model.snapshot.accessibility {
                        Button("Continue without Screen Recording") { model.continueWithoutScreenRecording() }
                        if model.step == .relaunch || model.screenRequested {
                            Button("Relaunch WinMux") { model.relaunch() }.buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            if let error = model.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
        }
        .padding(28)
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }

    private var quit: some View { Button("Quit") { NSApp.terminate(nil) } }

    private func permission(_ name: String, state: String, reason: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text(state == "granted-relaunch-needed" ? "Granted · relaunch to finish" : state.capitalized)
                    .foregroundStyle(state == "missing" ? .secondary : .primary)
            }
            Text(reason)
            Button("Open \(name) Settings", action: action)
        }
    }
}
