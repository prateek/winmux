# A `reload-config` that a save's reload overtakes exits 1

Part of {{UMBRELLA}}.

## What to build

With `reload-on-save` on, saving `winmux.ncl` starts a reload 300 ms later (`ConfigFileWatcher`'s debounce). A `winmux reload-config` requested before that reload can lose to it in two ways, both in `ConfigReloader.swift`: `ConfigReloadState.loaded` answers `.supersede` when the command's load finishes after the newer request, and a command already waiting in `pending` is resumed with `false` when the newer request arrives. Either way `request` returns `.success(false)` with the text "A later reload replaced this one", and the command exits 1. The reload that replaced it may have loaded the same file and succeeded, so the exit status says the config failed when it did not.

The race is narrow: the command must be requested within the debounce and still be loading when the save's reload is requested. An agent that saves and reloads at once can meet it. **A skill for a person's agent, shipped with the CLI** tells the agent to show the person that output rather than edit the file.

## Decisions

- **A command reload that a save's reload overtakes answers with the save's reload's result**, by either path above. It waits for the attempt that replaced it and returns that attempt's success or failure and its text, so `reload-config`'s exit status and output describe the config WinMux now has.
- A dry run, and a command reload that another `reload-config` overtakes, behave as now.

## Depends on

Nothing.

## Done when

- [ ] Tests for both paths, in which a save's reload overtakes a command reload, show the command returning the save's reload's result: 0 for a good file, 1 with the file's diagnostic for a bad one.
- [ ] The agent skill's reload step no longer lists "A later reload replaced this one" among the outputs it shows the person.

## Sources

- Pull request #267's third review round, against `ConfigReloader.request` at `160d9a46`.
