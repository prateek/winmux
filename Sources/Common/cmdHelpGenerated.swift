// CLI help is maintained here; this fork has no adoc generator.

let balance_sizes_help_generated = """
    USAGE: balance-sizes [-h|--help] [--workspace <workspace>]
    """
let close_all_windows_but_current_help_generated = """
    USAGE: close-all-windows-but-current [-h|--help] [--quit-if-last-window]
    """
let close_help_generated = """
    USAGE: close [-h|--help] [--quit-if-last-window] [--window-id <window-id>]

    Exits 1 when the window cannot be closed.
    """
let config_help_generated = """
    USAGE: config [-h|--help] --get <name> [--json] [--keys]
       OR: config [-h|--help] --major-keys
       OR: config [-h|--help] --all-keys
       OR: config [-h|--help] --config-path
       OR: config [-h|--help] status
       OR: config [-h|--help] check [<file>]
       OR: config [-h|--help] convert [<file>]
       OR: config [-h|--help] schema [--json]

    status reports the config helper and live permissions. The permissions object contains
    accessibility (granted/missing), screen-recording (granted/missing/granted-relaunch-needed),
    and setup (done/waiting-for-permissions/waiting-for-go).
    """
let debug_windows_help_generated = """
    USAGE: debug-windows [-h|--help] [--window-id <window-id> [--filter-context]]
    """
let enable_help_generated = """
    USAGE: enable [-h|--help] toggle
       OR: enable [-h|--help] on [--fail-if-noop]
       OR: enable [-h|--help] off [--fail-if-noop]
    """
let exec_and_forget_help_generated = """
    USAGE: exec-and-forget <bash-script>
    """
let flatten_workspace_tree_help_generated = """
    USAGE: flatten-workspace-tree [-h|--help] [--workspace <workspace>]
    """
let focus_back_and_forth_help_generated = """
    USAGE: focus-back-and-forth [-h|--help]
    """
let focus_monitor_help_generated = """
    USAGE: focus-monitor [-h|--help] [--wrap-around] (left|down|up|right)
       OR: focus-monitor [-h|--help] [--wrap-around] (next|prev)
       OR: focus-monitor [-h|--help] <monitor-pattern>...
    """
let focus_help_generated = """
    USAGE: focus [-h|--help] [--ignore-floating] [--wrap-around]
                 [--boundaries <boundary>] [--boundaries-action <action>]
                 (left|down|up|right)
       OR: focus [-h|--help] [--ignore-floating] [--wrap-around]
                 [--boundaries <boundary>] [--boundaries-action <action>]
                 (dfs-next|dfs-prev)
       OR: focus [-h|--help] [--ignore-floating] [--wrap-around]
                 [--boundaries <boundary>] [--boundaries-action <action>]
                 (tab-next|tab-prev)
       OR: focus [-h|--help] --tab-index (<tab-index>|last)
       OR: focus [-h|--help] --window-id <window-id>
       OR: focus [-h|--help] --dfs-index <dfs-index>
    """
let fullscreen_help_generated = """
    USAGE: fullscreen [-h|--help]     [--window-id <window-id>] [--no-outer-gaps]
       OR: fullscreen [-h|--help] on  [--window-id <window-id>] [--no-outer-gaps] [--fail-if-noop]
       OR: fullscreen [-h|--help] off [--window-id <window-id>] [--fail-if-noop]
    """
let join_with_help_generated = """
    USAGE: join-with [-h|--help] [--window-id <window-id>] (left|down|up|right)
    """
let layout_help_generated = """
    USAGE: layout [-h|--help] [--window-id <window-id>]
                  (h_tiles|v_tiles|h_tab_group|v_tab_group|tiles|tab-group|horizontal|vertical|tiling|floating)...
    """
let list_apps_help_generated = """
    USAGE: list-apps [-h|--help] [--macos-native-hidden [no]] [--format <output-format>] [--count] [--json]
    """
let list_exec_env_vars_help_generated = """
    USAGE: list-exec-env-vars [-h|--help]
    """
let list_modes_help_generated = """
    USAGE: list-modes [-h|--help] [--current] [--count] [--json]
    """
let list_monitors_help_generated = """
    USAGE: list-monitors [-h|--help] [--focused [no]] [--mouse [no]] [--format <output-format>] [--count] [--json]
    """
