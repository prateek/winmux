
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

By default the sidebar rests as a compact rail and expands when hovered. To hide the rail
completely until the pointer reaches the left display edge, enable auto-hide. On macOS 26 and
newer, native Liquid Glass is enabled by default. Choose an opaque solid color for greater
contrast across the sidebar, tab groups, and switcher:

```nickel
workspace-sidebar = {
  auto-hide = true,
  chrome-style = 'solid,
  solid-chrome-color = "lavender", # Choose any color shown in Appearance, including custom.
},
```

To keep the full sidebar visible, reserve its expanded width when laying out tiled windows:

```nickel
workspace-sidebar = {
  always-expanded = true,
  width = 240,
},
```

`always-expanded` takes precedence over `auto-hide`. The configured `gaps.outer.left` remains
the spacing between the sticky sidebar and tiled windows, and monitor selection continues to
control which displays reserve sidebar space.

The sidebar clock can be configured independently:

```nickel
workspace-sidebar = {
  show-clock = true,
  show-seconds = true,
  show-date = true,
  show-weekday = true,
},
```

`show-clock` hides the entire clock card. The other settings independently control seconds,
the month and day, and the weekday; for example, `show-date = false` with
`show-weekday = true` leaves a weekday-only calendar label in the expanded sidebar.

### Window and sidebar spacing

The `gaps` settings control the visible borders around tiled windows. `inner.horizontal`
and `inner.vertical` set the space between neighboring windows. The outer gaps set the space
at each display edge; when the sidebar is enabled, `outer.left` is the space between the
sidebar and the tiled windows. Any of these values can be reduced or set to zero independently.

For borderless tiling, including no border beside the sidebar:

```nickel
gaps = {
  inner = { horizontal = 0, vertical = 0 },
  outer = { left = 0, bottom = 0, top = 0, right = 0 },
},
```
### Tab Groups
![](resources/screenshots/tab-groups.png)
Tab groups allow you to have many windows occupy the same footprint, similar to Yabai stacks but with browser-like tab behavior. This is useful when you want to have multiple pieces of reference information next to an editor, multiple tabs in different browser profiles, or, when you simply want multiple fullscreen views without the additional friction and overhead of creating a new workspace.

Unlike stack-only layouts, WinMux tab groups behave more intuitively like you would expect tabs to in browsers, and don't need a keyboard shortcut to activate. You can drag tabs from tab groups into another window's [intent zone](#managed-tiling-mode), or in between workspaces. You can also rearrange tab order within a tab group, and navigate through them with relative and absolute keybindings.

### Philosophy

#### Automatic tiling

WinMux tiles newly discovered windows by default. To keep their existing macOS size and position while still using WinMux's sidebar, workspaces, and manual layout commands, disable automatic tiling:

```nickel
automatically-tile-new-windows = false,
```

This applies to windows discovered when WinMux starts and windows opened later. You can still tile an individual floating window with `winmux layout tiling` or the configured `layout floating tiling` shortcut.

While dragging a window by its title bar, shake it horizontally to toggle between floating and tiling. The gesture requires several deliberate direction changes in quick succession, and does not activate during resize, sidebar, tab-strip, or tab-group drags. Disable it with:

```nickel
enable-shake-to-toggle-tiling = false,
```

#### Workspaces
You can NOT create workspaces that have no windows in them. Workspaces with no windows are automatically destroyed.

### Multi-Monitors
Monitors share the global project/workspace state. Each monitor can be treated as *independent* from each other. They each just use the sidebar to browse through projects and 'select' a workspace to view. 

Monitors can not be attached to the same workspace at the same time. They can be on the same project at the same time.

#### App Launching
WinMux supports single-modifer keybindings (e.g. triggering an action on press of `⌘`)

I highly recommend that you configure the apps you use every day to be launch with Left/Right Option+Command, or similar shortcuts, otherwise it might be hard to launch common things into the current workspace (and instead, take you to the other workspace where the app is currently active). Here is some of the apps that I have keybinded:

```nickel
mode.main = {
  binding-tap = {
    left-alt = m%"exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Default""%,
    right-cmd = m%"exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Profile 1""%,
  },
  binding = {
    # Disable the native "Hide App" shortcut.
    cmd-h = [],

    cmd-d = "exec-and-forget osascript ~/Documents/scripts/launchTerminalWindow.scpt",
    cmd-e = "exec-and-forget osascript ~/Documents/scripts/launchFinderWindow.scpt",
  },
},
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

Documentation: [Lenses](docs/lenses.md) and [Columns](docs/columns.md).

## Installation
Install WinMux with Homebrew:

```shell
brew tap ZimengXiong/homebrew https://github.com/ZimengXiong/homebrew
brew trust ZimengXiong/homebrew
brew install --cask winmux
xattr -cr /Applications/WinMux.app
```

Or download the latest binary from releases and launch.

Release builds are signed with the project's Apple Development certificate. They are not notarized, so macOS may require you to right-click the app and choose **Open** the first time you launch it.

WinMux checks GitHub Releases for signed updates automatically. You can also select **Check for Updates…** from the menu bar.

## Config
The config is one [Nickel](https://nickel-lang.org) file, `~/.config/winmux/winmux.ncl`. It merges your settings over the defaults WinMux ships and checks the result against WinMux's contracts:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  gaps.inner.horizontal = 0,
  mode.main.binding.alt-enter = "exec-and-forget open -a Terminal",
}) | W.Config
```

The snippets in this README are fields of that record. `winmux config check` reports mistakes with Nickel's own diagnostics, saving the file or any file it imports applies it (`reload-on-save = false` leaves that to `winmux reload-config`), and `winmux config status` shows the state of `winmux-nickel`, the helper process that evaluates it. WinMux never writes to the config file: the Settings window shows what is loaded, and names and colours changed in the sidebar are kept in `~/.local/state/winmux/sidebar.json`.

### Filters
A Filter is a function that says yes or no to a window. It takes the window as `w` and the Filter context as `ctx`, and named Filters live in the config's `filters` record:

```nickel
filters = {
  mail = fun w ctx => w.app.bundleId == "com.apple.mail",
  same-app = fun w ctx => ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId,
  other-mail = fun w ctx => filters.mail w ctx && w.workspace != ctx.workspace.name,
},
```

`winmux config schema` prints every field of `w` and `ctx` with its type and a description, and `--json` prints the same as JSON. WinMux calls every Filter twice when the config loads, against a made-up window, so a misspelled field fails the load with Nickel's diagnostic. `ctx.focused`, `ctx.mouse` and `ctx.previous` are `null` when there is no such window. The first call sets all three and the second leaves them `null`, so the load fails for a Filter that reads one without checking.

## Migrating
### From a TOML config
If `~/.config/winmux/winmux.ncl` does not exist and `~/.config/winmux/winmux.toml` does, WinMux converts it on first launch. `winmux config convert` prints the same conversion, and works without WinMux running.

### From AeroSpace
If you have an AeroSpace config but no WinMux config yet, WinMux creates one for you on first launch. It converts your AeroSpace key mapping and bindings and takes WinMux's defaults for everything else, including the sidebar and window tabs. WinMux leaves your AeroSpace config alone and does not read it again.

If neither exists, WinMux writes a starter config that takes every default.

## Credits
[Aerospace](https://github.com/nikitabobko/AeroSpace)
