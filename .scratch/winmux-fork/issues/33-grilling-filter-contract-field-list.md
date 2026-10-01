# Grilling: the Filter contract's final field list

Type: grilling
Status: open
Blocked by: 10, 11

## Question

What is the exact, complete field list of `Window`, `App`, the Filter context and `Column` that WinMux passes to Nickel? It is written twice: as Nickel contracts in the shipped config library and as the helper's typed Rust structs ([Grilling: where the Nickel evaluator runs](31-grilling-nickel-evaluator-process.md)), and the two must agree.

Fields have been added ticket by ticket: Window classes and attributes in [Prototype: filter language worked examples](06-prototype-filter-language.md), the Filter context and `lastFocusedSeq` in [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md), activation policy, subrole and level in the Accessory research, and `w.tabs`, `w.tabsSource`, `w.tabsAge`, `w.document` and `w.private` in [Grilling: tab provider interface](24-grilling-tab-provider-interface.md). The Display profile and the floating and Accessory defaults tickets will add more, which is why this waits on them. Native tab grouping is deferred (2026-09-30), so the tab fields stay as the tab provider grilling left them.

Consolidate them into one list with each field's name, type, enum values, and value when unknown (Nickel errors on a missing field). Decide which fields are enums rather than strings, how the contract is versioned, and whether `winmux` can print it (the CLI ticket asks for a listing of the Filter attribute schema).
