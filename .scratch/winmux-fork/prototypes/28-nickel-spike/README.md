# Nickel binding spike

Throwaway. Answers [Task: Nickel binding spike](../../issues/28-task-nickel-binding-spike.md).

- `src/lib.rs`: `Engine` (load once, `lookup` a function, `call` it with host values), JSON marshalling, a C ABI (`wm_load`, `wm_call`).
- `src/main.rs`: `spike config` benchmarks; `spike config errors|toml|leak|leak2|leak3|leak4|serve`.
- `config/`: stand-in `winmux.ncl` contracts, the reference `config.ncl`, a typo config, leak probes, a TOML import.
- `swift/`: the Swift caller, in-process through the C ABI and through `spike config serve` over pipes.

```sh
cargo build --release
./target/release/spike config          # bench.txt
swiftc -O -import-objc-header swift/bridge.h swift/main.swift -Ltarget/release -lwinmux_nickel_spike -o swift/caller
./swift/caller config ./target/release/spike   # swift-bench.txt
```