let list_windows_help_generated = """
    USAGE: list-windows [-h|--help] (--workspace <workspace>...|--monitor <monitor>...)
                        [--monitor <monitor>...] [--workspace <workspace>...]
                        [--pid <pid>] [--app-bundle-id <app-bundle-id>] [--format <output-format>]
                        [--count] [--json]
       OR: list-windows [-h|--help] --all [--format <output-format>] [--count] [--json]
       OR: list-windows [-h|--help] --focused [--format <output-format>] [--count] [--json]

    LENS AND SEARCH:
      --lens <name>             Match a configured Lens and use its sort order
      --filter <name|body|->     Match a named Filter or inline Nickel body
      --search <text>           Narrow and rank by title, app, workspace and project
    These flags imply all workspaces when no scope flag is given. With a scope,
    results are the intersection. Inline enum tags need double quotes, e.g.
      --filter "w.class == 'floating"
    --filter - reads stdin. Filter failures print no stdout and exit 2;
    an unavailable helper or server exits 1. Search JSON adds score and matched-field.
    """
let list_workspaces_help_generated = """
    USAGE: list-workspaces [-h|--help] --monitor <monitor>... [--visible [no]] [--empty [no]] [--format <output-format>] [--count] [--json]
       OR: list-workspaces [-h|--help] --all [--format <output-format>] [--count] [--json]
       OR: list-workspaces [-h|--help] --focused [--format <output-format>] [--count] [--json]
    """
let macos_native_fullscreen_help_generated = """
    USAGE: macos-native-fullscreen [-h|--help] [--window-id <window-id>]
       OR: macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] on
       OR: macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] off
    """
let macos_native_minimize_help_generated = """
    USAGE: macos-native-minimize [-h|--help] [--window-id <window-id>]
    """
let mode_help_generated = """
    USAGE: mode [-h|--help] <binding-mode>
    """
let move_mouse_help_generated = """
    USAGE: move-mouse [-h|--help] [--fail-if-noop] <mouse-position>
    """
let move_node_to_monitor_help_generated = """
    USAGE: move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--wrap-around] (left|down|up|right|next|prev)
       OR: move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--fail-if-noop] <monitor-pattern>...
    """
let move_node_to_project_help_generated = """
    USAGE: move-node-to-project [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--wrap-around] [--fail-if-noop] (<project-index>|next|prev)
    """
let move_node_to_workspace_help_generated = """
    USAGE: move-node-to-workspace [-h|--help] [--focus-follows-window] [--wrap-around]
                                  [--stdin|--no-stdin]
                                  (next|prev)
       OR: move-node-to-workspace [-h|--help] [--focus-follows-window] [--fail-if-noop]
                                  [--window-id <window-id>] <workspace-name>
    """
let move_workspace_to_monitor_help_generated = """
    USAGE: move-workspace-to-monitor [-h|--help] [--workspace <workspace>] [--wrap-around] (left|down|up|right)
       OR: move-workspace-to-monitor [-h|--help] [--workspace <workspace>] [--wrap-around] (next|prev)
       OR: move-workspace-to-monitor [-h|--help] [--workspace <workspace>] <monitor-pattern>...
    """
let move_help_generated = """
    USAGE: move [-h|--help] [--window-id <window-id>] [--boundaries <boundary>] [--boundaries-action <boundary-action>] (left|down|up|right)
    """
let project_help_generated = """
    USAGE: project [-h|--help] [--wrap-around] [--fail-if-noop] (<project-index>|next|prev)
    """
let reload_config_help_generated = """
    USAGE: reload-config [-h|--help] [--no-gui] [--dry-run]
    """
let resize_help_generated = """
    USAGE: resize [-h|--help] [--window-id <window-id>] (smart|smart-opposite|width|height) [+|-]<number>
    """
let split_help_generated = """
    USAGE: split [-h|--help] [--window-id <window-id>] (horizontal|vertical|opposite)
    """
let stack_with_help_generated = """
    USAGE: stack-with [-h|--help] [--window-id <window-id>] (left|down|up|right)
    """
let subscribe_help_generated = """
    USAGE: subscribe [-h|--help] [--all] [--no-send-initial] [<event>...]

    Events: focus-changed, focused-monitor-changed, focused-workspace-changed,
            mode-changed, window-detected, binding-triggered, config-reloaded,
            lens-opened, lens-closed, columns-changed, hook-called
    """
let summon_workspace_help_generated = """
    USAGE: summon-workspace [-h|--help] [--fail-if-noop] <workspace>
    """
