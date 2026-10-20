# Prateek's checks on an installed build and real hardware

Part of {{UMBRELLA}}.

A guest cannot show a signed release build, a real keyboard, a second display, or a real sleep, wake or unlock. Each line below is a check a build issue left for Prateek. Tick it when it passes; comment when it does not, and the next driver turns the comment into an issue.

A driver adds a line at Land, under the issue that left it, with the exact steps and what a pass looks like.

## From the second build

**A trace of a Lens opening**
- [ ] Hold Cmd-Tab five times, then run `winmux debug-lens-trace --last 5`. `panel ordered front` ends near 107 ms in every row, the first included.
- [ ] After a launch, read the `Lens startup preparation took` line in the unified log, category `lens`, and note the duration on your display. It was 170 to 350 ms in a guest at 1280 by 720.

**The Hold**
- [ ] On a real keyboard: Cmd-Tab, keep Command down, press Tab three times, release. The selection moves at each press and the window selected at release is focused. Every key in the guest was a posted event.

**The `'grid` Presentation**
- [ ] Open a grid Lens with three windows on the ultrawide. If the pictures look blurred, say so here: the picture is saved at most 582 points wide and a large Tile stretches it.
- [ ] After a fresh launch, open a grid, then run `winmux debug-lens-trace --last 1`. One first opening took 548 ms in a guest and the stage that took it is not known.

**Sections**
- [ ] On two displays, open a list or grid with `--sections monitor`. Each display has its own Section. Tests only so far.

**The strip opens off the main thread in a release build**
- [ ] On the installed build `0.5.6-dogfood.13` or later, hold Cmd-Tab for a second, ten times. WinMux is still running after each, and `ls ~/Library/Logs/DiagnosticReports | grep WinMux` shows no new report. `.12` crashed on the first hold.

**The strip as one row of the grid**
- [ ] On the installed build, hold Cmd-Tab with twelve or more windows open. Every window is in the strip, in two or more rows, with no "+N"; Tab steps from the end of one row to the start of the next; release focuses the selected window.
- [ ] On the ultrawide, hold Cmd-Tab with your usual windows. Say here if the row count or the Tile sizes look wrong: the widest display tried was 1920 by 1080, where eleven cards fit one row.
- [ ] On a real keyboard, in a strip of two rows, keep Command down and press Down, then Up. The selection moves to the Tile below and back.

**Mission Control and Exposé with WinMux running**
- [ ] With WinMux running and windows on three or more workspaces, swipe up on the ultrawide. Say here whether the thumbnails are tiny and scattered, and whether the slowness is in the animation or in finding the window. A guest showed thumbnails at about 8% of real size and no extra delay, opened by key.
- [ ] In System Settings, Trackpad, More Gestures, open the Mission Control menu and say here whether it offers "Off". A WinMux view on that swipe needs the system's gesture turned off first.
- [ ] In Mission Control, press an arrow key, then Return. Say here whether a window was selected and focused. Sources disagree.
- [ ] On the installed build, with a tab group and Columns on the focused workspace and the sidebar collapsed, swipe up with three or four fingers on the trackpad. Pass: Mission Control shows only app windows, with no tab bar, tab-group frame, Column divider or sidebar among or over the thumbnails. Swipe down, switch workspace with the sidebar, and swipe up again: still none. Then swipe down with the same fingers over a terminal for App Exposé: its windows show and nothing of WinMux's does. Close each view by swiping back, by Escape and by clicking a thumbnail, and check the tab bars, dividers and sidebar are back where they were. Say here, with a screenshot, if any WinMux panel shows.

**The system's Cmd-Tab stays the system's, and a short list of default shortcuts**
- [ ] After the build with this change arrives on the daily machine, by Sparkle or `brew upgrade --cask winmux`, run `winmux config check`. If it says a chord "is no longer a default binding", delete that removal from your config, or use `W.without-bindings`, and check again. A pass prints nothing, and `winmux doctor` then names your own config file.
- [ ] With your config and no `cmd-tab` binding in it, hold Cmd-Tab. It is Apple's app switcher, and `winmux doctor` shows `held=[] marker=[]`.
- [ ] On a real keyboard, `ctrl-w` deletes a word and `ctrl-r` searches history in your shell, and `alt-shift-o` opens `overview`.

