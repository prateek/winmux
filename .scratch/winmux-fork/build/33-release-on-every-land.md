# Release a dogfood build on every land to `fork`

Part of {{UMBRELLA}}.

## What to build

Today `script/dogfood-release` runs only when Prateek asks. This issue cuts a release whenever a pull request lands on `fork`, so the installed build on a daily machine follows the trunk without anyone running a script.

It is first in the umbrella so that every later issue reaches an installed build as it lands.

## Blocked on Prateek

One decision is his and is not made: where the job runs. Nothing is built until he picks.

- **A GitHub Actions job on push to `fork`.** The signing identity, the Sparkle private key and a token for the Homebrew tap become repository secrets. It does not depend on the build machine, and each merge commit gets a red or green release. The keys leave the machine.
- **A job on the build machine that watches `fork`.** Nothing is exported. It depends on that machine being up, and a failed release shows in a log, not on the commit.

Exporting the keys is not something a builder or a driver does on an inference. If he picks the first, he exports them or says in words that an agent may.

## Decisions

- The same self-signed certificate signs every release. It is what keeps Accessibility and Screen Recording grants across upgrades.
- The job runs `script/dogfood-release`; the release logic stays in that script and is not copied into a workflow.
- The version is the next `<base>-dogfood.N` for the base in `VERSION`. The build number stays the commit count.
- A land that changes nothing in the built product still releases. Skipping by path is a later refinement.
- `AGENTS.md` says a release runs only when Prateek asks. That line changes to say what triggers one now, and that a manual run is still his to ask for.

## Not in this issue

- Notarization.
- Upstream's `release.yml`, which fires on pushes to `main`. It is left alone; this is a separate job.
- A rollback mechanism. Rolling back is reinstalling an older cask version.

## Depends on

Nothing in the repository. It waits for the decision above.

## Defaults chosen for you

- **Concurrency.** Two lands close together produce two releases in order. A release in flight is not cancelled by the next land.
- **A failed release** does not block the next one, and is reported where the chosen option reports: the commit status, or the log plus a notification on the build machine.
- **A bad build reaches installed machines through Sparkle.** The pull request says so in `AGENTS.md`, with the command that pins the cask to an older version.

## Done when

- [ ] Prateek's choice is recorded in this issue.
- [ ] A pull request merged to `fork` produces a prerelease, an updated Sparkle feed and a bumped cask with no manual step.
- [ ] The release is signed with the dogfood identity, and `brew upgrade` on a machine with existing grants keeps them.
- [ ] A failed release is visible where the chosen option says it is.
- [ ] `AGENTS.md` describes the new trigger.

## Sources

- **Dogfood releases: cut a signed build from `fork` and install it through the tap**, which built the script.
- [`script/dogfood-release`](https://github.com/prateek/winmux/blob/fork/script/dogfood-release)
