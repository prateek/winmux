// FILE IS MAINTAINED BY HAND
// Keep parser manifests, help strings, and CLI descriptions in sync.
// Validate with: python3 script/check-command-metadata

let balance_columns_help_generated = """
    USAGE: balance-columns [-h|--help] [--monitor <monitor-pattern>]
    """
let balance_sizes_help_generated = """
    USAGE: balance-sizes [-h|--help] [--workspace <workspace>]
    """
let card_help_generated = """
    USAGE: card [-h|--help] [--auto-back-and-forth] [--fail-if-noop] go <card-name>
       OR: card [-h|--help] new <card-name>
       OR: card [-h|--help] <deck-position>
       OR: card [-h|--help] [--wrap-around] [--stdin|--no-stdin] (next|prev)
       OR: card [-h|--help] back-and-forth
       OR: card [-h|--help] [--fail-if-noop] summon <card-name>
       OR: card [-h|--help] [--workspace <card>] [--wrap-around] move (left|right|<column-id>|<scene>:<column>)
    """
let close_all_windows_but_current_help_generated = """
    USAGE: close-all-windows-but-current [-h|--help] [--quit-if-last-window]
    """
let close_help_generated = """
    USAGE: close [-h|--help] [--quit-if-last-window] [--window-id <window-id>]
    """
let column_help_generated = """
    USAGE: column [-h|--help] resize [+|-]<percent>% [<column-id>]
       OR: column [-h|--help] (collapse|expand|toggle) [<column-id>]
       OR: column [-h|--help] color <hex> [<column-id>]
       OR: column [-h|--help] init [--dry-run|--write] [--replace-existing] [--preset <preset>]
                  [--monitor <monitor-pattern>]
    """
let config_help_generated = """
    USAGE: config [-h|--help] --get <name> [--json] [--keys]
       OR: config [-h|--help] --major-keys
       OR: config [-h|--help] --all-keys
       OR: config [-h|--help] --config-path
       OR: config [-h|--help] --check <path>
       OR: config [-h|--help] --restore-backup <path>
    """
let cycle_column_snap_policy_help_generated = """
    USAGE: cycle-column-snap-policy [-h|--help] [--monitor <monitor-pattern>] <policy>...
    """
let debug_windows_help_generated = """
    USAGE: debug-windows [-h|--help] [--window-id <window-id>]
    """
let enable_help_generated = """
    USAGE: enable [-h|--help] toggle
       OR: enable [-h|--help] on [--fail-if-noop]
       OR: enable [-h|--help] off [--fail-if-noop]
    """
let exec_and_forget_help_generated = """
    USAGE: exec-and-forget <bash-script>
    """
let expose_help_generated = """
    USAGE: expose [-h|--help] (display|card)
    """
let flatten_workspace_tree_help_generated = """
    USAGE: flatten-workspace-tree [-h|--help] [--workspace <workspace>]
    """
let focus_back_and_forth_help_generated = """
    USAGE: focus-back-and-forth [-h|--help]
    """
let focus_column_help_generated = """
    USAGE: focus-column [-h|--help] <column>
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
       OR: focus [-h|--help] --tab-index <tab-index>
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
let list_cards_help_generated = """
    USAGE: list-cards [-h|--help] --monitor <monitor>... [--visible [no]] [--empty [no]] [--format <output-format>] [--count] [--json]
       OR: list-cards [-h|--help] --all [--format <output-format>] [--count] [--json]
       OR: list-cards [-h|--help] --focused [--format <output-format>] [--count] [--json]
    """
let list_columns_help_generated = """
    USAGE: list-columns [-h|--help] [--format <output-format>] [--count] [--json]
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
let move_node_to_card_help_generated = """
    USAGE: move-node-to-card [-h|--help] [--focus-follows-window] [--wrap-around]
                             [--stdin|--no-stdin]
                             (next|prev)
       OR: move-node-to-card [-h|--help] [--focus-follows-window] [--fail-if-noop]
                             [--window-id <window-id>] <card-name>
    """
let move_node_to_column_help_generated = """
    USAGE: move-node-to-column [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                               [--fail-if-noop] <column>
    """
let move_node_to_monitor_help_generated = """
    USAGE: move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--wrap-around] (left|down|up|right|next|prev)
       OR: move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                                [--fail-if-noop] <monitor-pattern>...
    """
let move_help_generated = """
    USAGE: move [-h|--help] [--window-id <window-id>] [--boundaries <boundary>] [--boundaries-action <boundary-action>] (left|down|up|right)
    """
let reload_config_help_generated = """
    USAGE: reload-config [-h|--help] [--no-gui] [--dry-run]
    """
let resize_help_generated = """
    USAGE: resize [-h|--help] [--window-id <window-id>] (smart|smart-opposite|width|height) [+|-]<number>
    """
let scene_help_generated = """
    USAGE: scene [-h|--help] [--monitor <monitor-pattern>] <name>
       OR: scene [-h|--help] [--monitor <monitor-pattern>] next
       OR: scene [-h|--help] [--monitor <monitor-pattern>] new <name>
    """
let set_column_snap_policy_help_generated = """
    USAGE: set-column-snap-policy [-h|--help] [--monitor <monitor-pattern>] <policy>
    """
let split_help_generated = """
    USAGE: split [-h|--help] [--window-id <window-id>] (horizontal|vertical|opposite)
    """
let stack_with_help_generated = """
    USAGE: stack-with [-h|--help] [--window-id <window-id>] (left|down|up|right)
    """
let subscribe_help_generated = """
    USAGE: subscribe [-h|--help] [--all] [--no-send-initial] [<event>...]
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
