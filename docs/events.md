# Subscription events

`winmux subscribe --all` includes ten events: `focus-changed`, `focused-monitor-changed`, `focused-workspace-changed`, `mode-changed`, `window-detected`, `binding-triggered`, `config-reloaded`, `lens-opened`, `lens-closed` and `columns-changed`. Output is one JSON record per line, with `_event` naming the event. Select individual events by listing their names. `--no-send-initial` suppresses the existing focus/mode initial records. The four events added here have no synthetic initial records.

```sh
winmux subscribe config-reloaded
winmux subscribe lens-opened lens-closed
winmux subscribe columns-changed
winmux subscribe --all
```

| Event | Payload keys besides `_event` |
| --- | --- |
| `config-reloaded` | `ok`: Bool, `error`: String or null, `configPath`: String |
| `lens-opened`, `lens-closed`, named Lens | `lens`: String |
| `lens-opened`, `lens-closed`, ad-hoc Lens | `lens`: null, `filter`: String |
| `columns-changed` | `workspace`: String, `count`: Int, `widths`: array of fractions, `occupied`: array of one-based indices |

A reload emits once after it reaches a result, whether a command, menu, Settings action or file save started it. Success has `ok: true` and `error: null`; a load or apply failure has `ok: false` and its diagnostic. `configPath` identifies the loaded config on success and the attempted editable path on load failure. A reload discarded because a newer load overtook it emits nothing. A dry run only checks the config and emits nothing. A save ignored because the config was removed, the server is disabled or startup is not ready has not reached a reload result; a deferred startup save emits when it is subsequently loaded.

A Lens emits `lens-opened` when its panel is presented and `lens-closed` only if that session emitted an opening. A quick strip tap released inside the 100 ms display delay emits neither event because no panel appeared. A held strip that appears emits one pair. List and miniatures Lenses are presented at once, so their event timing is unchanged. Search, Presentation changes and a strip handed off to the list keep that session and emit nothing. Escape, click, release, an unrelated global binding and explicit dismissal all close the session once. An invalid ad-hoc Filter or disabled Lens that cannot open emits neither. An ad-hoc Filter records its resolved name or body, including stdin content, on both events.

Column events compare the settled model after normalization on the focused workspace. Count is the physical slot count, including a squeeze Column; widths are fractions and occupied indices are sorted. Every refresh retains a baseline by workspace name for all existing workspaces, including Columns on workspaces away from focus, and drops baselines for workspaces that no longer exist. A first-seen workspace is a silent baseline. A focus move alone emits nothing; a Column change arriving with focus, including a transferred or new window filling a Column, is compared with that workspace's own prior baseline and emits. The tracker reads existing roots and tests occupancy without creating a root or building leaf-window arrays. Turning Columns off emits `count: 0`, `widths: []`, `occupied: []`. Divider previews do not change the retained model; committing emits once. Moving a window within an already occupied Column emits nothing unless occupancy, widths or count changes.

Examples:

```json
{"_event":"config-reloaded","ok":true,"error":null,"configPath":"/demo/winmux.ncl"}
{"_event":"lens-opened","lens":"search"}
{"_event":"lens-closed","lens":null,"filter":"same-app"}
{"_event":"columns-changed","workspace":"Demo","count":3,"widths":[0.5,0.25,0.25],"occupied":[1,3]}
```
