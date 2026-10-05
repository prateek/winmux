# Upgrade check by clicking: do WinMux's grants survive `brew upgrade` and Sparkle?

Run on 2026-10-05 in a fresh Tart guest (`upgrade-71`, macOS 26.2 build 25C56, 1280x720, user `admin`, Homebrew 7.0.8). Commands ran over ssh; every grant was given by clicking in System Settings with `cliclick`, and WinMux was never started as a child of ssh. No TCC row was written by hand. Every `sqlite3` call below is a `select`, kept as a cross-check.

The guest has SIP disabled (`csrutil status`: "disabled"), which is how its image gives ssh its own grants. Gatekeeper was on (`spctl --status`: "assessments enabled"), so the blocks and non-blocks below are Gatekeeper's real answers.

Raw command output is in `raw/`; screenshots are in `captures/`.

## Verdicts

| Claim | Verdict | Evidence |
| --- | --- | --- |
| Grants clicked in System Settings work | **Shown** | Before any click, 0.5.6-dogfood.4 asked macOS for Accessibility and quit (step 3). After the Accessibility toggle, `winmux doctor` said `accessibility: granted`, `screen capture: missing`. After the Screen Recording toggle it said both `granted` (step 4). |
| They survive `brew upgrade` | **Shown** | 0.5.6-dogfood.5, installed by `brew upgrade --cask winmux`, reported both `granted` with no click in either pane, launched two ways: reopened by brew, and double-clicked in Finder (steps 5 and 6). |
| They survive a Sparkle update | **Shown** | 0.5.6-dogfood.6, installed by Sparkle from the app's own Check for Updates, reported both `granted` after Sparkle relaunched it (steps 7 and 8). |

All three builds carry the same designated requirement, which is what TCC matches a grant against:

```
designated => identifier "com.zimengxiong.winmux" and certificate leaf = H"d8f180de23d68c50b2e1a82811edfad87b098288"
```

## What did not go as the plan or the cask's caveats say

1. **`ditto --noqtn` did not remove the quarantine attribute.** After the caveats' step, run exactly as printed, `com.apple.quarantine` was still on the app and the CLI, on both .4 and .5. A plain `ditto --noqtn` into a temp directory keeps it too (`raw/a2-ditto-probe.txt`). I did not strip it another way.
2. **Gatekeeper blocked only the first version.** .4 got the "Not Opened" dialog and needed Open Anyway plus an admin password. .5 (after `brew upgrade`) and .6 (after Sparkle) opened with no dialog and nothing to approve. The caveats say Open Anyway is needed "on the first launch of each version"; that did not happen here.
3. **WinMux cannot be running with Accessibility missing.** It asks for the permission and quits at once (`checkAccessibilityPermissions` in `Sources/AppBundle/util/accessibility.swift`), so step 3's "`winmux doctor` shows both missing" cannot be observed. The control is instead: `doctor` could not connect, macOS showed WinMux's Accessibility prompt, and the pane showed WinMux with its switch off.
4. **`brew upgrade` reopened the app itself.** Homebrew 7 quits the app for the upgrade and then reopens it (`reopen_apps_after_upgrade` in `cask/upgrade.rb`). So .5 was first started by brew through LaunchServices, parent `launchd`, before I touched Finder. I recorded `doctor` on that run, quit it, and launched again from Finder.
5. **A second Screen Recording prompt appeared on .5.** About a minute after the Finder launch of .5, macOS showed "'WinMux' is requesting to bypass the system private window picker and directly access your screen and audio" with Allow and Open System Settings. `doctor` already said `screen capture: granted` and the pane's switch was on while the prompt was up. I clicked Allow. It did not appear on .4 or on .6. I do not know whether the upgrade caused it or whether it was simply the first time WinMux captured a window; .4 ran for about a minute with the grant and never showed it.
6. **`brew trust prateek/tap` was needed** before Homebrew 7 would load the cask ("Refusing to load cask prateek/tap/winmux from untrusted tap").
7. **After the Sparkle update the CLI is still .5**, because Sparkle replaces only the app. `winmux --version` warns that client and server versions do not match; `winmux doctor` still answers.

## How WinMux was launched

