# Ultrawide Zones

WinMux zones split one physical ultrawide monitor into named workspace
viewports. A common setup is `Reference` on the left, `Work` in the center, and
`Comms` on the right. Each zone has its own active workspace and layout pass.

Use this guide when you want to dogfood zones without reading the implementation
plan.

## Install

Install WinMux, then launch it once so macOS can ask for permissions.

```bash
xattr -dr com.apple.quarantine /Applications/WinMux.app/
open /Applications/WinMux.app
```

WinMux reads `~/.config/winmux/winmux.toml` by default. If the file does not
exist, WinMux creates one from `resources/default-config.toml`.

## Permissions

Open System Settings and grant the permissions WinMux needs:

- Accessibility: lets WinMux inspect and move windows.
- Screen Recording: lets WinMux build previews and run visual diagnostics.
- Automation: lets configured commands interact with apps when you choose to use
  AppleScript or app automation.
- Input Monitoring: lets global keyboard and mouse bindings work.

Check the current state with:

```bash
winmux doctor
```

## Fast Setup

For a new config, use the setup assistant. Start with a dry run:

```bash
winmux zone init --dry-run --preset balanced
winmux zone init --preset balanced --write
winmux config --check ~/.config/winmux/winmux.toml
winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'
```

`--write` keeps a backup before editing the config. If you already have
unmanaged active `[[zones]]`, the assistant will not overwrite them unless you
remove the unmanaged block or use `--replace-existing` on a WinMux-managed block.

Available setup presets are:

- `balanced`: Reference 25%, Work 50%, Comms 25%.
- `focus-only`: narrow side zones and a wide Work zone.
- `comms-open`: gives Comms more room.
- `dashboard`: adds a fourth Dashboard zone.

## Starter Template

Fresh configs include a commented block named `WINMUX ULTRAWIDE ZONES TEMPLATE`.
Uncomment that block if you prefer to hand-edit TOML. It defines:

- a balanced `[[zone-layouts]]` preset;
- a focus layout;
- `[[zone-scenes]]` for triage and deep work;
- focus-only, communications, and full-dashboard availability sets;
- default zone-mode bindings;
- a `mouse.zone-snap` starter policy.

After editing, run:

```bash
winmux config --check ~/.config/winmux/winmux.toml
```

## Keyboard Commands

The default config includes `alt-z = 'mode zone'`. In zone mode:

```toml
h = ['focus-zone prev', 'mode main']
l = ['focus-zone next', 'mode main']
shift-h = ['move-node-to-zone --focus-follows-window prev', 'mode main']
shift-l = ['move-node-to-zone --focus-follows-window next', 'mode main']
minus = ['resize-zone current width -10%', 'mode main']
equal = ['resize-zone current width +10%', 'mode main']
"0" = ['balance-zones', 'mode main']
t = ['toggle-zone current', 'mode main']
space = ['layout floating tiling', 'mode main']
s = ['cycle-zone-snap-policy freeform snap-to-zone', 'mode main']
```

Zone selectors accept ids or names when they are unique. They also accept
`current`, `next`, and `prev`, scoped to the focused physical monitor. If two
monitors reuse the same zone id, qualify the selector with the monitor, such as
`1:left`.

Useful direct commands:

```bash
winmux focus-zone Comms
winmux move-node-to-zone --focus-follows-window Work
winmux resize-zone Work width +10%
winmux balance-zones --monitor 1
winmux toggle-zone Comms
winmux use-zone-profile focus-only
winmux use-zone-profile communications
winmux cycle-zone-style current urgent calm
```

## Overview (Exposé)

The starter template binds Ctrl+Up to a zone overview of the focused display
and Ctrl+Down to a window overview of the focused zone:

```toml
ctrl-up = 'zone-expose display'
ctrl-down = 'zone-expose zone'
```

Select a tile with arrows and Return, a number key, or a click; Escape
closes. Zone previews come from cached screenshots captured after workspace
transitions and need the Screen Recording permission (the first overview use
prompts once); without it tiles show labels only. macOS's own Mission
Control shortcuts may shadow Ctrl+Up/Down — disable them in System Settings
> Keyboard > Shortcuts > Mission Control if nothing happens.

## Mouse

For a one-handed mouse flow, use secondary-button drag:

```toml
[mouse.zone-snap]
policy = 'float-unless-snap'
modifier = 'alt'
gesture = 'secondary-button-drag'
target = 'zone'
```

With `float-unless-snap`, a normal drag leaves the window floating. Holding the
configured gesture during the drag shows the whole-zone overlay and snaps on
release.

Use `target = 'window'` when you want the same gesture to snap onto a slot
inside an existing window instead of the whole zone:

```toml
[mouse.zone-snap]
policy = 'float-unless-snap'
modifier = 'alt'
gesture = 'secondary-button-drag'
target = 'window'
```

The window target shows slot overlays such as `Window slot: Right`. It keeps the
drag inside the current zone unless you configure a zone target or move command
for the cross-zone flow.

You can drag the divider between adjacent zones to change widths at runtime.
By default divider dragging is armed only while zone mode is active
(`alt-z`), so boundaries are inert during normal work. Configure this with:

```toml
[mouse]
zone-divider-drag = 'zone-mode' # or 'always', 'off'
```

Run `winmux save-zone-layout` to persist the new widths:

```bash
winmux save-zone-layout --dry-run
winmux save-zone-layout
```

## Profiles And Scenes

Use layouts when you want to resize columns. Use scenes when you also want each
zone to show a named workspace.

