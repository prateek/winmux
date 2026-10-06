# One pinned toolchain for CI, the guest and the release

Part of {{UMBRELLA}}.

## What to build

WinMux is built in three places, by three toolchains, and no check runs on the one that builds what is installed.

- **CI** installs swift.org's Swift 6.2.4 through swiftly, from `.swift-version`, and takes whatever Rust the runner has for the `winmux-nickel` helper.
- **The guest** uses the Swift 6.2.4 inside Xcode 26.3, from the Cirrus base image, and the Rust the image recipe installed.
- **The release** is built on the build machine with whatever Xcode and Rust are selected there. Its Swift is newer than the other two.

The first two disagreed once already: CI's compiler crashed with "Failed to reconstruct type" on a struct declared inside a function, which the guest's built. It cost two CI runs. The third has never been compared with anything.

Make a build the same wherever it runs: the same Xcode, Swift and Rust, named in the repository, and refused when they differ.

## Decisions

- **Xcode's Swift is the compiler.** The app links Apple frameworks and ships built by Xcode's toolchain. CI selects an Xcode by version and stops installing swiftly.
- **Xcode has a pin of its own**, an `.xcode-version` file, because nothing can install Xcode for us: Nix on macOS and Bazel's Apple rules both build with the Xcode on the machine.
- **Nix holds every other pin.** A flake at the repository root, with its `flake.lock`, supplies Rust, Python and the build's command-line tools, and `nix develop` gives CI, the guest and the build machine the same shell. Prateek chose Nix over mise; he is considering moving his machines to it. CI, `vm build-image`, `make check` and the release script build inside that shell, nothing else names a version, and `.swift-version` goes.
- **The Nix shell does not supply Swift or the SDK.** It leaves Xcode's toolchain as the machine has it and must not put a compiler, linker or SDK of its own ahead of Xcode's. Check this first: a SwiftPM build of the app and a cargo build of the helper, both from inside the shell, linking against Xcode's SDK. If the two cannot be made to work together, stop and say what failed.
- **Not Bazel.** It would replace SwiftPM and cargo as the build and still take its compiler from the machine's Xcode.
- **A build with another toolchain is refused by name.** `make check` and the release script check the selected Xcode and the Rust toolchain before building and say which pin they miss. A developer's local `swift build` is not policed.
- **Dependencies are locked.** `Package.resolved` and `Cargo.lock` are committed and the builds use them as they are (`--locked` for cargo; a resolve that changes `Package.resolved` fails CI).
- **The first step is to look**: which Xcode versions the `macos-26` runner carries, and what the build machine has installed. If no one version is available in all three, stop and say so in the pull request, with the versions found.
- **Nix is installed where it is missing**: on the CI runner by a pinned installer action with the store cached between runs, in the golden image by the image recipe, and on the build machine once. The pull request gives CI's time with and without the cache.
- **`ci.yml` then differs from upstream's.** That is accepted; pushes to the fork go over SSH.

## Not in this issue

- Reproducible, byte-identical artefacts.
- Building the release in a guest. It needs the signing keys, which stay on the build machine.

## Depends on

Nothing.

## Done when

- [ ] `swift --version`, `xcodebuild -version` and `rustc --version` print the same in CI's log, in a fresh guest and in the release script's output.
- [ ] `make check` and the release script each refuse, by name, an Xcode or a Rust that is not the pinned one.
- [ ] A build that would change `Package.resolved` or `Cargo.lock` fails.
- [ ] `make check` passes in all three places.
- [ ] `flake.lock` and `.xcode-version` are the only places a toolchain version is written, and the `vm` skill, `AGENTS.md` and the handoff say how to move a pin.

## Sources

- The handoff brief after pull request [#83](https://github.com/prateek/winmux/pull/83).
- Prateek, 2026-10-05: "Why can't we use the compiler that works on the guest in CI?" and "use the same toolchain, hermetic builds, in all locations". On what holds the pins: "nix".