| Launch | By | Parent of the WinMux process |
| --- | --- | --- |
| .4, first (blocked) | double-click in a Finder window | `launchd` (pid 1) |
| .4, after Open Anyway | macOS, on the authenticated Open Anyway | `launchd` |
| .4, with Accessibility | double-click in Finder | `launchd` |
| .4, with both grants | macOS, on the pane's Quit & Reopen button | `launchd` |
| .5, first | Homebrew, reopening the app it quit | `launchd` |
| .5, second | double-click in Finder | `launchd` |
| .6 | Sparkle's Install and Relaunch | `launchd` |

`open /Applications/WinMux.app` was never used. The brief asked for the reopen after the Screen Recording grant to come from Finder; I clicked the dialog's own Quit & Reopen instead, which is what the dialog offers a person.

Why `winmux doctor` is the app's answer and not the CLI's: the CLI is a child of ssh and has both grants from the guest image throughout, yet `doctor` failed to connect while the app was not running, and its `screen capture` line changed from `missing` to `granted` only after the click.

---

## A. Install 0.5.6-dogfood.4 and grant by clicking

### Step 1: install the older build

```
$ brew tap prateek/tap
Tapped 3 casks and 2 formulae (19 files, 41.1KB).
$ git -C "$(brew --repo prateek/tap)" checkout f9d6335a2e
HEAD is now at f9d6335 winmux 0.5.6-dogfood.4
$ brew info --cask winmux
Error: Refusing to load cask prateek/tap/winmux from untrusted tap prateek/tap.
Run `brew trust --cask prateek/tap/winmux` or `brew trust prateek/tap` to trust it.
$ brew trust prateek/tap
Trusted tap: prateek/tap
$ HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask winmux
==> Fetching downloads for: prateek/tap/winmux
✔︎ Cask winmux (0.5.6-dogfood.4)
==> Installing Cask winmux
==> Moving App 'WinMux.app' to '/Applications/WinMux.app'
==> Linking Binary 'winmux' to '/opt/homebrew/bin/winmux'
🍺  winmux was successfully installed!
$ brew list --cask --versions winmux
winmux 0.5.6-dogfood.4
$ xattr -l /Applications/WinMux.app
com.apple.provenance:
com.apple.quarantine: 0181;6ac38d89;Homebrew\x20Cask;D428575C-3F38-4A98-B0E2-77CC9332990D
$ codesign -dvv /Applications/WinMux.app
Identifier=com.zimengxiong.winmux
Authority=WinMux Dogfood Signing
TeamIdentifier=not set
$ spctl -a -vv /Applications/WinMux.app
/Applications/WinMux.app: rejected
origin=WinMux Dogfood Signing
```

Full output: `raw/a1-install.txt`.

### Step 2: the ditto step, launch from Finder, Gatekeeper

The caveats' commands, run as printed (`raw/a2-ditto.txt`):

```
+ ditto --noqtn /Applications/WinMux.app /var/folders/.../tmp.GptT4NF4Wv/app
+ rm -rf /Applications/WinMux.app
+ ditto --noqtn /var/folders/.../tmp.GptT4NF4Wv/app /Applications/WinMux.app
+ cli=/opt/homebrew/Caskroom/winmux/0.5.6-dogfood.4/WinMux-0.5.6-dogfood.4/bin/winmux
+ ditto --noqtn .../bin/winmux /var/folders/.../tmp.GptT4NF4Wv/cli
+ rm -f .../bin/winmux
+ ditto --noqtn /var/folders/.../tmp.GptT4NF4Wv/cli .../bin/winmux
+ rm -rf /var/folders/.../tmp.GptT4NF4Wv
xattrs on app:
com.apple.provenance:
com.apple.quarantine: 0181;6ac38d89;Homebrew\x20Cask;D428575C-3F38-4A98-B0E2-77CC9332990D
xattrs on cli (...):
com.apple.provenance:
com.apple.quarantine: 0181;6ac38d89;Homebrew\x20Cask;D428575C-3F38-4A98-B0E2-77CC9332990D
```

The quarantine attribute is unchanged. There were no TCC rows for WinMux at this point (`select ... where client like '%winmux%'` returned nothing from either database).

Then, by clicking:

