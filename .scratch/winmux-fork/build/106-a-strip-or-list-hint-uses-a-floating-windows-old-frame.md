# A strip or list landing hint uses a floating window's old frame

Part of {{UMBRELLA}}.

## What to build

For a floating window whose workspace is shown on another monitor, the Summon landing hint maps the window's frame onto the destination, as `layoutFloatingWindow` does. **Three landing and placement edge cases: a float hint across displays, an empty container, and Columns turned off** made that mapping match the real move. The frame it maps is `MiniatureWindow.frame`, and for a floating window that is `Window.miniatureFrame` (`lens/MiniatureTabSnapshot.swift`, `miniatureWindowFrame`). `miniatureFrame` is written when the window is hidden in a corner (`MacWindow.hideInCorner`), and refreshed from AX only when a `miniatures` or `grid` Lens opens (`SwitcherPalettePanel.openLens`). A strip or list Lens uses whatever was last written.

So a floating window that was hidden once, shown again and then moved keeps its old frame in a strip or list. The hint picks the source monitor and the proportion from that old frame. The real move reads the window's live position, so the window lands somewhere other than the hint. When the old frame's centre sits on the destination monitor, the hint says the window will not move while Summon moves it.

**Reproduce:** this needs two displays, so it is shown by a test with synthetic monitors. A live run on one display cannot show it: with one monitor a visible floating window is never moved.

## Decisions

- The hint for a visible floating window maps the window's frame as it is when the hint is computed, in every Presentation.
- Opening a strip or list does not pay for an AX read of every floating window. Read the frame of the selected window when its hint is computed, or keep `miniatureFrame` current as floating windows move. Choose the one that costs less on open, and say which in the pull request.

## Not in this issue

- The hint for a hidden window, which uses the proportion saved when it was hidden.
- How `miniatures` and `grid` draw floating windows.

## Depends on

**Three landing and placement edge cases: a float hint across displays, an empty container, and Columns turned off**.

## Done when

- [ ] A test with two synthetic monitors moves a floating window after it was hidden and shown again, opens a strip and then a list, and compares each hint with the frame Summon gives the window. It fails on the base.
- [ ] Opening a strip with many floating windows reads AX no more often than it does today, or the pull request gives the measured cost.

## Sources

- The second review of the pull request for **Three landing and placement edge cases: a float hint across displays, an empty container, and Columns turned off**.
