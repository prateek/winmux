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

`TART_HOME` must be set, to a directory off the boot disk; `vm` refuses to run without it. The name is yours; use the issue or the demo it is for. `up` clones the golden image, boots it with no window, sets the display, and runs the preflight. `boot` reboots a guest whose ssh port does not answer within about a minute, up to three tries. A guest dies with the shell session that started it, so start it from a shell that outlives the work.

`up` and `build-image` start at 3 cores and 5120 MB. `VM_CPU` (cores) and `VM_MEMORY` (MB) override both. At most two guests may run: every running guest in `tart list` counts, including Tartelet, sized by `tart get`; stopped guests do not. `vm stop <name>` shuts a guest down and keeps it, and `up` on a stopped guest boots it at the size asked for. `up` refuses a guest that is already running: `vm stop` it first to change its display size or cores. `build-image` takes one of the two slots while it runs. Starts are serialized: a second `up` says it is waiting while another guest boots. A start is refused before cloning if it would exceed two guests or 70% of host cores and memory, rounded down (memory to whole GB). On a 10-core, 16-GB host that is 7 cores and 11264 MB. The refusal names the running sizes, request and cap.

Done when the preflight prints `ok` for unlocked, accessibility, screen recording, approvals and clean desktop, and Swift 6.2.4. A `FAIL` is a defect in the golden image: stop and report it. A missing golden image is built once with `$SKILL/vm build-image`, which takes about fifteen minutes.

## 2. Put the source in and build it

```sh
$SKILL/vm sync <name> <worktree>   # copies the worktree to ~/winmux in the guest
$SKILL/vm build <name>             # make helper, then swift build
$SKILL/vm check <name>             # make check, on the Swift version CI pins
```

Edit on the host, then `sync` and `build` again; the build is incremental.

Done when `~/winmux/.build/debug/WinMuxApp` and `~/winmux/.build/debug/winmux` exist in the guest.

## 3. Run and film

`$SKILL/vm ssh <name> '<command>'` runs anything in the guest's desktop session. Start long-lived apps with `nohup … &`. `/opt/homebrew/bin` is not on the ssh `PATH`: `cliclick` and `brew` need `export PATH=/opt/homebrew/bin:$PATH` inside the command.

- **WinMux:** `.build/debug/WinMuxApp` with `XDG_CONFIG_HOME` and `XDG_STATE_HOME` set to directories under `~/demo`, and `WINMUX_NICKEL_HELPER` set to `~/winmux/nickel-helper/target/release/winmux-nickel`. Talk to it with `.build/debug/winmux`; the release CLI cannot reach a debug build.
- **Keys and pointer:** `cliclick`, with a whole chord sequence in one invocation: `cliclick kd:cmd kp:tab w:1000 kp:tab ku:cmd`. A key sent by a second invocation arrives without the held modifier. Return needs a wait after it, `kp:return w:300`, or presses are lost. `kp:` presses named keys only, so it has no letter and no backtick; use the `demo` skill's `keys` for those. `cliclick` adds 100 ms of its own between actions.
- **Recording:** `screencapture -x -v -V <seconds> ~/takes/<take>.mov`. It will not overwrite a file, so remove an old take first or it passes for the new one, and it records at a variable frame rate. 1920 by 1080 films without stutter at the default size.
- **Long sessions.** The image supplies replayd’s private-picker approval for the observed ssh-wrapper identity, shared by ssh-launched WinMux and the recorders. `up` runs `bash ~/vm/renew-approvals.sh` before preflight: replayd updates the last-use date on capture, and an idle approval lapses after 30 days even with a future privacy-hint date. `preflight` checks both dates and names the renewal command when they lapse. If the private-picker prompt still appears, stop the run, leave it unanswered and save a screenshot over ssh, the approvals plist and replayd/tccd logs as an image defect. A missing renewal script needs a rebuilt golden image.
- **Park the pointer near the bottom-right, not in the corner.** WinMux's sidebar expands under a pointer at the left edge, and the exact bottom-right corner is macOS's Quick Note hot corner, which draws a white page fold. `cliclick m:1240,714`, in the margin below the windows, suits a 1280 by 720 guest; `1250,690` lands on Zed's status bar on the standing desk and raises a tooltip.
- Use `cliclick`, Swift and the `winmux` CLI for automation. AppleScript Automation is granted for Notes, Finder, System Events, Calendar and Music. Calendar data access is granted to the observed sshd-keygen-wrapper requester in the user TCC database; other targets wait on a permission prompt. To post a test notification without a new grant, use `osascript -e 'tell application "System Events" to display notification "Desk check" with title "WinMux"'`.

Done when the takes are in `~/takes` in the guest.

## 4. Take the results out and delete the guest

```sh
$SKILL/vm pull <name> takes <host-dir>
$SKILL/vm down <name>
```

Done when the takes are on the host and `tart list` shows no guest by that name.

## What a guest cannot show

A second display, real sleep, wake and unlock, fast user switching, and a release build as installed: downloaded, quarantined and updated by Sparkle. Those checks stay Prateek's.

A release build itself does run in a guest. The guest's compiler is not the release's, so build on the host with `script/dogfood-release --next --dry-run`, `vm push` `WinMux.app` from the `.xcarchive` under `.release/` and `bin/winmux` from `.release/package/`, and start `WinMux.app/Contents/MacOS/WinMux` over ssh with `nohup` and the two scratch `XDG` directories. It has the image's grants and answers its own CLI. Use it for anything the optimiser could change; a debug build did not show the strip crashing on Cmd-Tab.

## The golden image

`vm build-image` builds `winmux-golden` from `ghcr.io/cirruslabs/macos-tahoe-xcode:26.3`, whose Xcode 26.3 carries Swift 6.2.4, the version CI pins. `guest/provision.sh` is the entry point: tools, the TCC grants in `guest/grant.sh`, replayd’s separate ScreenCaptureApprovals file and boot renewal, the set's apps, and `guest/first-run.sh` for a quiet desktop. The approval uses the observed responsible binary path `/usr/libexec/sshd-keygen-wrapper`; display names such as `com.apple.sshd-session` are not extra approval keys. Renewal stops replayd before atomically writing the dates so its cached record cannot overwrite them. The `approvals` preflight line checks the same date rules with the recipe’s Python helper. The image initializes local Calendar and Music without an account, grants their Automation and Calendar data access, sets Calendar to a full-day range, and hides the Apple Music sidebar. Music’s cold-library welcome still appears after its stored first-run settings; the Music prop uses its album and track text in Zed. It initializes local Notes without welcome or iCloud alerts, disables Ghostty updates and window restoration, registers and dismisses its Dock tile notice by the accessible Close label, clears saved desktop widgets, disables wallpaper reveal, and persists Do Not Disturb through 2099. No credential or account is added. Zed trust is set by the desk's copied settings file. Rebuild it when `.swift-version` changes or when the preflight starts failing in fresh clones.

A newer Cirrus image is a trap: Xcode 27 cannot build WinMux, even with the 6.2.4 toolchain installed over it.

Build replacements alongside the current image with `VM_GOLDEN=<replacement> vm build-image`, and use the same override for fresh proof clones. Keep the old image until the preflight, guest `make check` and both desk sets pass. The driver swaps the passing replacement into `winmux-golden` at landing and removes the previous image; builders leave both images named as built. An existing stopped guest can boot without a golden image; cloning needs one.
