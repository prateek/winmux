# Nickel runs in a supervised helper process

WinMux's config is Nickel, and Filters and Policy hooks are Nickel functions called many times a day. `nickel-lang-core` leaks memory on almost every call that touches its stdlib ([nickel-lang/nickel#1908](https://github.com/nickel-lang/nickel/issues/1908), open since 2024, no fix in sight), and dropping the engine frees nothing. So WinMux never links Nickel. A small Rust binary, `winmux-nickel`, ships inside the app, evaluates the whole config, and answers calls over a pipe; WinMux replaces it on config reload and when its memory passes a threshold, which throws the leak away.

## Considered options

- **In-process, with WinMux restarting itself on a memory threshold.** A restart drops the window manager's runtime state (focus history, thumbnails, observers) and the link adds 31 MB.
- **Patch Nickel with cycle collection.** A deep change to a 0.x evaluator that upstream has no plan for; we would carry the fork.
- **Pick another config language.** Throws away a settled choice over one bug that a process boundary contains.

A pipe call costs the same as an in-process call (about 2 ms for a 50-window Lens, 0.2 ms for `place`), and a respawn takes about 8 ms. Nickel's own language server contains the same leak the same way ([nickel-lang/nickel#1869](https://github.com/nickel-lang/nickel/pull/1869)). If upstream fixes the leak, the helper is still worth keeping: a Nickel crash or hang can't take the window manager down.
