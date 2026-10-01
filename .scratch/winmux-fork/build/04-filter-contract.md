# Filter contract v1 and `config schema`

Part of {{UMBRELLA}}.

## What to build

Define the records WinMux hands to Nickel (Window, App, Monitor, Filter context, Column) as contract version 1, once, and generate the Nickel contracts, the helper's typed Rust structs and the `winmux config schema` output from that one definition. Let a config declare Filters as Nickel functions, check every Filter when the config loads with a smoke run, and evaluate a Lens's Filter over all windows in one batched request to the `winmux-nickel` helper. After this issue a Filter with a typo or an unguarded `null` fails at load with Nickel's diagnostic, and `winmux config schema` prints every field a Filter can read.

## Decisions

**The records (contract version 1)**

- Every field is always present in every record. Nickel raises an error on a missing field, so WinMux sends the "when unknown" value when it has nothing to report.
- A Filter receives a Window as `w` and the Filter context as `ctx`.

Window (`w`):

| Field | Type | When unknown |
|---|---|---|
| `id` | Number | never unknown |
| `title` | String | `""` |
| `class` | enum: `'tiled`, `'floating`, `'fullscreen`, `'minimized`, `'hidden-app`, `'accessory-popup`, `'app-popup` | never unknown |
| `subrole` | String (the AX subrole) | `""` |
| `level` | Number (the CG window layer) | `0` |
| `hasCloseButton` | Bool | `false` |
| `document` | String (from `AXDocument`) | `""` |
| `workspace` | String | never unknown |
| `project` | String | `""` |
| `monitor` | Monitor | never unknown |
| `lastFocusedSeq` | Number | `0` (never focused) |
| `app` | App | never unknown |

App (`w.app`):

