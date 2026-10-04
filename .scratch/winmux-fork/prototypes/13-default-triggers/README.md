# Owned Trigger and event demo

`demo.swift` builds two owned AppKit apps from one source. A regular app named `TriggerDemo` creates three titled coloured windows. An Accessory app named `TriggerEvidence`, launched with the argument `evidence`, shows real CLI and subscription text in a floating window.

Use distinct app bundles with identifiers `org.example.TriggerDemo` and `org.example.TriggerEvidence`, the corresponding executable names and `LSUIElement = true` for the evidence app only. Compile with `swiftc demo.swift`; no external packages are needed.

The demo reads `/Users/Shared/winmux13-demo/command`. `raise <nonce> <n>` raises an owned window (the nonce allows repeated commands), `new <nonce>` creates a Violet Page, `close <nonce>` closes only the latest owned window and `quit` terminates the demo. The evidence app reads `text` in the same directory. Display actual command output there, with private paths redacted; it never runs shell commands itself.

Save all existing window frames before launching WinMux, use isolated XDG directories, hide private apps, leave permission prompts unanswered and verify native chord restoration after quitting. The fresh-default run must use the shipped config. For other captures, remove cmd-tab, cmd-shift-tab and cmd-backtick from the imported record and restrict Lens Filter results to these owned apps. A wrapper can import an unchanged user example or converted file and apply these capture-only restrictions.