**Display profiles: match a profile to the attached display**
- [ ] Once it has landed: with a profile for the laptop panel and one for the ultrawide, undock and dock with the lid shut, then with it open, then run your display script. Each time the Column count changes once, after the display settles, and docking again restores the ultrawide's arrangement.

**Release a dogfood build on every land**
- [ ] `brew upgrade --cask winmux` on the daily machine keeps the Accessibility and Screen Recording grants. It did in a guest with SIP off, by `brew upgrade` and by Sparkle.
- [ ] After that upgrade WinMux does not ask to "bypass the system private window picker". It asked once in a guest, on one version of three.

**A windowing mode on `alt-semicolon`**
- [ ] On a real keyboard, press `alt-semicolon`, let go, then `l`, `l`, `shift-j`, `3`, Escape. Focus moves twice, the window moves down, workspace 3 comes up, and a small `window` label sits at the bottom centre of the screen until Escape. Then do it fast, as you would in use: say here if the first letter after `alt-semicolon` is typed into the app as `¬` or another Option character, which means Option was still down when it landed.
- [ ] With a second display attached and the mode on, move focus to a window on the other display. The `window` label follows to that display.
- [ ] After the build with this change arrives, run `winmux config check`. If it says "The default binding mode lens was renamed to window", change that read to `defaults.mode.window.binding`. A config converted earlier keeps its own five-letter `lens` mode until you replace it.

**The Hold ends at the first letter**
- [ ] With the Cmd-Tab opt-in, on a real keyboard: Cmd-Tab, then `j` with Command still down, release, wait a second, `j`, Return. The strip stays up after the release, each `j` moves the selection, and Return focuses the selected window. Then press `j` as fast after Cmd-Tab as you can: say here if the `j` goes to the app in front instead (anything within about 100 ms of the Tab does, before the strip is drawn).
- [ ] `alt-slash`, then type "safari" at your normal speed. Search reads `safari`. Say here if it reads `såfari` or loses the first letter: that means Option was still down after the first letter, which now types an Option character.
- [ ] `alt-shift-o`, then `j` with both still down, release. The overview stays open with its selection moved, and Return focuses that window.
- [ ] Tap Cmd-Tab and let go as fast as you can, five times. Each time it switches to the previous window, and no strip is left on screen.

**`'miniatures` fills the screen, and a tab group shows its windows**
- [ ] On the installed build, with four workspaces in use, press `alt-shift-o` after each has been shown once. The four sit two by two and fill most of the screen. (Right after WinMux starts, a workspace not yet shown can draw its windows in the wrong places; that is a separate defect.)
- [ ] With three Safari pages in a tab group, the overview shows three cards fanned right and down, the active page in front with no text from the others showing through it. Move the pointer onto the edge of a card behind: it is selected. Return focuses that page, and it is the group's active tab afterwards.
- [ ] On the ultrawide, `alt-shift-o` with four workspaces gives two by two, and with two workspaces one row. Say here if the pictures are too blurry to read at that size.

**The strip draws pictures at one height**
- [ ] With the Cmd-Tab opt-in, hold Cmd-Tab on your own desk. The strip is one row of pictures at one height with the selected window's title in the footer, not two rows of cards. Say here if a strip of fifteen or more windows reads as a row of icons.

