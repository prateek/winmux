# Crash and bug reports that are easy to send and easy to read

Part of {{UMBRELLA}}.

## What to build

The first crash on an installed build was found because Prateek said "it crashed, I think". The report sat in `~/Library/Logs/DiagnosticReports`, its WinMux frames were bare offsets, and they could be named only because the build machine still had that release's archive. A tester would have had nothing to send and we would have had nothing to read.

Two things: a person can send a report in one step, and every report we get can be symbolicated.

## Decisions

- **It follows One pinned toolchain for CI, the guest and the release.** Symbols are only worth keeping for a build that can be made again.
- **Nothing leaves the machine without the person seeing it first.** No silent upload.
- **Collection is off until the user opts in**, through `crash-reports.enabled = false` in `defaults.ncl`. With it off nothing is collected and nothing is prompted. With it on, the next launch after a crash finds WinMux `.ips` files newer than the last one seen and offers the report. This is the convention of AltTab, Rectangle and Ice: a "report a bug" entry in the app that gathers diagnostics and opens a prefilled GitHub issue, nothing sent on its own.
- **Config and hook failures** that today reach only `last-error` can be reported through the same `winmux report`.
- **A report is triaged by the relay.** The relay's Orient step reads reports filed since its last run, symbolicates each with the script, and files a child of the build umbrella with the stack and a first reading of the cause, linked to the report, so a crash reaches the queue without Prateek reading an `.ips`.
- **dSYMs are public release assets.** The repository is public and the symbols give away nothing the source does not; a private store is not needed.

## Not in this issue

- A hosted crash service. If the builder thinks one is needed, that is a question for Prateek, with the tradeoff.
- Usage analytics.

## Depends on

- **One pinned toolchain for CI, the guest and the release**.

## Defaults chosen for you

- **Symbols.** Each dogfood release publishes its dSYMs as a release asset, and `script/` gains a command that takes a `.ips` file and prints the stack with names, fetching the symbols for the report's version and checking the image UUID.
- **`winmux report`**, and the same from the menu bar: it gathers the version and commit, `doctor`, `config status`, the last Lens traces, the last minutes of WinMux's unified log and the newest WinMux crash report, removes the user name, home path and machine name, shows the result, and opens a new issue on the fork with the text ready and the archive to attach.
- **After a crash**, with `crash-reports.enabled` on, the next launch says WinMux quit unexpectedly and offers the report, and says whether the system's Cmd-Tab was restored; with it off the launch says nothing and `winmux report` still works by hand.
- **What a report never holds**: window titles, config contents beyond the diagnostics already printed by `config status`, or screen pictures.

## Done when

- [ ] A release's dSYMs are downloadable, and the script names every WinMux frame of a crash report from that release.
- [ ] `winmux report` on a guest produces an archive with none of the guest's user name, home path or host name in it.
- [ ] With `crash-reports.enabled` off, a forced crash in a guest produces no prompt and collects nothing.
- [ ] With it on, the next launch after a forced crash offers the report and the report holds that crash.
- [ ] `docs/` says how to send a report and what is in it.

## Sources

- #263, the two crashes on dogfood.66 of 2026-10-19 and the reporting design it carried, folded in here.
- The grilling record of 2026-10-19, `.scratch/winmux-fork/issues/36-grilling-what-winmux-becomes.md`, "Features": follow the conventions of AltTab, Rectangle and Ice.
- The Cmd-Tab crash on `0.5.6-dogfood.12`, 2026-10-06, and Prateek the same day: "We should have some mechanism of crash reporting. Bug reporting, making it really easy for users and for us … a fast follow after the hermetic build."
