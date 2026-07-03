// FILE IS MAINTAINED BY HAND
// Keep parser manifests, help strings, and CLI descriptions in sync.
// Validate with: python3 script/check-command-metadata

let apply_zone_bindings_help_generated = """
    USAGE: apply-zone-bindings [-h|--help] [--monitor <monitor-pattern>]
    """
let balance_sizes_help_generated = """
    USAGE: balance-sizes [-h|--help] [--workspace <workspace>]
    """
let balance_zones_help_generated = """
    USAGE: balance-zones [-h|--help] [--monitor <monitor-pattern>]
    """
let bind_node_to_zone_help_generated = """
    USAGE: bind-node-to-zone [-h|--help] [--window-id <window-id>] <zone>
    """
let close_all_windows_but_current_help_generated = """
    USAGE: close-all-windows-but-current [-h|--help] [--quit-if-last-window]
    """
let close_help_generated = """
    USAGE: close [-h|--help] [--quit-if-last-window] [--window-id <window-id>]
    """
let config_help_generated = """
    USAGE: config [-h|--help] --get <name> [--json] [--keys]
       OR: config [-h|--help] --major-keys
       OR: config [-h|--help] --all-keys
       OR: config [-h|--help] --config-path
       OR: config [-h|--help] --check <path>
       OR: config [-h|--help] --restore-backup <path>
    """
let cycle_zone_availability_help_generated = """
    USAGE: cycle-zone-availability [-h|--help] [--monitor <monitor-pattern>] <set-id>...
    """
let cycle_zone_layout_help_generated = """
    USAGE: cycle-zone-layout [-h|--help] [--monitor <monitor-pattern>] <layout-id>...
    """
let cycle_zone_profile_help_generated = """
    USAGE: cycle-zone-profile [-h|--help] [--monitor <monitor-pattern>] <profile-id>...
    """
let cycle_zone_scene_help_generated = """
    USAGE: cycle-zone-scene [-h|--help] [--monitor <monitor-pattern>] <scene-id>...
    """
let cycle_zone_snap_policy_help_generated = """
    USAGE: cycle-zone-snap-policy [-h|--help] [--monitor <monitor-pattern>] <policy>...
    """
let cycle_zone_style_help_generated = """
    USAGE: cycle-zone-style [-h|--help] [--monitor <monitor-pattern>] <zone> <style-id>...
    """
let debug_windows_help_generated = """
    USAGE: debug-windows [-h|--help] [--window-id <window-id>]
    """
let disable_zone_help_generated = """
    USAGE: disable-zone [-h|--help] [--monitor <monitor-pattern>] <zone>
    """
let enable_help_generated = """
    USAGE: enable [-h|--help] toggle
       OR: enable [-h|--help] on [--fail-if-noop]
       OR: enable [-h|--help] off [--fail-if-noop]
    """
let enable_zone_help_generated = """
    USAGE: enable-zone [-h|--help] [--monitor <monitor-pattern>] <zone>
    """
let exec_and_forget_help_generated = """
    USAGE: exec-and-forget <bash-script>
    """
let export_zone_layout_help_generated = """
    USAGE: export-zone-layout [-h|--help] [--monitor <monitor-pattern>] <layout-id>
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
let focus_zone_help_generated = """
    USAGE: focus-zone [-h|--help] <zone>
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
let list_workspaces_help_generated = """
    USAGE: list-workspaces [-h|--help] --monitor <monitor>... [--visible [no]] [--empty [no]] [--format <output-format>] [--count] [--json]
       OR: list-workspaces [-h|--help] --all [--format <output-format>] [--count] [--json]
       OR: list-workspaces [-h|--help] --focused [--format <output-format>] [--count] [--json]
    """
let list_zone_bindings_help_generated = """
    USAGE: list-zone-bindings [-h|--help] [--count]
    """
let list_zones_help_generated = """
    USAGE: list-zones [-h|--help] [--format <output-format>] [--count] [--json]
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
let move_node_to_zone_help_generated = """
    USAGE: move-node-to-zone [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                             [--fail-if-noop] <zone>
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
let resize_zone_help_generated = """
    USAGE: resize-zone [-h|--help] [--monitor <monitor-pattern>] <zone> width [+|-]<percent>%
    """
let save_zone_layout_help_generated = """
    USAGE: save-zone-layout [-h|--help] [--dry-run] [--layout <layout-id>] [--monitor <monitor-pattern>]
    """
let set_zone_snap_policy_help_generated = """
    USAGE: set-zone-snap-policy [-h|--help] [--monitor <monitor-pattern>] <policy>
    """
let set_zone_style_help_generated = """
    USAGE: set-zone-style [-h|--help] [--monitor <monitor-pattern>] <zone> <style-id>
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
let summon_workspace_help_generated = """
    USAGE: summon-workspace [-h|--help] [--fail-if-noop] <workspace>
    """
let swap_help_generated = """
    USAGE: swap [-h|--help] [--window-id <window-id>] [--swap-focus]
                [--wrap-around]
                (left|down|up|right|dfs-next|dfs-prev)
    """
let toggle_zone_help_generated = """
    USAGE: toggle-zone [-h|--help] [--monitor <monitor-pattern>] <zone>
    """
let trigger_binding_help_generated = """
    USAGE: trigger-binding [-h|--help] <binding> --mode <mode-id>
    """
let unbind_node_zone_binding_help_generated = """
    USAGE: unbind-node-zone-binding [-h|--help] [--window-id <window-id>]
    """
let scene_help_generated = """
    USAGE: scene [-h|--help] [--monitor <monitor-pattern>] <name>
       OR: scene [-h|--help] [--monitor <monitor-pattern>] next
       OR: scene [-h|--help] [--monitor <monitor-pattern>] new <name>
    """
let use_zone_availability_help_generated = """
    USAGE: use-zone-availability [-h|--help] [--monitor <monitor-pattern>] <set-id>
    """
let use_zone_layout_help_generated = """
    USAGE: use-zone-layout [-h|--help] [--monitor <monitor-pattern>] <layout-id>
    """
let use_zone_profile_help_generated = """
    USAGE: use-zone-profile [-h|--help] [--monitor <monitor-pattern>] <profile-id>
    """
let use_zone_scene_help_generated = """
    USAGE: use-zone-scene [-h|--help] [--monitor <monitor-pattern>] <scene-id>
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
let zone_help_generated = """
    USAGE: zone [-h|--help] init [--dry-run|--write] [--replace-existing] [--preset <preset>]
                [--monitor <monitor-pattern>]
    """

let zone_expose_help_generated = """
    USAGE: zone-expose [-h|--help] (display|zone)
    """
