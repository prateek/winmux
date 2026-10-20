# Issues closed when the adoption umbrella is filed

Each is closed as not planned, with the comment below, after the umbrella and its children exist so the comment can link the replacing issue by number. `#273` and `#280` are the filed numbers of **Modes are the only modality** and **A command hands a chord to the system switcher**.

## #213, Escape while Cmd-Tab is held does not dismiss the strip

Closed in favour of #273. Under it the Cmd-Tab hold is a mode, `cmd-tab`, whose record binds `esc` to close the Lens and return to `main`; Escape during the hold is then an ordinary key in that mode, and the test for it is one row of that issue's rule table.

## #144, Keys queued while a Lens opens are decided by the session's own rules

Closed in favour of #273. The Lens session's own key rules go away; keys pressed while a Lens is opening are queued and read in the mode that is current when it is ready, and a global chord runs at once and closes the Lens. That is a named engine rule and a Done-when item there.

## #145, How many Escapes close a Lens that opens in Search?

Answered by #273: two. In the shipped `search` mode Escape runs `mode browse`, keeping the text and the matches; in `browse` Escape closes the Lens and returns to `main`. A Lens that opened in Search behaves the same, since it is simply a Lens with `search` current. Closed as answered.

## #227, A window row above the system switcher

Closed as superseded. The grilling of 2026-10-19 settled the switcher differently: Cmd-Tab opens a Lens of the current workspace's windows, the wider scopes are shipped Lenses, and the system's own switcher is reached by #280, which lends the chord back to macOS for one use. No row above the native switcher is built.

## #228, Should entering the window row above Cmd-Tab close the system's switcher?

Closed with #227; the row is not built, so the question has no subject.

## #268, Adoption tracker from a day of daily use

Closed as done when the umbrella is filed, with the item map as the closing comment: every item is linked to a child, an existing issue or marked dotfiles-only; the umbrella is filed; the grilling happened and its outcome is in `.scratch/winmux-fork/issues/36-grilling-what-winmux-becomes.md`, `AGENTS.md`'s Scope section through its docs child, and the umbrella's body.