**Hover selects in the strip and the grid**
- [ ] With the Cmd-Tab opt-in, on the installed build, with a real mouse or trackpad: hold Cmd-Tab with the pointer resting, then move it over another picture and release Cmd. The selection follows the pointer, and release focuses the window under it. Then hold Cmd-Tab without touching the pointer: the second entry stays selected even when the strip draws under the pointer.
- [ ] In a grid (`winmux lens recent --presentation grid`), one notch of a real mouse wheel steps the selection one Tile, and one two-finger swipe on a real trackpad steps it once, not many times. Say here if a swipe should step more than once, or if the wheel should work with the pointer outside the panel, as the system's switcher does.
**The Search match highlighted, and window controls on a Tile**
- [ ] On the installed build, with the Cmd-Tab opt-in and a real mouse or trackpad: hold Cmd-Tab and move the pointer onto a picture that is not selected. Three circles, red, yellow and green, appear at its top-left. Press Tab to move the selection on, click the yellow circle without moving, and release Cmd. The window you clicked minimizes and its picture dims while the strip stays up, and release focuses the selected window, not the minimized one.
- [ ] Press `alt-slash` and type part of a window's title and its app name, such as `rep saf`. The matched letters are yellow in each remaining row. Say here if the yellow is hard to read on your wallpaper, in light or dark.

**Hints shown while a key is held**
- [ ] With the Cmd-Tab opt-in, on the installed build and a real keyboard: hold Cmd-Tab until the strip is up, then press Option too. Within a frame the selected picture shows `⌥↩ Summon to <workspace>` when it is on another workspace, a dashed orange landing spot appears where it would land, each picture shows `⌘<n>` for its workspace, and a legend sits under the strip. Let go of Option: all of it goes, the strip stays. Let go of Cmd: the selected window is focused.
- [ ] Press `alt-slash` at your normal speed and keep Option down a moment before letting go. No label, landing spot or legend flashes while the chord's Option is down. Press Option again: they appear. Say here if the thinner panel makes the list hard to read on your wallpaper.
- [ ] Hold Shift in an open list or grid: nothing appears, and Shift-Return still Summons the selected window.
**Peek: see the selected window at full size before switching**
- [ ] On the installed build, on your Retina display: `winmux lens recent --presentation grid`, Space, then `winmux debug-lens-trace --last 1`. Its `Session:` line ends with `peek-capture=<ms>ms`. Say here what it reads, and whether the picture sharpens from blurry to crisp quickly enough not to notice. The guest's 1x virtual display read about 19 ms warmed and 46 to 69 ms in a running Lens.
- [ ] With the Cmd-Tab opt-in, on a real keyboard: hold Cmd-Tab, press Cmd-Y, Tab twice, release Cmd. The selected window grows to its real place, the picture moves with each Tab, and release focuses the last one. Say here if you would rather have Space work in a Cmd-held strip too (Cmd-Space opens Spotlight, so it cannot without rebinding Spotlight).
- [ ] With a Japanese or Chinese input method, `alt-slash`, type a word in kana or pinyin, press Space to convert and Return to commit. The text converts and commits, and nothing is peeked or focused.
- [ ] With two displays, open a grid on one and peek a window that sits on the other, then click a Tile on the grid's display. The zoom ends and nothing else happens: no window is focused and the selection does not move.

**Staying open on release, and light and dark**
- [ ] On the installed build and a real keyboard, add `ctrl-alt-g = "lens committing-grid"` to `mode.main.binding` and `lenses.committing-grid = { presentation = 'grid, on-release = 'commit }` to your config. Tap Control-Option-G at your normal speed: focus moves to the next window and no grid flashes. Then hold Control-Option, press G twice and let go: the grid steps twice, and letting go focuses the selected window.
- [ ] Switch macOS to Light in System Settings, Appearance, then open `alt-slash`, the Cmd-Tab strip and `winmux lens recent --presentation grid`. Each draws a pale panel with dark text over your wallpaper, and with Option held the labels over the pictures stay readable. Say here if the light panel reads too grey or too bright, then switch back.

**Shipped Lenses for the grid, and the docs**
- [ ] With the Cmd-Tab opt-in, on the installed build and a real keyboard, with one app's windows on two workspaces: hold Cmd-backtick, press backtick twice and release. The grid shows only that app's windows, with no section headers, in the order you last used them; each backtick moves one card, and the window selected at release is focused. Then tap Cmd-backtick at your normal speed five times: each tap switches windows and no grid is left on screen.

