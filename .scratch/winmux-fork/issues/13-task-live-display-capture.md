# Task: live capture of display identity during g95nc and clamshell switches

Type: task
Status: open

## Question

What does macOS (CoreGraphics and AppKit) actually report during `g95nc set`, `g95nc reset`, and closing and opening the lid with the ultrawide attached? Log each screen's display ID, UUID, localized name, frame, built-in and main flags, and the sequence of reconfiguration callbacks with timestamps. Settle three things: which screen AppKit reports for the mirror set and under what name; whether the virtual screen's vendor is 2198; and whether its UUID is identical across two `set` runs. HITL: needs Prateek at the ultrawide with BetterDisplay running. The agent can prepare a read-only logging script beforehand.