let swap_help_generated = """
    USAGE: swap [-h|--help] [--window-id <window-id>] [--swap-focus]
                [--wrap-around]
                (left|down|up|right|dfs-next|dfs-prev)
    """
let trigger_binding_help_generated = """
    USAGE: trigger-binding [-h|--help] <binding> --mode <mode-id>
    """
let volume_help_generated = """
    USAGE: volume [-h|--help] (up|down) [--no-gui]
       OR: volume [-h|--help] (mute-toggle|mute-off|mute-on) [--no-gui]
       OR: volume [-h|--help] set <number> [--no-gui]
    """
let workspace_back_and_forth_help_generated = """
    USAGE: workspace-back-and-forth [-h|--help]
    """
let workspace_help_generated = """
    USAGE: workspace [-h|--help] [--auto-back-and-forth] [--fail-if-noop] <workspace-name>
       OR: workspace [-h|--help] [--wrap-around] [--stdin|--no-stdin] (next|prev)
    """

let lens_help_generated = """
    USAGE: lens <name> [--search <text>] [--presentation list|strip|miniatures|grid] [--tile card|picture|text] [--sections none|workspace|project|monitor|app]
           lens --filter <name|body|-> [--sort mru,title,...] [--presentation ...]
           lens --presentation list

    Toggle a named Lens, open an ad-hoc Lens, or change the open Presentation.
    Lists start in Search; strips, grids and miniatures start in normal mode unless
    starts-in overrides it. In normal mode hjkl/arrows move and / enters Search.
    Escape leaves Search keeping matches; another Escape dismisses.
    A first unbound letter ends the Trigger's Hold; its later release never commits.
    Inline Filters bind w and ctx. Quote enum tags with double quotes:
      lens --filter "w.class == 'floating"
    --filter - reads a body from stdin.
    --tile overrides this opening; miniatures rejects --tile.
    """

let focus_back_help_generated = "USAGE: focus-back\nRestore and focus the previously confirmed focused window. Exits 1 if none exists."
let mark_help_generated = "USAGE: mark [<register>]\nName a window with one lowercase letter a to z, or print its registers: the window the command runs for, as other window commands find it, or else the focused one. Exits 1 if there is none. Marks last for this process."
let jump_help_generated = "USAGE: jump <register>\nRestore and focus the window marked with a lowercase letter a to z. Exits 1 if the register is empty or its window has closed."
let list_marks_help_generated = "USAGE: list-marks [--json]\nPrint window registers, window ids, app names and titles, in register order."
let list_lenses_help_generated = "USAGE: list-lenses [--json]\nPrint the Lenses resolved for the default Display profile."

let sections_help_generated = "USAGE: sections (next|none|workspace|project|monitor|app)\nChange the open Lens grouping without closing it."

let summon_help_generated = "USAGE: summon [--window-id <id>]\nMove a window to the current workspace and focus it."

let focus_column_help_generated = "USAGE: focus-column [-h|--help] <n> [--workspace <name>]"
let move_node_to_column_help_generated = "USAGE: move-node-to-column [-h|--help] <n> [--window-id <id>]"
let column_width_help_generated = "USAGE: column-width [-h|--help] next|prev|<fraction> [--window-id <id>]"
let compact_help_generated = "USAGE: compact [-h|--help] [--workspace <name>]"
let list_columns_help_generated = "USAGE: list-columns [-h|--help] [--json] [--workspace <name>]"
let column_count_help_generated = "USAGE: column-count [-h|--help] <n>|off [--workspace <name>]"
let place_help_generated = "USAGE: place [-h|--help] --dry-run --window-id <id> [--json]"

public let debug_hooks_help_generated = """
USAGE: debug-hooks [-h|--help] [on|off|status] [--json]

Capture Policy hook calls in hook-capture.jsonl in WinMux's state directory
(hook-capture-debug.jsonl for a debug build).
With no subcommand, print status. Capture is off at startup.
On starts a fresh capture, or extends an active capture, for 15 minutes.
Off prints the path and record count. Every form reports a write error
since the last fresh capture.

OPTIONS:
  --json       Print capturing, path, until, records and error as JSON
  -h, --help   Show this help
"""

public let debug_lens_trace_help_generated = """
USAGE: debug-lens-trace [-h|--help] [--json] [--last <n>]

Print recent Lens openings, from the event timestamp to the first frame.

OPTIONS:
  --json       Print machine-readable traces, with millisecond stage times
  --last <n>   Print the last n openings (default 5; up to 20 retained)
  -h, --help   Show this help
"""
