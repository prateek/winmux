# Prototype: grid Presentation look and behaviour

Type: prototype
Status: open
Blocked by: 03, 14

## Question

What should the grid Presentation look and behave like, so it no longer 'looks awful'? Build a rough UI prototype: thumbnail layout for about 5 to 40 windows, grouping by workspace or project, how stale thumbnails of parked windows are shown, how Accessory app windows look, selection and keyboard or gesture navigation, the Summon affordance, and behaviour on the laptop panel versus the ultrawide.

Inputs from [Task: measure thumbnail capture on Prateek's machine](14-task-measure-thumbnail-capture.md): most parked thumbnails are frozen at park time, so design them as "as of when you left it"; the grid panel should be non-opaque so visible windows keep painting underneath it. That was only checked on Chrome with an 85% black backdrop; confirm Electron and Metal apps, and whether a darker non-opaque backdrop still keeps them live.
