# Second build: releases on land, the Lens look and the grid, and the follow-ups

The fork foundation, #1, is built. This umbrella holds everything open after it: a release on every land, the Lenses brought up to the look and reach of the switchers they replace, the `'grid` Presentation, the follow-ups the first build left behind, and the deferred features that wait on Prateek. It replaces the follow-ups umbrella, #38, whose children moved here.

## What the Lens work is

A Lens's appearance is split into four parts that do not know about each other.

- **Tile**: what one entry looks like. One drawing, used by every Presentation.
- **Presentation**: where Tiles go and how large they are. `'list` is a column, `'strip` is one row, `'grid` is packed rows sized to fit, `'miniatures` puts them where the windows are.
- **Sections**: how entries are grouped.
- **Behaviour**: what any Presentation can take. What release does, hints, peek, Search, Summon, marks and the Lens's keys.

Anything the Tile gains appears in every Presentation at once. The look was chosen from a working prototype, [`prototypes/31-lens-look`](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), which also holds captures of native Cmd-Tab, Mission Control and AltTab on the same desk. Open it in a browser. It is the visual specification the Lens issues point to.

## Child issues, in build order

{{CHILDREN}}

- **The release issue is first** so that each later issue reaches an installed build as it lands. The release runs on the build machine as the last step of landing; GitHub CI stays the gate.
- **Then the `vm` skill's two-guest limit and guest size**, so two relays can run side by side inside 70% of the build machine.
- **Then the two issues split from the architecture review that touch Lens code.** The Lens work rewrites the same files, so they go first, and the Tile is built on the session they produce.
- **After the Tile, three issues go ahead of the rest of the Lens look.** The first-run screens issue, because every later issue films in a clone of that image. Then the trace of a Lens opening, taken once the Tile has settled what the first frame draws and before the grid, sections and the strip each change it; it finds and removes the strip's half second. Then the Hold, which gives keys one meaning while a Trigger's modifiers are down in every Presentation, before the grid and the release setting build on it; it reads that trace's key events.
- **Then the Lens look**, in dependency order: the Tile, the grid, sections, the strip, the Search highlight and window controls, hints, peek, release behaviour and appearance, `'miniatures`, and last the shipped Lenses and the docs.
- **The follow-ups are independent of the Lens work** and of each other, except where a draft names a dependency. The three landing and placement edge cases are among them. They can be built at any point. The `close` bug is still the best first issue for a relay that has never run end to end in a guest.
- **The hero demos are last**, so they are filmed once, of the Lenses as they will look.

## Blocked on Prateek

- **Deferred features.** Designed in part during #1 and put off. None is specified, and no child issue builds toward them beyond what it states.
  - #47 Display profiles
  - #48 Tabs. The Tile draws an entry, not a window, so that a Tab can be an entry later.
  - #49 Trackpad gestures as Triggers
  - #51 Proactive registration of Accessory apps
- **The checks #1 left for him**: installed and release builds, real wake and unlock, two displays. #14 stays open with #1 until he has made them.

## Later, with no issue yet

- Paging the grid when Tiles would get too small, and collapsing Tiles to text.
- Windows moving from their places into the grid as it opens.
- An icons-only Tile, as native Cmd-Tab has.

## Running the relay

- The `issue-relay` skill takes its umbrella from the brief it is started with, and stops on a brief that names none.
- The relay starts when Prateek asks for it. Opening this umbrella did not start it, and no child has a worktree or a guest until he does.
- The relay has never run end to end in a guest. Expect gaps in the skill on the first issue; the driver fixes them as they turn up and says what changed.
- A child that says **Blocked on Prateek** is not buildable. The driver skips it and takes the next child whose dependencies are closed.
- **Before the builder pass of the first-run screens issue**, the driver checks two things. That issue has the builder rebuild the golden image, while the relay's own guest for it is a clone of the old image and the builder runs on the host. So: the builder's environment has `TART_HOME` set, and renaming `winmux-golden` aside does not disturb the running clone. If either fails, that is a gap in the skill to fix and report.
- A stopped guest named `demo-set` holds the desk as it was dressed by hand, with the first-run screens already clicked and AltTab installed for the prototype's captures. It is for looking at the set, and proves nothing about a fresh clone. Delete it once the first-run screens issue has landed.
- **The staged desk** the Lens issues name is the fourteen-window one in the prototype's captures. Its staging script is [`demo/desk/stage-rich.sh`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/desk/stage-rich.sh). The Tile issue moved the set into the `demo` skill.
- The driver's Land step runs `script/dogfood-release --next` on the host after every land, from the pulled `fork` checkout, before removing the issue worktree. It records the version, docs-only skip or failure; a failed release does not undo the merge or stop the relay. Builders never publish; a builder working on the release script may use `--dry-run` on the host.

## How the children are written

The same way as the children of #1. **Decisions** are settled. **Defaults chosen for you** are starting points: the implementer may change one and says so in the pull request. Anything a child is silent on is the implementer's call, reported the same way. The terms are defined in [`CONTEXT.md`](https://github.com/prateek/winmux/blob/fork/CONTEXT.md).

AltTab is GPL-3. The Lens issues match what it does and how finished it looks. No code or asset of it is copied.

## Where this came from

- The Lens look prototype and its captures, linked above.
- [Issue #35](https://github.com/prateek/winmux/issues/35), the **Declined** lists of pull requests [#32](https://github.com/prateek/winmux/pull/32) and [#33](https://github.com/prateek/winmux/pull/33), and pull requests [#34](https://github.com/prateek/winmux/pull/34) and [#36](https://github.com/prateek/winmux/pull/36), for the follow-ups.
- The architecture review first filed as one issue, now three: the Column placement issue, the Lens state issue, and the reload and Policy hook issue.