**Three landing and placement edge cases: a float hint across displays, an empty container, and Columns turned off**
- [ ] On two displays, on the installed build: give a workspace Columns and a `place` hook that answers Overflow `float` into an occupied Column, and open a `miniatures` Lens there. Hold the Summon modifier over a floating window on the other display's shown workspace, then over one on a hidden workspace, and Summon each. Each window lands inside the outline the hint drew.

**The grid's first opening, and what refreshing every Tile costs**
- [ ] On the installed build, quit WinMux, start it again with your usual windows open, and wait ten seconds. Press `alt-semicolon` then `w` five times, pressing Escape between openings, then run `winmux debug-lens-trace --last 5`. The first opening's total is within 50 ms of the median of the other four. Say here what the five totals read.
- [ ] With about forty windows open across your workspaces, open the grid with `alt-semicolon` then `w` and leave it open for thirty seconds. The pictures refresh without the panel visibly stuttering, and WinMux stays under about a tenth of a core in Activity Monitor. The guest measured about 0.066 of a core.

**A picture as sharp as the Tile that draws it**
- [ ] On the installed build, on your Retina display, with three windows open on one workspace, one of them showing text: `winmux lens recent --presentation grid`, wait a second. The text in each picture is as crisp as the window's own text at that size, with no soft or smeared edges. Say here if any stays soft.
- [ ] On a display larger than 1920 × 1080 (an ultrawide or a 1440p external), open the same grid with two windows, then with one window parked on another workspace so its Tile is Frozen. Live pictures are crisp. Say here how soft the Frozen one looks next to them: that answers "Should a parked window's picture be as large as a grid draws it?" in Open with Prateek.
- [ ] With a Retina laptop and a 1x external display, open the grid on each display in turn. The pictures are crisp on both, and none looks blocky on the 1x display.

**Ctrl-Up does nothing while the pointer is over the expanded sidebar**
- [ ] On the installed build, with a terminal focused and no Lens open, rest the pointer on the left edge until the sidebar expands, keep it there, and press Ctrl-Up: Mission Control opens. Close it with Ctrl-Up, then do the same with Ctrl-Down: App Exposé opens for the terminal. Then press Cmd-N with the pointer still on the sidebar: the terminal opens a new window, and its name stays in the menu bar.
- [ ] Still on the installed build, with the pointer over the expanded sidebar, type a few letters so the sidebar searches, click once in the sidebar's search field, then press Cmd-Delete: the search clears. Say here if it does not.

**A Safari window's picture is a thin grey strip**
- [ ] On the installed build, open three Safari windows on different pages, wait a few seconds, then run `winmux lens --filter true --presentation grid --sections app` and, after Escape, hold Cmd-Tab for the strip: every Safari Tile shows its page, none a thin grey strip or the Safari icon. Say here if one does, with a screenshot.

**Quitting WinMux puts windows back where they were**
- [ ] On the installed build with two displays: put a floating window on display A, start WinMux, drag the window to display B and resize it, then quit from the menu. Pass: it is back on A at its old position and size.
- [ ] Set `restore-windows-on-quit = false` and reload. Put a window on the display that is not the main one, then quit. Pass: the window is centred on that display, not on the main one.
- [ ] Start WinMux with a window on display B, unplug B, then quit. Pass: every window is on the remaining display, none off screen.
- [ ] Log out with WinMux running and windows on two workspaces, then log back in before WinMux starts. Pass: Cmd-Tab is Apple's again, and no window sat in a screen corner at logout.

