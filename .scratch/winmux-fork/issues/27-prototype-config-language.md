# Prototype: config and scripting language

Type: prototype
Status: resolved

## Question

Should WinMux's config stay TOML with CEL expressions, or move to a real language? Prateek floated "a lisp for everything, no toml, no cel" while grilling [Grilling: fixed Columns, Width presets and Overflow policy semantics](09-grilling-fixed-columns-model.md). Rewrite Prateek's real config (a few Lenses and named Filters, the Columns `place` and `move-boundary` hooks, per-profile and per-workspace overrides, some on-window-detected rules) in each candidate and compare them side by side:

- **TOML + CEL**, as decided in [Prototype: filter language worked examples](06-prototype-filter-language.md).
- **An embedded Lisp**: Janet, Fennel on Lua, or s7 Scheme (check licences stay MIT-compatible).
- **TOML for static settings plus hook functions in JS** on JavaScriptCore, which already hosts cel-js.

Weigh: load-time checking (CEL's type-checking against the typed `Window`/`App`/`Monitor`/`Column` declarations), error messages, the AeroSpace TOML importer and compatibility with existing configs, embedding cost in Swift, hot reload, and how `winmux` CLI flags that take inline expressions (`winmux lens --filter`) would look.

Also in scope: merging `[[on-window-detected]]` and the `place` hook into one window-arrival hook, and letting hooks return arbitrary `winmux` command lists instead of the fixed action vocabulary. If a candidate other than TOML + CEL wins, it supersedes the language half of the filter-language prototype.

## Answer

> Under review 2026-09-30: the in-process embedding below is in question at [Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md), after [Task: Nickel binding spike](28-task-nickel-binding-spike.md) found that `nickel-lang-core` leaks memory on nearly every call (nickel-lang/nickel#1908).

Prototyped and grilled with Prateek on 2026-09-29. Prototype: [27-config-language.html](../prototypes/27-config-language.html), kept in `.scratch` like the filter-language one. It shows one reference config (Filters and Lenses, `place`, `move-boundary`, the Columns precedence chain, window arrival, hook return styles, errors, CLI) in seven candidates: TOML + CEL, Janet, TOML + JS hooks, HCL, Nickel, Dhall, and Guile written in Guix's style. A purpose-built DSL and a Nix module generating TOML were also drafted, then dropped at Prateek's request.

- **Nickel replaces both TOML and CEL.** The config is `~/.config/winmux/winmux.ncl`, checked against a WinMux-shipped `winmux.ncl` of contracts and defaults. Filters and Policy hooks are Nickel functions (`fun w ctx => …`). This supersedes the language half of [Prototype: filter language worked examples](06-prototype-filter-language.md); its Window classes (`accessory-popup`, `app-popup`), popup defaults and Filter attributes stand.
  - Why Nickel: it was the only candidate that gives both load-time errors and real computation (let bindings, helper functions, computed placement) in one syntax. Janet and JS typos read as silent nil or undefined. Dhall can't compare `Text`. HCL has no user functions and no Swift implementation. CEL's rule tables hit a ceiling where every new kind of decision needs a word added in Swift.
- **Embedding: our own thin Rust binding over `nickel-lang-core`** (MIT), exposed to Swift through UniFFI or swift-bridge. It loads the config once, keeps the evaluated functions, and calls them with Swift values marshalled in. Rejected: the shipped C API (`nickel_lang.h`; 1.18's arm64 dylib is 13.3 MB), because it only evaluates source text and has no call-this-function entry point. Also rejected: writing our own Nickel-like language, because it would lose `nls` and the official CLI and turn every semantic difference into a trap. Open facts go to [Task: Nickel binding spike](28-task-nickel-binding-spike.md).
- **Checking.** Contracts cover the config's shape and every hook's return value. At load, a smoke run calls each Filter and hook once against a synthetic, fully populated window. In Nickel, reading a missing field is an error, not nil, so a typo like `bundelId` fails at load, but only in branches the synthetic window takes. Verified with nickel 1.18 on an unannotated function: ``error: missing field `bundelId` … Did you mean `bundleId`?``. `nls` gives editor feedback. Inline type annotations stay optional: only inline record types are checked statically, while named ones like `W.Window` act as contracts. Real errors from nickel 1.18 are on the prototype's Errors tab.
- **Load failure** keeps the last good config running, shows a notification, and `reload-config` exits non-zero with the Nickel diagnostic.
- **TOML is dropped.** A one-shot `winmux config convert` translates an existing `winmux.toml`, and the AeroSpace importer emits Nickel.
- **Decided shapes carry over path for path.** `lenses.<name>` (filter, presentation, entries, sections, sort, `keys`), `when.<profile>`, `mode.<mode>.binding`/`gesture`, and the Columns precedence chain from `columns` through `workspace.<name>.columns.when.<profile>` keep the meaning the Lens-shape and Columns tickets gave them. Nickel's merge priorities (`& | default | force`) are only for layering files, e.g. a work-laptop file over a base. Display profiles stay runtime `when` resolution in WinMux.
- **One window-arrival hook.** `arrive` replaces `[[on-window-detected]]` and falls through to `place` for tiling windows. This fixes the ordering problem where the new-window binding ran before on-window-detected.
- **Mixed return style.** A hook returns fixed actions for placement (workspace, float, Column, Overflow policy; for `move-boundary`, its boundary actions), which the Placement contract checks and `columns place --dry-run` can explain. It can add an optional `run = [...]` of winmux commands that execute after placement settles. This amends the fixed-vocabulary-only decision in [Grilling: fixed Columns, Width presets and Overflow policy semantics](09-grilling-fixed-columns-model.md).
- **Routing, then placing.** When `arrive` returns a workspace but no Column, WinMux routes first, then calls `place` with the target workspace's Columns. Hooks stay pure functions of their arguments.
- **Handed on.** How inline `--filter` expressions look in Nickel goes to [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md). Enum tags start with `'`, which collides with zsh single quotes, so a candidate is passing only the body with `w` and `ctx` bound.
