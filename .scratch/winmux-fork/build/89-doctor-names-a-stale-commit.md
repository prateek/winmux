# `winmux doctor` names a commit the build was not made from

Part of {{UMBRELLA}}.

## What to build

`winmux doctor` prints `WinMux doctor — git <hash>`. In a guest, on a debug build synced from the host and built there, it printed `c75b7f0c` across two builder passes and a demo pass whose source was three different, later commits. The builder had to prove what it was running from the synced files.

The line is there so a report says which build it came from. It has to be true or absent.

## Decisions

- **Find out where the hash comes from** and why it does not follow the source: a generated file that `vm sync` copies and the build does not regenerate, or one written only by the release script.
- **A build that cannot know its commit says so**, with a word such as `unknown`, and does not print an old one.

## Not in this issue

- Version numbers in a release build, which the release script sets.

## Depends on

Nothing.

## Done when

- [ ] In a guest, after `vm sync` and `vm build` of a new commit, `winmux doctor` names that commit or says it is unknown.
- [ ] A release build still names the commit it was cut from.

## Sources

- The builder's reports while building **The system's Cmd-Tab stays the system's unless the config asks for it**, 2026-10-13: "Doctor's embedded `c75b7f0c` label is stale".
