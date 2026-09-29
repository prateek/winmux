# Research: Swish's gesture vocabulary and snapping model

Researched 2026-09-29 for the gesture Trigger table (`[mode.main.gesture]`). The current Swish release per its changelog is 1.13.3 ("General compatibility with macOS 27").

## Sources

Primary sources, all first-party (Christian Renninger, "Highly Opinionated"):

- **[Site]** https://highlyopinionated.co/swish/ : landing page and FAQ.
- **[Shots]** The seven settings-window screenshots the site embeds, `https://highlyopinionated.co/swish/media/screenshot-{1..7}.png`: General, Windows, Tabs/Screens, Snapping, Apps, Menubar, Advanced. These are the closest thing to a manual; the gesture tables below are transcribed from them. Screenshot 4 (Snapping) is cropped after the "Vertical" row, so the rest of the snapping table isn't visible.
- **[Video]** Demo clips on the site (`media/snapping.mp4`, `general.mp4`, `screens.mp4`). I sampled frames with ffmpeg; every clip shows two fingers on the trackpad.
- **[CL]** Changelog, https://highlyopinionated.co/swish/changelog (redirects to a public Notion page, read via Notion's page-chunk API). Covers 1.0 through 1.13.3.
- **[Legal]** https://highlyopinionated.co/legal/ : privacy policy and EULA.
- **[HN-dev]** Developer comments on Hacker News: item 20076380 (2019) and item 29746919 (2021).

Secondary sources, used only where marked:

- **[DT]** Digital Trends review, https://www.digitaltrends.com/computing/swish-window-management-mac-app/
- **[ANT]** AppsNTips, https://www.appsntips.com/home/mac-weekly-swish-supercharge-mac-trackpad
- **[Setapp]** https://setapp.com/apps/swish
- **[HN-users]** Hacker News items 40736068, 34382250 and 46999478.

Anything marked **UNVERIFIED** has no first-party source.

## 1. Gesture model

**Finger count.** Every gesture uses two fingers. The developer: "2x2 and 2x3 window tiling through two-finger swiping on the window's titlebar or the app's dock icon" [HN-dev 20076380]. All demo clips show two fingers [Video], and [DT] and [HN-users 40736068] agree. None of the settings screenshots or changelog entries mention three- or four-finger input; the conclusion rests on the developer's description and the demo clips [HN-dev; Video].

**Primitives.** Swipe in four directions, pinch in, pinch out, double tap, and tap-and-hold. From these Swish builds compounds:

- **Double swipe or double pinch.** The same motion twice without lifting: "pause your finger movement momentarily (until you feel haptic feedback) and then continue the motion" [Site FAQ]. The table symbols ↑↑ and the double-pinch icon mean this.
- **Tap, hold, then swipe or pinch.** For example, "tap, hold and swipe up" toggles fullscreen [Shots: Windows]. It is a distinct gesture from the plain swipe.
- **Direction changes inside one gesture** refine a snap (see §3).
- **Chaining.** A tap-and-hold "activates and chains" a window, so the next gesture applies to it [Shots: Apps, Tabs].

**Location qualifies almost everything.** "It uses the location of your cursor to determine which of its gestures can be activated" [DT]. The first-party screenshots name these zones:

| Zone | Source wording |
|---|---|
| Window titlebar or toolbar | "swiping and pinching on window titlebars" [Shots: Windows]. The FAQ calls it "a safe area for gestures" so Swish doesn't steal scroll or zoom [Site]. |
| Native tab bar (Finder, Safari, some browsers) | "Control tabs in windows with a native tab bar" [Shots: Tabs] |
| Dock icon, or the app's menu in the menubar | "swiping and pinching on their dock icon or menubar menu" [Shots: Apps]. In 1.1: "Extended dock functionality to the menubar menu" [CL] |
| Empty menubar area | "Invoke global convenience functions on the empty menubar area" [Shots: Menubar] |
| Windows in Mission Control or App Exposé | [Site FAQ]; [CL 1.4, 1.7] |
| Anywhere on a window | Only while the **Super Modifier** (default fn) is held: "perform window gestures on their entire area instead of their titlebar only or on their dock icon" [Shots: Advanced] |

**Modifiers form a second qualifier axis.** Swish has four configurable modifier slots plus Super: General **G** (default ⌃), Screen **S** (⌘), Secondary **2** (⇧) and Tertiary **3** (⇧⌥) [Shots: Advanced]. Each gesture row lists a primary form and an alternate. The alternate is usually a modifier plus a simpler motion, such as G+↓ in place of a pinch-in. An option also exists to "require the super modifier for all gestures" [CL 1.8].

## 2. Default actions

