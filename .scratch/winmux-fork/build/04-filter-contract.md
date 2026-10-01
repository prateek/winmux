# Filter contract v1 and `config schema`

Part of {{UMBRELLA}}.

## What to build

Define the records WinMux hands to Nickel (Window, App, Monitor, Filter context, Column) as contract version 1, once, and generate the Nickel contracts, the helper's typed Rust structs and the `winmux config schema` output from that one definition. Fill the Window, App, Monitor and Filter context records from WinMux's live windows, and supply the synthetic records the load-time smoke run feeds to every Filter. The helper's requests, its smoke-run loop and its marshalling already exist, built against a stand-in record by "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"; this issue supplies the real records they run on. After this issue a Filter with a typo or an unguarded `null` fails at load with Nickel's diagnostic, and `winmux config schema` prints every field a Filter can read.

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
| `workspace` | String | `""` (every popup-class window; a minimized window reports the workspace it was minimized on) |
| `project` | String | `""` |
| `monitor` | Monitor | a Monitor with every field at its "when unknown" value |
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
| `name` | String | `""` |
| `uuid` | String | `""` |
| `builtin` | Bool | `false` |

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

**Spelling**

- Every field name and enum tag the fork adds to Nickel uses hyphens, never underscores: `'hidden-app`, `'accessory-popup`, `'app-popup`, `contract-version`, `filters.same-app`. Nickel accepts hyphens inside identifiers and enum tags. `a-b` is therefore one name, and a subtraction needs spaces around the minus sign.
- The camelCase record fields in the tables above (`bundleId`, `hasCloseButton`, `lastFocusedSeq`, `activationPolicy`) are spelled as shown.

**Field notes**

- **Enums.** `class` and `activationPolicy` are Nickel enum tags. `subrole` is a String because the set of AX subroles is open. `ctx.profile` is a String.
- **Absent context windows are `null`.** `ctx.focused`, `ctx.mouse` and `ctx.previous` are `null` when there is no such window. A Filter must guard them, for example `ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId`.
- **One class per window, from the node it sits under.** The class follows the same parent relation that `list-windows`'s layout field prints (`getChildParentRelation` in `Sources/AppBundle/tree/TreeNodeCases.swift`): a window under a tiling container is `'tiled`, under a workspace `'floating`, under the native-fullscreen container `'fullscreen`, under the hidden-apps container `'hidden-app`, under the minimized container `'minimized`, and under the popup container one of the two popup classes. A window has exactly one parent, so exactly one class applies. A minimized floating window is `'minimized`.
- **`'fullscreen` means macOS native fullscreen.** WinMux's own `fullscreen` command sets a flag on the window and leaves it where it is in the tree, so such a window keeps the class it had (`'tiled` or `'floating`).
- **`'floating` keeps today's meaning:** the window's parent is a workspace.
- **Popups are two classes.** `'accessory-popup` is a close-button-less window of an app that has no Dock icon at that moment. `'app-popup` is a regular app's popup, such as an autofill dropdown.
- **`'accessory-popup` follows the live activation policy,** as upstream's popup classification does. A close-button-less window is an accessory-popup only while its app has no Dock icon. An Accessory app that turns `regular` while its dialog is open therefore has a `'floating` dialog, which stays in Lenses.
- **`workspace` can be unknown.** WinMux keeps popup-class windows in a container outside every workspace, so their `workspace` is `""`. Minimized windows also sit in a container outside every workspace, but a minimized window reports the workspace it was on when it was minimized.
- **`app.accessory`** is read from the bundle's `LSUIElement` and never changes while the app runs. "Windows of Accessory apps" is `w.app.accessory`.
- **`app.activationPolicy`** is the live value and can change while the app runs.
- **`lastFocusedSeq`** is the Global MRU sequence number. It is a Window field that Filters can read.
- **`document`** is in version 1 because it needs no Tab provider: WinMux reads it from the window's own `AXDocument` attribute.
- **Left out of version 1:** every tab field (`tabs`, `tabsSource`, `tabsAge`, `private`) and `registered`. With no proactive registration, every window a Filter sees is registered.

**Filling the records**

- This issue builds the Swift code that turns a live window into a Window record, and the focused window, the window under the mouse, the previous window, the current workspace and the focused monitor into a Filter context.
- **Reading `AXDocument` is new work.** Nothing in WinMux reads `kAXDocumentAttribute` today; the name appears only in a comment in `Sources/AppBundle/util/accessibility.swift`. This issue adds the read. It is the one field in the contract that costs an extra AX round-trip per window.
- **Remembering a minimized window's workspace is new work.** The minimized container has no workspace above it, and nothing records where a minimized window came from. This issue adds a last-known workspace to `Window`, written when WinMux moves the window into the minimized container, and `w.workspace` reads it. "Thumbnail cache and the `'miniatures` Presentation" uses the same value to draw minimized windows under their workspace.
- **Values supplied elsewhere.** `lastFocusedSeq` is written by "Global MRU (`lastFocusedSeq`)". The values of `app.accessory` and `app.activationPolicy`, and which of the two popup classes a popup-classified window gets, are supplied by "Accessory window defaults and the `floating` Lens". This issue declares all of them in the contract.

