# Build on Xcode 27

Part of {{UMBRELLA}}.

## What to build

The build machine's selected Xcode is now 27.0, with Swift 6.4. CI pins Swift 6.2.4 in `.swift-version`, and the golden image carries Xcode 26.3 with the same 6.2.4. On 6.4, WinMux builds and every test passes, but `swift package resolve` changes `Package.resolved`: `swift-clocks` ships a manifest per Swift version, and the one 6.4 reads depends on `swift-issue-reporting` 2.1.2 where 6.2.4's depends on `xctest-dynamic-overlay` 1.13.1. So `make check` fails on the build machine, and `script/dogfood-release` builds, signs and verifies the app, then refuses to publish because the tree changed while it built. No release can be cut until the three agree again.

Move CI, the guest and the lockfile to the build machine's Swift.

## Decisions

- **Swift 6.4.0 is the pin.** `.swift-version` names it; it is the Swift inside Xcode 27.0.
- **`Package.resolved` is resolved by 6.4** and committed. Nothing else in the dependency graph moves.
- **CI keeps its runner and its mechanism**: `macos-26`, with swiftly installing the pinned Swift. The `xcode-27` label is a preview on macOS 27 and is not used.
- **The golden image moves to `ghcr.io/cirruslabs/macos-tahoe-xcode:27`**, built beside the current image and swapped in at landing, as the `vm` skill says.
- **The mechanism is not this issue's.** **One pinned toolchain for CI, the guest and the release** still decides how a toolchain is pinned and checked; this issue moves the version only.

## Depends on

Nothing.

## Done when

- [ ] `make check` passes on the build machine on its Xcode 27.0 and leaves `Package.resolved` unchanged.
- [ ] `make check` passes in a fresh clone of the new golden image, whose preflight passes and reports Swift 6.4.
- [ ] `Build and test` is green in CI on Swift 6.4.0.
- [ ] `script/dogfood-release --next --dry-run` completes on the build machine with the tree unchanged.
- [ ] Both desk sets stage in a fresh clone of the new image.
- [ ] The `vm` skill and the relay skill name Swift 6.4 and the new base, and no longer call Xcode 27 a trap.

## Sources

- Prateek, 2026-10-16: "can you upgrade our build to use 27".
- The release dry run and `make check` on the build machine under Xcode 27.0, during **The fourteen-window desk stages on its first run in a fresh guest**.
