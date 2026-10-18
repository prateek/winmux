# First-run setup

WinMux loads your config before setup. When Accessibility is missing, or Screen Recording is missing without a saved decline, its setup window describes each permission and opens the matching System Settings pane. Each button requests that permission before opening Settings, so macOS can add WinMux to the list. The window updates about once a second. Accessibility is required; **Continue without Screen Recording** keeps tiling available with degraded pictures and previews, and saves your choice.

Screen Recording can require a relaunch before the granting process can use it. **Relaunch WinMux** reopens WinMux with its current environment, including `XDG_CONFIG_HOME` and `XDG_STATE_HOME`. macOS's **Quit & Reopen** also returns at Go: the reopened process finds the pending setup in its state file. It starts with macOS's launch environment and no arguments, so a launch with its own `XDG_STATE_HOME` or `--config-path` loses them on that path. If the live grant cannot be read, WinMux offers the relaunch after you open Screen Recording Settings and grant Accessibility; the new process checks again. You can always quit.

Once permissions are ready, the window explains that WinMux will arrange the windows on this screen. It reads `restore-windows-on-quit` from your loaded config: quitting restores the original frames when on, and centres windows when off. **Start WinMux** begins window discovery and arrangement and reveals the sidebar. Closing setup without starting is done with **Quit**. A launch interrupted before Start returns to this step, even if both grants are now present.

An existing install with both grants and no pending setup starts with no window. An existing install with Accessibility alone sees setup at its next launch, until Screen Recording is granted or declined. Config errors still have their own error window. WinMux registers no hotkey until Start, so every chord, Cmd-Tab included, still reaches the system and your apps while setup waits.

## CLI during setup

`config status`, `config --config-path`, `config --get <key>` (including `--keys`), `config --major-keys`, `config --all-keys`, and the `--version` handshake work during setup without reading or refreshing the window model. Help and parse errors retain their usual behavior. Other server commands, including subscriptions, exit 1 with the missing permission's System Settings location or a message asking you to start WinMux in its setup window. Local `config check`, `config convert` and `config schema` continue to run without the app.

`config status` retains its existing `state`, `pid`, `rss`, `recycles`, `last-error` and `config-path` keys and adds:

```json
{
  "permissions": {
    "accessibility": "granted",
    "screen-recording": "missing",
    "setup": "waiting-for-permissions"
  }
}
```

Both permission keys are always present and read live. Accessibility is `granted` or `missing`. Screen Recording is `granted`, `missing` or `granted-relaunch-needed` when a fresh child can read a grant the current process cannot yet use. `setup` is `done`, `waiting-for-permissions` (including a needed relaunch), or `waiting-for-go`. A declined Screen Recording permission remains `missing` even when setup is `done`.

## Saved choice

`$XDG_STATE_HOME/winmux/setup.json`, falling back to `~/.local/state/winmux/setup.json` (`setup-debug.json` for a debug build, which has grants of its own), stores `pending` and `screenRecordingDeclined`. Start clears `pending`; a recorded decline survives. Granting Screen Recording later requires no change to this file. Deleting the file forgets the choice; setup then follows the current grants. If either launch-time grant is missing, setup waits before window observers and the startup refresh begin. When Accessibility is missing at a launch with no setup pending, WinMux resets its Accessibility entry to clear a stale one from an earlier signature, before its setup button registers the app again. A launch with setup pending keeps the entry the button made.
