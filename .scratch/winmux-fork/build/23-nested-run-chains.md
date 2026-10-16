# Nested `run` lists: let a chain through, stop a loop

Part of {{UMBRELLA}}.

## What to build

A hook's `run` list can move its window, and the move can call another hook with a `run` list of its own. Today every such inner list is suppressed: `ColumnPolicy.run` keeps the ids of windows whose list is executing in `runningWindows`, and a second list for the same window is dropped and logged as "nested run list suppressed". That stops a loop, and it also stops a chain a config can reasonably want: `arrive` runs `move-node-to-workspace 3`, and workspace 3's `place` has a `run` list that sets the Column width. The width is never set. This issue lets the chain run and still stops the loop.

## Decisions

- This replaces a decision of **Column Policy hooks and Column commands**, which suppressed every nested list.
- A `run` list executes while another list for the same window is executing, as long as it comes from a different hook definition.
- A list from a hook definition whose list is already executing for that window is suppressed, and logged once as a hook failure, as today. A hook definition is one config path, such as `arrive`, `columns.place` or `workspace.3.columns.place`.
- So a chain is at most as long as the number of hook definitions in the config, and a loop ends the first time it comes back to a definition it has already run.
- The inner list runs to its end before the outer list's next command, in the order the commands are written.
- `place --dry-run` and the Summon landing spot still run no `run` list.

## Not in this issue

- **`arrive` is skipped when its refresh session is cancelled** covers a hook call lost to cancellation.
- Any change to which commands a `run` list may hold.
- A promoted popup still gets `arrive`'s `run` list twice, once as a popup and once at promotion.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The guard's key.** `runningWindows` becomes a set of window id and hook path. `ColumnPolicy.run` takes the path of the hook whose result it is running.
- **The log line.** `Policy run: <path> is already running for this window; its run list is suppressed`.
- **The docs.** `docs/columns.md` states the old rule; rewrite that passage with the chain example above and a loop example.

## Done when

- [x] A test: `arrive` runs `move-node-to-workspace` to a workspace whose `place` has a `run` list, and both lists execute, the inner one before the outer list's next command. The test fails without the change.
- [x] A test: two workspaces whose `place` hooks each send the window to the other. The window stops moving after one round trip, and `config status` shows one suppression.
- [x] A test: a `place` whose `run` list uses `layout floating` then `layout tiling` on its own workspace binds through the inner Place, suppresses its list once and continues the outer list.
- [x] `place --dry-run` executes no `run` list.
- [x] `docs/columns.md` describes the rule, and its Nickel examples pass `winmux-nickel check`.
- [x] A live run shows the chain: a new window is routed by `arrive` and its Column takes the width the destination's `place` asked for.

## Build notes

All Done-when items are met. The chain and Move-boundary chain regressions fail on `160dabd3` at width `0.4` and pass at `0.7`; the ping-pong test now asserts Ping, Column 2, three Place calls and two executed lists. `layout floating` followed by `layout tiling` is the same-workspace re-entry trigger, through `WindowRelayout`. The guard also covers overlapping tasks and shared global Place definitions without task tracking or a status counter. No default changed.

The same owned-window guest script ran three chain trials per tree: the new build lands on workspace 3 with width `0.5` in all three; the base lands there with the configured `0.3` and the old suppression message in all three. The new loop ends on Ping, Column 2, with one path-named suppression; the base ends on Pong, Column 3. Dry-run preview and floating-to-tiling transfer checks pass on both. Numbered workspaces 2 and 3 are created before staging; a literal workspace named `3` created by Arrive is not itself the third automatic workspace. The proof config and script are in `.scratch/winmux-fork/proofs/nested-run-chains/`. All five fenced Columns-guide examples pass the real helper.

The builder publishes no release.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- The **Declined** list of pull request [#32](https://github.com/prateek/winmux/pull/32), and the decision above it there.
- [`docs/columns.md`](https://github.com/prateek/winmux/blob/fork/docs/columns.md)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
