# `subscribe` sends the whole state on connect

Part of {{UMBRELLA}}.

## What to build

`winmux subscribe` sends an initial record for four of its eleven event types, `focus-changed`, `focused-workspace-changed`, `mode-changed` and `focused-monitor-changed`, and `--no-send-initial` turns that off. It sends nothing initial for the rest: a consumer that connects while a Lens is open never learns it, there is no project event at all, and the active Display profile and the Columns state have no initial record. The gesture bridge had to track the open Lens from a start it never saw; a status display would have to track the project the same way.

The grilling made status displays consumers of WinMux, so WinMux's side is to make the state cheap to read in one record.

## Decisions

- **The first line on a subscription is one `state` event**, sent before any other, whatever event types the subscription names, unless `--no-send-initial` is given. It carries the current mode, the focused workspace and its monitor, the project, the open Lens as the `lens-opened` payload or null, the active Display profile, the focused window's id and app, and the Columns state of the focused workspace as `columns-changed` reports it.
- **The four per-type initial records are replaced by the snapshot**, and `docs/events.md` says so; a consumer that wants them as events reads the snapshot.
- **A `project-changed` event** is added, with the old and new project names.
- **`winmux state`** prints the same record once, with `--json`, for a script that does not want a subscription.
- **`winmux agent skill`** describes both, since an agent is a consumer too.

## Depends on

Nothing.

## Defaults chosen for you

- **The snapshot is sent on every subscription**, filtered or not; filtering applies to the events that follow.
- **An event that lands while the snapshot is being written** follows it; the snapshot never reflects a later state than the first event after it.

## Done when

- [ ] A test connects with each filter and asserts the `state` record and every field, including the open Lens and the project; another changes project and asserts the event.
- [ ] A test with `--no-send-initial` asserts no snapshot.
- [ ] `docs/events.md` lists `state` and `project-changed` with their fields and the ordering rule, and `docs/cli.md` lists `winmux state`.

## Sources

- #268's handoff, "`winmux subscribe` sends no initial Lens state".
- `Sources/AppBundle/subscriptions.swift`, the `sendInitial` branch, and `docs/events.md`.
- The grilling record, 2026-10-19, "The boundary": status displays are consumers.
