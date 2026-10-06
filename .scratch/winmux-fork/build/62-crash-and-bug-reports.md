# Crash and bug reports that are easy to send and easy to read

Part of {{UMBRELLA}}.

## What to build

The first crash on an installed build was found because Prateek said "it crashed, I think". The report sat in `~/Library/Logs/DiagnosticReports`, its WinMux frames were bare offsets, and they could be named only because the build machine still had that release's archive. A tester would have had nothing to send and we would have had nothing to read.

Two things: a person can send a report in one step, and every report we get can be symbolicated.

## Decisions

- **It follows One pinned toolchain for CI, the guest and the release.** Symbols are only worth keeping for a build that can be made again.
- **Nothing leaves the machine without the person seeing it first.** No silent upload.

## Not in this issue

- A hosted crash service. If the builder thinks one is needed, that is a question for Prateek, with the tradeoff.
- Usage analytics.

## Depends on

- **One pinned toolchain for CI, the guest and the release**.

## Defaults chosen for you

- **Symbols.** Each dogfood release publishes its dSYMs as a release asset, and `script/` gains a command that takes a `.ips` file and prints the stack with names, fetching the symbols for the report's version and checking the image UUID.
- **`winmux report`**, and the same from the menu bar: it gathers the version and commit, `doctor`, `config status`, the last Lens traces, the last minutes of WinMux's unified log and the newest WinMux crash report, removes the user name, home path and machine name, shows the result, and opens a new issue on the fork with the text ready and the archive to attach.
- **After a crash.** The next launch says WinMux quit unexpectedly and offers the same report. It also says whether the system's Cmd-Tab was restored.
- **What a report never holds**: window titles, config contents beyond the diagnostics already printed by `config status`, or screen pictures.

## Done when

- [ ] A release's dSYMs are downloadable, and the script names every WinMux frame of a crash report from that release.
- [ ] `winmux report` on a guest produces an archive with none of the guest's user name, home path or host name in it.
- [ ] After a forced crash in a guest, the next launch offers the report and the report holds that crash.
- [ ] `docs/` says how to send a report and what is in it.

## Sources

- The Cmd-Tab crash on `0.5.6-dogfood.12`, 2026-10-06, and Prateek the same day: "We should have some mechanism of crash reporting. Bug reporting, making it really easy for users and for us … a fast follow after the hermetic build."