**A first run that explains itself**
- [ ] On a Mac account that has never granted WinMux anything (or after `tccutil reset Accessibility com.zimengxiong.winmux` and `tccutil reset ScreenCapture com.zimengxiong.winmux`, with WinMux quit), install the release from the cask, follow the caveats past Gatekeeper, and open it. Pass: the WinMux Setup window appears; each button adds WinMux to its list in System Settings and opens that pane; after both toggles, the window offers a relaunch or macOS offers Quit & Reopen, and either one comes back at "Ready to arrange your windows?"; no window moves until **Start WinMux**, and then they tile. Say here which step needed anything the window did not tell you.
- [ ] With two displays, the setup window and the first tile after Start. Pass: the setup window is on the main display, and windows on both displays stay put until Start.

**A `winmux://` URL runs a command**
- [ ] On the installed build, paste `winmux://run/workspace/2` into Safari's address bar and press Return, then allow it to open WinMux if Safari asks. Pass: workspace 2 is shown, and no WinMux window opens. Do the same from a Shortcuts "Open URLs" action, and from Raycast or another launcher if you use one, with `winmux://run/lens/overview`: the Overview Lens opens.
- [ ] With WinMux quit, open `winmux://run/workspace/2` from Safari. Pass: WinMux starts and then shows workspace 2. Say here if it starts and does nothing.

**Settings shows what is loaded**
- [ ] On the installed build, open **Settings…** from the menu bar, then **Open Config**. Pass: `winmux.ncl` opens in the editor you use for it (or macOS asks which app, if `.ncl` has none), and Settings lists your Lenses with their Triggers, your Columns per workspace, and your bindings; typing a chord you use, such as `⌥⇧O`, into the Shortcuts search finds it.
- [ ] With Settings open, save a typo into `winmux.ncl`. Pass: a banner with the error appears at the top without reopening Settings, the values below it are still yours, and saving the fix clears it.

