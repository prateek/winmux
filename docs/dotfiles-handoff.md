# Dotfiles handoff

Changes the relay wants in Prateek's dotfiles, which it does not edit. `AGENTS.md`'s **Scope and compatibility** says when an entry is added. Prateek reconciles the file against the dotfiles; a reconciled entry moves under **Done** and stays.

Each entry is a bullet with the date and the pull request, or where it came from when there was none, then what to change, where in the dotfiles, and why, with the exact lines where they are known. The repository is public: no home paths, usernames, machine names or secrets.

## Pending

## Done

- **2026-10-13, #135, recorded after the fact.** The dotfiles config removed the shipped Control and Command chords with `std.record.remove`; once #135 dropped them from the defaults, every launch failed with ``missing field `ctrl-q` `` and ran on built-in defaults. Reconciled by the dotfiles commit "fix(winmux): stop removing chords the defaults no longer bind", which merges straight over the defaults.
- **2026-10-17, from the relay's speed review.** Add Orca's `codex-accounts/*/home/sessions` root to agentsview's `[agents.codex] dirs` in the chezmoi template for agentsview's `config.toml`, so the relay's builder rollouts land in the agentsview store. Reconciled by the dotfiles commit "fix(agentsview): reconcile Orca Codex homes in place".
- **2026-10-18, #241.** In the WinMux config managed by the dotfiles, change Option-9 to focus the last tab and delete the Option-0 binding so it reaches the focused app, matching the new defaults. In the TOML's `[mode.main.binding]`, replace the `alt-9` line with `alt-9 = "focus --tab-index last"` and delete `alt-0 = "focus --tab-index 10"`. In a `winmux.ncl` converted from that TOML, the same two lines sit inside `converted-modes`, under `main`'s `binding` record: change `alt-9 = "focus --tab-index 9",` to `alt-9 = "focus --tab-index last",` and delete `alt-0 = "focus --tab-index 10",`. Conversion preserves these user-owned chords, so upgrading alone does not change them. Reconciled with no change: the dotfiles config is hand-written Nickel merged over `winmux/defaults.ncl`, not a TOML conversion, and binds neither chord, so it already inherits the new defaults.