| Capture | What it shows |
| --- | --- |
| `a2-01-finder-selected.png` | `/Applications` in a Finder window, WinMux selected. |
| `a2-02-gatekeeper-block.png` | After the double-click: **"WinMux" Not Opened. Apple could not verify "WinMux" is free of malware that may harm your Mac or compromise your privacy.** Buttons: Move to Trash, Done. This is a dialog, not a silent stall. |
| `a2-04-privacy-security-top.png` | After Done (no WinMux process left), System Settings > Privacy & Security. |
| `a2-05-privacy-security-open-anyway.png` | Scrolled to Security: **"WinMux" was blocked to protect your Mac.** with an Open Anyway button. |
| `a2-06-open-anyway-confirm.png` | After clicking Open Anyway: **Open "WinMux"?** with Move to Trash, Open Anyway, Done. |
| `a2-07-open-anyway-auth.png` | After clicking Open Anyway again: Privacy & Security asks for an administrator's username and password. |
| `a2-08-auth-typed.png` | Password typed. Return did nothing; clicking OK submitted it. |
| `a2-09-after-open-anyway.png` | WinMux started and macOS shows **"WinMux" would like to control this computer using accessibility features.** The Open Anyway row is gone from the pane. |

### Step 3: `winmux doctor` before any grant

```
$ ps -axo pid,ppid,comm | grep -i winmux
$ winmux doctor
Can't connect to WinMux server. Is WinMux.app running?
The operation couldn’t be completed. (Network.NWError error 2 - No such file or directory)
exit=1
```

WinMux was not running. The system log shows the app asking for Accessibility and terminating itself in the same 5 ms:

```
11:46:59.471 tccd   ... identifier=com.zimengxiong.winmux, pid=1792 ... attempted to call TCCAccessRequest for kTCCServiceAccessibility ...
11:46:59.474 WinMux[1792] [com.apple.AppKit:Application] terminate:
11:46:59.475 WinMux[1792] [com.apple.AppKit:Application] Termination complete. Exiting without sudden termination.
```

So "both missing" could not be read from `doctor`. What was observed instead: no connection, the prompt in `a2-09-after-open-anyway.png`, and the pane with WinMux's switch off in `a4-01-accessibility-pane-before.png`. The check is not void: nothing was granted before the clicks.

### Step 4: grant both by clicking

Accessibility:

| Capture | What it shows |
| --- | --- |
| `a4-01-accessibility-pane-before.png` | Clicked Open System Settings on the prompt. Accessibility pane lists WinMux, switch off. TCC row (read only): `kTCCServiceAccessibility\|com.zimengxiong.winmux\|0`. |
| `a4-02-accessibility-toggle-clicked.png` | Clicked the switch. "Privacy & Security is trying to modify your system settings. Enter your password to allow this." |
| `a4-03-accessibility-enabled.png` | After typing the password and clicking Modify Settings: switch on. TCC row: `kTCCServiceAccessibility\|com.zimengxiong.winmux\|2`. |
| `a4-04-finder-relaunch-selected.png` | Finder window again, WinMux selected. |
| `a4-05-launched-with-accessibility.png` | After the double-click: WinMux is running (sidebar at the left, Finder tiled) and macOS shows **"WinMux" would like to record this computer's screen and audio.** No Gatekeeper dialog this time. |

```
$ ps -axo pid,ppid,comm | grep WinMux.app
 2013     1 /Applications/WinMux.app/Contents/MacOS/WinMux
 2014  2013 /Applications/WinMux.app/Contents/Helpers/winmux-nickel
$ winmux doctor
WinMux doctor — git 9fd6c1ad

Symbolic hotkeys: held=[1, 2] marker=[1, 2]
Permissions:
  accessibility: granted
  screen capture: missing (tab previews / radius estimation degraded)
```

Screen Recording:

| Capture | What it shows |
| --- | --- |
| `a4-06-screen-recording-pane-before.png` | Clicked Open System Settings on the prompt. Screen & System Audio Recording lists WinMux, switch off. |
| `a4-07-screen-recording-toggle-clicked.png` | Clicked the switch. No password this time. **"WinMux" may not be able to record the contents of your screen until it is quit.** Buttons: Quit & Reopen, Later. |
| `a4-08-screen-recording-enabled.png` | Clicked Quit & Reopen. Switch on; WinMux restarted (pid 2013 became 2064). |
| `a4-09-accessibility-pane.png`, `a4-09-screen-recording-pane.png` | Both panes with WinMux on. |

