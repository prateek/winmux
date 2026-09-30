# Task: confirm the grid backdrop keeps Electron and Metal windows live

Type: task
Status: open

## Question

Does a non-opaque grid backdrop keep the visible windows painting, for apps other than Chrome, and how dark can it get? [Task: measure thumbnail capture on Prateek's machine](14-task-measure-thumbnail-capture.md) found that a fully covered Chrome window stops painting, while one under an 85% black non-opaque cover keeps going. Only Chrome was tried.

Using the harness in `prototypes/14-thumbnail-harness/`, cover VS Code (Electron) and Ghostty (Metal) under non-opaque covers at 60%, 85% and 95% black, with and without a behind-window blur (`NSVisualEffectView`). For each, record whether the window keeps painting and how quickly it resumes once uncovered. The answer sets the backdrop's allowed opacity range for the grid and miniatures overlays ([Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md) defaults to 60% black with blur). AFK if the harness can drive the apps on the Mac mini; otherwise HITL on Prateek's Mac.
