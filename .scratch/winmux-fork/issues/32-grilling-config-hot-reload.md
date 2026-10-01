# Grilling: config hot reload

Type: grilling
Status: resolved

## Question

Should WinMux reload its config when the file changes, and how? [Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md) settled the swap (a fresh helper loads and smoke-runs, then replaces the old one atomically; a failed load keeps the old config) and gave WinMux the resolved list of imported files on every load. What's left:

- Whether reload on save is on by default, or `reload-config` stays the only trigger.
- What gets watched (the config file plus its imports, re-armed after each load), and how editor save patterns are handled: atomic rename, several writes in a row, a half-written file. Pick a debounce.
- Where a failed reload's diagnostic shows beyond the notification (a log file, `winmux config status`, an overlay), and whether a repeat of the same error is silenced.
- Whether a change to bindings or Triggers applies while a mode or a Lens is active, or waits for it to close.
- Whether a file change resets the helper's circuit breaker the way `reload-config` does.

## Answer

Resolved 2026-09-30 with Prateek.

- **Reload on save is on by default.** A `reload-on-save` setting turns it off, leaving `reload-config` as the only trigger. A failed load keeps the old config, so a bad save costs nothing.
- **What's watched.** The config file and every file it imports, from the resolved list the helper returns on each load. The watch is re-armed after every load, successful or not, so a newly added import is picked up.
- **Save patterns.** WinMux watches the containing directories, so an atomic rename is seen. It waits 300 ms after the last change before loading, which folds a burst of writes into one reload. A half-written file fails to load and the old config stays.
- **Where a failure shows.** A notification, the last error in `winmux config status`, and the log. An identical error is not notified again until the file changes to something that fails differently or loads.
- **Reload while something is active.** New bindings and Triggers apply immediately. The current mode is kept if it still exists; otherwise WinMux returns to `main`. An open Lens keeps its already-filtered entries until it closes, as the evaluator ticket decided.
- **Circuit breaker.** A file change resets the helper's circuit breaker the same way `reload-config` does, as [Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md) anticipated.