**Declaring Filters**

- A Filter is a Nickel function `fun w ctx => …` that returns a Bool. It only says yes or no. Ordering belongs to the Lens.
- Named Filters live in the config's top-level `filters` record: `filters.<name> = fun w ctx => …`.
- This issue supplies the contract for a Filter (a Window, then a Filter context, to a Bool) and the contract for the `filters` record (every field is a Filter), and adds both to the shipped `winmux.ncl`.
- Wherever a Filter is accepted, the config can give a named Filter (`filter = filters.same-app`) or write the function inline.
- Filters call each other as ordinary functions: `filters.floating w ctx`. There is no other reference syntax.
- A Filter can use anything Nickel offers: `let` bindings, helper functions, the standard library.

**Checking at load**

- The shipped `winmux.ncl` contracts cover the records above and the Filter function shape. This issue generates them and adds them to the shipped library. The config is checked against them at load.
- The smoke-run loop is not built here. This issue supplies what it runs on: a synthetic, fully populated Window and two Filter contexts. Every Filter, named and inline, is called twice against that Window: once with `ctx.focused`, `ctx.mouse` and `ctx.previous` all set, and once with all three `null`. An unguarded `ctx.focused.app` therefore fails at load.
- Reading a missing field is a Nickel error, so a typo such as `w.app.bundelId` fails the smoke run with Nickel's own diagnostic (``missing field `bundelId` … Did you mean `bundleId`?``). The smoke run only catches errors in the branches the synthetic records take.
- The same synthetic Window and the same two Filter contexts are what the smoke run passes to Policy hooks. The hooks' other arguments and their return contracts belong to "Column Policy hooks and Column commands".

**Typed marshalling**

- The helper's typed Rust struct for each record, which knows which fields are enum tags and which fields must be present, is generated from this issue's definition. The conversion and the missing-field rejection that use those structs are not built here.
- The structs are versioned with the Filter contract and ship in the same app as the contracts.

**Versioning**

- One integer, `contract-version`. This is version 1.
- It is bumped only when a field is removed or renamed. Adding a field does not bump it.
- The app, the shipped contracts and the helper's structs ship together, so only a user's config can lag behind.

**`winmux config schema [--json]`**

- Prints the contract version and every field of every record with its type, its enum values and a one-line description.
- The output is generated from the same source as the Nickel contracts and the helper's Rust structs, so the three cannot drift.
- `--json` prints the same content as JSON.

## Not in this issue

