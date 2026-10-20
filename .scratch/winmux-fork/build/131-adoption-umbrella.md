# Adoption: what a day of daily use asked for

The second build, #55, carries the Lens look, the sidebar and the follow-ups. This umbrella holds what a day of adopting dogfood.66 on a laptop asked for, filed on GitHub as #55's children are, after [the grilling that settled what WinMux becomes](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/36-grilling-what-winmux-becomes.md): modes as the only modal concept, a minimal shipped keyboard with a full one beside it, an overview Presentation built from panes, native gestures, fullscreen and modifier drags, and the CLI gaps that the dotfiles helpers had to work around.

## The boundary

WinMux is a window manager with an integration surface. A helper becomes a feature when it needs state the surface cannot expose, fights WinMux, or must be continuous; otherwise it stays a script and the gap is a CLI issue. Tuna is the launcher. Status displays consume events. The test is in `AGENTS.md`'s **Scope and compatibility** once **Scope and compatibility: the native-versus-dotfiles test** lands.

## What the mode work is

A **mode** is a named record of chords to command lists with a lifetime, latched or held, a policy for unbound keys, and commands on entry and on release. A **Lens** is a view with a selection, driven by Lens verbs from whatever mode is current. Every Lens opener is a pair of commands. There is no stack. The held, normal and Search states of a Lens session, and the words Trigger and Hold, leave the glossary with **Modes are the only modality**.

## Child issues, in build order

{{CHILDREN}}

- **Scope and compatibility: the native-versus-dotfiles test** is first and docs-only. Nothing depends on it in the graph; it goes first by priority so every later child is reviewed against it.
- **Modes are the only modality** is the first large child. The shipped keyboard, the HUD legend, the mark keys, Column keys, gestures and the overview's keys all build on it. The mark commands themselves, **focus-back, mark and jump**, do not, and are ready now.
- **These are ready now and independent of the mode work**: the four reproduced defects, `fullscreen` on a floating window, clicking outside a Lens, double-sided windows hiding the tab strip, and the pointer jump; the five integration gaps; the system-switcher command; modifier move and resize; the two status children, the menu bar item and the sidebar accents; the strip's buttons and the search list's look; the modifier-held hints on the sidebar and move targets; and the research child. A relay can take them in any order. **Fullscreen is a round trip on the same Space** waits on the floating-window defect.
- **The overview goes prototype, pick, build.** Its prototype is independent; its build waits on Prateek's pick and on the mode work, since the Presentation's keys are a mode.
- **Hint mode follows the mode rewrite**, beside the modifier-held hints: Vimium's `f`, a transient mode that labels every window, Column and workspace row and reaches the label typed.
- **Gestures are #49, unparked**, with a replacement body on held modes. Its last checks need Prateek's trackpad.
- **Crash and reports**: #263 keeps the crash and the relaunch; #106 gains the opt-in flag and the prefilled-issue convention, and still waits on #91, the pinned toolchain, which is blocked on Prateek.
- **Display profiles, #47, absorbs the display-switching helper** as written; nothing in it changes.
- **Five issues are closed by this umbrella's filing**, each with a comment naming what replaces it: #213, Escape while Cmd-Tab is held, is a key in the `cmd-tab` mode of **Modes are the only modality**; #144, keys queued while a Lens opens, is that child's engine rule; #145, how many Escapes close a Lens that opens in Search, is answered by its `search` and `browse` modes, two; #227 and #228, the window row above the system switcher and its question, are superseded by Cmd-Tab showing the current workspace and **A command hands a chord to the system switcher**. #268 closes when this umbrella is filed, with its item map as the closing comment.
- **#109, re-running Place when a window leaves about:blank**, is a child of neither #55 nor #84; it joins #55's list by hand when this umbrella is filed.
- **Questions and checks that wait on Prateek** are children of **Open with Prateek: questions and checks that wait on him**, not of this umbrella.

## Later, with no issue yet

- **The tracker moves to beads.** Decided in the grilling, then deferred by Prateek on 2026-10-19 in favour of filing on GitHub for now. The two drafts, moving every open issue into beads with the relay reading them, and a phone view of beads, are kept beside this umbrella's drafts under `build/later/`, and the cap of 100 sub-issues is the reason to come back to them.

## How the children are written

As #55's are: **Decisions** are settled, **Defaults chosen for you** are starting points the implementer may change and say so. The terms are in `CONTEXT.md`, which **Modes are the only modality** rewrites for Mode, Lens, Trigger and Hold.

## Where this came from

- #268 and its handoff file.
- The grilling record above, resolved 2026-10-19.