Transcribed from [Shots]. Notation: ↓ is a swipe, ↓↓ a double swipe, ⊙ a double tap, ○ a tap and hold, `pinch-in` / `pinch-out` a pinch.

**Titlebar (Windows tab)**

| Action | Primary | Alternate |
|---|---|---|
| Quit app | pinch-in twice | G+↓↓ |
| Close window | pinch-in | G+↓ |
| Minimize | ↓ | ○↓ |
| Fullscreen toggle | pinch-out | ○↑ |
| Hide app (Secondary: hide others) | G+⊙ | 2+⊙ |
| Move window to adjacent Space | ○←/→ | G+←/→ |

In fullscreen, minimize needs a tap and hold first "to prevent accidentals" [CL 1.1].

**Tab bar**

| Action | Primary | Alternate |
|---|---|---|
| Detach tab into a new window, then chain | ○ | none |
| Close tab | pinch-in | ↓ + G |

**Screens (Screen modifier, titlebar)**

| Action | Primary | Alternate |
|---|---|---|
| Move window to the screen in that direction | S+←↑↓→ | none |
| Fullscreen on the other screen (two-screen setups) | pinch-out twice | S+pinch-out |

**Dock icon or app menu (Apps tab)**

| Action | Primary | Alternate |
|---|---|---|
| Activate and chain frontmost window | ○ | none |
| Cycle the app's windows forward or back | ← / → | none |
| Quit | pinch-in | G+↓ |
| Minimize (Secondary: all windows) | ↓ | 2+↓ |
| Unminimize and chain (Secondary: all) | ↑ | 2+↑ |
| Hide (Secondary: hide others) | ⊙ | 2+⊙ |
| New tab or window (⌘N) | pinch-out | G+↑ |

**Empty menubar**

| Action | Primary | Alternate |
|---|---|---|
| ⌘-Tab switcher: tap, hold and scroll. Swipe ←/→ jumps straight to the previous or next app | ○ | ←→ |
| Unsnap all windows on this screen (Secondary: all screens) | ⊙ | 2+⊙ |
| Minimize all on this screen (twice or Secondary: all screens) | ↓ | 2+↓ |
| Unminimize all (same scoping) | ↑ | 2+↑ |
| Move all snapped windows to the screen in that direction | S+←↑↓→ | none |

Other gestures:

- Moving Spaces between screens from Mission Control [CL 1.9].
- A `Menubar → Mission Control → Screens` gesture, broken on macOS 27 by an Apple bug [CL 1.13.3]. The exact motion isn't in any screenshot (**UNVERIFIED**).

The site claims "30 easy-to-use window, dock and menubar gestures" [Site]; Setapp and older copy say 28. I count about 30 rows across the screenshots once snapping is included.

**Not remappable.** Each gesture can only be switched on or off ("click on a gesture's icon ... to enable or disable it" [Site FAQ]). Only the modifier keys are configurable. Next to BetterTouchTool, Swish is "less customizable but way more elegant" and needs "no configuration whatsoever" [Site FAQ]. A few behaviours can be split: Center versus Unsnap, and arrow versus Center hotkeys [CL 1.8].

## 3. Snapping

**Grids.** "Snap windows to a 2×2, 2×3 or 3×3 grid" [Shots: Snapping]. The site says "2×2, 3×2 & 3×3" [Site]. The unmodified gesture snaps in 2×2. Holding Secondary unlocks "2×3 snapping", which gives thirds and sixths, and Tertiary unlocks "3×3 snapping" [Shots: Advanced]. 3×3 arrived in 1.5. Thirds and sixths "auto-adjust to vertical screen orientations" [CL 1.8]. There is no custom-grid editor.

**The visible snapping rows** [Shots: Snapping]:

| Action | Gesture |
|---|---|
| Center (unsnap and center) | ⊙ |
| Maximize (fill the desktop area) | ↑ once |
| Left or right half | ← or → |
| Top or bottom half | ↑↑ or ↓↓ (double swipe) |

Maximize and top-half share ↑. The single-versus-double distinction is what separates them.

**Not in the cropped screenshot:**

- "Almost Maximize" was added as a snapping option [CL 1.8]. Its gesture is **UNVERIFIED**.
- Thirds: "access one-third directly on a single horizontal swipe (tap, hold and swipe to access two-thirds directly)" [CL 1.1]. Presumably this applies in the Secondary (2×3) grid; the mapping is **UNVERIFIED**.

