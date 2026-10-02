# Handoff: building the WinMux fork foundation

Planning is finished and the build is under way: the deployment target, Nickel config and dogfood release issues have landed on `fork`, on top of upstream `v0.5.6`, and `0.5.6-dogfood.1` is published. Config hot reload and the Filter contract are next. This note orients an agent that is about to build. It holds only what the issues, the map and the code don't. Last updated 2026-10-01.

## Start here

- **The work:** the umbrella issue [Fork foundation: Nickel config, Lenses, fixed Columns and the CLI](https://github.com/prateek/winmux/issues/1) and its thirteen child issues on `prateek/winmux`, linked as sub-issues with blocked-by dependencies. Each child is one buildable slice and stands alone. Build in dependency order; the Lens issues and the Column issues are independent of each other once the Nickel config lands.
- **Done:** [Raise the deployment target to macOS 26](https://github.com/prateek/winmux/issues/2), landed as `9aac8be2`. The issue stays open for one check that needs an installed build: the double-sided flip animating.
- **Done, with checks left:** [Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`](https://github.com/prateek/winmux/issues/3). A debug build was run on scratch config and state directories and passed the startup, reload, kill and breaker checks. Two Done-when items are left, both needing someone at the screen: the Settings panes, and sidebar renames surviving a restart.
- **Done, with checks left:** [Dogfood releases: cut a signed build from `fork` and install it through the tap](https://github.com/prateek/winmux/issues/14). `0.5.6-dogfood.1` is published and the cask points at it. Nobody has installed it yet, so the issue's install, upgrade and Sparkle checks are open. The by-eye checks of the two issues above were done in a debug build, with the recording on pull request #15 and the screenshots on #16.
- **Next:** [Config hot reload](https://github.com/prateek/winmux/issues/4) and [Filter contract v1 and `config schema`](https://github.com/prateek/winmux/issues/5), in either order.
- **Glossary:** `CONTEXT.md` at the repo root. Use its terms and avoid the words it lists under _Avoid_.
- **ADR:** `docs/adr/0001-nickel-helper-process.md`.

## How to read an issue

- **Decisions** are settled. Don't reopen them; if the code makes one impossible, stop and tell Prateek.
- **Defaults chosen for you** are starting points no ticket settled. Change one if the code argues for it, and say so in the pull request.
- **Open details** remain in one issue only, the strip. Both can only be answered by running a build.
- When an issue and a ticket disagree, the issue is right. The issues apply later amendments.
- If an issue body needs correcting, edit the draft in `.scratch/winmux-fork/build/` and update the issue from it, so the two stay the same. The drafts use `{{UMBRELLA}}` and `{{CHILDREN}}` placeholders for the issue numbers.
- **How far to trust the issues.** They were drafted by agents from the tickets, reviewed once against the tickets and the code, then patched. The review's three errors and the gaps it found were fixed, and the issues were checked against each other for names, key defaults and import paths. Nobody has re-read all twelve end to end since the patch. Treat a claim about existing code (a file path, a function name, a current default) as probably right, and check it before building on it.

## Where the reasoning lives

Read these only when an issue's reasoning isn't enough.

- `.scratch/winmux-fork/map.md`: every decision in one line, in the order made, with links.
- `.scratch/winmux-fork/issues/`: the 35 decision tickets, each resolved or marked out of scope.
- `.scratch/winmux-fork/research/` and `prototypes/`: evidence and throwaway code. `prototypes/28-nickel-spike/` is the working Swift-to-Nickel spike the helper grows from.
- `.scratch/winmux-fork/build/review.md`: the review of the issues against the tickets and code, with the source for every default.

## Not being built

Tabs, trackpad gestures, Display profiles, the `'grid` Presentation and proactive registration of Accessory apps are deferred. The config keeps a `when.<profile>` slot with one implicit profile, `"default"`.

## Open with Prateek

- **Landing.** `AGENTS.md` at the repo root has the process: a pull request against `fork`, with screenshots or video of anything visible, squash-merged after CI and Prateek's review. The first build issue went straight onto `fork` before this was the rule.
- **Running a release.** Ask before each run; see `AGENTS.md`.
- **Decisions belong to him.** For a discrete choice, ask with a recommended answer first; he usually takes it. Don't settle a product question for him, and don't reopen one he has settled.

## Repo setup

- **The build lands on the `fork` branch.** It is the default branch of `prateek/winmux` and Orca's default worktree base (`fork/fork`). It holds the planning files, `CONTEXT.md` and the ADR. `main` only mirrors upstream `main`; don't build on it. The branch was called `wayfind-fork` until 2026-10-01, and GitHub redirects the old name.
- This checkout is a worktree on the local branch `fork`, tracking `fork/fork` (the remote is also named `fork`). The worktree directory is still named `wayfind-fork`. Its base is upstream `main` at `470eedb`, which is tag `v0.5.6`.
- Remotes: `origin` is upstream `ZimengXiong/winmux` (HTTPS), `fork` is `prateek/winmux` (SSH), `aerospace` is AeroSpace.
- Push over SSH. The `gh` HTTPS token lacks `workflow` scope, and GitHub rejects any push that brings upstream `.github/workflows/*` changes into the fork.
- `prateek/winmux` is public, so keep usernames, home paths, hardware serials and machine names out of issues and committed files.
- Build with `swift build`; the `Makefile` has the packaging targets. `swift build -c release --product winmux` builds the CLI alone.
- Ignored and large: `.build/` (about 390 MB) and `prototypes/28-nickel-spike/target/` (about 1 GB). Both are caches and safe to delete.

## The machine this was planned on

- A Mac mini with one virtual display and no trackpad, not Prateek's laptop. Check `sysctl -n hw.model` and the display list before relying on anything measured here.
- It has upstream WinMux 0.5.6 from the `ZimengXiong/homebrew` cask on the bundled default config, not Prateek's earlier dogfood build. His old config is kept at `~/.config/winmux.dogfood-backup-20260930`.
- The upstream cask ships no CLI, so `/opt/homebrew/bin/winmux` is a copy built from `v0.5.6`. It warns about a client/server version mismatch and works. A build from this repo will replace both.
- Ghost Pepper 2.4.4 is installed from the upstream cask; it was the test app for Accessory windows.
- Neither WinMux nor Ghost Pepper was running when planning ended. Starting WinMux re-tiles the windows on the session, so ask first.

## Things not captured elsewhere

- **Prior art.** The `codex-columns` branch of the fork (153 commits: columnar zones, scenes, rules, an overview) overlaps the Column issues. Prateek chose upstream `main` as the base anyway. Mine it; don't build on it.
- **A possible dotfiles bug, outside this work.** `g95nc`'s `discard` step appears to wipe BetterDisplay's "associate with display" setting; the evidence is in `research/05-*`. Mention it to Prateek; don't fix it here.
- **Research limits.** The first research agents had no web fetch. Apple API facts come from SDK headers, and each findings file flags its own unverified points.
- **Window capture.** `WindowScreenshot` in `Sources/AppBundle/util/` wraps the one-shot ScreenCaptureKit call and caches the `SCWindow` list, refetching only when a window id is missing. The thumbnail issue builds its cache on it. The capture's default size is the window's size in points, so callers pass a pixel size.
- **Deprecation warnings.** The macOS 26 target surfaces about 30 that were left alone: `onChange(of:perform:)`, `CVDisplayLink` and `activateIgnoringOtherApps`. Only code in `Sources/WinMuxApp` fails the Release build on a warning.
- **Working on the Nickel config.**
  - `make helper` builds `winmux-nickel`; `make check` builds it and runs its tests before the Swift ones. A debug build of WinMux and the Swift tests find it in `nickel-helper/target/`, release before debug, or through `WINMUX_NICKEL_HELPER`. Swift tests that need it skip when it is missing.
  - After changing `nickel-helper/nickel/winmux/defaults.ncl`, run `make default-config`. A helper test fails while `resources/default-config.json` is out of date.
  - `nickel-helper/src/records.rs` holds the stand-in Window and Filter context records and the hook argument table. The Filter contract issue and the Column hooks issue replace its contents; nothing else names a field.
  - Supervisor behaviour (timeouts, restarts, the breaker, memory recycling) is tested against a stub helper, a Python script written out by `NickelSupervisorTest`. Extend the stub for new failure cases instead of starting WinMux.
  - The startup fallback (a failed first load leaves WinMux on the built-in defaults with the reason on screen) lives in `initAppBundle` and has no test. `ReadConfigTest` covers the load and its failure message.
  - The Swift parser still takes TOMLKit types; the helper's JSON is converted to a `TOMLTable` in `parseConfig.swift`. Its error text still says TOML things such as "actual type is 'integer'".
  - CI runs only for `main` and pull requests, so nothing runs on a push to `fork`. `make check` now needs cargo, and `ci.yml` installs only swiftly; whether the `macos-26` runner has Rust is unchecked.
- **Driving the UI for screenshots.** `cliclick` and System Events work from the build machine. Raise the Settings window first (`AXRaise` and `set frontmost`), and move it clear of WinMux's own sidebar, which expands under the pointer and takes the clicks. Capture one window with `screencapture -l <window id>`, record with `screencapture -v -V <seconds>`, and upload with `gh attach --repo prateek/winmux <pr> <files>`; without `--repo` it targets upstream.
- **Known flaw in the flip.** A hidden tab keeps its own size, so its snapshot is stretched to the visible window's frame during the rotation.
- **Running a debug build.** `make run` fails: it copies the binary to `.debug/` without `Sparkle.framework`. Run `.build/debug/WinMuxApp` instead. Set `XDG_CONFIG_HOME` and `XDG_STATE_HOME` to scratch directories to keep Prateek's own config out of it; his `~/.config/winmux/winmux.toml` is upstream's and would be converted on first launch.
- **Nickel binaries.** Nickel's 1.18 macOS release binaries link libiconv from `/nix/store` and won't run outside Nix. To try one, repoint it with `install_name_tool -change <nix libiconv path> /usr/lib/libiconv.2.dylib` and re-sign with `codesign -f -s -`. `nickel-lang-core` 0.19.0 builds from source, which is what the helper uses.
- **Releases.** `script/dogfood-release <version>` cuts one from `fork`; `--dry-run` publishes nothing. Builds are signed with the self-signed `WinMux Dogfood Signing` identity, which lives in its own keychain on the build machine and keeps Accessibility and Screen Recording grants across upgrades. The hardened runtime is off for these builds, because a self-signed app cannot load its own `Sparkle.framework` with it on. The build number is the commit count of `fork`. The old `codex-columns` line ended at build 1889, so until `fork` passes that many commits Sparkle will not offer the new line to a machine still on `0.51.0-dogfood.15`; that machine reinstalls the cask once.

## Suggested skills

- `utils-agent:orca-cli`: create the worktree for each child issue.
- `mattpocock:implement`: build one child issue. It was not installed in the first build session; the issue was built without it.
- `mattpocock:tdd`: test-first at the seams each issue's "Done when" list names.
- `mattpocock:domain-modeling`: when a term needs to change, so `CONTEXT.md` stays current.
- `mattpocock:diagnosing-bugs`: for the two strip questions that need a running build.
- `core:testing-philosophy` and `core:writing-for-humans`: for tests and for replies and pull request text.
