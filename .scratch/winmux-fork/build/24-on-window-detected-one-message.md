# One removal message for `on-window-detected`

Part of {{UMBRELLA}}.

## What to build

`[[on-window-detected]]` was removed in favour of the `arrive` hook, and a config that still has it fails to load with a message that names `arrive`. That message is assembled in three places with two wordings, and a TOML config gets it twice over: once as the removal message and once as "Unknown top-level key". This issue gives the message one source on each side of the helper boundary and makes a config report it once.

The three places:

- `nickel-helper/src/protocol.rs` appends `on-window-detected was removed; rewrite it using arrive` to a Nickel error in two branches, and returns the same string from a third.
- `Sources/AppBundle/config/parseConfig.swift` appends `Removed; rewrite window detection using arrive` in two functions, one of them guarded by a search of the earlier errors for the word "arrive".
- `Sources/AppBundle/config/TomlParseError.swift` reports the key again as `Unknown top-level key`.

## Decisions

- A config with `on-window-detected` still fails to load, on both parsers.
- It reports the removal once. No "Unknown top-level key" line for that key, and no second copy of the removal message.
- The message names `arrive` and `winmux config convert`, which keeps the old rules as commented-out `arrive` branches.
- `config convert` keeps its own warning text, which says a different thing: that a rule was left as a comment.

## Not in this issue

- Any change to what `config convert` writes for an `on-window-detected` rule.
- Bringing `on-window-detected` back, or translating its rules to a working `arrive`.
- The other TOML-era wording in the Swift parser's errors, such as "actual type is 'integer'".

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The wording.** `on-window-detected was removed. Rewrite it as an arrive hook; winmux config convert leaves each rule as a commented-out arrive branch.`
- **One source per language.** One constant in the helper and one in Swift, with a test on each side that compares it with a fixture string, so the two cannot drift apart unnoticed.
- **Where Swift decides.** The check that looks for "arrive" in earlier error text goes; the removal is detected by the key, in one function both parse paths call.

## Done when

- [ ] `winmux config check` on a Nickel config with `on-window-detected` fails with the message once.
- [ ] Loading a TOML config with `[[on-window-detected]]` fails with the message once, and without "Unknown top-level key" for that key.
- [ ] A TOML config with `[[on-window-detected]]` and a second, truly unknown key reports the removal once and "Unknown top-level key" for the other key.
- [ ] The message text appears once in the helper's source and once in Swift's, and a test on each side holds it to the shared fixture.
- [ ] `winmux config convert` output for such a config is unchanged.
- [ ] The pull request's transcript shows the three commands above and their output from a debug build.

## Sources

- The **Declined** list of pull request [#32](https://github.com/prateek/winmux/pull/32).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