**Quarters come from refining a direction mid-gesture.** In the demo video [Video: snapping.mp4, ~2–4 s, checked on native-resolution crops of the tooltip], the cursor tooltip first shows the left-half icon, then the top-left-quarter icon, and on lift the window lands in the top-left quarter. A second window goes left-half, then bottom-left. So one continuous gesture goes ← then ↑ (or ↓). The developer calls the keyboard version "snake-selector" shortcuts [HN-dev 29746919]. [DT] puts it as "two-finger swipe to a bottom corner for a four-screen split", and [Setapp] as "lower right corner ... just swipe down and right". **UNVERIFIED:** whether a pure diagonal also works, or only an L-shaped path.

**Feedback and commit** [Shots: General; CL]:

- **Haptics.** A tick when two fingers land, and another when a gesture step registers [DT]. There is a "Haptic Feedback" toggle.
- **Tooltip.** A small grid icon follows the cursor. Since 1.8, "Live tooltips provide a full-size animated and translucent preview", which is a ghost of the target frame.
- **Commit on lift.** "A full Swish gesture ends with you lifting your fingers" [Site FAQ].
- **Cancel.** "Cancel gestures by pressing Esc or resting for the specified timeout" (Cancel Timeout, default 0.8 s) [Shots: General]. The Esc cancel arrived in 1.0.1 and the rest timeout in 1.2.
- **Touch Sensitivity.** A slider with four levels. A fourth was added "as macOS 12 somehow decreases sensitivity" [CL 1.8.1].

**Unsnap and resize** [Shots: Snapping]:

- Drag to Unsnap. Holding Secondary disables it temporarily.
- Resize Adjacent Windows: "dragging the divider between them" resizes both neighbours.
- Grid Spacing sets the gaps.
- Optional Activate Window and Move Cursor behaviours after a snap.
- A re-snap step runs after displays connect or disconnect.
- Since 1.11, 2×2 snapping can optionally use macOS Sequoia's native tiling.

**Multiple displays.** The Screen modifier plus a direction moves a window "to the next screen in that direction", based on "their physical location in your multi-monitor setup" [Shots; Site]. A menubar variant moves every snapped window [Shots: Menubar].

**Keyboard parity.** Super modifier plus arrows (or WASD, IJKL, HJKL, Dvorak) run all snapping, screen and Spaces gestures. Backspace centers and unsnaps [Shots: Advanced; CL 1.7, 1.8.1].

## 4. Coexistence, permissions, known issues

- **No conflict with system three- or four-finger swipes.** Swish uses only two-finger gestures, confined to titlebars, the Dock, the menubar, or Super-held areas, so Mission Control and Spaces swipes can stay on. No first-party source asks the user to disable them. The FAQ even recommends turning *on* Three Finger Dragging [Site]. It does fight two-finger scroll and pinch-zoom, which is why the titlebar is the "safe area" [Site FAQ].
- **Scroll stealing.** An optional "Active Event Listener" (on in the screenshot) can "block scroll, flick and pinch events in the underlying window during gestures" [Shots: Advanced]. Since 1.1 it also blocks "scroll momentum after gestures ... for Catalina apps, where scroll areas often extend to the titlebar" [CL].
- **Scrollable toolbars.** Swish checks through Accessibility whether a scrollbar is under the cursor. Apps that don't expose one break this: Firefox's tab strip (workaround: show the Title Bar, or ignore Firefox and use Super) [Site FAQ; CL 1.13.1, 1.13.2]. Gestures are also disabled on toolbar sliders [CL 1.11], popovers [CL 1.6], and HTML tab elements [CL 1.10.2].
- **Permissions.** Only Accessibility is needed [Shots: General]. The "Input Monitoring popup" went away for new installs in 1.10.2 [CL]. Swish "needs to listen to all mouse movement" (under 1% CPU) [Site FAQ] and "cursor movement and keyboard events" [Legal]. It isn't on the App Store because it can't be sandboxed [Site FAQ].
- **How it reads touches.** **UNVERIFIED.** Nothing first-party names MultitouchSupport. The developer only mentions "weird macOS bugs and undocumented APIs" (HN item 22606684). The haptic ticks while fingers rest and the tap-and-hold gestures imply raw touch frames, not NSEvent scroll or magnify events alone. That is an inference.
- **Known issues.**
  - "system-wide pinch and swipe gestures might stop working unexpectedly", an Apple bug. Swish ships a "Fix Pinch & Swipe" action that briefly sleeps the display [CL 1.1, 1.9].
  - Apps can silently lose the Accessibility grant; re-check or re-add Swish [Site FAQ].
  - An Apple bug breaks the Mission Control → Screens gesture on macOS 27 [CL 1.13.3].
  - Tab support breaks with browser updates: Edge can't be restored, and Safari 26, Chrome, Arc and Dia were all restored after breaking [CL 1.13–1.13.3].
  - Users complain of limited grids on ultrawide displays and of stops or crashes after new macOS releases [secondary: search-result review summary; **UNVERIFIED**].