```
$ ps -axo pid,ppid,comm | grep WinMux.app
 2064     1 /Applications/WinMux.app/Contents/MacOS/WinMux
 2065  2064 /Applications/WinMux.app/Contents/Helpers/winmux-nickel
$ winmux --version
winmux CLI client version: 0.5.6-dogfood.4 9fd6c1ad22e8a03fd2739519fbd41b03343919bb
WinMux.app server version: 0.5.6-dogfood.4 9fd6c1ad22e8a03fd2739519fbd41b03343919bb
$ winmux doctor
WinMux doctor — git 9fd6c1ad

Symbolic hotkeys: held=[1, 2] marker=[1, 2]
Permissions:
  accessibility: granted
  screen capture: granted
```

Full output: `raw/a4-doctor-ax-only.txt`, `raw/a4-doctor-both.txt`.

## B. Upgrade by brew to 0.5.6-dogfood.5

### Step 5: `brew upgrade`, ditto, launch from Finder

```
$ git -C "$(brew --repo prateek/tap)" checkout 266ce08fa9
HEAD is now at 266ce08 winmux 0.5.6-dogfood.5
$ HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask winmux
winmux
$ HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask winmux
  (output lost: my filter dropped every line; the result is below)
$ brew list --cask --versions winmux
winmux 0.5.6-dogfood.5
$ defaults read /Applications/WinMux.app/Contents/Info CFBundleShortVersionString
0.5.6-dogfood.5
$ pgrep -lx WinMux
2400 WinMux
$ xattr -l /Applications/WinMux.app
com.apple.provenance:
com.apple.quarantine: 01c1;6ac38f1d;Homebrew\x20Cask;6EEE0EE0-F702-4D43-9D27-C45F7E9A097B
```

`--greedy` was not needed even though the cask declares `auto_updates true`. brew's own upgrade output is not recorded; I filtered it too hard and cannot rerun it.

WinMux .5 was already running when brew returned, with a new quarantine record and no Gatekeeper dialog (`b5-01-right-after-brew-upgrade.png`). Homebrew reopened it:

```
$ ps -axo pid,ppid,lstart,comm | grep WinMux.app
 2400     1 Mon Oct  5 11:50:55 2026     /Applications/WinMux.app/Contents/MacOS/WinMux
11:50:55.388 CoreServicesUIAgent ... LAUNCH: 0x0-0x62062 com.zimengxiong.winmux starting stopped process.
$ winmux doctor        # on the run brew started
WinMux doctor — git b3a6b8b3
Permissions:
  accessibility: granted
  screen capture: granted
```

Then I quit it (`pkill -x WinMux`), ran the ditto step again (quarantine still present afterwards: `01c1;6ac38f1d;...` on the app, `0181;...` on the CLI), and launched from Finder:

| Capture | What it shows |
| --- | --- |
| `b5-02-finder-selected.png` | Finder window, WinMux selected, modified "Today at 11:50 AM". |
| `b5-03-finder-launch-3s.png` | Three seconds after the double-click: WinMux running, Finder tiled. No Gatekeeper dialog. |
| `b5-04-finder-launch-10s.png` | Ten seconds after: the same. No Open Anyway was needed, so none was clicked. |

### Step 6: `winmux doctor` on .5

```
$ ps -axo pid,ppid,comm | grep WinMux.app
 2601     1 /Applications/WinMux.app/Contents/MacOS/WinMux
 2602  2601 /Applications/WinMux.app/Contents/Helpers/winmux-nickel
$ winmux --version
winmux CLI client version: 0.5.6-dogfood.5 b3a6b8b37508378851fb27901217e9e827dd47b5
WinMux.app server version: 0.5.6-dogfood.5 b3a6b8b37508378851fb27901217e9e827dd47b5
$ winmux doctor
WinMux doctor — git b3a6b8b3

Symbolic hotkeys: held=[1, 2] marker=[1, 2]
Permissions:
  accessibility: granted
  screen capture: granted
```

Both grants survived. No switch was clicked between step 4 and here.

| Capture | What it shows |
| --- | --- |
| `b6-00-bypass-picker-prompt.png` | Taken while opening the Accessibility pane, about a minute after launch: **"WinMux" is requesting to bypass the system private window picker and directly access your screen and audio.** Buttons: Allow, Open System Settings. I clicked Allow. |
| `b6-accessibility-pane.png` | WinMux on. |
| `b6-screen-recording-pane.png` | WinMux on. |

