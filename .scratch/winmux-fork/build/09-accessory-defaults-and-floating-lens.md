# Accessory window defaults and the `floating` Lens

Part of {{UMBRELLA}}.

## What to build

Make windows of Accessory apps float by default instead of tiling, give Filters a stable way to say "window of an Accessory app", and expose popup-classified windows as two Window classes that a Lens leaves out unless its `popups` field lists them. Ship a default `floating` Lens so that a floating window buried behind tiled windows can be reached and focused or Summoned.

## Decisions

**Floating windows keep today's behaviour**

- "Floating" keeps its current meaning: the window's parent is a workspace.
- Nothing else about floating windows changes. Their positions are not remembered, and they do not stay visible across workspace switches.
- The problem this issue solves is reach: a floating window hidden behind tiled windows had no way to be found. The `floating` Lens is the whole fix.

**Accessory app windows float**

- A window of an Accessory app that would be tiled today floats by default. Today that is a window with the `AXStandardWindow` subrole and an enabled fullscreen button. Its other windows already float or are classified as popups.
- "Accessory app" here means the glossary's definition: the app's bundle declares `LSUIElement`. It does not mean the live activation policy. An app such as Ghost Pepper reports `regular` for as long as it has a window open, so the live policy cannot identify its windows.
- The decision is made where windows are classified as floating or tiled: `isDialogHeuristic` in `Sources/AppBundle/model/AxUiElementWindowType.swift`.
- The `arrive` hook can override the default and send such a window to a Column.

**Two Filter fields, two different signals**

- `a.accessory` is a boolean read from the app bundle's `LSUIElement`. It never changes while the app runs. It is `false` when the app has no bundle or the key is absent. "Windows of Accessory apps" is `w.app.accessory`.
- WinMux reads `LSUIElement` from the bundle's `infoDictionary`, which `Sources/AppBundle/command/impl/DebugWindowsCommand.swift` already reads through `Bundle(url:)`. It reads the key once, when the app is registered. In a plist the value can be a boolean, a number or a string such as `"1"`, and all three are accepted.
- `a.activationPolicy` is the live value from `NSRunningApplication`: `'regular`, `'accessory` or `'prohibited`. It can change at runtime.
- Filter contract v1 and `config schema` declares both fields and the two popup Window classes. This issue supplies their values, and its Done-when items are the ones that test those values.

**Popup Window classes follow the live policy**

- A popup-classified window has one of two Window classes: `'accessory-popup` or `'app-popup`.
- `'accessory-popup` follows the live activation policy, as upstream's check does today (`isWindowHeuristic` in `Sources/AppBundle/model/AxUiElementWindowType.swift`): a window with no close button is an `'accessory-popup` only while its app's activation policy is `accessory`, that is, while the app has no Dock icon.
- `'app-popup` is a regular app's popup, such as an autofill dropdown.
- A consequence, and the intended one: a modal dialog with no close button, shown by an Accessory app while that app reports `regular`, is `'floating` and stays in Lenses. Hiding a dialog that needs an answer is the worse failure.

**A Lens opts into popup windows with its `popups` field**

- A Lens has a `popups` field listing the popup Window classes it includes: any of `'accessory-popup` and `'app-popup`. It is empty by default.
- Windows of a popup class the Lens does not list never reach its Filter. For a listed class, the Filter still decides window by window.
- A Lens that wants an Accessory app's popups as well as its floating windows sets `popups = ['accessory-popup]` and writes a Filter that matches both classes.
- Popup-class windows sit in one global container outside every workspace (`macosPopupWindowsContainer` in `Sources/AppBundle/tree/MacosUnconventionalWindowsContainer.swift`), so they report `w.workspace` as `""`.
- Lens core and the `'list` Presentation with Search declares the `popups` field, applies it, and reads the popup container for the classes a Lens lists. This issue gives each popup-classified window the right class.

**No proactive registration**

- WinMux keeps upstream's behaviour: an app whose activation policy is `accessory` at the time is registered only once it has been frontmost. Apps that turn `regular` when they open a window are found like any Dock app.
- An app that shows windows while staying `accessory` and never becomes frontmost stays invisible to WinMux. No such app has turned up. Revisit when one does.

**The default `floating` Lens**

- `floating` is defined in the shipped `defaults.ncl`, which a user's config imports and merges over. This issue adds it there.
- Its Filter matches the floating Window class on every workspace. It is the named Filter `filters.floating`, defined beside the Lens in `defaults.ncl`: `fun w ctx => w.class == 'floating`.
- It does not set `popups`, so it shows no popup-class windows.
- Its Presentation is `'list`.
- `enter` focuses the selected window and `shift-enter` Summons it. These are the Lens defaults.
- This issue adds no key binding for it. `winmux lens floating` opens it, and Default config, Triggers, the `lens` leader mode, `subscribe` events adds the binding.

## Not in this issue

