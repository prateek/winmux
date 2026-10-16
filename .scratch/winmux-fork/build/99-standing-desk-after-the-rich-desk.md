# The standing desk does not stage after the rich desk in the same guest

Part of {{UMBRELLA}}.

## What to build

`desk/stage-desk.sh` stages its four windows in a fresh clone, but not in a guest where `desk/stage-rich.sh` has run. Seen while landing **The fourteen-window desk stages on its first run in a fresh guest**, on both the current golden image and one built from the Xcode 27 base. It exits 1 with `expected one Safari window, got 3`, and the window list also shows the rich set's Calculator, Preview and Finder `desk` windows and a Ghostty terminal at `~`:

- Its `pkill` list stops neither Calculator nor Preview, and nothing closes the Finder window.
- Safari comes back with two `Untitled` windows beside the docs page. Deleting the rich set's `TabCreationPolicy` preference before staging does not change that.

So a demo pass that films both sets has to film the standing set first or take a fresh clone.

## Decisions

- **Either set stages after the other**, in either order, in one guest, with no fresh clone.
- **Stop what the other set opened**, by name, and wait for it as the rich script does; do not close stray windows after the fact.
- **The standing set's windows, apps and layout do not change.**

## Depends on

Nothing.

## Done when

- [ ] In one fresh clone, the rich set, then the standing set, then the rich set again each stage on their first run with exactly their own windows.
- [ ] The `demo` skill no longer needs a fresh clone between the two sets.

## Sources

- The driver's runs while landing **The fourteen-window desk stages on its first run in a fresh guest**.
