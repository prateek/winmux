# Grilling: config hot reload

Type: grilling
Status: open

## Question

Should WinMux reload its config when the file changes, and how? [Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md) settled the swap (a fresh helper loads and smoke-runs, then replaces the old one atomically; a failed load keeps the old config) and gave WinMux the resolved list of imported files on every load. What's left:

- Whether reload on save is on by default, or `reload-config` stays the only trigger.
- What gets watched (the config file plus its imports, re-armed after each load), and how editor save patterns are handled: atomic rename, several writes in a row, a half-written file. Pick a debounce.
- Where a failed reload's diagnostic shows beyond the notification (a log file, `winmux config status`, an overlay), and whether a repeat of the same error is silenced.
- Whether a change to bindings or Triggers applies while a mode or a Lens is active, or waits for it to close.
- Whether a file change resets the helper's circuit breaker the way `reload-config` does.
