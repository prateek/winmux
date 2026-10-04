---
name: vm
description: Give a debug WinMux a desktop of its own, a Tart guest driven over ssh from the host. Use when a live run or a demo has to run WinMux, film it, or build it on CI's toolchain without touching the host's desktop.
---

# VM

A debug WinMux re-tiles whatever desktop it runs on. The **guest** is that desktop: a clone of the **golden image**, with nothing on screen but what you put there. You stay on the host and drive it with `$SKILL/vm`, where `$SKILL` is this directory. The guest holds no credential: git, `gh` and every sign-in stay on the host.

## 1. Bring a guest up

```sh
$SKILL/vm up <name> [WxH]      # default 1280x720
```

The name is yours; use the issue or the demo it is for. `up` clones the golden image, boots it with no window, sets the display, and runs the preflight.

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

`$SKILL/vm ssh <name> '<command>'` runs anything in the guest's desktop session. Start long-lived apps with `nohup … &`.

- **WinMux:** `.build/debug/WinMuxApp` with `XDG_CONFIG_HOME` and `XDG_STATE_HOME` set to directories under `~/demo`, and `WINMUX_NICKEL_HELPER` set to `~/winmux/nickel-helper/target/release/winmux-nickel`. Talk to it with `.build/debug/winmux`; the release CLI cannot reach a debug build.
- **Keys and pointer:** `cliclick`, with a whole chord sequence in one invocation: `cliclick kd:cmd kp:tab w:1000 kp:tab ku:cmd`. A key sent by a second invocation arrives without the held modifier.
- **Recording:** `screencapture -x -v -V <seconds> ~/takes/<take>.mov`.
- **Park the pointer bottom-right.** WinMux's sidebar expands under a pointer at the left edge.
- Use `cliclick`, Swift and the `winmux` CLI for automation. `osascript` waits forever on an Automation prompt here.

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

`vm build-image` builds `winmux-golden` from `ghcr.io/cirruslabs/macos-tahoe-xcode:26.3`, whose Xcode 26.3 carries Swift 6.2.4, the version CI pins. `guest/provision.sh` is the whole recipe: tools, the grants in `guest/grant.sh`, the set's apps, and a bare desktop. Rebuild it when `.swift-version` changes or when the preflight starts failing in fresh clones.

A newer Cirrus image is a trap: Xcode 27 cannot build WinMux, even with the 6.2.4 toolchain installed over it.