Full output: `raw/b6-doctor.txt`, `raw/b6-bypass-prompt.txt`.

## C. Upgrade through Sparkle to 0.5.6-dogfood.6

### Step 7: Check for Updates

The feed is `https://github.com/prateek/winmux/releases/download/dogfood/appcast.xml` (`SUFeedURL` in the app's Info.plist). The item is in WinMux's menu bar menu.

| Capture | What it shows |
| --- | --- |
| `c7-01-menu-open.png` | WinMux's menu bar menu: "WinMux v0.5.6-dogfood.5 b3a6b8b3", ..., Check for Updates…. |
| `c7-02-sparkle-offer.png` | After clicking it: **A new version of WinMux is available! WinMux 0.5.6-dogfood.6 is now available—you have 0.5.6-dogfood.5.** Buttons: Skip This Version, Remind Me Later, Install Update. |
| `c7-03-sparkle-after-install-click.png` | After Install Update: "Updating WinMux, Ready to Install", button Install and Relaunch. |
| `c7-04-after-relaunch-5s.png`, `c7-05-after-relaunch-20s.png` | Five and twenty seconds after Install and Relaunch: WinMux is back, no dialog of any kind. |

Gatekeeper did not block the Sparkle-installed build, so I did nothing. The app Sparkle installed carries no quarantine attribute at all:

```
$ ps -axo pid,ppid,lstart,comm | grep WinMux.app
 2737     1 Mon Oct  5 11:54:07 2026     /Applications/WinMux.app/Contents/MacOS/WinMux
 2739  2737 Mon Oct  5 11:54:07 2026     /Applications/WinMux.app/Contents/Helpers/winmux-nickel
$ defaults read /Applications/WinMux.app/Contents/Info CFBundleShortVersionString
0.5.6-dogfood.6
$ xattr -l /Applications/WinMux.app
$ codesign -d -r- /Applications/WinMux.app
designated => identifier "com.zimengxiong.winmux" and certificate leaf = H"d8f180de23d68c50b2e1a82811edfad87b098288"
```

### Step 8: `winmux doctor` on .6

```
$ winmux --version
Warning: WinMux client/server versions don't match. Possible fixes:
  - Restart WinMux.app (server restart is required after each update)
  - Reinstall and restart WinMux (corrupted installation)
winmux CLI client version: 0.5.6-dogfood.5 b3a6b8b37508378851fb27901217e9e827dd47b5
WinMux.app server version: 0.5.6-dogfood.6 ec821d5a70bb9a26bb06f3f92fe258e397b16a44
$ winmux doctor
WinMux doctor — git ec821d5a

Symbolic hotkeys: held=[1, 2] marker=[1, 2]
Permissions:
  accessibility: granted
  screen capture: granted
$ sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select service,client,auth_value from access where client like '%winmux%'"
kTCCServiceAccessibility|com.zimengxiong.winmux|2
kTCCServiceScreenCapture|com.zimengxiong.winmux|2
```

Both grants survived. `doctor` has no version line of its own beyond the git hash in its header; `ec821d5a` is the commit of 0.5.6-dogfood.6, and `winmux --version` gives the server version in full.

| Capture | What it shows |
| --- | --- |
| `c8-accessibility-pane.png` | WinMux on. |
| `c8-screen-recording-pane.png` | WinMux on. |
| `c8-menu-version.png` | The menu bar menu now reads "WinMux v0.5.6-dogfood.6 ec821d5a". |

Full output: `raw/c7-sparkle.txt`, `raw/c8-doctor.txt`.

## What was not checked

- Whether Screen Recording works in use (a tab preview actually drawn) on .5 and .6. The evidence is `doctor`'s `CGPreflightScreenCaptureAccess` answer and the pane's switch.
- Why Gatekeeper let .5 through with a quarantine attribute still on it. The attribute's flags read `01c1` rather than `0181` by the time I looked, after brew had reopened the app. Open Anyway left no rule that `sudo spctl --list` shows for WinMux, and `spctl -a -vv` still says `rejected` for .6 (`raw/c8-spctl.txt`), so the mechanism is not identified.
- Whether a first launch of .5 from Finder, without brew's reopen coming first, would have been blocked. Brew's reopen always comes first on Homebrew 7 when the app is running at upgrade time.
- A real Mac with SIP enabled. This ran in a VM.
