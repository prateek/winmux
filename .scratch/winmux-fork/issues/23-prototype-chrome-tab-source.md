# Prototype: Chrome-family AppleScript tab source

Type: prototype
Status: out of scope
Blocked by: 21, 24

Deferred 2026-09-30: Prateek put tabs off to a later effort so the foundation can be built first. See the map's Out of scope section.

## Question

Build the Chrome family as the first built-in tab provider (shape set by [Grilling: tab provider interface](24-grilling-tab-provider-interface.md)): a throwaway source for Chrome and its derivatives that fills `w.tabs` (title, url, active, index) over AppleScript and switches tabs by setting `active tab index`, then react to it. Settle: how scripted windows map to WinMux windows (title plus bounds, per the probes), the cache and refresh policy on Lens open, what a stale or failed read looks like in a Lens, the setup flow for Automation grants (`AEDeterminePermissionToAutomateTarget` only works while the browser runs), and the build changes (`NSAppleEventsUsageDescription`, the apple-events entitlement under the hardened runtime). Its result decides the open half of the "Tab-aware Lenses" fog item: whether browser tabs are only searchable window attributes or their own Lens entries. Background in §1, §5, §6 and §9 of [the tab research](../research/18-reading-app-tabs.md).