- **Speed cost.** Moving the cursor to a titlebar, plus the built-in delays for double gestures and cancels, make Swish "slower by design" than a hotkey [HN-users 46999478].

## 5. Licensing

Swish is commercial and closed source. It costs $16 once (two machines), or comes through a Setapp subscription, with a 14-day trial [Site]. The EULA says "Your license does not give you ownership of the Software. All rights to the Software are owned by the Author", and forbids distributing "the Software, or parts of the Software" [Legal]. There is no public repository. **Use it for design inspiration only**, the same rule the map applies to GPL tools. Copy no assets or tooltip artwork.

## 6. Implications for WinMux (options, not decisions)

**The main mismatch.** Swish's vocabulary is two-finger and location-qualified. WinMux's current grammar is three- and four-finger and global. Borrowing Swish's ideas means choosing one of two routes:

- **(a) Keep global three- and four-finger swipes.** Borrow only Swish's semantics: the refine-mid-gesture idea, the ghost preview, commit on lift, and cancel by Esc or resting.
- **(b) Add a location qualifier and allow two fingers in that zone only.** This re-inherits Swish's hard problems: hit-testing the titlebar through Accessibility, apps that scroll in the titlebar, and suppressing scroll and pinch. Research 01's finger-down scroll tap is the right base for the suppression.

**Candidate mappings onto Columns and Width presets:**

| Swish gesture | Swish action | WinMux analogue (option) |
|---|---|---|
| titlebar ← / → | snap to a half | move the window to the neighbouring Column (`move left/right`) |
| titlebar ←, then ↑/↓ in the same gesture | quarter | move to the neighbouring Column, then stack above or below within it (a vertical split in the target Column) |
| titlebar ↑ | maximize | toggle fullscreen or zoom of the Column (`fullscreen`, or a "max" Width preset) |
| titlebar ↑↑ / ↓↓ | top or bottom half | move up or down within the Column's stack |
| titlebar pinch-out / pinch-in | fullscreen / close | cycle the Width preset up or down. Better than close, which is destructive on a single pinch |
| titlebar ↓ | minimize | toggle floating, or minimize. Floating fits a tiling WM better |
| titlebar ⊙ (double tap) | center and unsnap | toggle floating and center (the closest analogue to "unsnap") |
| titlebar ○←/→ (tap, hold, swipe) | move to adjacent Space | `move-node-to-workspace next/prev` |
| screen-modifier + direction | move to the screen in that direction | `move-node-to-monitor left/right/up/down` |
| dock-icon ← / → | cycle the app's windows | focus the next window of the same app (useful for tab-heavy apps) |
| menubar ○ + scroll | ⌘-Tab switcher | open the Picker or strip and commit on lift (the open question in map.md about continuous gestures) |
| menubar ⊙ | unsnap all | `balance-sizes`, or reset the Workspace to its Columns default |

**Which need a location qualifier.** Everything two-finger does, because two-finger is scroll and zoom everywhere else. Three- and four-finger swipes can stay global, as they are now. Dock-icon gestures are the only way to target an app rather than a window. Menubar gestures are the natural home for per-screen or all-screens actions.

**Grammar sketches** (none chosen):

1. **Prefix a location onto today's names**: `titlebar-two-finger-swipe-left`, `dock-two-finger-pinch-in`, `menubar-two-finger-double-tap`. Unqualified names mean anywhere. Easy to parse, but the name space grows combinatorially.
2. **Structured key**: `[[mode.main.gesture]] fingers = 2, kind = "swipe", direction = "left", where = "titlebar", modifiers = ["cmd"], repeat = 2, prelude = "tap-hold"`. It scales to Swish's modifier, double and tap-hold variants without a naming explosion, but it's heavier than the current flat table.
3. **Path strings for refinement**: `titlebar-two-finger-swipe-left-up`, where a direction sequence inside one gesture is a distinct trigger. This mirrors Swish's quarter selection. It needs a recognizer with a pause-to-segment rule, as Swish uses a haptic pause.

**Worth copying regardless of grammar:**

- Commit on lift.
- Cancel with Esc or a rest timeout (0.8 s default).
- A ghost preview of the target frame.
- A haptic tick when a step registers.
- Keyboard parity: every gesture action is also a plain command.
- Per-gesture on/off rather than full remapping, which is Swish's choice. WinMux's config table already gives full remapping.

**Worth avoiding:** gestures whose single form is destructive (Swish pinch-in closes a window and pinch-in twice quits the app). Swish needs ↑ versus ↑↑ disambiguation and cancel timeouts partly because it overloads one zone with many actions.
