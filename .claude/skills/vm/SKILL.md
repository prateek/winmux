---
name: vm
description: Give a debug WinMux a desktop of its own, a Tart guest driven over ssh from the host. Use when a live run or a demo has to run WinMux, film it, or build it on CI's toolchain without touching the host's desktop.
---

# VM

A debug WinMux re-tiles whatever desktop it runs on. The **guest** is that desktop: a clone of the **golden image**, with nothing on screen but what you put there. You stay on the host and drive it with `$SKILL/vm`, where `$SKILL` is this directory, and with nothing else of your own: no `tart exec` and no screenshot through Tart's guest agent, which raises a Screen Recording prompt of its own. Do not edit `$SKILL/vm` while a `vm` command is running from it; bash reads a script as it runs. The guest holds no credential: git, `gh` and every sign-in stay on the host.

## 1. Bring a guest up

```sh
$SKILL/vm up <name> [WxH]      # default 1280x720
```

`TART_HOME` must be set, to a directory off the boot disk; `vm` refuses to run without it. The name is yours; use the issue or the demo it is for. `up` clones the golden image, boots it with no window, sets the display, and runs the preflight. `boot` waits for ssh alone, never for Tart's guest agent, and reboots a guest whose ssh port does not answer within about four minutes, up to three tries. A guest dies with the shell session that started it, so start it from a shell that outlives the work.

`up` and `build-image` start at 3 cores and 5120 MB. `VM_CPU` (cores) and `VM_MEMORY` (MB) override both. At most two guests may run: every running guest in `tart list` counts, including Tartelet, sized by `tart get`; stopped guests do not. `vm stop <name>` shuts a guest down and keeps it, and `up` on a stopped guest boots it at the size asked for. `up` refuses a guest that is already running: `vm stop` it first to change its display size or cores. `build-image` takes one of the two slots while it runs. Starts are serialized: a second `up` says it is waiting while another guest boots. A start is refused before cloning if it would exceed two guests or 70% of host cores and memory, rounded down (memory to whole GB). On a 10-core, 16-GB host that is 7 cores and 11264 MB. The refusal names the running sizes, request and cap.

Done when the preflight prints `ok` for unlocked, accessibility, screen recording, approvals and clean desktop, and Swift 6.4. A `FAIL` is a defect in the golden image: stop and report it. The one exception is a `loginwindow` stranger on the clean-desktop line just after boot, which clears within seconds: run `$SKILL/vm preflight <name>` again before calling it a defect. A missing golden image is built once with `$SKILL/vm build-image`, which takes about fifteen minutes.

## 2. Put the source in and build it

```sh
$SKILL/vm sync <name> <worktree>   # copies the worktree to ~/winmux in the guest
$SKILL/vm build <name>             # make generate, make helper, then swift build
$SKILL/vm check <name>             # quits a running WinMuxApp, then make check on the Swift CI pins
```

Edit on the host, then `sync` and `build` again; the build is incremental.
`sync` records the worktree's commit and `build` regenerates, so `winmux doctor` in the guest names the synced commit, with `-dirty` for uncommitted changes on the host or edits made in the guest since.

Done when `~/winmux/.build/debug/WinMuxApp` and `~/winmux/.build/debug/winmux` exist in the guest.

## 3. Run and film

`$SKILL/vm ssh <name> '<command>'` runs anything in the guest's desktop session. Start long-lived apps with `nohup … &`. `/opt/homebrew/bin` is not on the ssh `PATH`: `cliclick` and `brew` need `export PATH=/opt/homebrew/bin:$PATH` inside the command.

