public let agentSkillText = """
    ---
    name: winmux
    description: Configure WinMux in winmux.ncl with bindings, Filters, Lenses and hooks; query focused windows, workspaces and Columns; drive WinMux and move or arrange windows.
    ---

    # WinMux

    ## What is focused

    Run `winmux list-windows --focused --json` for the focused window's `window-id`, `app-name` and `window-title`.
    Run `winmux list-workspaces --focused` for its workspace.
    Run `winmux list-columns --json` and find the entry whose `window-ids` contains that window id; its `index` is the Column number.
    There is no `--focused` flag on `list-columns`. With Columns off the list is empty: answer "no Column". If listing fails because Columns are off, also answer "no Column"; report other errors rather than guessing.
    An empty focused-window list means there is no focused managed window; do not invent a window or Column.

    ## Reading state

    Run `winmux list-windows --all` and `winmux list-workspaces --all` for the inventory.
    Run `winmux list-lenses --json` for resolved Lens settings and Filter paths; Triggers live in config bindings, not this output.
    Run `winmux config status` for the loaded config and last error.
    Use `winmux --help` and `winmux <command> --help` for commands not covered here. State and driving commands need WinMux running; `agent skill` and `config check`, `config schema`, `config convert` run locally.

    ## Config is Nickel

    Edit only `winmux.ncl` under `$XDG_CONFIG_HOME/winmux/`, or `~/.config/winmux/winmux.ncl` when XDG_CONFIG_HOME is unset or empty.
    With the app running, `winmux config --config-path` names the file it loaded. Edit that file if it is locally accessible. If it is not accessible in your filesystem, prepare and check the local default-path file instead, and report that it still needs loading in the running app. Use the CLI interface; do not inspect its executable or installation internals to reach another filesystem.
    Never write a JSON config or edit JSON state WinMux writes, such as `~/.local/state/winmux/sidebar.json`. Never write TOML: use `winmux config convert` to turn an old `winmux.toml` into Nickel.
    When no file exists, create its parent directory and start with this import-only config to keep the defaults:

    ```nickel
    let W = import "winmux/winmux.ncl" in
    (import "winmux/defaults.ncl") | W.Config
    ```

    After every edit run `winmux config check`, fix its diagnostics, and repeat until it passes. No argument checks the default path; `winmux config check <file>` checks a named file.
    With `reload-on-save` on, saving applies the config; otherwise run `winmux reload-config` after a passing check. A failed reload keeps the last good config; inspect `winmux config status`.
    Run `winmux config schema` for record fields. The imports above are shipped library names resolved by the config helper; do not look for repository docs or replace them with local files.

    ## Recipes

    Treat every Nickel block here as a complete config file, checked as written. To combine recipes, merge their fields into the same record over defaults, then check the resulting file. Preserve existing user settings.
    Write commands as strings without a leading `winmux`. Spell Option as `alt`, Command as `cmd`, and Control as `ctrl` in bindings.

    Add a binding in `main`; free an inherited chord with an empty command list `[]` so it reaches the focused app:

    ```nickel
    let W = import "winmux/winmux.ncl" in
    ((import "winmux/defaults.ncl") & {
      mode.main.binding.alt-shift-f = "find-focus",
      mode.main.binding.alt-slash = [],
    }) | W.Config
    ```

    Define a Filter as `fun w ctx => ...` under `filters.<name>`. A Lens combines that Filter with a Presentation and sort order; its binding is the Trigger:

    ```nickel
    let W = import "winmux/winmux.ncl" in
    ((import "winmux/defaults.ncl") & {
      filters.editors = fun w ctx => w.app.name == "Zed" || w.app.name == "Ghostty",
      lenses.editors = {
        filter = filters.editors,
        presentation = 'list,
        starts-in = 'normal,
        sort = ['mru, 'title],
      },
      mode.main.binding.alt-shift-e = "lens editors",
    }) | W.Config
    ```

    Try the Filter before saving it: `winmux list-windows --filter 'w.app.name == "Zed" || w.app.name == "Ghostty"' --json` lists matches without opening a Lens.
    Or run `winmux lens --filter 'w.app.name == "Zed" || w.app.name == "Ghostty"'` to open it. CLI expressions are bodies over `w` and `ctx`, not `fun w ctx => ...`; a Filter path printed by `list-lenses` is a label, not a callable expression.
    In a Lens use arrows to select and Return to focus; `/` starts Search, Escape leaves Search, and Escape again closes. Option-Return Summons a selected window onto the current workspace.

    Enable Columns on only the workspace named `Code`, then use its `place` Policy hook to put arriving Ghostty windows in Column 3 and other windows in the nearest empty Column. This record does not create the workspace:

    ```nickel
    let W = import "winmux/winmux.ncl" in
    ((import "winmux/defaults.ncl") & {
      columns.count = 'off,
      workspace.Code.columns = {
        count = 3,
        place = fun w ctx cols => {
          column = if w.app.name == "Ghostty" then 3 else 'nearest-empty,
          overflow = 'tab-group,
        },
      },
    }) | W.Config
    ```

    Keep hooks pure Nickel. `place` receives a Window, Filter context and Column records and must return `column` and `overflow`. Columns hold windows, tab groups or splits; occupied targets use the Overflow policy (`'tab-group`, `'split`, `'float` or `'squeeze`). Place does not run when Columns are off.

    ## Arranging windows

    Use this workflow for layout changes. Its JSON request file is not config: the rule against editing generated JSON above concerns config/state, while this interface requires editing the request's `edit` object.

    You MUST use the file workflow. Do not guess operation names. Do not search the repository for docs. This skill is the command reference.

    Required workflow for every arrangement request:
    1. Query the current state into a JSON file:
       `winmux agent query --path /tmp/winmux-agent.json`
    2. Read the file you just wrote:
       `/tmp/winmux-agent.json`
       Important: `query --path` writes the JSON to the path. It does not print the JSON to stdout. Running `ls /tmp/winmux-agent.json` is not enough; you must read the file contents.
    3. Edit only the `edit` object inside `/tmp/winmux-agent.json`.
       Treat `schemaVersion`, `snapshotId`, `worldId`, `inventory`, and `reasoning` as read-only context. Do not edit titles, app names, frames, panes, workspace inventory, or the world id.
    4. For a small change, replace the entire `edit.operations` array with only the operations for the current user request. Do not append to operations left by an earlier request.
    5. For a full workspace redesign, edit `edit.layout.workspaces` instead of `edit.operations`.
    6. Apply the same file:
       `winmux agent apply --path /tmp/winmux-agent.json`
    7. If apply says the JSON is stale or the `worldId` does not match, discard `/tmp/winmux-agent.json`, run the query command again, read the new file, redo the edit, and apply again.
    8. Return a short summary of what changed.

    Usually skip the separate check command. `apply` validates before changing anything. Use `winmux agent check --path /tmp/winmux-agent.json` only for complex edits or after a failed apply.

    The file includes a `worldId` freshness guard. If windows move, close, change fullscreen state, or the user manually changes the layout, discard the file and query again.

    For small changes, replace the entire `edit.operations` array. Do not append to old operations unless the user asked for one multi-step batch. Prefer operations for focus, moving one window, moving one tab group, swapping, placing one pane, setting WinMux fullscreen, closing, or parking windows.

    For full workspace setup, edit `edit.layout.workspaces`. Use layout mode for requests like "set up my coding workspace" or "organize all windows into workspaces".

    Use `windowId` for one window. Use `tabGroupId` for the whole tab group. If the user says "tab group", "tabs", "tap group", or "the whole group", do not move only the active window. `createTabGroup` takes `tabs`; `windows` is accepted as an alias.

    If the user says "all Chrome windows" or "all IDEs", scan every item in `inventory.windows` and include every matching `windowId`. Do not stop after the first match. Also inspect `inventory.tabGroups`, because an existing tab group may already contain more matching windows.

    If you create a tab group in `edit.operations` and need to refer to it later in the same operations array, give it a temporary `tabGroupId` and reuse that exact value later. Example: create with `"tabGroupId": "tabgroup-chrome"` and then refer to `{ "tabGroupId": "tabgroup-chrome" }`. The alias is only for the current apply; after applying, query again to see the real persistent tab group id.

    Read the query file before choosing IDs:
    - Find windows in `inventory.windows`. Match by `appName`, `title`, and `windowId`.
    - Find whole tab groups in `inventory.tabGroups`. Use `tabGroupId` when moving or editing the whole group.
    - Find current layout in `reasoning.panes`, `reasoning.relations`, and `reasoning.rawTrees`.
    - Use `size` and `sizeAxis` from the query file to understand current proportions before resizing.
    - Never invent a `windowId`, `paneId`, `tabGroupId`, or workspace name if the query file already gives the correct value.

    Canonical operation type names are camelCase. Common snake_case aliases are accepted, but prefer the exact schemas below.

    Pane refs:
    - Window: `{ "windowId": 123 }` or pane id `"pane-123"`
    - Tab group: `{ "tabGroupId": "tabgroup-123" }` or pane id `"pane-tabgroup-123"`

    All `edit.operations` commands:
    - `focusWindow`: `{ "type": "focusWindow", "windowId": 123 }`
    - `focusWindow` by match: `{ "type": "focusWindow", "match": { "appName": "Google Chrome", "titleContains": "Docs" } }`
    - `focusWorkspace`: `{ "type": "focusWorkspace", "workspace": "2" }`
    - `moveWindowToWorkspace`: `{ "type": "moveWindowToWorkspace", "windowId": 123, "workspace": "2", "focus": true }`
    - `moveTabGroupToWorkspace`: `{ "type": "moveTabGroupToWorkspace", "tabGroupId": "tabgroup-123", "workspace": "2", "focus": true }`
    - `swapPanes`: `{ "type": "swapPanes", "paneId1": "pane-123", "paneId2": "pane-456" }`
    - `swapPanes` alt: `{ "type": "swapPanes", "a": { "windowId": 123 }, "b": { "tabGroupId": "tabgroup-456" } }`
    - `placePane`: `{ "type": "placePane", "pane": { "windowId": 123 }, "relation": "below", "target": { "windowId": 456 } }`
    - `createTabGroup`: `{ "type": "createTabGroup", "tabGroupId": "tabgroup-chrome", "workspace": "1", "tabs": [123, 456, 789], "activeWindowId": 123 }`
    - `createTabGroup` alt: `{ "type": "createTabGroup", "tabGroupId": "tabgroup-chrome", "windows": [123, 456, 789] }`
    - `addWindowToTabGroup`: `{ "type": "addWindowToTabGroup", "windowId": 123, "tabGroupId": "tabgroup-456", "activeWindowId": 123 }`
    - `moveWindowOutOfTabGroup`: `{ "type": "moveWindowOutOfTabGroup", "windowId": 123 }`
    - `setActiveTab`: `{ "type": "setActiveTab", "tabGroupId": "tabgroup-123", "windowId": 456 }`
    - `setWinMuxFullscreen`: `{ "type": "setWinMuxFullscreen", "windowId": 123, "value": true, "noOuterGaps": true }`
    - `setFloating`: `{ "type": "setFloating", "windowId": 123, "value": true }`
    - `closeWindow`: `{ "type": "closeWindow", "windowId": 123, "quitAppIfLastWindow": true }`
    - `parkWindow`: `{ "type": "parkWindow", "pane": { "windowId": 123 }, "workspace": "__agent_parked" }`
    - `setPaneSize`: `{ "type": "setPaneSize", "pane": { "windowId": 123 }, "size": 0.8 }`
    - `setPaneSize` percent alt: `{ "type": "setPaneSize", "pane": { "tabGroupId": "tabgroup-123" }, "sizePercent": 80 }`
    - `setPaneSize` vertical split: `{ "type": "setPaneSize", "pane": { "windowId": 123 }, "axis": "vertical", "size": 0.75 }`
    - `setWorkspaceLayout`: `{ "type": "setWorkspaceLayout", "layout": { "name": "1", "layout": { "kind": "window", "windowId": 123 } } }`

    For a small change, the `edit` object in the queried file should look like this. Keep the rest of the queried file unchanged:
    ```json
    {
      "edit": {
        "operations": [
          { "type": "focusWindow", "windowId": 123 }
        ]
      }
    }
    ```

    Relations for `placePane`: `leftOf`, `rightOf`, `above`, `below`.

    WinMux fullscreen is not macOS native fullscreen. Use `setWinMuxFullscreen`.

    If the user wants a window not to show in the current workspace but does not ask to close it, use `parkWindow` or `moveWindowToWorkspace`, not native minimize.

    Full layout mode:
    - Edit `edit.layout.workspaces`.
    - Replace `edit.operations` with an empty array unless the user explicitly asked for extra operations in the same batch.
    - Prefer layout mode when the user asks to design or reorganize a workspace, especially when the request includes exact sizes like "80/20", "left takes 80%", or multiple groups/panes in one workspace.
    - A split's `direction` describes how children are arranged: `horizontal` means left/right; `vertical` means top/bottom.
    - Workspace layout shape: `{ "name": "coding", "layout": <layoutNode>, "focus": { "windowId": 123 }, "floating": [{ "windowId": 456 }] }`
    - Split node: `{ "kind": "split", "direction": "horizontal", "children": [<layoutNode>, <layoutNode>], "size": 0.5 }`
    - Window node: `{ "kind": "window", "windowId": 123, "size": 0.5 }`
    - Tab group node: `{ "kind": "tabGroup", "tabs": [123, 456], "activeWindowId": 123, "size": 0.5 }`
    - Directions: `horizontal`, `vertical`.
    - `size` is a proportional share of the parent split. Use `0.8` for 80%. `80` and `sizePercent: 80` are also accepted. If a sibling omits `size`, it receives an equal share of the remaining space.
    - For `setPaneSize`, add `"axis": "vertical"` when resizing a top/bottom split and `"axis": "horizontal"` when resizing a left/right split. Without `axis`, WinMux uses the nearest split containing the pane.
    - For "Chrome 80%, IDE column 20%, terminal below IDE", use a horizontal root split with Chrome tab group `size: 0.8` and a vertical split `size: 0.2` containing the IDE tab group and terminal.

    For a full layout redesign, the `edit` object in the queried file should look like this. Keep the rest of the queried file unchanged:
    ```json
    {
      "edit": {
        "layout": {
          "workspaces": [
            {
              "name": "1",
              "layout": {
                "kind": "split",
                "direction": "horizontal",
                "children": [
                  { "kind": "window", "windowId": 123, "size": 0.8 },
                  { "kind": "window", "windowId": 456, "size": 0.2 }
                ]
              },
              "focus": { "windowId": 123 }
            }
          ]
        }
      }
    }
    ```

    ## Who can drive WinMux

    The CLI acts with the person's full reach and has no read-only mode.
    """
