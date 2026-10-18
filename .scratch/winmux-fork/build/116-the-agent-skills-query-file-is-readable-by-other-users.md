# The agent skill's query file is readable by other users

Part of {{UMBRELLA}}.

## What to build

The bundled agent skill, which `winmux agent skill` prints, tells an agent to write its query to `/tmp/winmux-agent.json`, read it, edit it and apply it. The file holds every window's title, app and frame. Written under the default umask it is mode 644 in a world-listable directory, so every user on the Mac can read it, and another user can create it first and own what the agent reads and applies.

**The CLI socket moves out of `/tmp`, and the docs say who can use it** made the socket reachable only by the person's own processes. The skill's file keeps the same titles readable outside that boundary.

## Decisions

- **The skill's file lives where only the person can read it.** Other users cannot read it or put it there first.
- **The skill's file workflow stays**: query to a file, read that exact file, edit it, apply that exact file.

## Defaults chosen for you

- **Where.** A path the skill can name without the agent expanding an environment variable it may not have: `winmux agent query` could choose and print the path when `--path` is left out, under the same per-user directory as the socket.

## Depends on

**The CLI socket moves out of `/tmp`, and the docs say who can use it**.

## Done when

- [ ] The skill text names no path under `/tmp`.
- [ ] The file the workflow writes is mode 600, or in a mode-700 directory, checked in a test.
- [ ] `AgentCommandTest` covers the new path in the skill text.

## Sources

- Found while building **The CLI socket moves out of `/tmp`, and the docs say who can use it**, 2026-10-18, in `Sources/AppBundle/command/impl/agent/AgentCommand.swift`.
