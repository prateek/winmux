# Sign dogfood builds with the Developer ID and notarize them

Part of {{UMBRELLA}}.

**Blocked on Prateek** until his Developer ID certificate and a notarization credential are on the build machine. See **Put the Developer ID on the build machine**.

## What to build

Dogfood builds are signed with a self-signed identity and are not notarized. So Gatekeeper blocks the first launch, and the cask prints two manual steps to get past it. The clicked-through upgrade check found both steps wrong: `ditto --noqtn`, run as printed, left the quarantine attribute on, and Open Anyway was needed on the first version only, not on each.

Prateek has a Developer ID. A build signed with it and notarized opens from Finder with no step at all. Sign and notarize every release, and delete the steps.

## Decisions

- **`script/dogfood-release` signs with the Developer ID Application identity**, submits the archive with `notarytool`, waits, and staples the ticket to the app. A release that is not accepted is not published.
- **The hardened runtime goes on.** It was off because a self-signed app cannot load its own `Sparkle.framework` with it on. With one team's identity it can. The entitlements WinMux needs under it are found by running it, not guessed.
- **The grants are given once more, and the release says so.** The designated requirement changes from the self-signed certificate to the team's, so macOS treats the first notarized build as a new app for Accessibility and Screen Recording. After that they carry across upgrades as now. The release notes of that one version and the cask's caveats tell the user to grant both again.
- **Sparkle's update signature is unchanged.** Its EdDSA key is separate from code signing. An update from the last self-signed build to the first notarized one is checked in a guest before the release is published.
- **The cask loses its quarantine steps and its comment about them.** The cask is in `prateek/homebrew-tap`; the release script rewrites its version and checksum and must leave the rest alone.
- **Credentials stay in the build machine's keychain**: the certificate in the signing keychain, and a `notarytool` keychain profile. No secret goes into the repository, a log or a pull request. `--dry-run` signs and verifies, and submits for notarization only when asked.
- **The self-signed identity is kept as a named fallback** (`WINMUX_SIGN_IDENTITY`), for a machine without the Developer ID. Such a build is never published.

## Depends on

- **Put the Developer ID on the build machine**, a question open with Prateek.

## Defaults chosen for you

- **If the credential is not there yet**, do not build this issue: it is not buildable, and the relay skips it.
- **The interim caveat.** If this issue will not land soon, a one-line fix to the cask is fair game in its own pull request to the tap: replace the `ditto` step with the command that a fresh guest shows removes quarantine, and say Open Anyway is needed once.

## Done when

- [ ] `spctl -a -vv` accepts the published app as "Notarized Developer ID", and `stapler validate` passes.
- [ ] In a fresh guest, `brew install --cask winmux` and a double-click in Finder open WinMux with no Gatekeeper dialog and no manual step.
- [ ] WinMux runs under the hardened runtime: Sparkle loads, the Nickel helper starts, a Lens with pictures opens.
- [ ] In a guest, Sparkle updates the last self-signed build to the first notarized one. Both grants are asked for once and hold on the next update.
- [ ] The cask's caveats carry no quarantine step, and the next release leaves them so.
- [ ] `AGENTS.md`, the handoff and the release-pipeline notes say how the build is signed and what the build machine must hold.

## Sources

- Pull request [#71](https://github.com/prateek/winmux/pull/71), "What the click-through found that the cask's caveats do not say".
- Prateek, 2026-10-05, on a paid Developer ID: "I have one!"
