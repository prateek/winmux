# Config reload attempts and Policy hook completion, each with one owner

Part of {{UMBRELLA}}.

## What to build

Two workflows depend on knowledge spread across their callers.

- [ReloadConfigCommand.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/command/impl/ReloadConfigCommand.swift) coordinates candidate helpers, application, notifications, watchers and events through global state. The handoff says tests avoid `reloadConfig` and `applyConfig` because they affect login items and launch-agent files in the real home directory, so no test exercises a whole reload attempt.
- [ColumnPolicy.place](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/tree/ColumnPolicy.swift#L183) and [MoveCommand](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/command/impl/MoveCommand.swift#L28) each assemble evaluation, stale-result checks, mutation, normalization and `run` execution.

This issue gives the config reload module ownership of a complete attempt, and concentrates the common completion rules in the Policy hook module. It puts the timing of both under a controlled clock where deterministic tests add value. Each part is its own pull request.

It does not touch Lens code and does not conflict with the Lens issues in the umbrella.

These are demonstrated ownership and testability problems, not a claim that every path has a visible defect. Start from the current `fork` and recheck the observations above.

## Decisions

**Config reload attempts**

- The active configuration is modelled separately from loading and application: an older config keeps serving while a new candidate loads or fails.
- The public interface expresses requesting a reload and observing its result. Internally there are explicit transitions for requests, load results, application results and pending work. Helper preparation and adoption are separated from runtime application and observable reporting with focused adapters, not a broad application-wide environment.
- Every existing entry point converges on this behaviour: CLI, menu, Settings, startup and saves. The save scheduler still does debounce and coalescing.
- A newer non-dry-run request supersedes an older candidate that has not begun adoption or application. The superseded helper is disposed of, and its caller keeps its existing result and diagnostic.
- Dry runs neither supersede nor are superseded by ordinary reloads. They dispose of their candidates, adopt nothing, do not update watcher state and emit no `config-reloaded`. Existing diagnostic options are preserved.
- `@MainActor` does not prevent interleaving across `await`. Once adoption or application begins, that attempt completes before another candidate is applied. Requests arriving during application are represented explicitly. Loading may overlap if ownership stays clear.
- That serialization is a proposed ordering refinement, not something the code guarantees today. Characterize the current behaviour, and make the resulting ordering visible in tests and in the pull request. Define each explicit caller's completion result and the save-coalescing behaviour. No waiter and no candidate helper is stranded.
- A failure before adoption keeps the serving config and helper. If application throws after adoption, the established partial-application contract holds: report failure and watch the adopted candidate's imports. No rollback or full atomicity is claimed.
- Preserved: notification deduplication, warnings, mode retention, disabled and startup behaviour, file-removal handling, import watch updates and failed-load recovery watches.
- Preserved: the [subscription event contracts](https://github.com/prateek/winmux/blob/fork/docs/events.md). Each completed ordinary reload emits once. Superseded loads and dry runs emit nothing. Ignored or deferred saves emit only if they later become a completed reload. Payload paths and errors are unchanged.
- #42 owns keyboard-layout parity and the narrow superseded-reload event test. This issue broadens reload testability and keeps or strengthens that coverage. Its rule against calling the live `reloadConfig` and `applyConfig` in tests holds until the effects are actually isolated.

**Policy hook completion**

- Placement and movement callers no longer each reconstruct the evaluate, recheck, mutate, normalize, run sequence. The shared rules have one owner.
- Only rules that genuinely match are shared. Placement, arrival and movement have distinct fallback, abandonment and cancellation semantics, and those stay explicit.
- The existing ancestry and binding revision checks, and the destination Column identity checks after awaits, are kept, including the second await when movement asks Place for the Overflow policy.
- Preserved: routing before destination placement, normalization before `run`, command result behaviour, and built-in placement when a hook fails.
- The decisions and tests from #39 and #40 are preserved. Arrival work survives the cancellation of the refresh that detected the window, including popup promotion, while command-owned `place` and `move-boundary` work follows its command. Nested `run` chains and loop suppression by window and hook definition stay as #40 defines them.
- The helper process and its real and controlled adapters stay. Movement scenarios may use the same controlled dependency seam as placement scenarios, and do not adopt a helper into `NickelSupervisor.shared` only for a test.

**Controlled time and cancellation**

- Clocks are injected into save scheduling, and into helper retry and backoff policy where deterministic policy tests add value. Process integration tests for real timeout, kill and recovery behaviour stay.
- Policy tests advance a controlled clock. Dependencies are suspended with continuations or explicit signals; a sleep is never used as synchronization.
- Cancellation policy is specific to the operation: an active window-refresh pass finishes and drains coalesced follow-up work; an application already begun follows the reload contract; arrival follows #39.
- The refresh strategy in `layout/refresh.swift` is kept. Its comments document starvation under cancel-and-restart during window-event bursts. Generic cancel-in-flight does not replace it.
- A test fails clearly if it reaches an unconfigured live dependency.

**Scope of the change**

- [ADR-0001](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md) stands: Nickel stays in a supervised helper process.
- Existing Swift types and narrow internal seams are the default. Full TCA adoption, a root store for the app, and moving the AX window tree or per-frame layout into reducers are out.
- Each state value is authoritative. Tasks, process handles, AppKit objects and effect execution stay outside any value-state model used for transitions.
- The deletion test applies: the change removes duplicated knowledge or caller choreography. A generic forwarding module alone does not count. An internal seam is justified by behaviour that actually varies, such as live versus controlled effects.
- Helper supervision and the stale-result guards stay.

## Not in this issue

- **One meaning for Column placement, shared by the Lens landing hint** covers what a placement resolves to.
- **Lens state, events and effect lifetimes, with controlled time** covers the Lens session and its clocks.
- The keyboard layout tables, which #42 owns.
- A universal effect runner built ahead of the workflows that need it.
- A release. No pull request for this issue runs `script/dogfood-release`.

## Depends on

- **`arrive` is skipped when its refresh session is cancelled** and **Nested `run` lists: let a chain through, stop a loop**, for the Policy hook part, so their behaviour is preserved and not reimplemented independently. The Policy hook part lands after them or stacked on them.
- **Tests for the keyboard layout tables and for a superseded reload**, for the reload part: coordinate with it and keep its regression test.
- **One meaning for Column placement, shared by the Lens landing hint** should land first if both are in flight, since both touch `ColumnPolicy`.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Order.** Reload coordination with its clock and dependency seams first, then Policy hook completion, then the remaining timing-policy coverage and cross-workflow regression checks. Clock work may accompany the part that needs it.
- **A library.** Swift Clocks or Dependencies may be used where one removes concrete work. Explain the tradeoff in the pull request; adding a framework is not an acceptance criterion.
- **Actor isolation** around AppKit and live window objects stays as it is.
- **The handoff.** Update its guidance on reload tests once tests can safely exercise the new interface.

## Done when

**Config reload attempts**

- [ ] Tests exercise the real coordination interface with controlled loading and application and explicit completion signals, without touching real home files, login items, hotkeys or production helpers.
- [ ] The cases cover older and newer load completion in either order, an older failure, dry runs interleaved with reloads, requests during suspended application, and failure after adoption.
- [ ] Assertions cover the active config and helper, watched imports, the reported result, candidate disposal, notification behaviour and emitted events, not only a ticket counter or internal call order.
- [ ] Save bursts, saves during reload, startup deferral, missing config and disabled-server behaviour keep coverage through their actual wiring.
- [ ] The existing real-helper and filesystem watcher integration tests remain, and #42's reload guarantees are incorporated without weakening its regression test.

**Policy hook completion**

- [ ] The shared completion rules have one owner, and commands no longer duplicate the corresponding lifecycle protocol.
- [ ] The existing races remain covered: closed, unbound or moved windows during record collection or helper evaluation, replacement Columns, abandoned destination placement, and suppressed follow-on commands where required.
- [ ] Real-helper contract coverage, no-hook behaviour, popup promotion and the #39 and #40 regression scenarios pass.
- [ ] The pull request says which rules were unified and which intentionally stay operation-specific.

**Time and cancellation**

- [ ] The touched timing-policy tests use controlled time and finish without wall-clock sleeps. Necessary process and filesystem integration timing stays separate.
- [ ] Deadline tests prove there is no early result and that a late result is rejected, including from a dependency that does not promptly honour cancellation.
- [ ] Refresh-burst coverage shows the active pass completes and coalesced work drains, with no starvation and no lost work.
- [ ] Effect-lifetime tests show that cancellation ends owned work and cannot clear or overwrite a newer operation's state.

**Overall**

- [ ] CLI, config and helper contracts, subscription events, Column invariants and the cancellation distinctions keep their coverage.
- [ ] The last pull request records the checks run, live evidence and remaining limits.

## Sources

- [Issue #53](https://github.com/prateek/winmux/issues/53), workstreams 2 and 3 and the non-Lens parts of workstream 5.
- [ReloadConfigCommand.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/command/impl/ReloadConfigCommand.swift), [ColumnPolicy.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/tree/ColumnPolicy.swift#L183) and [MoveCommand.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/command/impl/MoveCommand.swift#L28)
- [Subscription events](https://github.com/prateek/winmux/blob/fork/docs/events.md)
- [TCA state and effect testing](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md), [Swift Clocks](https://github.com/pointfreeco/swift-clocks), [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