```toml
[[zone-layouts]]
id = 'balanced'
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[[zone-scenes]]
id = 'deep-work'
layout-preset = 'balanced'
workspaces = [
  { zone = 'left', workspace = 'FocusQueue' },
  { zone = 'main', workspace = 'FocusBuild' },
  { zone = 'right', workspace = 'FocusNotes' },
]
```

Use availability sets when you want to hide or restore whole zones:

```toml
[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']

[[zone-availability-sets]]
id = 'communications'
enabled-zones = ['main', 'right']
```

Commands:

```bash
winmux use-zone-layout balanced
winmux use-zone-scene deep-work
winmux use-zone-profile focus-only
winmux cycle-zone-profile focus-only communications full-dashboard
```

## App Affinities

Use `[[zone-affinities]]` to route new matching windows into a zone.

```toml
[[zone-affinities]]
zone = 'Comms'
if.app-id = 'com.apple.mail'
if.window-title-regex-substring = 'Inbox|Mail'
fail-if-noop = false
```

For generic callback routing, `[[on-window-detected]]` can run the same move
command:

```toml
[[on-window-detected]]
if.window-title-regex-substring = 'Slack|Messages|route-comms'
run = ['move-node-to-zone Comms --fail-if-noop']
```

Prefer `[[zone-affinities]]` for the common app-routing case. Use
`[[on-window-detected]]` when you need a broader callback.

## Persistence

Runtime changes do not rewrite the config unless you ask WinMux to save them.

- `resize-zone` and divider drag change runtime widths.
- `save-zone-layout --dry-run` shows the pending config edit.
- `save-zone-layout` writes the current widths and keeps a backup.
- `config --restore-backup <path>` restores a saved backup.

After saving, quit and relaunch WinMux. `list-zones` should show the saved
widths.

## Troubleshooting

Start with these commands:

```bash
winmux config --check ~/.config/winmux/winmux.toml
winmux doctor
winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|profile=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|width=%{monitor-width}'
winmux list-windows --workspace visible
```

If a zone disappeared, check whether a profile hid it:

```bash
winmux use-zone-profile full-dashboard
winmux enable-zone Comms
```

If a saved layout is wrong, restore the backup named by `save-zone-layout`:

```bash
winmux config --restore-backup /path/to/winmux.toml.backup-YYYYMMDDTHHMMSSZ
```

## Updates

The menu bar's "Check for Updates..." fetches the dogfood appcast on demand.
Background checks are off unless you opt in:

```toml
[updates]
automatic-check = true
```

## Support Bundle

For beta reports, generate a local support bundle:

```bash
winmux doctor zones --support-bundle --output ~/Desktop/winmux-zone-support
```

The bundle is an attachable directory with redacted config, monitor topology,
active workspaces, permissions, zone overlays, affinities, bindings, routing
retention notes, command-failure retention notes, and log boundaries. It does
not upload anything.

Window titles are redacted by default. Use `--include-window-titles` only if the
titles are safe to share.

## Sample Configs

Complete parse-checked samples live under `docs/samples/`:

- `ultrawide-balanced.toml`
- `ultrawide-focus-only.toml`
- `ultrawide-comms-open.toml`
- `ultrawide-dashboard.toml`
- `ultrawide-app-affinities.toml`

Check one before copying it:

```bash
winmux config --check docs/samples/ultrawide-balanced.toml
```

## Accepted Evidence

These Tart-derived artifacts back the current docs:

- `artifacts/e2e/slice-27-20260630T043500Z/recordings/slice-27-window-slot-snap.mov`: secondary-button `target = 'window'` snap with the `Window slot: Right` overlay.
- `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/recordings/demo-columnar-zones.mp4`: product demo for divider drag, save, relaunch, and `list-zones`.
- `artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z/recordings/slice-37-starter-onboarding.mov`: commented starter template, uncommenting, config check, `list-zones`, and first `focus-zone`.
- `artifacts/e2e/slice-38-pre-tart-20260701T075713Z/recordings/slice-38-user-readiness.mov`: normal user config path, `focus-zone`, `move-node-to-zone`, `resize-zone`, and `save-zone-layout --dry-run`.
- `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/recordings/slice-39-dogfood-install-permissions.mov`: installed app launch, permissions, relaunch, and normal config path.
- `artifacts/e2e/slice-40-pre-tart-20260701T130717Z/recordings/slice-40-zone-setup-assistant.mov`: `zone init --dry-run`, `zone init --write`, backup, and generated config validation.
- `artifacts/e2e/slice-41-20260701T173400Z/recordings/slice-41-zone-affinity-beta.mov`: beta app and window affinity routing.
- `artifacts/e2e/slice-42-pre-tart-20260701T210703Z/recordings/slice-42-zone-availability-profiles.mov`: profile-level visibility workflows.
- `artifacts/e2e/slice-45-pre-tart-20260702T022831Z/recordings/slice-45-display-topology-recovery.mov`: simulated display loss and recovery boundaries.
- `artifacts/e2e/slice-46-pre-tart-20260702T045535Z/recordings/slice-46-persistence-rollback-doctor.mov`: persistence, rollback, and config doctor.
- `artifacts/e2e/slice-47-pre-tart-20260702T062251Z/recordings/slice-47-zone-chrome-polish.mov`: profile and style visibility in the sidebar.
- `artifacts/e2e/slice-48-20260702T094800Z/recordings/slice-48-support-bundle-diagnostics.mov`: redacted support bundle generation.

Known limits:

- Zones are columns, not a freeform rectangle editor.
- Mouse snap supports whole-zone and window-slot targets, but not arbitrary
  freeform grid cells.
- Runtime width changes persist only after `save-zone-layout`.
- The display topology recovery proof is a Tart simulation, not a hardware
  hotplug claim.
- Support bundles do not collect crash logs, macOS unified logs, or full live
  routing history yet.