| Field | Type | When unknown |
|---|---|---|
| `bundleId` | String | `""` |
| `name` | String | `""` |
| `pid` | Number | never unknown |
| `accessory` | Bool (the bundle's `LSUIElement`) | `false` |
| `activationPolicy` | enum: `'regular`, `'accessory`, `'prohibited` | never unknown |

Monitor (`w.monitor`, `ctx.monitor`):

| Field | Type | When unknown |
|---|---|---|
| `name` | String | not specified |
| `uuid` | String | `""` |
| `builtin` | Bool | not specified |

Filter context (`ctx`):

| Field | Type | Notes |
|---|---|---|
| `focused` | Window or `null` | the focused window |
| `mouse` | Window or `null` | the window under the mouse |
| `previous` | Window or `null` | the previously focused window |
| `workspace` | `{ name, project }` | the current workspace |
| `monitor` | Monitor | the focused monitor |
| `profile` | String | always `"default"` until Display profiles are built |

Column (passed to the `place` and `move-boundary` Policy hooks, never to Filters):

| Field | Type |
|---|---|
| `index` | Number |
| `width` | Number (a fraction) |
| `empty` | Bool |
| `windows` | Array of Window |

**Field notes**

- **Enums.** `class` and `activationPolicy` are Nickel enum tags. `subrole` is a String because the set of AX subroles is open. `ctx.profile` is a String.
- **Absent context windows are `null`.** `ctx.focused`, `ctx.mouse` and `ctx.previous` are `null` when there is no such window. A Filter must guard them, for example `ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId`.
- **`'floating` keeps today's meaning:** the window's parent is a workspace.
- **Popups are two classes.** `'accessory-popup` is a close-button-less window of an app that has no Dock icon at that moment. `'app-popup` is a regular app's popup, such as an autofill dropdown.
- **`'accessory-popup` follows the live activation policy,** as upstream's popup classification does. A close-button-less window is an accessory-popup only while its app has no Dock icon. An Accessory app that turns `regular` while its dialog is open therefore has a `'floating` dialog, which stays in Lenses.
- **`app.accessory`** is read from the bundle's `LSUIElement` and never changes while the app runs. "Windows of Accessory apps" is `w.app.accessory`.
- **`app.activationPolicy`** is the live value and can change while the app runs.
- **`lastFocusedSeq`** is the Global MRU sequence number. It is a Window field that Filters can read.
- **`document`** stays in version 1 because WinMux reads `AXDocument` itself.
- **Left out of version 1:** every tab field (`tabs`, `tabsSource`, `tabsAge`, `private`) and `registered`. With no proactive registration, every window a Filter sees is registered.

**Declaring Filters**

- A Filter is a Nickel function `fun w ctx => …` that returns a Bool. It only says yes or no. Ordering belongs to the Lens.
- Named Filters live in the config's `filters` record: `filters.<name> = fun w ctx => …`.
- Wherever a Filter is accepted, the config can give a named Filter (`filter = filters.same_app`) or write the function inline.
- Filters call each other as ordinary functions: `filters.floating w ctx`. There is no other reference syntax.
- A Filter can use anything Nickel offers: `let` bindings, helper functions, the standard library.

**Checking at load**

- The shipped `winmux.ncl` contracts cover the records above and the Filter function shape. The config is checked against them at load.
- The helper then runs a smoke run. It calls every Filter, named and inline, twice against a synthetic, fully populated Window: once with `ctx.focused`, `ctx.mouse` and `ctx.previous` all set, and once with all three `null`. An unguarded `ctx.focused.app` therefore fails at load.
- Reading a missing field is a Nickel error, so a typo such as `w.app.bundelId` fails the smoke run with Nickel's own diagnostic (``missing field `bundelId` … Did you mean `bundleId`?``). The smoke run only catches errors in the branches the synthetic records take.
- The smoke run happens on every load: startup, reload and `winmux config check`. A contract or smoke-run failure fails the load, and the diagnostic is the text Nickel prints.
- Policy hooks go through the same smoke run, twice in the same way. Their records and return contracts belong to "Column Policy hooks and Column commands".

**Typed marshalling**

- WinMux sends records to the helper as plain JSON, with enum values as JSON strings.
- The helper holds one typed Rust struct per record. The struct knows which fields are enum tags and converts them. It rejects a record with a missing field before any Nickel runs, because Nickel's contracts are lazy and do not catch a missing field in host data before the Filter body runs.
- The structs are versioned with the Filter contract and ship in the same app as the contracts.

**Evaluating Filters**

- **One batched request per Lens open.** WinMux sends the Filter context and every candidate Window in one request that names the Lens's Filter. The helper answers with one match bit per window.
- **`eval-filter` request.** A function body with `w` and `ctx` bound, sent as text with the Filter context and the windows. The helper evaluates it in the loaded config's environment, so `filters.<name> w ctx` works inside it. It is compiled per request and not cached. The answer is one match bit per window, or the Nickel diagnostic.
- **Budget.** A Filter request gets 100 ms.
- **When a Filter fails or times out,** or the helper is unavailable, an interactive Lens shows every window with a banner saying the Filter failed. A result from an earlier open is never reused, because it could hide a new window. Non-interactive commands treat the same failure differently, as described in "Lens core and the `'list` Presentation with Search".
- A failed call does not poison the helper. The next request runs normally.

**Versioning**

- One integer, `contract-version`. This is version 1.
- It is bumped only when a field is removed or renamed. Adding a field does not bump it.
- The app, the shipped contracts and the helper's structs ship together, so only a user's config can lag behind.

**`winmux config schema [--json]`**

- Prints the contract version and every field of every record with its type, its enum values and a one-line description.
- The output is generated from the same source as the Nickel contracts and the helper's Rust structs, so the three cannot drift.
- `--json` prints the same content as JSON.

## Not in this issue

- The `winmux-nickel` helper itself, the JSON-lines transport, request ids, supervision, recycling, crash backoff, the circuit breaker, what a failed load does to the running config, and `config check`, `config convert` and `config status`: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`". This issue adds the Filter requests and the smoke run to that helper.
- Writing `lastFocusedSeq`: "Global MRU (`lastFocusedSeq`)". Until that lands the field is `0`.
- Lens records, leaving the popup classes out of Lenses, sort, Search, `lens --filter`, `list-windows --filter` and the exit codes for a failed Filter in a script: "Lens core and the `'list` Presentation with Search".
- Floating Accessory app windows by default: "Accessory window defaults and the `floating` Lens".
- The `place`, `move-boundary` and `arrive` hooks, their return contracts, and filling the Column record: "Column Policy hooks and Column commands" and "Fixed Columns: slots, the count invariant, Width presets". This issue only defines the Column record's fields.
- Deferred: tab fields and Tab providers, Display profile matching (`ctx.profile` is always `"default"`), and proactive registration of Accessory apps.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"

## Open details

- What is the single source that the Nickel contracts, the Rust structs and the `config schema` output are generated from, and which build step generates them? Only the requirement that they share one source was decided.
- What values does the smoke run's synthetic Window carry (which `class`, which strings), and does it try more than one Window? Only "synthetic, fully populated" and the two context cases were decided.
- Where is `contract-version` declared, and what happens when a user's config was written for an older version? Only the integer and when it is bumped were decided.
- What is the shape of `config schema --json`?
- Does `config schema` work with the server down, the way `config check` does by running the helper directly?
- What do `monitor.name` and `monitor.builtin` hold when WinMux cannot read them? Only `uuid` has a stated value.
- How does WinMux assign `class` when more than one could apply, for example a floating window that is minimized, and does `'fullscreen` mean WinMux fullscreen, macOS native fullscreen or both?

## Done when

- [ ] A config with `filters.<name> = fun w ctx => …` loads, and a Lens can use the Filter by name or inline.
- [ ] A named Filter that calls another (`filters.floating w ctx`) loads and evaluates.
- [ ] `winmux config check` on a config whose Filter reads `w.app.bundelId` exits non-zero and prints Nickel's missing-field diagnostic.
- [ ] `winmux config check` on a config whose Filter reads `ctx.focused.app` without a `null` guard exits non-zero. The same Filter with a guard passes.
- [ ] A Filter that returns something other than a Bool fails at load.
- [ ] The helper rejects a Window record with a missing field before evaluating any Nickel, and a test covers it.
- [ ] One batched Filter request carrying the Filter context and every window returns one match bit per window.
- [ ] An `eval-filter` request with the body `w.class == 'floating` returns match bits, and a body that calls a named Filter works.
- [ ] `class` and `activationPolicy` reach Nickel as enum tags: `w.class == 'floating` matches a floating window and `w.app.activationPolicy == 'accessory` matches an app with no Dock icon.
- [ ] A close-button-less window of an app with no Dock icon is `'accessory-popup`. The same app's window is `'floating` while the app is `regular`.
- [ ] `w.app.accessory` is `true` for an `LSUIElement` app even while its activation policy is `'regular`.
- [ ] A Filter request that runs past 100 ms, or whose Filter raises an error at run time, returns a failure with the diagnostic that the caller can turn into "every window, with a banner". A test covers both cases.
- [ ] `winmux config schema` prints contract version 1 and every field in the tables above with type, enum values and a description. `winmux config schema --json` prints the same as JSON.
- [ ] A test fails if the Nickel contracts, the Rust structs and the schema output disagree on a field.

## Sources

- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md)
- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Task: Nickel binding spike](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/28-task-nickel-binding-spike.md) and its [spike code](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/28-nickel-spike/README.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md) (for `config schema`)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md)
