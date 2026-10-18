# read-only

Captured on the wrapped debug build of `7a5ba3f7` in `relay-123`.

```console
$ zsh ~/settings-proof/read-only.zsh
pressed WinMux
pressed Settings…
pane Overview: 0
pane Lenses: 0
pane Shortcuts: 0
pane Columns: 0
pane Hooks and Filters: 0
pane Behavior: 0
pane Appearance: 0
pane Config File: 0
pressed Reload From Disk
pane Configuration Reference: 0
# Four searches, Hide Sidebar, Show Sidebar, Open Config, Cancel omitted here.
PASS: every pane, search and Reload From Disk preserve config hash, mtime and defaults
READ_ONLY_EXIT=0
```

The script's before snapshot:

```console
$ shasum "$HOME/.config/winmux/winmux.ncl"
45ef92a730dbeb51403f3bbc5c3e00f671fd2893  /Users/admin/.config/winmux/winmux.ncl
$ stat -f %m "$HOME/.config/winmux/winmux.ncl"
1792320947
$ defaults read com.zimengxiong.winmux.debug
{
    "NSSplitView Subview Frames WinMux-Debug.shortcutSettings, SidebarNavigationSplitView" =     (
        "0.000000, 0.000000, 243.000000, 672.000000, NO, NO",
        "0.000000, 0.000000, 900.000000, 672.000000, NO, NO"
    );
    "NSWindow Frame WinMux-Debug.messageView" = "190 120 900 450 0 0 1280 690 ";
    "NSWindow Frame WinMux-Debug.shortcutSettings" = "190 0 900 672 0 0 1280 690 ";
    doubleSidedWindows = 0;
}
```

The after snapshot:

```console
$ shasum "$HOME/.config/winmux/winmux.ncl"
45ef92a730dbeb51403f3bbc5c3e00f671fd2893  /Users/admin/.config/winmux/winmux.ncl
$ stat -f %m "$HOME/.config/winmux/winmux.ncl"
1792320947
$ defaults read com.zimengxiong.winmux.debug
{
    "NSSplitView Subview Frames WinMux-Debug.shortcutSettings, SidebarNavigationSplitView" =     (
        "0.000000, 0.000000, 243.000000, 672.000000, NO, NO",
        "0.000000, 0.000000, 900.000000, 672.000000, NO, NO"
    );
    "NSWindow Frame WinMux-Debug.messageView" = "190 120 900 450 0 0 1280 690 ";
    "NSWindow Frame WinMux-Debug.shortcutSettings" = "190 0 900 672 0 0 1280 690 ";
    doubleSidedWindows = 0;
}
$ diff -u before.txt after.txt
# No output; exit 0.
```

The audit was run after the script. Its extra `search-command.ax` was freshly captured with the `⌘` query; that query is not part of `read-only.zsh` itself.

```console
$ python3 ~/settings-proof/audit-ax.py ~/takes/settings-loaded
overview: 0 editable text fields; no setting editors
lenses: 0 editable text fields; no setting editors
shortcuts: 1 editable text fields; no setting editors
columns: 0 editable text fields; no setting editors
hooks: 0 editable text fields; no setting editors
behavior: 0 editable text fields; no setting editors
appearance: 0 editable text fields; no setting editors
config-file: 0 editable text fields; no setting editors
reference: 0 editable text fields; no setting editors
config hash, mtime and defaults: unchanged
search lens: 8 matches
search glyph: 16 matches
search window: 45 matches
search empty: 0 matches
# Traceback shortened: the next assertion expects 3 command-glyph matches.
AssertionError: ('command', <re.Match object; span=(9182, 9233), match='AXStaticText | 0 bindings | settings-shortcut-cou>)
```

The read-only checks passed. The complete audit exited 1: the shipped config has zero `⌘` bindings, while the earlier rich-config capture had `cmd-backtick`, `cmd-shift-tab`, and `cmd-tab`. No expectation or source file was changed to make this pass. The audit's later base/head comparison section was not reached; those older captures are not new validation of this commit.

Full output: [read-only.log](read-only.log), [read-only-audit.log](read-only-audit.log). Fresh snapshots and AX dumps: [final](demo-takes/settings-loaded/final/).
