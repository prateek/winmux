# `winmux doctor` names a commit the build was not made from

Part of {{UMBRELLA}}.

## What to build

`winmux doctor` prints `WinMux doctor — git <hash>`. In a guest, on a debug build synced from the host and built there, it printed `c75b7f0c` across two builder passes and a demo pass whose source was three different, later commits. The builder had to prove what it was running from the synced files.

The line is there so a report says which build it came from. It has to be true or absent.

## Decisions

- **Hash provenance:** the tracked generated file held an upstream commit. Only `make generate` rewrote it; `vm build` called bare `swift build`. Regenerating against the guest's synthetic sync repository would name that repository's commit, so the source commit crosses from the host instead.
- **A build that cannot know its commit says so**, with a word such as `unknown`, and does not print an old one.

## Built

- The tracked `Sources/Common/gitHashGenerated.swift` contains `unknown` for both hashes, so bare Swift builds compile without naming an old commit. The tracked version file is unchanged.
- `make generate` calls `script/source_commit.py`. A root `.source-commit` wins, with `-dirty` added when the tree has changed since the guest's sync commit; otherwise Git supplies the full HEAD of the tree's own repository, with `-dirty` for staged, unstaged or untracked source changes. Only the two generated Swift files are excluded. With no identity, or a malformed marker, both hashes are `unknown`. SHA-1 and SHA-256 names are accepted. Short hashes have eight characters, followed by `-dirty` when appropriate. Unchanged generated files are not rewritten, so a repeated build does not recompile Common. CLI, handshake and report formats are unchanged.
- `vm sync` reads the host identity before and after rsync and writes it to the guest's `.source-commit` on every sync, marked dirty when it changed during the copy. The marker is ignored by Git. An archive's marker says `unknown`, and the guest still gets its sync commit, which `make check`'s `Package.resolved` diff needs. `vm build` runs `make generate` before compiling; `vm check` is unchanged.
- The release refuses to publish an app whose `--version` is not `<version> <commit it was cut from>`. A script test fails when the committed hash file holds anything but `unknown`.
- Command-seam and generator-output regressions cover clean, dirty and generated-only trees, a commit during the copy, marker precedence, guest edits, nested trees, archives and unchanged files. Host and pinned-version guest `make check` pass. Guest debug and signed release readbacks name the source commit; the release dry run restores the committed generated files and publishes nothing.

## Not in this issue

- Version numbers in a release build, which the release script sets.

## Depends on

Nothing.

## Done when

- [x] In a guest, after `vm sync` and `vm build` of a new commit, `winmux doctor` names that commit or says it is unknown.
- [x] A release build still names the commit it was cut from.

Installed-build checks, a second display and real sleep, wake or unlock remain Prateek's; this issue's checks use guest CLI transcripts.

## Sources

- The builder's reports while building **The system's Cmd-Tab stays the system's unless the config asks for it**, 2026-10-13: "Doctor's embedded `c75b7f0c` label is stale".
