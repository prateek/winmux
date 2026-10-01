# Accessory window defaults and the `floating` Lens

Part of {{UMBRELLA}}.

## What to build

Make windows of Accessory apps float by default instead of tiling, give Filters a stable way to say "window of an Accessory app", and expose popup-classified windows as two Window classes that Lenses leave out unless asked. Ship a default `floating` Lens so that a floating window buried behind tiled windows can be reached and focused or Summoned.

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
- `a.activationPolicy` is the live value from `NSRunningApplication`: `'regular`, `'accessory` or `'prohibited`. It can change at runtime.
- Both fields are declared in the Filter contract. This issue supplies their values.

**Popup Window classes follow the live policy**

- A popup-classified window has one of two Window classes: `accessory-popup` or `app-popup`.
- `accessory-popup` follows the live activation policy, as upstream's check does today (`isWindowHeuristic` in `Sources/AppBundle/model/AxUiElementWindowType.swift`): a window with no close button is an `accessory-popup` only while its app's activation policy is `accessory`, that is, while the app has no Dock icon.
- `app-popup` is a regular app's popup, such as an autofill dropdown.
- A consequence, and the intended one: a modal dialog with no close button, shown by an Accessory app while that app reports `regular`, is floating and stays in Lenses. Hiding a dialog that needs an answer is the worse failure.
- Lenses leave out both popup classes unless the Lens's Filter names them. A Filter that wants an Accessory app's popups as well as its floating windows names both classes. Lens core applies the leaving-out; this issue makes sure each popup-classified window carries the right class.

**No proactive registration**

- WinMux keeps upstream's behaviour: an app whose activation policy is `accessory` at the time is registered only once it has been frontmost. Apps that turn `regular` when they open a window are found like any Dock app.
- An app that shows windows while staying `accessory` and never becomes frontmost stays invisible to WinMux. No such app has turned up. Revisit when one does.

**The default `floating` Lens**

- The default config ships a Lens named `floating`.
- Its Filter matches the floating Window class on every workspace (`w.class == 'floating`).
- Its Presentation is `'list`.
- `enter` focuses the selected window and `shift-enter` Summons it. These are the Lens defaults.
- It ships unbound in this issue. `winmux lens floating` opens it.

## Not in this issue

- The declaration of `a.accessory`, `a.activationPolicy`, `w.class` and the other contract fields, and `config schema`: Filter contract v1 and `config schema`.
- The `lens` command, the `'list` Presentation, `keys` actions and `summon`: Lens core and the `'list` Presentation with Search.
- The `arrive` hook itself, and how its result says "tile this window": Column Policy hooks and Column commands. This issue only has to leave the float as a default that an `arrive` result replaces.
- The key that opens `floating` (`f` in the `lens` leader mode): Default config, Triggers, the `lens` leader mode, `subscribe` events.
- How an Accessory app window is drawn in a Lens (the `accessory_window` field): Thumbnail cache and the `'miniatures` Presentation.
- Not built: proactive registration of Accessory apps, and watching activation-policy changes.
- Not built: remembered positions for floating windows, keeping them visible across workspace switches, or re-placing them when the display changes.

## Depends on

- Filter contract v1 and `config schema`
- Lens core and the `'list` Presentation with Search

## Open details

Settle each of these while building and note the choice in the PR.

- **How "the Filter names them" is detected.** This is shared with Lens core and the `'list` Presentation with Search; settle it in whichever lands first. Filters are Nickel functions, so "names a popup class" is not something the function's result shows. Candidates are a check on the Filter's source for the two class tags, or always passing popup-class windows through the Filter and relying on Filters not to match them. Not decided.
- **Popup-class windows have no workspace.** WinMux keeps them in a global container outside every workspace, and Lenses today enumerate windows through workspaces. The Lens's window source has to include that container. The Filter contract says `w.workspace` is never unknown; what it holds for a popup-class window was not decided.
- **Which popup class a window gets when it is not the close-button case.** `accessory-popup` is defined as a window with no close button of an app whose live policy is `accessory`. An app with policy `accessory` can also have a window classified as a popup for another reason (a non-standard subrole, for example). Whether that is `accessory-popup` or `app-popup` was not decided.
- **What focus and Summon do on a popup-class window.** Not decided.
- **The `floating` Lens's sort order.** None was given. The `search` Lens, which is also a `'list`, sorts by MRU.
- **Reading `LSUIElement`.** `DebugWindowsCommand.swift` already reads the bundle's `infoDictionary`. In a plist the key can be a boolean or a string such as `"1"`; handle both. When to read it (once at app registration is enough, since it never changes) is the implementer's choice.

## Done when

- [ ] A window of an app whose bundle declares `LSUIElement`, with a standard subrole and an enabled fullscreen button, opens floating. The same window tiled before this change.
- [ ] Windows of ordinary Dock apps are classified exactly as before.
- [ ] `winmux list-windows --filter "w.app.accessory" --json` lists the windows of Accessory apps, including one whose app currently reports `regular`.
- [ ] `winmux list-windows --filter "w.app.activationPolicy == 'accessory" --json` reflects the live policy and changes when the app's policy changes.
- [ ] A close-button-less window of an app whose live policy is `accessory` has the class `accessory-popup`; a regular app's popup has the class `app-popup`.
- [ ] A close-button-less dialog of an Accessory app that reports `regular` at that moment has the class `floating` and appears in the `floating` Lens.
- [ ] With Lens core landed, a Lens whose Filter does not name a popup class shows no popup-class windows, and a Lens whose Filter names `'accessory-popup` shows them.
- [ ] `winmux lens floating` opens a list of every floating window on every workspace. `enter` focuses the selection, and `shift-enter` Summons it into the current workspace.
- [ ] `winmux list-windows --lens floating --json` prints the same windows.
- [ ] `winmux list-lenses --json` includes `floating` with the `'list` Presentation.
- [ ] `winmux config schema` shows `accessory` and `activationPolicy` on App.

## Sources

- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Task: live check of Ghost Pepper's windows under WinMux](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/12-task-live-check-ghost-pepper.md)
- [Ghost Pepper probe scripts and captures](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/12-ghost-pepper-probe)
- [Research: how WinMux sees Accessory app windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/02-research-accessory-app-windows.md)
- [Research findings: how WinMux sees Accessory app windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/02-accessory-app-windows.md)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md)
- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md)
