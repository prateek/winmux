---
name: vm
description: Give a debug WinMux a desktop of its own, a Tart guest driven over ssh from the host. Use when a live run or a demo has to run WinMux, film it, or build it on CI's toolchain without touching the host's desktop.
---

# VM

A debug WinMux re-tiles whatever desktop it runs on. The **guest** is that desktop: a clone of the **golden image**, with nothing on screen but what you put there. You stay on the host and drive it with `$SKILL/vm`, where `$SKILL` is this directory, and with nothing else: not `tart exec`, and not Tart's guest agent, which raises a Screen Recording prompt of its own. Do not edit `$SKILL/vm` while a `vm` command is running from it; bash reads a script as it runs. The guest holds no credential: git, `gh` and every sign-in stay on the host.

## 1. Bring a guest up

```sh
$SKILL/vm up <name> [WxH]      # default 1280x720
```

`TART_HOME` must be set, to a directory off the boot disk; `vm` refuses to run without it. The name is yours; use the issue or the demo it is for. `up` clones the golden image, boots it with no window, sets the display, and runs the preflight. `boot` reboots a guest whose ssh port does not answer within about a minute, up to three tries. A guest dies with the shell session that started it, so start it from a shell that outlives the work.

`up` and `build-image` start at 3 cores and 5120 MB. `VM_CPU` (cores) and `VM_MEMORY` (MB) override both. At most two guests may run: every running guest in `tart list` counts, including Tartelet, sized by `tart get`; stopped guests do not. `vm stop <name>` shuts a guest down and keeps it, and `up` on a stopped guest boots it at the size asked for. `up` refuses a guest that is already running: `vm stop` it first to change its display size or cores. `build-image` takes one of the two slots while it runs. Starts are serialized: a second `up` says it is waiting while another guest boots. A start is refused before cloning if it would exceed two guests or 70% of host cores and memory, rounded down (memory to whole GB). On a 10-core, 16-GB host that is 7 cores and 11264 MB. The refusal names the running sizes, request and cap.

Done when the preflight prints `ok` for unlocked, accessibility, screen recording and clean desktop, and Swift 6.2.4. A `FAIL` is a defect in the golden image: stop and report it. A missing golden image is built once with `$SKILL/vm build-image`, which takes about fifteen minutes.

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
- **Keys and pointer:** `cliclick`, with a whole chord sequence in one invocation: `cliclick kd:cmd kp:tab w:1000 kp:tab ku:cmd`. A key sent by a second invocation arrives without the held modifier. Return needs a wait after it, `kp:return w:300`, or presses are lost. `cliclick` cannot type letters or a backtick, and adds 100 ms of its own between actions.
- **Recording:** `screencapture -x -v -V <seconds> ~/takes/<take>.mov`. It will not overwrite a file, so remove an old take first or it passes for the new one, and it records at a variable frame rate. 1920 by 1080 films without stutter at the default size.
- **Long sessions.** After about two hours and several hundred captures a guest has shown "… is requesting to bypass the system private window picker", for `sshd-session` and for `WinMuxApp`. Do not grant it; film a long pass in a fresh clone. **A long guest session raises the private-picker prompt** is the issue.
- **Park the pointer bottom-right.** WinMux's sidebar expands under a pointer at the left edge.
- Use `cliclick`, Swift and the `winmux` CLI for automation. AppleScript Automation is granted only for Notes, Finder and System Events; other targets wait on a permission prompt. To post a test notification without a new grant, use `osascript -e 'tell application "System Events" to display notification "Desk check" with title "WinMux"'`.

Done when the takes are in `~/takes` in the guest.

## 4. Take the results out and delete the guest

```sh
$SKILL/vm pull <name> takes <host-dir>
$SKILL/vm down <name>
```

Done when the takes are on the host and `tart list` shows no guest by that name.

## What a guest cannot show

A second display, real sleep, wake and unlock, fast user switching, and a signed release build. Those checks stay Prateek's.

## The golden image

`vm build-image` builds `winmux-golden` from `ghcr.io/cirruslabs/macos-tahoe-xcode:26.3`, whose Xcode 26.3 carries Swift 6.2.4, the version CI pins. `guest/provision.sh` is the entry point: tools, the grants in `guest/grant.sh`, the set's apps, and `guest/first-run.sh` for a quiet desktop. The image initializes local Notes without welcome or iCloud alerts, disables Ghostty updates and window restoration, registers and dismisses its Dock tile notice by the accessible Close label, clears saved desktop widgets, disables wallpaper reveal, and persists Do Not Disturb through 2099. No credential or account is added. Zed trust is set by the desk's copied settings file. Rebuild it when `.swift-version` changes or when the preflight starts failing in fresh clones.

A newer Cirrus image is a trap: Xcode 27 cannot build WinMux, even with the 6.2.4 toolchain installed over it.

Build replacements alongside the current image with `VM_GOLDEN=winmux-golden-next vm build-image`, and use the same override for fresh proof clones. Keep the old image until the preflight, guest `make check` and both desk sets pass. Then rename the old image to `winmux-golden-prev` and the passing replacement to `winmux-golden`; the lander removes the previous image. An existing stopped guest can boot without a golden image; cloning needs one.
