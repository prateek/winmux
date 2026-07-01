
<p align="left">
  <img src="resources/winmux-logo.svg" width="80" alt="WinMux logo">
</p>

# WinMux

<p align="left">A powerful sidebar-first window manager for macOS.</p>

https://github.com/user-attachments/assets/51983568-a168-494f-8ae3-5f50ca1efce1

## Highlights
### Projects
Projects are collection of workspaces. Think of it like a parent/child hiearchy, you can switch between projects. Each project has it's own set of workspaces.

### Sidebar
The sidebar is a more interactively-performant and useful alternative to [Sketchybar](https://github.com/felixkratz/sketchybar) and traditional workspace menu bar dropdowns for most everyday tasks. It provides better visibility into spaces and spatial awareness on the desktop.

You can drag windows in and out of the sidebar from and to the current workspace. You can rearrange windows across all spaces using the sidebar, including tab groups.

The sidebar can be configured (as shown) to display the current date and time.


### Tab Groups
![](resources/screenshots/tab-groups.png)
Tab groups allow you to have many windows occupy the same footprint, similar to Yabai stacks but with browser-like tab behavior. This is useful when you want to have multiple pieces of reference information next to an editor, multiple tabs in different browser profiles, or, when you simply want multiple fullscreen views without the additional friction and overhead of creating a new workspace.

Unlike stack-only layouts, WinMux tab groups behave more intuitively like you would expect tabs to in browsers, and don't need a keyboard shortcut to activate. You can drag tabs from tab groups into another window's [intent zone](#managed-tiling-mode), or in between workspaces. You can also rearrange tab order within a tab group, and navigate through them with relative and absolute keybindings.

### Philosophy

#### Workspaces
You can NOT create workspaces that have no windows in them. Workspaces with no windows are automatically destroyed.

### Multi-Monitors
Monitors share the global project/workspace state. Each monitor can be treated as *independent* from each other. They each just use the sidebar to browse through projects and 'select' a workspace to view. 

Monitors can not be attached to the same workspace at the same time. They can be on the same project at the same time.

### Columnar Zones
On ultrawide displays, WinMux can split one physical monitor into named column zones. Each zone acts like its own workspace viewport, so Reference, Work, and Comms can stay visible at the same time without turning the whole display into one huge tiling surface.

See [demo-columnar-zones.mp4](demo-columnar-zones.mp4) for an
already-configured zones workflow with runtime divider controls. First-run setup
uses the CLI commands below.

For a first setup, let WinMux write the starter zones and keep a backup:

```bash
winmux zone init --dry-run --preset balanced
winmux zone init --preset balanced --write
winmux config --check ~/.config/winmux/winmux.toml
winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'
```

Fresh WinMux configs still include the same ultrawide setup as a commented
template if you prefer to hand-tune the TOML before enabling it.

```toml
[[zones]]
monitor = 1
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[mode.main.binding]
alt-z = 'mode zone'

[mode.zone.binding]
esc = 'mode main'
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

Use `list-zones` to inspect the active zone state. Zone selectors accept ids or names when they are unique. They also accept `current`, `next`, and `prev`, scoped to the focused physical monitor. If multiple physical monitors reuse the same zone id, qualify the selector with the monitor, such as `1:left`.

You can drag a divider between adjacent zones to resize the columns at runtime.
Run `winmux save-zone-layout` after a drag to write the new widths back to the
active config. The new widths are then restored on the next WinMux launch.

For repeatable setups, define layout presets, scenes, availability sets, and styles:

```toml
[[zone-styles]]
id = 'urgent'
color = '#D3455B'

[[zone-styles]]
id = 'calm'
color = '#3EA2FF'

[[zone-layouts]]
id = 'balanced'
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[[zone-layouts]]
id = 'focus'
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Queue', width = 0.18 },
  { id = 'main', name = 'Build', width = 0.64 },
  { id = 'right', name = 'Notes', width = 0.18 },
]

[[zone-scenes]]
id = 'deep-work'
layout-preset = 'focus'
workspaces = [
  { zone = 'left', workspace = 'FocusQueue' },
  { zone = 'main', workspace = 'FocusBuild' },
  { zone = 'right', workspace = 'FocusNotes' },
]

[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']

[[zone-availability-sets]]
id = 'communications'
enabled-zones = ['main', 'right']

[[zone-availability-sets]]
id = 'full-dashboard'
enabled-zones = ['left', 'main', 'right']

[mode.main.binding]
alt-1 = 'use-zone-layout focus'
alt-2 = 'use-zone-scene deep-work'

[mode.zone.binding]
tab = ['cycle-zone-layout balanced focus', 'mode main']
a = ['cycle-zone-availability focus-only communications full-dashboard', 'mode main']
y = ['cycle-zone-style current urgent calm', 'mode main']
```

Use `use-zone-layout` when you only want to resize the columns. Use `use-zone-scene` when you want to resize columns and switch each zone to a named workspace. The `tab`, `a`, and `y` zone-mode bindings require the matching `[[zone-layouts]]`, `[[zone-availability-sets]]`, and `[[zone-styles]]` entries.

Window rules can route new windows into a zone by using the same command surface:

```toml
[[on-window-detected]]
if.window-title-regex-substring = 'Slack|Messages|route-comms'
run = ['move-node-to-zone Comms --fail-if-noop']
```

#### App Launching
WinMux supports single-modifer keybindings (e.g. triggering an action on press of `⌘`)

I highly recommend that you configure the apps you use every day to be launch with Left/Right Option+Command, or similar shortcuts, otherwise it might be hard to launch common things into the current workspace (and instead, take you to the other workspace where the app is currently active). Here is some of the apps that I have keybinded:

```toml
[mode.main.binding-tap]
    left-alt = 'exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Default"'
    right-cmd = 'exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Profile 1"'

[mode.main.binding]
    # Disable the native "Hide App" shortcut.
    cmd-h = []

    cmd-d = 'exec-and-forget osascript ~/Documents/scripts/launchTerminalWindow.scpt'
    cmd-e = 'exec-and-forget osascript ~/Documents/scripts/launchFinderWindow.scpt'
```

```applescript
# ~/Documents/scripts/launchTerminalWindow.scpt
tell application "cmux"
    if it is running
        tell application "System Events" to tell process "cmux"
            click menu item "New Window" of menu "File" of menu bar 1
        end tell
    else
        activate
    end if
end tell

# ~/Documents/scripts/launchFinderWindow.scpt
tell application "Finder"
    if it is running
        tell application "System Events" to tell process "Finder"
            click menu item "New Finder Window" of menu "File" of menu bar 1
        end tell
    else
        activate
    end if
end tell

```

## Installation
Download the latest binary from releases and launch.

As WinMux is not signed, you will need to bypass gatekeeper:

```bash
xattr -dr com.apple.quarantine /Applications/WinMux.app/
```

## Migrating
### From AeroSpace
If `~/.config/winmux/winmux.toml` already exists, WinMux uses it as-is.

If you have an AeroSpace config but no WinMux config yet, WinMux creates one for you on first launch. It copies over your AeroSpace shortcuts/key mapping and fills in the rest with WinMux defaults, including the sidebar and window tabs.

You do not need to edit anything to get started. After import, WinMux uses `~/.config/winmux/winmux.toml` and leaves your AeroSpace config alone.

If neither exists, WinMux creates a new WinMux config with the bundled defaults.

## Credits
[Aerospace](https://github.com/nikitabobko/AeroSpace)