- The `winmux-nickel` helper itself, the JSON-lines transport, request ids, supervision, recycling, crash backoff, the circuit breaker, what a failed load does to the running config, and `config check`, `config convert` and `config status`: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`". That issue also builds the batched Filter request, the `eval-filter` request, the Policy hook requests, their timeouts, the smoke-run loop, and the typed marshalling with its missing-field rejection, all tested against a stand-in record. This issue builds none of them. It supplies the record definitions, the contracts and the synthetic values they run on.
- Writing `lastFocusedSeq`: "Global MRU (`lastFocusedSeq`)". Until that lands the field is `0`.
- Reading `LSUIElement` for `app.accessory`, reading the live `app.activationPolicy`, and deciding which popup class a popup-classified window gets: "Accessory window defaults and the `floating` Lens". Until that lands, `accessory` is `false`, `activationPolicy` is `'regular` and every popup-classified window is `'app-popup`.
- Lens records, the Lens's `popups` field that decides whether popup-class windows reach a Filter, sort, Search, the banner an interactive Lens shows when its Filter fails, `lens --filter`, `list-windows --filter` and the exit codes for a failed Filter in a script: "Lens core and the `'list` Presentation with Search".
- Floating Accessory app windows by default: "Accessory window defaults and the `floating` Lens".
- The `place`, `move-boundary` and `arrive` hooks, their return contracts, and filling the Column record: "Column Policy hooks and Column commands" and "Fixed Columns: slots, the count invariant, Width presets". This issue only defines the Column record's fields.
- Deferred: tab fields and Tab providers, Display profile matching (`ctx.profile` is always `"default"`), and proactive registration of Accessory apps.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The single source.** The definition is a set of Rust types in `nickel-helper/` with a derive that emits the `.ncl` contracts and the schema JSON at build time.
- **Synthetic smoke-run values.** One Window: `'tiled`, of a `'regular` app, with implausible strings such as `"winmux-smoke"` in every String field. The context windows of the first pass are fully populated in the same way. The smoke run includes no popup-class Window.
- **Where `contract-version` is declared.** It is a `contract-version` field in the shipped library. A version declared in a user's config is accepted and ignored, because at version 1 no config can lag behind.
- **Shape of `config schema --json`.** `{ "contract-version": 1, "records": { "Window": [ { "name", "type", "enum", "description" } ], … } }`.
- **`config schema` with the server down.** It works: `schema` is a one-shot mode of `winmux-nickel` that the `winmux` CLI execs directly, the way it execs `check`.
- **`monitor.name` and `monitor.builtin` when unknown.** `""` and `false`.
- **`project` and `monitor` for a window outside every workspace.** The tree gives a minimized or popup-class window no monitor either (`nodeMonitor` in `Sources/AppBundle/tree/TreeNodeEx.swift` is `nil` under both containers). A minimized window reports the project and the monitor of its remembered workspace. A popup-class window reports `project = ""` and a Monitor with `name = ""`, `uuid = ""` and `builtin = false`.
- **A window first seen minimized.** It has no remembered workspace, so its `workspace` and `project` are `""` and its `monitor` is the all-unknown Monitor.
- **When `AXDocument` is read.** In the same per-window pass that reads the title when the records are built.

## Done when

- [ ] A config with `filters.<name> = fun w ctx => …` loads, and a named Filter that calls another (`filters.floating w ctx`) passes the smoke run.
- [ ] A Filter that reads every field in the tables above passes the smoke run, in both passes when its context reads are guarded.
- [ ] `winmux config check` on a config whose Filter reads `w.app.bundelId` exits non-zero and prints Nickel's missing-field diagnostic.
- [ ] `winmux config check` on a config whose Filter reads `ctx.focused.app` without a `null` guard exits non-zero. The same Filter with a guard passes.
- [ ] A Filter that returns something other than a Bool fails at load, and so does a `filters.<name>` that is not a function.
- [ ] `class` and `activationPolicy` reach Nickel as enum tags: `w.class == 'floating` is true for a record whose `class` is sent as the JSON string `"floating"`, and `w.app.activationPolicy == 'accessory` is true for one whose `activationPolicy` is sent as `"accessory"`. A test covers both.
- [ ] The record WinMux builds for a live window carries the right class: `'tiled` under a tiling container, `'floating` under a workspace, `'fullscreen` in macOS native fullscreen, `'hidden-app` for a window of a hidden app, `'minimized` when minimized. A tiled window put in WinMux's own fullscreen is still `'tiled`. A test covers the mapping.
- [ ] A window minimized on workspace `2` reports `workspace = "2"` in its record while minimized, and a test covers it. A popup-classified window reports `workspace = ""`.
- [ ] `w.document` holds the window's `AXDocument` value for a document window that has one and `""` for a window that does not.
- [ ] `winmux config schema` prints contract version 1 and every field in the tables above with type, enum values and a description, including `accessory` and `activationPolicy` on App. `winmux config schema --json` prints the same as JSON.
- [ ] A test fails if the Nickel contracts, the Rust structs and the schema output disagree on a field.
## Sources

- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md) (hyphenated names, `workspace` when unknown, reading `AXDocument`)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md)
- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Task: Nickel binding spike](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/28-task-nickel-binding-spike.md) and its [spike code](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/28-nickel-spike/README.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md) (for `config schema`)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md)