- The declaration of `a.accessory`, `a.activationPolicy`, `w.class`, `w.workspace` and the other contract fields, and `config schema`: Filter contract v1 and `config schema`.
- The `lens` command, the Lens record, the `popups` field and the reading of the popup container, the `'list` Presentation, `keys` actions and `summon`: Lens core and the `'list` Presentation with Search.
- The `arrive` hook itself, and how its result says "tile this window": Column Policy hooks and Column commands. This issue only has to leave the float as a default that an `arrive` result replaces.
- The key that opens `floating` (`f` in the `lens` leader mode): Default config, Triggers, the `lens` leader mode, `subscribe` events.
- How an Accessory app window is drawn in a Lens (the `accessory-window` field): Thumbnail cache and the `'miniatures` Presentation.
- Not built: proactive registration of Accessory apps, and watching activation-policy changes.
- Not built: remembered positions for floating windows, keeping them visible across workspace switches, or re-placing them when the display changes.

## Depends on

- Filter contract v1 and `config schema`
- Lens core and the `'list` Presentation with Search

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Which popup class a window gets when it is not the close-button case.** The app's live activation policy decides. A popup-classified window of an app whose policy is `accessory` is `'accessory-popup`, whatever made it a popup (a non-standard subrole, for example). Every other popup-classified window is `'app-popup`.
- **Focus and Summon on a popup-class window.** `focus` raises the window through `nativeFocus`. Summon refuses with a message and moves nothing, because the window has no workspace to leave.
- **The `floating` Lens's sort order.** `['mru]`, the same as the `search` Lens.

## Build notes

The decisions and chosen defaults are unchanged. Bundle identity is cached at app registration;
live policy is read for each record. Popup classification still precedes the floating default.
App fields and popup class are captured before the AX round-trip, so a policy change during
that read does not mix two moments in one record.

`list-lenses --json` reports a Filter's callable config path, `lenses.floating.filter`, rather
than its source alias `filters.floating`; Nickel functions stay in the helper. Profile overrides
report their `when.default.filter` path, and an absent Filter is `null`. The shipped Lens still
references the named, overridable `filters.floating`. This extends Lens core's introspection,
which previously omitted functions entirely.

Validation: `make check` passes, including classifier, plist-value, record, AX snapshot,
popup-gate, row-action and real-helper CLI tests. `make default-config` and `make contract`
were run. The live run used owned neutral Accessory and Dock apps, with genuine AX close-button
absence. It covered floating at open, the regular-policy dialog, both popup gates, popup Enter
and shift-enter, cross-workspace floating Focus and Summon, policy changes on one window,
and the CLI. Captures are named in the pull request's Live run section. The three popup checks
left by Lens core and the list are now verified live. A native fullscreen Space was not tried;
a controlled AXUnknown Dock-app popup represented a browser autofill dropdown.

## Done when

- [x] A window of an app whose bundle declares `LSUIElement`, with a standard subrole and an enabled fullscreen button, opens floating. The same window tiled before this change.
- [x] Windows of ordinary Dock apps are classified exactly as before.
- [x] `winmux list-windows --filter "w.app.accessory" --json` lists the windows of Accessory apps.
- [x] `w.app.accessory` is `true` for an `LSUIElement` app even while its activation policy is `'regular`.
- [x] `w.app.accessory` is `true` whether the bundle writes `LSUIElement` as a boolean, a number or the string `"1"`, and `false` for an app with no bundle or no such key. A test covers each case.
- [x] `winmux list-windows --filter "w.app.activationPolicy == 'accessory" --json` reflects the live policy and changes when the app's policy changes.
- [x] A close-button-less window of an app with no Dock icon is `'accessory-popup`; the same app's window is `'floating` while the app is `regular`.
- [x] A regular app's popup is `'app-popup`. A window of an app whose live policy is `accessory`, classified as a popup for a reason other than a missing close button, is `'accessory-popup`.
- [x] A close-button-less dialog of an Accessory app that reports `regular` at that moment appears in the `floating` Lens.
- [x] A Lens with `popups = ['accessory-popup]` and the Filter `fun w ctx => true` shows the close-button-less window of an app with no Dock icon and does not show a regular app's autofill dropdown. With `popups = ['app-popup]` it shows the dropdown and not the other.
- [x] In a Lens that lists a popup class, `enter` on a popup-class window raises it, and `shift-enter` prints a message and moves nothing.
- [x] `winmux lens floating` opens a list of every floating window on every workspace, most recently focused first. `enter` focuses the selection, and `shift-enter` Summons it into the current workspace.
- [x] `winmux list-windows --lens floating --json` prints the same windows.
- [x] `winmux list-lenses --json` includes `floating` with the `'list` Presentation, the Filter `filters.floating` and an empty `popups`.

## Sources

- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Task: live check of Ghost Pepper's windows under WinMux](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/12-task-live-check-ghost-pepper.md)
- [Ghost Pepper probe scripts and captures](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/12-ghost-pepper-probe)
- [Research: how WinMux sees Accessory app windows](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/02-research-accessory-app-windows.md)
- [Research findings: how WinMux sees Accessory app windows](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/02-accessory-app-windows.md)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md)
- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