**The CLI socket moves out of `/tmp`, and the docs say who can use it**
- [ ] On the installed build after Sparkle updates WinMux and before `brew upgrade --cask --greedy winmux` (Sparkle updates the app but not the cask's `winmux`), run the older `winmux list-workspaces --all` from the cask. Pass: it prints your workspaces. Then upgrade the cask, quit and reopen WinMux, and run `winmux --version` and `ls -ld "$(getconf DARWIN_USER_TEMP_DIR)com.zimengxiong.winmux"`. Pass: client and server versions match, and the directory reads `drwx------` with your name.

**A command that shows where focus is**
- [ ] On the installed build with several windows on screen (Columns on, if you use them), press Option-semicolon, then `c`, on your own keyboard. Pass: every screen dims except the focused window, which gets an accent border, for about a second before it fades; the windowing mode stays on, and `h` right away moves focus with no mark left behind. Then run it again and press any key or click at once. Pass: the mark goes immediately. Say here if the look is wrong: the dim, the border colour, or the length.
- [ ] With two displays, focus a window on the second display and run `winmux find-focus`. Pass: both displays dim, and the border is on that window on the second display.

**Close a window from its WinMux tab**
- [ ] On the installed build, make a tab group of five windows, hover a background tab and click its ×, then click three times in one place, at the active tab's × or a hovered tab's ×, with your own mouse or trackpad. Pass: each click closes one window, the next tab's × lands under the pointer without the tabs widening, and the tabs widen only once the pointer leaves the strip. Then middle-click a tab with a real mouse's middle button. Pass: that window closes. Say here if the hold or the animation feels wrong.
- [ ] Put an unsaved document from an app you use (TextEdit, Pages, an editor) in a tab group as a background tab and click its ×. Pass: its tab stays, it comes to the front with the save sheet, and Cancel leaves it in the group.

**The ninth tab digit goes to the last tab**
- [ ] After the dotfiles change for Option-9 and Option-0, on the installed build with a real keyboard, make a tab group of more than nine windows and press Option-9, then Option-8. Pass: the last tab, then the eighth, is focused. Then press Option-0 in a text field. Pass: the app gets it (on a US layout it types `º`) and WinMux does nothing.

**Shortcut hints on tabs while the modifier is held**
- [ ] On the installed build with a real keyboard, focus a window in a tab group of more than nine tabs and hold Option. Pass: after about half a second each of the first eight tabs shows its digit where its icon was, the last tab shows `9`, the tabs between show their icons, and releasing Option brings the icons back. Then press Option-3 the way you usually do, quickly, and also Option-3 followed by keeping Option down. Pass: neither shows a hint, and both focus the third tab. Say here if half a second is too long or too short.

**Dragging a window shows no overlay when Columns are on**
- [ ] On the installed build with your own Columns config, drag a window by its title bar over each Column, one empty and one occupied. Pass: each shows an outline where the window will land (the whole Column, its lower half for a `'split` hook, a new Column for `'squeeze`), and the drop lands inside that outline. Then drag with Columns off. Pass: the overlays look as they did before.

**Arrange windows from the sidebar**
- [ ] On the installed build, with your own trackpad or mouse and keyboard, hold Option and drag a window row onto another window row's left zone, then a third window onto one of them's tab zone; once, release Option before you let go. Pass: the zones appear on the row only while Option is held, each drop makes the split or tab group its highlighted zone names, and with Option released the row shows the plain before/after line and the drop makes a sibling.

**The sidebar as a tree**
- [ ] On the installed build with your own sidebar config, move the pointer to the left edge, then away, at your usual speed. Pass: the rail shows workspace numbers only, the tree opens on hover and closes when you leave, and the pin keeps it open. Say here if the open or close timing feels wrong.
- [ ] With your own mouse or trackpad, drag a window row onto the upper half of another window row, then the lower half, with Splits and Columns off. Pass: the insertion line follows the pointer and the window lands before, then after, that window. Drag a tab group onto a Column mark. Pass: it lands in that Column.
- [ ] Set `workspace-sidebar.tree.splits = true` in your config and reload. Pass: every workspace shows its splits until you click a workspace's Splits button, which hides them there only.
- [ ] With two displays, expand the sidebar on each and drag a window from one display's sidebar onto a window row of a workspace on the other. Pass: it lands beside that window. Then sleep and wake, and lock and unlock. Pass: the tree matches the windows on screen.

**A dragged tab group moves one window when its active tab is a nested container**
- [ ] On the installed build, make a tab group whose active tab is a split (Columns on, then move a window into an occupied Column slot, or join two windows and make their parent a tab group with a third). With your own mouse or trackpad, drag the group's tab-strip header onto another window, then its sidebar header onto another workspace. Pass: every window of the group moves each time, the inner split included; the sidebar lists them all under the destination. Until **A window in a tab group's active split stays on screen when its workspace hides** lands, one window of the split may stay on screen after the workspace drop.

**A skill for a person's agent, shipped with the CLI**
- [ ] After `brew upgrade --cask --greedy winmux` (the cask's `winmux` is not updated by Sparkle), quit WinMux and run `winmux agent skill | head -3`. Pass: it exits 0 and prints `name: winmux`. Then install it with `mkdir -p ~/.claude/skills/winmux && winmux agent skill > ~/.claude/skills/winmux/SKILL.md`, start WinMux, and ask your agent "which window is focused, on which workspace, and in which Column?". Pass: its answer matches the screen.

**A capture mode for hooks**
- [ ] After `brew upgrade --cask --greedy winmux` (Sparkle does not update the cask's `winmux`), run `winmux debug-hooks on`, open a window on a workspace whose Columns have your own `place` hook, then `winmux debug-hooks off`. Pass: `on` prints a `hook-capture.jsonl` path under `~/.local/state/winmux`, the file has one record per hook that ran for that window with `args` and `result` you recognise from your config, and `off` prints that count.

## From the first build

- [ ] The double-sided flip animates (deployment target).
- [ ] The Settings panes show the loaded config, and sidebar renames survive a restart (Nickel config).
- [ ] A signed build shows the screen-recording indicator as expected while a Lens with pictures is open (thumbnail cache).
- [ ] The strip and the Cmd-Tab takeover survive a real sleep, wake and unlock, and fast user switching (strip).
- [ ] A window moves between two real displays, and a display changes size, with Columns on (fixed Columns, Column Policy hooks).
