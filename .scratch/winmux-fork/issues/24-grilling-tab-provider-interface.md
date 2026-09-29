# Grilling: tab provider interface

Type: grilling
Status: open

## Question

Instead of per-app code, apps plug their tabs into WinMux through registered tab providers, matched by bundle id (see §10 of [the tab research](../research/18-reading-app-tabs.md)). Decide the interface:

- **Modes:** pull (a command WinMux runs when a Picker opens, with a timeout, printing JSON, like Alfred's Script Filter), push (a long-lived watch command such as `cmux events`, or a `winmux tabs publish --app-id --pid` verb an app or extension calls itself), or both.
- **Schema:** one versioned document per app. Window match hints in priority order (exact `CGWindowID`, then pid plus title, pid plus bounds, pid alone), and per-tab `id`, `title`, `url`, `path`, `group` (a sidebar item such as an Orca worktree) and a free-form `meta` map. Where an optional `jq` transform lives in the config.
- **Switching:** how a provider declares the command that brings a tab to the front (Orca's `orca terminal switch --terminal <handle>`, cmux's `focus-pane`, Chrome's `active tab index`).
- **Filter side:** the CEL types this adds (`w.tabs` as `list<Tab>`, `w.document`, `w.incognito`) and how `meta` is typed.
- **Built-ins:** the Chrome-family AppleScript route and native macOS tab grouping become the first built-in providers; Orca and cmux become config entries.

Check the schema against Orca, cmux and Chrome before fixing it; freezing it too early is the main risk. The CLI verbs also feed [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md).

Starting points from §9 and §10 of the research: `w.tabsSource` (which provider answered) and `w.tabsAge` (a duration, so a binding can ignore stale tabs); absent `url` or `path` as `""` rather than optionals, so `w.tabs.exists(...)` needs no guards; `Tab.group` for the sidebar level and `Tab.meta` as `map<string, string>`. Runtime rules to confirm: pull providers run off the main thread with a hard timeout, at most one in flight per app, only when a binding references `w.tabs` (type-to-search over tab titles counts); keep the last good answer on failure, retry at most once per Picker open; restart watch providers with backoff; run `activate` only after WinMux has focused the window.