- **WinMux:** `.build/debug/WinMuxApp` with `XDG_CONFIG_HOME` and `XDG_STATE_HOME` set to directories under `~/demo`, and `WINMUX_NICKEL_HELPER` set to `~/winmux/nickel-helper/target/release/winmux-nickel`. Talk to it with `.build/debug/winmux`; the release CLI cannot reach a debug build.
- **Keys and pointer:** `cliclick`, with a whole chord sequence in one invocation: `cliclick kd:cmd kp:tab w:1000 kp:tab ku:cmd`. A key sent by a second invocation arrives without the held modifier. Return needs a wait after it, `kp:return w:300`, or presses are lost. `kp:` presses named keys only, so it has no letter and no backtick; use the `demo` skill's `keys` for those. `cliclick` adds 100 ms of its own between actions.
- **System shortcuts.** macOS matches Control-arrow (Mission Control, App Exposé, Spaces) only with the Function flag set, which `cliclick` and `keys` both drop, so their Control-Up opens nothing. Send those with `.scratch/winmux-fork/proofs/sidebar-shortcuts/arrow-chord.swift` (`arrow-chord up`), compiled in the guest. `cliclick`'s Cmd-Space does not open Spotlight either; `keys` does. Spotlight's first use shows an information screen; dismiss it before a measured run.
- **Recording:** `screencapture -x -v -V <seconds> ~/takes/<take>.mov`. It will not overwrite a file, so remove an old take first or it passes for the new one, and it records at a variable frame rate. 1920 by 1080 films without stutter at the default size.
- **Long sessions.** The image supplies replayd’s private-picker approval for the observed ssh-wrapper identity, shared by ssh-launched WinMux and the recorders. `up` runs `bash ~/vm/renew-approvals.sh` before preflight: replayd updates the last-use date on capture, and an idle approval lapses after 30 days even with a future privacy-hint date. `preflight` checks both dates and names the renewal command when they lapse. If the private-picker prompt still appears, stop the run, leave it unanswered and save a screenshot over ssh, the approvals plist and replayd/tccd logs as an image defect. A missing renewal script needs a rebuilt golden image.
- **Park the pointer near the bottom-right, not in the corner.** WinMux's sidebar expands under a pointer at the left edge, and the exact bottom-right corner is macOS's Quick Note hot corner, which draws a white page fold. `cliclick m:1240,714`, in the margin below the windows, suits a 1280 by 720 guest; `1250,690` lands on Zed's status bar on the standing desk and raises a tooltip.
- **A Local Network prompt for Python** can appear after a desk script serves its docs page (`stage-desk.sh` or `stage-rich.sh`). It is not a prompt for WinMux or for the tool driving it, staging still finishes with every window, and synthetic clicks do not reach it. Close it without answering with `vm ssh <guest> 'killall UserNotificationCenter'`, and check for it with a screenshot and `ps -axo command | grep '[U]serNotificationCenter'` after staging and before each measured run. A run during which it appears is discarded. It is [#183](https://github.com/prateek/winmux/issues/183).
- **Reading text back from a field.** Synthetic Cmd-A and Cmd-C do not reliably refresh the clipboard, so `pbpaste` after them can return an earlier copy. Type into a note in Notes and read it with `osascript -e 'tell application "Notes" to get body of note 1'`, which the image's Automation grant allows; TextEdit has no grant, and scripting it raises a prompt.
- Use `cliclick`, Swift and the `winmux` CLI for automation. AppleScript Automation is granted for Notes, Finder, System Events, Calendar and Music. Calendar data access is granted to the observed sshd-keygen-wrapper requester in the user TCC database; other targets wait on a permission prompt. To post a test notification without a new grant, use `osascript -e 'tell application "System Events" to display notification "Desk check" with title "WinMux"'`.

Done when the takes are in `~/takes` in the guest.

## First-run setup: an independent bundle with no grants

For an assigned relay guest, keep its disk and leave it running when finished. Do not
resize, reboot, replace the image, or grant permissions to a recorder. Set
`TART_HOME` in each host shell before using `vm`.

After `vm sync` and `vm build`, run these through `vm ssh` (all paths below are
guest paths):

```sh
bash "$HOME/winmux/.claude/skills/vm/setup-bundle.sh"
app="$HOME/demo/WinMux Setup.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
tccutil reset Accessibility com.zimengxiong.winmux.debug
tccutil reset ScreenCapture com.zimengxiong.winmux.debug
mkdir -p "$HOME/demo/setup-config/winmux" "$HOME/demo/setup-state"
cp "$HOME/desk/winmux.ncl" "$HOME/demo/setup-config/winmux/winmux.ncl"
open --env XDG_CONFIG_HOME="$HOME/demo/setup-config" \
  --env XDG_STATE_HOME="$HOME/demo/setup-state" \
  --env WINMUX_NICKEL_HELPER="$HOME/winmux/nickel-helper/target/release/winmux-nickel" "$app"
```

Stage the standing desk first with `desk/stage-desk.sh`. The wrapper copies the
debug executable and Sparkle framework, declares the debug bundle identifier and
ad-hoc signs the bundle. LaunchServices gives it its own responsible-process
identity; running the executable over ssh inherits the image's grants instead.
The assigned Tahoe guest supports `open --env`. On an older guest, use
`launchctl setenv` for these variables before `open`, and `launchctl unsetenv`
afterwards; never change the host environment for this purpose.

Film the welcome window, each Settings button and its correct pane. Answer the
native Accessibility alert's **Open System Settings** button too; an alert can
sit behind Settings. Verify the pane heading is **Accessibility**, then toggle
WinMux's entry and answer the native password sheet with the guest's local
admin password (`admin` in the recipe). Close Settings and show the live state.
Repeat for Screen Recording, verifying **Screen & System Audio Recording** and
the disabled WinMux entry before clicking its toggle. Both buttons register the
bundle natively; the final cold-bundle run needed no TCC database fixture.
Choosing **Later** on macOS's
Quit & Reopen sheet lets the film show **Granted · relaunch to finish** and
WinMux's own **Relaunch WinMux** button. That button preserves the environment
and returns at **Start WinMux**. Also test macOS's Quit & Reopen: leave Settings
running until the replacement process appears. Wait at least 20 seconds before
reading `config status`; verify the original config path and `waiting-for-go`.
Do not fill a failed reopen with `open`. Only after proving the new process is
running may `open -a` bring its existing setup window forward. Close Settings
before Start so it does not become part of the tiled desk.

macOS drops custom launch options on its own reopen. `WinMuxEntry` restores a
pending launch before SwiftUI and config loading by re-executing with the
original arguments and environment. The resume record is volatile shared
memory; the pending marker and decline still use only `setup.json`. Start
clears the resume record. Deleting the pending state file invalidates it for a
second take. An explicit differing XDG launch keeps its own config and still
honours the pending Go gate.
Film **Continue without Screen Recording** as a separate supported path: it
leads to the same go step and remembers the choice on later launches.

The first-run proof tools under `.scratch/winmux-fork/proofs/first-run/` read the
four staged windows with `CGWindowListCopyWindowInfo`, independently of WinMux.
Compile `frames.swift` and `ui.swift` in the guest. Sample frames before launch,
after at least 20 seconds at each setup step, and after Start. Do not poll
read-only WinMux commands during startup discovery; wait, then read once.
Save `config status` and a refused command at each step. `socket-routing.py`
also checks server-side help, parse failures and refused subscriptions.

```sh
swiftc "$HOME/winmux/.scratch/winmux-fork/proofs/first-run/frames.swift" -o "$HOME/demo/frames"
swiftc "$HOME/winmux/.scratch/winmux-fork/proofs/first-run/ui.swift" -o "$HOME/demo/ui"
mkdir -p "$HOME/takes/first-run"
"$HOME/demo/frames" > "$HOME/takes/first-run/before.frames.json"
screencapture -x "$HOME/takes/first-run/before.png"
```

Push the proof directory with `vm push <assigned-guest>
.scratch/winmux-fork/proofs/first-run first-run` before running its shell tools.
Use `screencapture -x -v -V <seconds> <movie>` to record, keep the recorder's PID
and wait for it to finish before pulling the directory. Read a frame from the
movie as well as a still screenshot to verify it actually captured the flow.

Old native permission alerts can outlive a quit during repeated takes. Inspect
and dismiss WinMux's own stale alerts before resetting; each can open a
different pane, so verify the heading again before touching a toggle. Quit can
end the app before AX replies: verify process disappearance even if AXPress
reports `cannotComplete`. `seed-screen-denial.sh` is retained only as a historical
diagnostic that writes a denial; it is not part of the verified filming flow.

WinMux's own Accessibility, Screen Recording and password prompts are the
subject of this flow. A private-window-picker bypass prompt for the recorder
is an image defect: do not grant it; capture it and stop that recording. The
same prompt for WinMux after its first picture must also remain ungranted;
capture it and continue checking tiling without pictures. Dismiss unrelated
screens and name them in the report; do not click the wallpaper.

For another take, quit WinMux first, reset both permissions with the two
`tccutil` commands above, and remove only
`$HOME/demo/setup-state/winmux/setup.json`. Quit the desk apps and Settings at
the end, repeat those resets, copy out the captures, and report `tart list`.
Never delete an assigned relay guest.

## 4. Take the results out and delete the guest

```sh
$SKILL/vm pull <name> takes <host-dir>
$SKILL/vm down <name>
```

Done when the takes are on the host and `tart list` shows no guest by that name.

## What a guest cannot show

A second display, real sleep, wake and unlock, fast user switching, and a release build as installed: downloaded, quarantined and updated by Sparkle. Those checks stay Prateek's.

The unbundled debug build never becomes the frontmost app: `NSApp.activate` and a click on its panels leave the app that was in front there, so a key the system sends to the active app never reaches it. A claim about what WinMux does once it is active needs the release build below, or is Prateek's.

A release build itself does run in a guest. The guest's compiler is not the release's, so build on the host with `script/dogfood-release --next --dry-run`, `vm push` `WinMux.app` from the `.xcarchive` under `.release/` and `bin/winmux` from `.release/package/`, and start `WinMux.app/Contents/MacOS/WinMux` over ssh with `nohup` and the two scratch `XDG` directories. It has the image's grants and answers its own CLI. Use it for anything the optimiser could change; a debug build did not show the strip crashing on Cmd-Tab.

## The golden image

`vm build-image` builds `winmux-golden` from `ghcr.io/cirruslabs/macos-tahoe-xcode:27`, whose Xcode 27.0 carries Swift 6.4, the version CI pins in `.swift-version` and the build machine's Xcode 27.0 uses for the release. `guest/provision.sh` is the entry point: tools, the TCC grants in `guest/grant.sh`, replayd’s separate ScreenCaptureApprovals file and boot renewal, the set's apps, and `guest/first-run.sh` for a quiet desktop. The approval uses the observed responsible binary path `/usr/libexec/sshd-keygen-wrapper`; display names such as `com.apple.sshd-session` are not extra approval keys. Renewal stops replayd before atomically writing the dates so its cached record cannot overwrite them. The `approvals` preflight line checks the same date rules with the recipe’s Python helper. The image initializes local Calendar and Music without an account, grants their Automation and Calendar data access, sets Calendar to a full-day range, and hides the Apple Music sidebar. Music’s cold-library welcome still appears after its stored first-run settings; the Music prop uses its album and track text in Zed. It initializes local Notes without welcome or iCloud alerts, disables Ghostty updates, window restoration and close confirmations, registers and dismisses its Dock tile notice by the accessible Close label, clears saved desktop widgets, disables wallpaper reveal, and persists Do Not Disturb through 2099. No credential or account is added. Rebuild it when `.swift-version` changes or when the preflight starts failing in fresh clones.

The image installs `guest/zed-settings.json` before Zed's first launch: all worktrees, standalone files included, are trusted, and the title-bar onboarding banner and updates are off. Both desks copy the same file from the synced `~/winmux` on each stage, so an edit to it reaches a guest without a rebuild. The image launches Zed once, waits for its database, stops it, and `guest/quiet-zed.py` marks the Delta announcement dismissed and clears a pending update notification. Zed 1.24.2 has no general promotion switch, and Delta only follows an update Zed installed itself, which the settings forbid; the seed is insurance. The helper fails when Zed's database or its `kv_store` table is missing, but not when a later Zed renames either key: a new promotion after a rebuild needs its own key here.

The base image, `.swift-version` and the build machine's Xcode move together. `Package.resolved` depends on the Swift version, because `swift-clocks` ships a manifest per Swift version: a Swift that differs from the pin re-resolves it, `make check` fails on the change, and the release refuses a tree that changed while it built.

Build replacements alongside the current image with `VM_GOLDEN=<replacement> vm build-image`, and use the same override for fresh proof clones. Keep the old image until the preflight, guest `make check` and both desk sets pass. The driver swaps the passing replacement into `winmux-golden` at landing and removes the previous image; builders leave both images named as built. An existing stopped guest can boot without a golden image; cloning needs one.
