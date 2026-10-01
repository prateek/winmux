# Task: confirm the grid backdrop keeps Electron and Metal windows live

Type: task
Status: resolved

## Question

Does a non-opaque grid backdrop keep the visible windows painting, for apps other than Chrome, and how dark can it get? [Task: measure thumbnail capture on Prateek's machine](14-task-measure-thumbnail-capture.md) found that a fully covered Chrome window stops painting, while one under an 85% black non-opaque cover keeps going. Only Chrome was tried.

Using the harness in `prototypes/14-thumbnail-harness/`, cover VS Code (Electron) and Ghostty (Metal) under non-opaque covers at 60%, 85% and 95% black, with and without a behind-window blur (`NSVisualEffectView`). For each, record whether the window keeps painting and how quickly it resumes once uncovered. The answer sets the backdrop's allowed opacity range for the grid and miniatures overlays ([Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md) defaults to 60% black with blur). AFK if the harness can drive the apps on the Mac mini; otherwise HITL on Prateek's Mac.

## Answer

Yes. VS Code (Electron) and Ghostty (Metal) both keep painting under a non-opaque cover at 60%, 85%, 95% and 99% black, with or without a behind-window blur. They stop at 100% black, even when the cover window has `isOpaque = false`: the window server goes by the cover's actual pixel alpha, not the flag. Measured 2026-09-30 on the Mac mini (one 1512×920 display at 2× scale), one run per cell.

| Cover | Blur | VS Code | Ghostty |
|---|---|---|---|
| 60%, 85%, 95% black | with and without | live | live |
| 99% black | without | live | live |
| 100% black, `isOpaque = false` | without | frozen | frozen |
| 100% black layer over `NSVisualEffectView` | with | live | live |
| Opaque control | without | frozen | frozen |

- **Allowed range for the grid and miniatures backdrop: 0 to 95% black.** The 60% with blur default from [Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md) is safe. At 95% the screen is already near black (mean brightness 4 to 5 of 255, against 1.3 fully opaque), so the config should cap the backdrop there and reject 100%.
- **Don't rely on blur to rescue 100%.** It stayed live in the one material tried (`.hudWindow`, `.active`), which isn't enough to build on.
- **Resume after a freeze** took under a quarter of a second for both apps (150 to 225 ms, at a 50 to 100 ms resolution).
- **Not tested:** VS Code's integrated terminal and webviews (the content was a text file rewritten every 100 ms), other Electron apps, an `NSPanel` at a higher window level, other blur materials, and alphas between 99% and 100%.

[findings](../research/30-grid-backdrop-liveness.md) · [harness and raw output](../prototypes/30-backdrop-liveness/)
