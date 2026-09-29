# Prototype: config and scripting language

Type: prototype
Status: open

## Question

Should WinMux's config stay TOML with CEL expressions, or move to a real language? Prateek floated "a lisp for everything, no toml, no cel" while grilling [Grilling: fixed Columns, Width presets and Overflow policy semantics](09-grilling-fixed-columns-model.md). Rewrite Prateek's real config (a few Lenses and named Filters, the Columns `place` and `move-boundary` hooks, per-profile and per-workspace overrides, some on-window-detected rules) in each candidate and compare them side by side:

- **TOML + CEL**, as decided in [Prototype: filter language worked examples](06-prototype-filter-language.md).
- **An embedded Lisp**: Janet, Fennel on Lua, or s7 Scheme (check licences stay MIT-compatible).
- **TOML for static settings plus hook functions in JS** on JavaScriptCore, which already hosts cel-js.

Weigh: load-time checking (CEL's type-checking against the typed `Window`/`App`/`Monitor`/`Column` declarations), error messages, the AeroSpace TOML importer and compatibility with existing configs, embedding cost in Swift, hot reload, and how `winmux` CLI flags that take inline expressions (`winmux lens --filter`) would look.

Also in scope: merging `[[on-window-detected]]` and the `place` hook into one window-arrival hook, and letting hooks return arbitrary `winmux` command lists instead of the fixed action vocabulary. If a candidate other than TOML + CEL wins, it supersedes the language half of the filter-language prototype.
