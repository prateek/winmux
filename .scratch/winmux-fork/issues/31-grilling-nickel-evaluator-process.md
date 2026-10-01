# Grilling: where the Nickel evaluator runs

Type: grilling
Status: open

## Question

`nickel-lang-core` leaks memory on almost every call that touches the stdlib (upstream issue nickel-lang/nickel#1908, open since 2024), about 160 KB per 50-window Lens open, and dropping the engine frees nothing ([Task: Nickel binding spike](28-task-nickel-binding-spike.md)). Where should WinMux evaluate Filters and Policy hooks? The main candidate is a supervised helper process (a small Rust binary shipped inside the app), recycled on an RSS threshold or config reload. It adds no measurable call cost over a pipe, and a warm respawn takes 7.6 ms. Nickel's own language server made the same choice for the same leak (nickel-lang/nickel#1869). The alternatives are in-process with periodic WinMux restarts, patching Nickel upstream (cycle collection), or revisiting the language choice. If it's the helper, settle the transport (pipe or XPC), the request shape (one batched request per Lens open; typed enum fields), what WinMux does while the helper restarts or after it crashes (block, time out, fall back to the last result or to "match everything"), who runs the load-time smoke run, and how reload swaps helpers atomically.
