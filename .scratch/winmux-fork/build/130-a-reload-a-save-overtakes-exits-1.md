# A `reload-config` that a save's reload overtakes exits 1

Part of {{UMBRELLA}}.

## What to build

With `reload-on-save` on, saving `winmux.ncl` starts a reload. A `winmux reload-config` run right after the save can lose the race: `ConfigReloadState.loaded` answers `.supersede` for any request that is no longer the newest, and `ConfigReloader.request` then returns `.success(false)` with the text "A later reload replaced this one" (`ConfigReloader.swift`). The command exits 1. The reload that replaced it may have loaded the same file and succeeded, so the exit status says the config failed when it did not.

This is what an agent editing the config meets every time: it saves the file, then runs `reload-config` to learn whether the config loaded. **A skill for a person's agent, shipped with the CLI** tells the agent to run it once more and to report any output that is not a problem in its file, instead of reading the exit status alone.

## Decisions

- **A command reload that a newer reload overtakes answers with the newer reload's result.** It waits for the attempt that replaced it and returns that attempt's success or failure and its text, so `reload-config`'s exit status and output describe the config WinMux now has.
- A dry run and a reload that a newer command reload overtakes behave as now.

## Depends on

Nothing.

## Done when

- [ ] A test in which a save's reload overtakes a command reload shows the command returning the newer reload's result: 0 for a good file, 1 with the file's diagnostic for a bad one.
- [ ] In a guest with `reload-on-save` on, writing the config and running `reload-config` at once exits 0 for a good file.
- [ ] The agent skill's reload step drops the sentence about a reload that replaced this one.

## Sources

- Pull request #267's third review round, against `ConfigReloader.request` at `160d9a46`.
