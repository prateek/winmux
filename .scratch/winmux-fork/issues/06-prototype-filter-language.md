# Prototype: filter language worked examples

Type: prototype
Status: resolved
Prototype: [06-filter-language.html](../prototypes/06-filter-language.html) (throwaway; open by double-click)

## Question

Which filter language should WinMux use: expression strings in `winmux.toml` or JavaScript predicates run by JavaScriptCore (current lean)? Write the same set of real Filters in both, and react to them together before choosing. Cover at least: current project; everything; all floating windows (including Accessory apps); same app as the focused window except itself; floating windows of the app under the mouse; windows on the current monitor in the ultrawide Display profile only; a named app list minus exclusions; the previously focused window first. Explore the implications: composition and reuse, error messages, how the Filter context is exposed, and how a Picker binding references a Filter.

From the Accessory-app research: "floating" today means "the window's parent is a workspace". The examples must decide whether it also covers popup-classified and never-registered windows, and should expose activation policy, AX subrole, window level, close-button presence, and WinMux's classification (tiled, floating, fullscreen, minimized, hidden-app, popup) as window attributes.

From the monitor-identity research: the Filter context should carry a monitor descriptor (UUID, built-in flag, name), not just an index, so filters can target a display reliably.

## Working notes

- 2026-09-28: Prateek picked CEL, via [marcbachmann/cel-js](https://github.com/marcbachmann/cel-js) (MIT, v8.0.0) running in JavaScriptCore, over hand-rolled expression strings and raw JS predicates. Checked in macOS's `jsc`: an 86 KB minified bundle type-checks Filters before they run (unknown fields, `string == bool`, a missing function, an unguarded `optional<Window>`) and prints a caret under the error. Gaps WinMux owns: `TextEncoder`/`TextDecoder` shims for a bare JSContext; misspelled enum strings (`w.class == "flaoting"`) pass the checker; named Filters become registered functions; custom functions receive Maps. Still open on this ticket: the default meaning of floating and whether Pickers drop popups by default, whether sort and "ultrawide only" live on the Picker binding, and the config shape.

## Answer

Prototype: [06-filter-language.html](../prototypes/06-filter-language.html), kept in `.scratch` rather than on a throwaway branch because the tracker is local.

- **Language: CEL**, via [marcbachmann/cel-js](https://github.com/marcbachmann/cel-js) (MIT) running in JavaScriptCore, instead of hand-rolled expression strings or raw JS predicates. WinMux declares typed `Window`, `App` and `Monitor` types and the Filter context variables, and `env.check` rejects a broken Filter when `winmux.toml` loads, with a caret under the error: unknown fields, `string == bool`, missing functions, and reading `focused`/`mouse`/`previous` (declared `optional<Window>`) without a guard. WinMux owns the `TextEncoder`/`TextDecoder` shims and a small extra check for misspelled enum strings, which CEL doesn't catch.
- **Floating keeps today's meaning** (the window's parent is a workspace). Popups become first-class window classes instead of one `popup`: `accessory-popup` (close-button-less windows of Accessory apps, e.g. Ghost Pepper) and `app-popup` (regular apps' popups, e.g. Arc's Autofill). Prateek marked the split as "maybe"; the implementing spec should confirm the names. So `w.class` is one of `tiled`, `floating`, `fullscreen`, `minimized`, `hidden-app`, `accessory-popup`, `app-popup`, and a Filter that wants Ghost Pepper writes `w.class in ["floating", "accessory-popup"]`.
- **Pickers drop both popup classes by default.** They appear only when the Filter mentions them.
- **Sort and Display-profile gating live on the Picker binding**, not in Filters. Filters stay yes/no predicates; "previous window first" is `sort = ["previous", "mru"]` and "ultrawide only" is `profiles = ["ultrawide"]` on the binding.
- **Config shape:** a `[filters]` table in `winmux.toml` maps names to CEL strings. A binding's `filter =` takes a name or inline CEL. Named Filters are registered as CEL functions, so one calls another as `floating(w)`.
- Filter attributes (CEL fields) come from the prototype and the Accessory-app research: title, class, subrole, level, close-button presence, registered, app name, bundle id and activation policy, workspace, project, and monitor name, UUID and built-in flag. Tab fields (`w.tabs`, `w.document`) come from [Grilling: tab provider interface](24-grilling-tab-provider-interface.md).
