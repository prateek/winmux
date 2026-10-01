# Handoff: building the WinMux fork foundation

Planning is finished and the build has started: the deployment target issue has landed on `fork`, on top of upstream `v0.5.6`, and the Nickel config issue is next. This note orients an agent that is about to build. It holds only what the issues, the map and the code don't. Last updated 2026-10-01.

## Start here

- **The work:** the umbrella issue [Fork foundation: Nickel config, Lenses, fixed Columns and the CLI](https://github.com/prateek/winmux/issues/1) and its thirteen child issues on `prateek/winmux`, linked as sub-issues with blocked-by dependencies. Each child is one buildable slice and stands alone. Build in dependency order; the Lens issues and the Column issues are independent of each other once the Nickel config lands.
- **Done:** [Raise the deployment target to macOS 26](https://github.com/prateek/winmux/issues/2), landed as `9aac8be2`. The issue stays open for one check that needs an installed build: the double-sided flip animating.
- **Next:** [Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`](https://github.com/prateek/winmux/issues/3). Everything else waits on it.
- **Then:** [Dogfood releases: cut a signed build from `fork` and install it through the tap](https://github.com/prateek/winmux/issues/14), before the Lens and Column issues, so they can be tested on Prateek's daily machine.
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

- **Commits and pushes.** He asks for each one. Planning used one commit per resolved ticket. The first build issue landed as one squashed commit pushed straight to `fork`, with no pull request, and its worktree was removed afterwards.
- **Running a release.** `script/dogfood-release` publishes a release and pushes to the tap. Ask before each run.
- **Decisions belong to him.** For a discrete choice, ask with a recommended answer first; he usually takes it. Don't settle a product question for him, and don't reopen one he has settled.

## Repo setup

- **The build lands on the `fork` branch.** It is the default branch of `prateek/winmux` and Orca's default worktree base (`fork/fork`). It holds the planning files, `CONTEXT.md` and the ADR. `main` only mirrors upstream `main`; don't build on it. The branch was called `wayfind-fork` until 2026-10-01, and GitHub redirects the old name.
- This checkout is a worktree on the local branch `fork`, tracking `fork/fork` (the remote is also named `fork`). The worktree directory is still named `wayfind-fork`. Its base is upstream `main` at `470eedb`, which is tag `v0.5.6`.
- Start each child issue in its own Orca worktree cut from `fork/fork`, and open its pull request against `fork`.
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
- **Nickel binaries.** Nickel's 1.18 macOS release binaries link libiconv from `/nix/store` and won't run outside Nix. To try one, repoint it with `install_name_tool -change <nix libiconv path> /usr/lib/libiconv.2.dylib` and re-sign with `codesign -f -s -`. `nickel-lang-core` 0.19.0 builds from source, which is what the helper uses.
- **Releases can't be cut yet.** `script/dogfood-release`, `script/setup-signing` and `script/setup-sparkle-keys` were copied unchanged from `codex-columns`. The two setup scripts work as they are: they create the stable self-signed identity that lets Accessibility and Screen Recording grants survive upgrades, and the Sparkle keys. `dogfood-release` calls `make beta-package`, which exists only in `codex-columns`'s `makefile`; this branch's `Makefile` has upstream's Xcode-based `release` target, hardcoded to upstream's identity and URLs. Porting `beta-package` is not a copy: it assembles the app bundle by hand from a SwiftPM build, and upstream has since added bundle resources (the app icon, the asset catalog, the `MASShortcut` resource bundle) that a hand-built bundle would lack. Either port it and add those, or teach `dogfood-release` to drive `make release` with the dogfood identity and the fork's URLs. The new `winmux-nickel` helper has to be signed with the same identity either way. The dogfood release issue (#14) tracks this and takes the second route.

## Suggested skills

- `utils-agent:orca-cli`: create the worktree for each child issue.
- `mattpocock:implement`: build one child issue. It was not installed in the first build session; the issue was built without it.
- `mattpocock:tdd`: test-first at the seams each issue's "Done when" list names.
- `mattpocock:domain-modeling`: when a term needs to change, so `CONTEXT.md` stays current.
- `mattpocock:diagnosing-bugs`: for the two strip questions that need a running build.
- `core:testing-philosophy` and `core:writing-for-humans`: for tests and for replies and pull request text.
