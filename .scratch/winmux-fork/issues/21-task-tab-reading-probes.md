# Task: live probes for reading tabs

Type: task
Status: out of scope

Deferred 2026-09-30: Prateek put tabs off to a later effort so the foundation can be built first. See the map's Out of scope section.

## Question

Run the probes that the tab research couldn't, on Prateek's Mac. The probes and their exact commands are at the end of [research/18-reading-app-tabs.md](../research/18-reading-app-tabs.md) ("Unverified claims, with probes for Prateek"). The ones that change decisions are 1 (WinMux registers background native tabs as separate windows), 2 (Chrome's AppleScript window `name` and `bounds` match WinMux's title and frame), 3 (bulk-read time for Chrome-family tabs at a normal tab load), 4 (Cocoa-scripting window `id` equals `CGWindowID` for Terminal and Safari), 5 (VS Code, Zed and Cursor expose the active file as `AXDocument`), and 14 (Orca only ever opens one window, so its provider can map by pid). Probe 7 (which installed browsers carry Chrome's dictionary) is read-only and can run AFK. HITL: probes 2 to 4 raise a macOS Automation prompt for the app running them, so Prateek runs those himself. Record each result, with numbers, in the answer.
