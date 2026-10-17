# Three screens a fresh guest still shows

Part of {{UMBRELLA}}.

## What to build

A builder working in a fresh clone of the golden image met three screens that are not WinMux's and that the image recipe does not settle. Each had to be dismissed by hand before a live run could go on.

- **Zed asks whether to trust a scratch folder** when a file outside the desk's trusted folders is opened.
- **Zed shows a promotion**, "Introducing Delta", on a first launch. It went away after Zed restarted.
- **Ghostty asks for confirmation before quitting** a window with a running shell.

## Decisions

- **A fresh clone shows none of the three.** The image recipe settles them, as it settles Notes, widgets and Ghostty's update prompt.

## Not in this issue

- A permission prompt for WinMux or for the tool driving it. That is **A long guest session raises the private-picker prompt**.

## Depends on

Nothing.

## Defaults chosen for you

- **Zed**: trust for the guest's home folder, or whatever setting covers a file opened from anywhere under it, and the setting that turns off first-run promotions if there is one. If there is none, say so and leave it.
- **Ghostty**: `confirm-close-surface = false` in the image's config.

## Done when

- [x] In a fresh clone of a rebuilt image, opening a new text file in Zed from a scratch directory shows no trust screen and no promotion.
- [x] Quitting Ghostty with a shell running asks nothing.
- [x] The preflight still passes, and both desks stage.

## Build notes

The image installs `guest/zed-settings.json` before Zed starts. Both desks restore that same file from `~/vm/zed-settings.json`; if it is absent they fail naming `vm build-image`. The settings retain all their previous keys, including `session.trust_all_worktrees`, disabled title-bar onboarding banners and disabled updates. Zed's documented broad trust includes standalone files, so no extra trusted-path state is needed.

Zed 1.24.2 has no general release-announcement setting. The recipe opens its installed app bundle once to initialize its database, stops it, then seeds `delta_announcement_dismissed` and clears the pending update-notification key through `guest/quiet-zed.py`. This is Zed's own dismissal state, not an invented settings key. Updates stay off; a future promotion with a different gate may need a recipe update. A missing database or changed schema fails the image build.

Ghostty's image config adds only `confirm-close-surface = false`. The hero config already contains it and is unchanged. The recipe regression reads installed JSON/config and persisted SQLite state; independently removing each fix fails it.

The unchanged guest proof script is `.scratch/winmux-fork/proofs/guest-three-screens/live.sh`. Before any staging, the current image showed Zed's scratch-file trust modal and Ghostty's running-session quit confirmation. No Delta promotion was visible on that base run. A fresh clone of the rebuilt image, with the same Zed 1.24.2 and Ghostty 1.3.1, opens the file directly and quits Ghostty without a question. No permission was granted.

Host and pinned-version guest `make check` pass: 1,444 Swift tests, 88 helper tests and 143 Python tests. Fresh-clone preflight passes at both prescribed sizes. The standing desk stages four windows and passes both workspace stranger checks; the fresh 1920×1080 rich desk stages fourteen, with three Columns on workspace 2 and two on workspace 3. Both scripts fail with the promised rebuild message when the shared settings file is absent. A controlled Zed run (`promotion.sh` beside the proof) displays Delta after removing the dismissal marker and setting a pending update, then opens without the promotion after the recipe's state helper runs. Final preflight passes with the debug build and owned apps closed.

## Sources

- The builder's reports while building **The system's Cmd-Tab stays the system's unless the config asks for it**, 2026-10-13.
- [Zed worktree trust](https://zed.dev/docs/worktree-trust), including standalone files.
- [Zed 1.24.2 announcement gates](https://github.com/zed-industries/zed/blob/v1.24.2/crates/auto_update_ui/src/auto_update_ui.rs) and [dismissal storage](https://github.com/zed-industries/zed/blob/v1.24.2/crates/db/src/kvp.rs).
- [Ghostty configuration reference](https://ghostty.org/docs/config/reference#confirm-close-surface).
