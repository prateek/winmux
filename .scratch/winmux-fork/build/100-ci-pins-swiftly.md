# CI installs a swiftly that cannot fetch Swift 6.4.0

Part of {{UMBRELLA}}.

## What to build

Since **Build on Xcode 27** pinned Swift 6.4.0, CI's toolchain step fails on some runners with `Swift 6.4.0 does not exist at URL https://download.swift.org/swift-6.4-release/xcode/swift-6.4-RELEASE/swift-6.4-RELEASE-osx.pkg`. `brew install swiftly` installs whichever swiftly the runner's bottle cache holds. swiftly 1.1.3 drops the `.0` and asks for a package that does not exist; 1.1.4 asks for `swift-6.4.0-RELEASE`, which does. Two of the first four runs on 6.4.0 failed this way.

## Decisions

- **CI pins swiftly itself**: swift.org's signed `swiftly-1.1.4.pkg`, checked against its SHA-256 and installed into the runner's home. Homebrew no longer supplies it.
- **The release workflow does the same**, so the two stay alike.
- **Moving the pin** means changing the version and the checksum together.

## Depends on

Nothing.

## Done when

- [ ] CI's toolchain step installs swiftly 1.1.4 from the pinned package and Swift 6.4.0 from swift.org.
- [ ] `Build and test` passes with it.

## Sources

- CI runs on pull requests #175 and #177, after **Build on Xcode 27** landed.
