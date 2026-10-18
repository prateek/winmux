# Dotfiles handoff

Changes the relay wants in Prateek's dotfiles, which it does not edit. `AGENTS.md`'s **Scope and compatibility** says when an entry is added. Prateek reconciles the file against the dotfiles; a reconciled entry moves under **Done** and stays.

Each entry is a bullet with the date and the pull request, or where it came from when there was none, then what to change, where in the dotfiles, and why, with the exact lines where they are known. The repository is public: no home paths, usernames, machine names or secrets.

## Pending

Nothing.

## Done

- **2026-10-17, from the relay's speed review.** Add Orca's `codex-accounts/*/home/sessions` root to agentsview's `[agents.codex] dirs` in the chezmoi template for agentsview's `config.toml`, so the relay's builder rollouts land in the agentsview store. Reconciled by the dotfiles commit "fix(agentsview): reconcile Orca Codex homes in place".
