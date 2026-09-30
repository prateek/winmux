# Task: Nickel binding spike

Type: task
Status: open

## Question

Can WinMux call Nickel functions from Swift through a thin Rust binding over `nickel-lang-core`, and what does it cost? [Prototype: config and scripting language](27-prototype-config-language.md) chose Nickel with our own binding instead of the shipped C API. Settle these with a throwaway Rust crate plus a Swift caller (AFK):

1. Can `nickel-lang-core` keep an evaluated closure from a loaded config and apply it to a new value built from Swift data, without re-parsing? Which internal API does that, and how stable has it been across the last few releases?
2. What does one call cost? Measure a Filter over about 50 synthetic windows per Lens open (per-window calls vs one call over the whole array) one `arrive` call, and one `place` call per selection change while Summon's modifier is held (the landing-spot hint of [Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md)), cold and warm.
3. The UniFFI or swift-bridge shape: how `Window`, `App`, the Filter context and Columns are marshalled in, and how returned records and Nickel diagnostics come back.
4. Does Nickel's documented `.toml` import work, which would help `winmux config convert`?
5. Build from source on macOS (the 1.18 release artifacts link libiconv from `/nix/store`): toolchain, binary size added to WinMux, and a version-pin and upgrade policy.
