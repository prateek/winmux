# Task 30: grid backdrop liveness for Electron and Metal windows

Ticket: [30-task-grid-backdrop-liveness](../issues/30-task-grid-backdrop-liveness.md)
Date: 2026-09-30
Harness and raw output: [prototypes/30-backdrop-liveness/](../prototypes/30-backdrop-liveness/) (`main.swift`, `ghostty-loop.sh`, `vscode-writer.sh`, one `cell-*.txt` per cover)

## Answer

VS Code and Ghostty keep painting under a non-opaque full-screen cover at 60%, 85% and 95% black, with or without a behind-window blur, and at 99% black without blur. They behave like Chrome did in task 14.

They stop painting when the cover's pixels are fully opaque, whatever `isOpaque` says. A cover with `isOpaque = false` and 100% black froze both apps, the same as the opaque control. The exception is a cover whose content view is an `NSVisualEffectView` with behind-window blending: with a 100% black layer on top of it, both apps stayed live, although the screen was as black as under the opaque cover.

Allow the grid backdrop 0% to 95% black. The measured boundary is higher (live at 99%, frozen at 100%), but 95% leaves margin and is the darkest value measured both with and without blur. At 95% the screen is already close to black (mean brightness 4 to 5 out of 255, against 1.3 for a fully opaque cover), so nothing is gained by going darker. The 60% black with blur default is safe.

## Results

"Changed" is the fraction of pixels that differ between two captures of the window taken 2 s apart. The visible baseline was 0.07 to 0.13 for VS Code and 0.92 for Ghostty; frozen is exactly 0.000. Each cell lists the 1–3 s and 8–10 s pairs under the cover.

| Cover | Blur | VS Code changed | Ghostty changed | Keeps painting? | Resume after uncover | Screen brightness under cover |
|---|---|---|---|---|---|---|
| 60% black, non-opaque | no | 0.110, 0.111 | 0.918, 0.921 | Yes, both | n/a | 30.1 |
| 60% | yes | 0.114, 0.105 | 0.918, 0.921 | Yes, both | n/a | 33.4 |
| 85% | no | 0.109, 0.098 | 0.921, 0.928 | Yes, both | n/a | 12.3 |
| 85% | yes | 0.122, 0.093 | 0.921, 0.918 | Yes, both | n/a | 11.9 |
| 95% | no | 0.123, 0.094 | 0.918, 0.928 | Yes, both | n/a | 5.1 |
| 95% | yes | 0.118, 0.112 | 0.918, 0.921 | Yes, both | n/a | 4.4 |
| 99% | no | 0.086, 0.107 | 0.928, 0.918 | Yes, both | n/a | 1.9 |
| 100%, `isOpaque = false`, black as window background | no | 0.000, 0.000 | 0.000, 0.000 | No, both frozen | VS Code 224 ms, Ghostty 162 ms | 1.3 |
| 100%, `isOpaque = false`, black as a layer in a clear window | no | 0.000, 0.000 | 0.000, 0.000 | No, both frozen | VS Code 192 ms, Ghostty 149 ms | 1.3 |
| 100%, `isOpaque = false`, black layer over the blur view | yes | 0.098, 0.089 | 0.928, 0.921 | Yes, both | n/a | 1.3 |
| Opaque control (`isOpaque = true`, black) | no | 0.000, 0.000 | 0.000, 0.000 | No, both frozen | VS Code 168 ms, Ghostty 106 ms | 1.3 |

Screen brightness is the mean of R, G and B over a capture of the whole display, 0 to 255. Uncovered it ranged from 49 to 102, moving with the Ghostty window's background colour.

Resume time is the delay from removing the cover to the first capture that differs from the last covered frame. The three frozen configurations resumed in 106 to 224 ms, consistent with the "within 0.3 s" from task 14. The resolution is coarse: a poll of both windows takes 50 to 100 ms, and the content itself only changes every 50 ms (Ghostty) or 100 ms (VS Code), so read these as "under a quarter of a second", and don't read the VS Code and Ghostty difference as real.

The 99% cell and the layer-only 100% cell were added to locate the boundary. They show that the window server decides occlusion from the cover's actual pixel alpha: 99% does not occlude and 100% does, and it makes no difference whether the black comes from the window's background colour or from a layer. `isOpaque = false` alone does not protect the windows underneath.

## Method

Same as task 14: capture each target window with `SCScreenshotManager.captureImage` and a `desktopIndependentWindow` filter, downscale to 320 px, and count the pixels that differ between two captures 2 s apart. A window-only capture shows the window's own surface, so the cover doesn't appear in it.

- One borderless cover at floating level over the whole 1512×920 display, with `ignoresMouseEvents` set. Both app windows sat under the same cover, tiled side by side by WinMux, which was left enabled; the cover's frame was read back 0.5 s after it went up and was never moved or resized.
- Per cover: a visible pair, cover up, pairs at 1–3 s and 8–10 s, cover down, poll until a frame differs from the last covered one, then one more pair.
- Three ways of filling the cover: black with alpha as the window `backgroundColor` (the task 14 construction); an `NSVisualEffectView` (`blendingMode = .behindWindow`, `material = .hudWindow`, `state = .active`, dark appearance) with a black layer-backed view over it; and the same black layer in a clear window with no effect view.
- Ghostty 1.3.1 ran a zsh loop that clears the terminal to a new background colour and prints `$EPOCHREALTIME` every 50 ms. VS Code showed a 60-line text file that a background loop rewrote every 100 ms, as in task 14. It ran on a throwaway profile with extensions disabled.

## Caveats

- **Mac mini stand-in.** macOS 26.4.1 on a Mac mini over Jump Desktop, not Prateek's laptop and ultrawide. The display is virtual, 1512×920 points. The harness reported `backingScaleFactor` 2.0 for it, so it is not a 1× display as the brief assumed. No physical display or GPU-driven panel was involved.
- **One run per cell.** Each cover was up for about 10 s, once. Throttling that starts later than 10 s would not show up. A real grid is open for less than that.
- **The 100% blur result depends on `NSVisualEffectView`.** It stayed live with the `.hudWindow` material and `.active` state. Other materials, an inactive state, or a different blur implementation (a `CABackdropLayer`, SwiftUI materials, Liquid Glass) were not tested. Don't rely on the blur to make a 100% backdrop safe.
- **The cover is not the product's panel.** It is an accessory-app `NSWindow` at floating level. An `NSPanel` at a higher level should behave the same for occlusion, but that wasn't tested.
- **VS Code's signal is small.** Thin text in a 320 px downscale gives a baseline change of about 0.1, against 0.92 for Ghostty. Frozen was exactly 0.000 every time, so the verdicts are clear, but VS Code's integrated terminal and webviews were not tested, only the text editor.
- **Not tested:** other Electron apps (Slack, Orca), Safari, Chrome at the new opacities, alphas between 0.99 and 1.0, partial covers, and several displays.
- **Raw output headers differ.** The first eight `cell-*.txt` files print `blur=yes|no`; the two boundary cells, run after the layer-only mode was added, print `fill=...`. The first control run was repeated because VS Code was showing a sign-in dialog and had a baseline of 0.000; `cell-opaque-control.txt` holds the repeat.
