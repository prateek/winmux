# Dogfood releases: cut a signed build from `fork` and install it through the tap

Part of {{UMBRELLA}}.

## What to build

Make `script/dogfood-release <version>` work on the `fork` branch. One run builds the app, the `winmux` CLI and the `winmux-nickel` helper, signs all three with the dogfood identity, publishes a GitHub prerelease on `prateek/winmux`, updates the Sparkle feed, and bumps the `winmux` cask in `prateek/homebrew-tap`. After this, a build of the fork can be installed on a daily machine with `brew`, and its Accessibility and Screen Recording grants survive upgrades. The Lens and Column issues need that to be tested where they will be used.

## Decisions

- **Signing identity.** Builds are signed with the self-signed identity `WinMux Dogfood Signing`, held in its own keychain and created by `script/setup-signing`. A stable certificate gives a stable designated requirement, so TCC grants made to one version carry to the next. The builds are not notarized. `script/setup-signing` and `script/setup-sparkle-keys` already work on this branch and are not rewritten.
- **Everything executable carries the same identity.** The app, the `winmux` CLI, the Sparkle framework's nested executables and `Contents/Helpers/winmux-nickel` are all signed with it. `dogfood-release` refuses to publish if any of them is not.
- **Where releases go.** Each version is a GitHub prerelease on `prateek/winmux`, tagged `v<version>`. The Sparkle appcast and app-only update archives live on the rolling `dogfood` release tag. The cask is `winmux` in `prateek/homebrew-tap`, and `dogfood-release` bumps its version and checksum; nobody bumps it by hand.
- **Package layout.** The release zip holds `WinMux-<version>/WinMux.app` and `WinMux-<version>/bin/winmux`, which is what the cask installs.
- **Build number.** `CFBundleVersion` is the git commit count, because Sparkle's version comparison stops at the first dash and every dogfood version shares its prefix. `CFBundleShortVersionString` is the full version, such as `0.5.6-dogfood.1`.
- **Minimum system.** The cask requires macOS 26, matching the deployment target.
- **Releases are cut from `fork`.** The script pushes the branch it runs on and tags the commit it built.
- **Publishing needs a go-ahead.** Running `dogfood-release` publishes a release and pushes to the tap. Prateek approves each run.

## Not in this issue

- Notarization, and anything that removes the Gatekeeper steps on a first install.
- Upstream's `release` workflow in `.github/workflows/release.yml`. It triggers on `main`, which only mirrors upstream.
- The helper itself and where it sits in the bundle: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`". This issue signs it and verifies the signature.

## Depends on

- "Raise the deployment target to macOS 26"
- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Build the bundle with Xcode, not by hand.** `dogfood-release` calls `make beta-package`, which exists only on `codex-columns` and assembles the app bundle by hand from a SwiftPM build. Don't port it. Since then upstream has added bundle resources (the app icon, the asset catalog, the `MASShortcut` resource bundle) that a hand-built bundle would lack, and the Nickel issue adds `Contents/Helpers` and `Contents/Resources/nickel`. Teach the `makefile`'s Xcode-based `release` target to take the identity, the expected authority, the Sparkle public key, the feed URL and the download URL prefix as variables, and have `dogfood-release` drive it. Upstream's values stay the defaults of those variables.
- **What `release` hardcodes today.** `EXPECTED_CODESIGN_AUTHORITY_PREFIX` and `DEVELOPMENT_TEAM` name upstream's Apple Development identity, the appcast step names `github.com/ZimengXiong/winmux`, `project.yml` hardcodes `SUFeedURL` to upstream's feed, and the target sets `CFBundleVersion` to the version and tests for it. `codesign -dv` omits `Authority=` for an untrusted self-signed certificate, so the authority check needs `-dvvv`.
- **The CLI.** Built with `swift build -c release --product winmux`, signed, and placed at `bin/winmux` in the package. Xcode builds only the app.
- **Bundle identifier.** Stays `com.zimengxiong.winmux`. The cask's `uninstall quit:` and existing TCC grants are keyed to it.
- **Version numbers.** `<upstream VERSION>-dogfood.<n>`, starting at `0.5.6-dogfood.1`.
- **Upgrading from the old dogfood line.** The last `codex-columns` release was `0.51.0-dogfood.15`, built from a branch with a different commit count. A machine that still runs it may not see the new line as an update. Reinstalling the cask once is the fix; don't add version arithmetic for it.
- **The cask.** One hand edit in `prateek/homebrew-tap`, made as part of this issue: `depends_on macos:` moves from `:ventura` to macOS 26, the description stops mentioning columnar zones, the caveats drop the zone setup text and keep the Gatekeeper steps, and `zap` covers the state directory the Nickel issue adds. After that only the script touches the cask.
- **Release text.** The script's release title and notes mention zones and link `docs/ultrawide-zones.md`, which this branch does not have. Replace both with text that fits the fork.
- **Hardened runtime.** Off for dogfood builds. With it on, the app cannot load its own `Sparkle.framework`: library validation wants Apple's signature or a shared team, and a self-signed identity has no team. `HARDENED_RUNTIME` is a `makefile` variable that defaults to `YES`, so upstream's build keeps it.
- **Dry run.** `script/dogfood-release --dry-run <version>` builds, signs and verifies everything and publishes nothing.
- **Start-up check.** Before it publishes, the script runs the packaged app with `--version` and the bundled helper with `check`, so a bundle that dyld refuses to load is caught on the build machine.

## Done when

- [x] `make release` with no variables set still produces upstream's build configuration, and `make check` passes. Checked with `make -n release`; the real build needs upstream's certificate.
- [ ] `script/dogfood-release <version>` run from a clean `fork` checkout builds, signs, publishes the prerelease, updates the feed on the `dogfood` tag and bumps the cask, with no manual step in between. A `--dry-run` passes; nothing has been published.
- [x] `codesign -dvvv` reports `Authority=WinMux Dogfood Signing` for `WinMux.app`, `bin/winmux` and `WinMux.app/Contents/Helpers/winmux-nickel`, and `codesign --verify --deep --strict` passes for the app.
- [ ] The built app has its icon, its asset catalog and the `MASShortcut` resource bundle, and the shortcut recorder in Settings renders. The three resources are in the bundle; the recorder has not been looked at.
- [x] The built `Info.plist` has the fork's `SUFeedURL`, the dogfood Sparkle public key, `CFBundleVersion` equal to the commit count, and `LSMinimumSystemVersion` 26.0.
- [ ] `brew install --cask prateek/tap/winmux` on a machine with no build toolchain installs the app and the CLI, and `winmux --version` reports the released version with no client/server mismatch warning.
- [ ] After the Gatekeeper steps in the cask's caveats, WinMux launches, and `winmux config status` reports the helper `ready`.
- [ ] Upgrading from one dogfood version to the next keeps the Accessibility and Screen Recording grants: no prompt, and window management and capture work at once.
- [ ] "Check for Updates…" on the older of two dogfood versions offers the newer one and installs it.
- [ ] With the installed build's own Screen Recording grant, the double-sided tab flip animates, and a burst of window captures shows no screen-recording indicator. These close the checks left open by "Raise the deployment target to macOS 26" and the umbrella issue.

## Sources

- `script/dogfood-release`, `script/setup-signing` and `script/setup-sparkle-keys` on this branch, copied unchanged from `codex-columns`.
- The `beta-package` target in `codex-columns`'s `makefile`, for what the old pipeline did.
- [The handoff](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/handoff.md), "Releases can't be cut yet".
