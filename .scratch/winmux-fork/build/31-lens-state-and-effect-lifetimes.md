# Lens state, events and effect lifetimes, with controlled time

Part of {{UMBRELLA}}.

## What to build

[LensSession](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/lens/LensSession.swift) chains Search and selection changes through property observers. Ownership of a session's effects is split among it, `LensLifecycle`, `LensInlineSearch`, `MiniatureSession` and `SwitcherPalettePanel`, and each caller has to keep the ordering rules by hand. [LensInlineSearchTest](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundleTests/LensInlineSearchTest.swift) waits on a real 10 ms debounce and a real 20 ms deadline.

This issue makes the Lens workflow's transitions explicit and gives the session's effects one owner, so the behaviour can be followed and tested through one module's interface. It also puts the Lens's timing under a controlled clock: the Search debounce and display deadlines, the strip's display delay, and thumbnail polling.

It changes nothing a person can see. It lands before the Tile and grid issues that follow in the umbrella, because they are built on the explicit-lifecycle session this produces, not on today's property-observer chain.

This is a demonstrated ownership and testability problem, not a claim that a visible defect exists. The existing Lens generation checks already protect substantial behaviour. Start from the current `fork` and recheck the observations above.

## Decisions

**State and events**

- Mutually exclusive lifecycle states are represented precisely: closed, opening, a strip session that is ready but not yet presented, and presented. A single `open` flag is not enough for event timing.
- Domain events are handled explicitly: Search changes, selection changes, modifier release, Presentation changes and dismissal. Related state is updated together, and then the required effects are started or cancelled.
- Reducer-style events are for meaningful workflow behaviour only. Pointer samples and layout operations do not go through a new global event system. Local focus, scroll and animation state stays local where it does not decide workflow behaviour.
- Each state value is authoritative. Task handles, process handles, AppKit objects and effect execution stay outside any value-state model used for transitions.

**Effects**

- Inline Search, landing prediction, the delayed strip display and thumbnail refresh are owned under the appropriate Lens lifetime. Internal modules may still implement each effect.
- Generation or request identities are kept wherever cancellation is cooperative or a dependency can still return late.
- The newest Search and the newest landing selection win. Cancellation ends owned work and cannot clear or overwrite a newer operation's state.

**What is preserved**

- Search memory, selection and marks, actions over the selected window versus the marked windows, inline-Filter failure behaviour, the opening strip's steps, release before ready, and Presentation conversion.
- The documented subscription event semantics: one opening and closing pair only for a presented session, no events for a quick strip tap that never draws, and no new pair when the Search or the Presentation changes. Named and ad-hoc payload identity is kept.
- The existing strip-close behaviour and regressions; **`close` reports success on a window with no close button, and the strip drops its entry** is independent and has not landed.

**Time**

- Clocks are injected into the Search debounce and display deadlines, the strip display delay and thumbnail polling.
- Policy tests advance a controlled clock. Dependencies are suspended with continuations or explicit signals; a sleep is never used as synchronization.
- A test fails clearly if it reaches an unconfigured live dependency.

**Scope of the change**

- Existing Swift types and narrow internal seams are the default. Full TCA adoption and a root store for the app are out.
- The deletion test applies: the change removes caller choreography. A forwarding module alone does not count.
- Actor isolation around AppKit and live window objects stays as it is.

## Not in this issue

- Any change to what a Lens shows or how it looks. The Tile, grid, sections and peek issues in this umbrella own that.
- **One meaning for Column placement, shared by the Lens landing hint** covers what a landing is. This issue covers when the evaluation runs and who cancels it.
- **Config reload attempts and Policy hook completion, each with one owner** covers the save-scheduling clock, helper retry and backoff, and the window-refresh strategy in `layout/refresh.swift`.
- A universal effect runner built ahead of the workflows that need it.

## Depends on

- **One meaning for Column placement, shared by the Lens landing hint**, so the landing evaluation this issue takes ownership of is already the shared one.
- **`close` reports success on a window with no close button, and the strip drops its entry** is independent. Whichever lands second keeps the other's behaviour and tests.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **A library.** Swift Clocks or Dependencies may be used where one removes concrete work. Explain the tradeoff in the pull request; adding a framework is not an acceptance criterion.
- **Where the owner lives.** `LensSession` or a new type beside it; the builder's call.
- **How many pull requests.** State and effect ownership first, controlled time second, or both together if the clock is needed to test the first.

## Done when

- [x] The owner of every session effect and its cancellation trigger is explicit. Dismissal or replacement leaves no session-owned polling and no late publication.
- [x] Tests cover an overtaken opening, release before readiness, dismissal while Search or landing evaluation is suspended, strip-to-list conversion, and repeated dismissal.
- [x] Event tests distinguish ready from presented, verify that a quick tap is silent, and verify one pair across Presentation changes.
- [x] Existing behaviour tests survive or are replaced by equivalent tests through the new interface. No test is removed only because the implementation moved.
- [x] The Lens timing tests use controlled time and finish without wall-clock sleeps.
- [x] Deadline tests prove there is no result just before a deadline, a result at it, and that a late response is rejected, including from a dependency that does not promptly honour cancellation.
- [ ] A live run in a guest shows the strip, the list and `overview` behaving as before, and the pull request says what was not checked.

## Build result

`LensLifecycle` is the effect owner. Its state is closed, opening (name, gesture, accumulated steps and recorded release), strip-ready or presented. `LensSession` holds observable data and applies explicit events; the panel holds AppKit presentation/input work. Landing uses the existing resolver and caches destination records; Column-state replacement re-evaluates inside the same task. Every late effect reply and task cleanup checks its request/session identity.

Decided: **Where the owner lives** changes to the existing `LensLifecycle`, grown into the owner, rather than a new adjacent type or `LensSession`.

Decided: **A library** uses exact Swift Clocks 1.1.1 in the test target only; production uses standard-library clocks and initializer dependencies. Swift Dependencies and TCA are not added. The test dependency resolves/builds on the guest's pinned Swift toolchain and through the release project's package resolution.

Decided: **How many pull requests** is one, as ruled by the relay. State, ownership and clocks are built together, with separate reviewable commits.

The first six Done-when items pass host/guest checks and controlled-time tests. The guest live item remains unchecked: while enabling Do Not Disturb, macOS showed an unsolicited “Click Wallpaper to Show Desktop Items” onboarding banner. The builder stopped the live run as required, before launching WinMux or owned demo windows. A cleanup capture also showed the macOS Tips card “See what’s new in macOS Tahoe”. Strip/list/overview equivalence, subscription/live focus readbacks and five-open timings on this branch versus the baseline therefore have no live result. The image must be clean before those checks can run. No release or physical-device checks were performed.

## Sources

- [Issue #53](https://github.com/prateek/winmux/issues/53), workstream 4 and the Lens parts of workstream 5.
- [LensSession.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundle/lens/LensSession.swift) and [LensInlineSearchTest.swift](https://github.com/prateek/winmux/blob/f438e6905718e78f5839c8754784e5b179dfe90d/Sources/AppBundleTests/LensInlineSearchTest.swift)
- [Subscription events](https://github.com/prateek/winmux/blob/fork/docs/events.md)
- [TCA state and effect testing](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md), [Swift Clocks](https://github.com/pointfreeco/swift-clocks), [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
