# `arrive` is skipped when its refresh session is cancelled

Part of {{UMBRELLA}}.

## What to build

A new window's `arrive` hook runs inside the refresh session that detected the window. A hotkey pressed while the hook gathers its arguments cancels that session, and the hook call goes with it: `ColumnPolicy` catches the `CancellationError`, returns no result, and the window gets the built-in placement. `arrive` is not asked again, so the window misses its routing, its float and its `run` list, with nothing recorded as a failure. This issue makes a cancelled session no reason to skip `arrive`.

## Decisions

- A new window gets its `arrive` call once, whether or not the refresh session that detected it is cancelled. The same holds for the second `arrive` at popup promotion.
- The call is shielded from the session's cancellation and finishes; it is not started again later. A hook is a pure function, so one finished call is enough, and a retry would need somewhere to remember the windows still owed one.
- The 50 ms helper deadline still bounds the call. A hook that times out, raises or breaks its contract gets the built-in placement, as today.
- The checks after the await stay: a window that closed or moved while the hook ran abandons the action without a dialog.
- `place` and `move-boundary` calls made on behalf of a command keep following their command's cancellation.

## Not in this issue

- Any change to the helper's supervision, its deadline or its request order.
- **Nested `run` lists: let a chain through, stop a loop** covers which `run` lists execute.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Where to shield.** The hook call in `Sources/AppBundle/tree/ColumnPolicy.swift` gathers the Window record, the Filter context and the Column records in a task group, then asks the supervisor. For `arrive`, run that whole call in a task that does not inherit the session's cancellation, and await its value.
- **What the cancelled session does with the answer.** The placement is applied by the shielded task itself, so it does not depend on the cancelled session still running. The next refresh sees the window already placed.
- **A window whose session is cancelled before `arrive` starts.** The next refresh that sees the window still unplaced runs `arrive` for it.
- **Recording.** A hook call that is cancelled anyway, such as at quit, records nothing, as today.

## Done when

- [ ] A test cancels the refresh session while `arrive` gathers its arguments, and the window ends where the hook's result sends it, with its `run` list executed. The test fails without the change.
- [ ] The same test for an `arrive` that returns `float = true`, and for one that returns a `workspace`.
- [ ] A window that closes during the shielded call is not bound anywhere and raises no dialog.
- [ ] A hook slower than 50 ms still gets the built-in placement.
- [ ] The existing `ColumnPolicyTest` and `FixedColumnsTest` pass unchanged.
- [ ] In a live run with an `arrive` hook that routes a window to another workspace, opening the window while pressing a bound hotkey repeatedly still routes it. The run is repeated ten times and every one routes.

## Sources

- The **Declined** list of pull request [#32](https://github.com/prateek/winmux/pull/32).
- [`docs/columns.md`](https://github.com/prateek/winmux/blob/fork/docs/columns.md)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
