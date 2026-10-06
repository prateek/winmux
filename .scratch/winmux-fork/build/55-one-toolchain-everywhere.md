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
- **The pins are two files in the repository.** A `mise.toml` pins everything mise can install: Rust for the helper, Python for the scripts, and the build's command-line tools. An `.xcode-version` pins Xcode, which nothing can install for us. CI, `vm build-image`, `make check` and the release script read them. Nothing else names a version, and `.swift-version` goes.
- **Not Bazel and not Nix.** Neither can supply Xcode: Bazel's Apple rules and Nix on macOS both build with the Xcode on the machine, so the compiler that disagreed would still come from outside the pin. Bazel would also replace SwiftPM and cargo as the build. Nix would pin Rust and the tools more strictly than mise does, at the cost of installing Nix on the CI runner, in the guest image and on the build machine; mise is already on the build machine. If the tools drift in practice, Nix for the non-Xcode part is the next step, and this issue does not rule it out.
- **A build with another toolchain is refused by name.** `make check` and the release script check the selected Xcode and the Rust toolchain before building and say which pin they miss. A developer's local `swift build` is not policed.
- **Dependencies are locked.** `Package.resolved` and `Cargo.lock` are committed and the builds use them as they are (`--locked` for cargo; a resolve that changes `Package.resolved` fails CI).
- **The first step is to look**: which Xcode versions the `macos-26` runner carries, and what the build machine has installed. If no one version is available in all three, stop and say so in the pull request, with the versions found.
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
- [ ] `mise.toml` and `.xcode-version` are the only places a toolchain version is written, and the `vm` skill, `AGENTS.md` and the handoff say how to move a pin.

## Sources

- The handoff brief after pull request [#83](https://github.com/prateek/winmux/pull/83).
- Prateek, 2026-10-05: "Why can't we use the compiler that works on the guest in CI?" and "use the same toolchain, hermetic builds, in all locations".
