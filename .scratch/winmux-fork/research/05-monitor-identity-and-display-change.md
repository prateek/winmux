# Monitor identity and display-change handling for Display profiles

Ticket: [05](../issues/05-research-monitor-identity-and-display-change.md). Researched 2026-09-28 against WinMux at `470eedbf`. Code paths are relative to the repo's `Sources/`.

## Answer in brief

- WinMux has no stable monitor identity. A monitor is its `NSScreen.screens` index, its `localizedName`, and its frame. Workspace-to-monitor state is keyed by the monitor's **top-left corner**. With one display at a time that corner is always the main-display origin, so WinMux can't tell the laptop from the ultrawide.
- The only display-change signal WinMux listens for is `NSApplication.didChangeScreenParametersNotification`. `MonitorConfigurationObserver` already runs an immediate pass and a debounced "settled" pass 750 ms after the last notification. That settled pass is the natural hook for applying a Display profile.
- Match a Display profile on a small descriptor computed from the CoreGraphics display ID: `isBuiltin`, vendor/model/serial (or the UUID derived from them), plus `localizedName` and pixel size as a fallback. Don't key on index, top-left corner, `CGDirectDisplayID`, or BetterDisplay tagID.
- The BetterDisplay virtual screen has a pinned vendor/model/serial, so its macOS UUID should be stable across recreates. I couldn't observe it live (details below), so treat that as documented rather than verified.

## 1. How WinMux identifies monitors today

| Identity | Source | Stable? |
|---|---|---|
| `monitorAppKitNsScreenScreensId`: 1-based index into `NSScreen.screens` | `AppBundle/model/Monitor.swift:20-21,132-134` | No. Order follows AppKit. |
| `name` = `NSScreen.localizedName` | `AppBundle/model/Monitor.swift:42,70` | Localized, so it's "Built-in Retina Display" here and would differ in another system language. |
| `monitorId_oneBased`: position in `sortedMonitors` (sorted by minX, then minY, then index) | `AppBundle/model/MonitorEx.swift:25-28`, `Monitor.swift:159-172` | No. Positional. |
| `MonitorViewportId` = `rect.topLeftCorner` | `AppBundle/tree/WorkspaceIdentity.swift:61-76` | Geometry only. The main display is always at (0,0). |
| `displayId` (`NSScreenNumber` → `CGDirectDisplayID`) | `AppBundle/model/Monitor.swift:63-65` | Used only to compare against `CGMainDisplayID()` (`Monitor.swift:77-79`). Not stored. |

Config-facing monitor matching is `MonitorDescription` (`Common/model/MonitorDescription.swift:1-38`): a 1-based sequence number, `main`, `secondary`, or a case-insensitive regex. `resolveMonitor` checks the regex against `monitor.name`, i.e. `localizedName` (`AppBundle/model/MonitorDescriptionEx.swift:4-12`). Only gaps (`DynamicConfigValue`/`PerMonitorValue`, `AppBundle/config/DynamicConfigValue.swift:4-33`, used in `AppBundle/config/parseGaps.swift:11-42`) and `workspace-to-monitor-force-assignment` (`AppBundle/config/parseConfig.swift:80`) take per-monitor values. `list-monitors` exposes only `monitor-id`, `monitor-appkit-nsscreen-screens-id`, `monitor-name`, and `monitor-is-main` (`AppBundle/command/format.swift:153-158`). Nothing exposes UUID, vendor/model/serial, or built-in status.

Mislabelled file in the ticket: `WorkspaceAutomaticDisplay.swift` is about automatic workspace *display names* (sidebar numbering, `AppBundle/tree/WorkspaceAutomaticDisplay.swift:1-40`). It has nothing to do with physical displays.

## 2. How WinMux reacts to displays appearing and disappearing

1. **Monitor cache invalidation.** The first main-thread access to `monitors` registers a `didChangeScreenParametersNotification` observer that clears `monitorsCache` and `sortedMonitorsCache` (`AppBundle/model/Monitor.swift:137-157`).
2. **`MonitorConfigurationObserver`.** It starts at app init (`AppBundle/initAppBundle.swift:36,42`) and observes the same notification (`AppBundle/ui/core/MonitorConfigurationObserver.swift:16-27`). On each notification it runs `refreshMonitorPolicy` immediately, then again 750 ms after the *last* notification in a burst, using a generation counter (`:29-50`). Each pass refreshes the sidebar panels and tab strip, then calls `scheduleRefreshSession(.globalObserver(reason))` (`:34-40`).
3. **Refresh session.** `.globalObserver` events other than app activation set `requiresWindowRefreshBarrier` (`Common/util/commonUtil.swift:107-119`). The session then runs `refresh()` followed by `gcMonitors()` (`AppBundle/layout/refresh.swift:141-149`), and then layout-reason normalization and `layoutWorkspaces()` (`:151-165`). Overlapping sessions are coalesced rather than restarted (`refresh.swift:75-84`).
4. **`gcMonitors()` → `rearrangeWorkspacesOnMonitors()`** (`AppBundle/tree/WorkspaceMonitorAssignment.swift:94-97,145-213`). This returns early if the set of viewport IDs (top-left corners) with a valid active workspace equals the current monitor set (`:156-158`). Otherwise it maps each new monitor to an old viewport, first by identical corner and then by nearest corner (`:167-179`), and carries over the active workspace and history.
   - Consequence: swapping laptop-only for ultrawide-only keeps the viewport at (0,0), so step 4 is a no-op. Workspaces stay put and only the frame changes. That's convenient for Display profiles, and it's also why WinMux has no notion of *which* display is attached.
5. **Callbacks.** `on-focused-monitor-changed` and the `focusedMonitorChanged` server event fire only when the focused `monitorId_oneBased` changes (`AppBundle/focus.swift:217-233,241-253`). A one-for-one display swap leaves the ID at 1, so **no user-visible event fires on a laptop↔ultrawide swap**. No `ServerEvent` exists for monitor add or remove (`AppBundle/model/ServerEvent.swift:25-47`).
6. WinMux doesn't use `CGDisplayRegisterReconfigurationCallback`. A repo-wide search for it came back empty. Sleep and wake come in separately through `NSWorkspace.didWakeNotification` and `screensDidWakeNotification` (`AppBundle/GlobalObserver.swift:106-107`).

## 3. What macOS exposes, and what's actually on this machine

Live read-only dump taken via `NSScreen` plus CoreGraphics, with the lid open and the laptop panel alone:

```
idx=1 name=Built-in Retina Display displayID=1 uuid=37D8832A-2D66-02CA-B9F7-8F30A301B230
vendor=1552 model=41055 serial=<redacted> builtin=1 main=1 frame=(0,0,1728,1117) backing=2.0
```

`system_profiler SPDisplaysDataType` shows the same panel as "Color LCD", a Built-in Liquid Retina XDR Display at 3456x2234. BetterDisplay's prefs store the same `systemUUID` 37D8832A-… for that panel (`defaults read pro.betterdisplay.BetterDisplay`, key `storedIdentifiers@Display:36`). That confirms BetterDisplay's "UUID" is the macOS `CGDisplayCreateUUIDFromDisplayID` value.

BetterDisplay's stored record for the physical ultrawide (`storedIdentifiers@Display:17`): `edidProductName` "Odyssey G95NC", vendorNumber 19501, modelNumber 29813, serial <redacted>, alphanumericSerial <redacted>, systemUUID `<redacted>`.

Apple APIs (cited from Apple's documentation; the web fetch tool was unavailable this session, so I checked the behavior in the dump above rather than re-reading the pages):
- `CGDisplayCreateUUIDFromDisplayID` (https://developer.apple.com/documentation/colorsync/1417111-cgdisplaycreateuuidfromdisplayid), plus `CGDisplayVendorNumber`, `CGDisplayModelNumber`, `CGDisplaySerialNumber`, and `CGDisplayIsBuiltin` (https://developer.apple.com/documentation/coregraphics/quartz_display_services). The UUID is derived from the EDID identity.
- `CGDirectDisplayID` is a session-scoped ID that can change across reconnects and reboots. BetterDisplay's CLI docs make the same point (next section).
- `NSScreen.localizedName` (https://developer.apple.com/documentation/appkit/nsscreen/localizedname) is localized, which rules it out as the primary key for the built-in panel.
- `NSApplication.didChangeScreenParametersNotification` (https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification) posts on any configuration change: add, remove, mode, arrangement, or main-display change. It carries no payload saying what changed.
- Mirroring: `NSScreen.screens` lists one screen per hardware mirror set, while `CGGetOnlineDisplayList` also includes mirrored members (https://developer.apple.com/documentation/coregraphics/1454964-cggetonlinedisplaylist). **Uncertain:** which member AppKit picks as the mirror set's `NSScreen` when a BetterDisplay virtual screen mirrors onto a physical panel. The script makes the virtual screen main (`executable_g95nc.sh:164-167`), so I expect the virtual screen to be the one listed. Unverified.

## 4. The `G95-HiDPI` virtual screen versus the physical panel and the built-in

What `g95nc set` does (`~/dotfiles/home/dot_config/raycast/scripts/executable_g95nc.sh`):
- Tears down all overlays and discards every virtual screen (`:59-66`, called at `:149`).
- Creates `G95-HiDPI` with a pinned serial of 90570057 and model 9057 (`:43,50-51,152-153`). The script comment says the vendor is BetterDisplay's fixed 2198 (`:44`). I haven't verified 2198 independently.
- Connects it (`:155`), sets the physical panel to 5120x1440 with HiDPI off (`:159`), sets the virtual screen resolution (`:160`), mirrors the virtual screen onto the panel (`:161`), and makes it main with one retry (`:165-167`).
- `reset` repeats the teardown, then sets the physical panel to main, reinitializes it, and restores 3840x1080 HiDPI, with one retry (`:182-210`).

Identity stability:
- BetterDisplay's developer describes the UUID as "permanent for the app created virtual screens unless you change the natural identifiers" (serial, model, vendor), and says `CGDirectDisplayID` is transient. Sources: [Discussion #3628](https://github.com/waydabber/BetterDisplay/discussions/3628) and [Issue #3786](https://github.com/waydabber/BetterDisplay/issues/3786), which calls them "UUID-producing identifiers". I read these as search-result excerpts, not full pages.
- The CLI can select a display by `tagID` ("unique … specific to this app installation"), `UUID` ("assigned by this macOS installation"), or `displayID` ("might change from time-to-time"). `get -identifiers` lists them all. Source: [Integration features, CLI wiki](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI), older revision seen through search. The installed binary contains `virtualScreenSerial`, `virtualScreenModelNumber`, `virtualScreenVendorNumber`, `identifiers`, `originalName`, and `nameLike` (`strings /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay`, app version 5.0.6).
- So the pinned serial and model should give the same macOS UUID on every `set`. The tagID and `CGDirectDisplayID` can still differ each time.
- **Couldn't verify live.** BetterDisplay wasn't running, the ultrawide wasn't attached, and creating a virtual screen would change display state, which this ticket forbids. `betterdisplaycli` printed nothing with the app down (`:70-72` notes the same failure mode). The prefs currently hold **no** VirtualScreen records at all, and `virtualScreenLinked` is 0 on both physical records. That fits `discard` deleting the virtual screen's config along with any association keyed to it. It contradicts the script comment's claim that association "persists" across teardown (`:44-49`). Worth confirming.
- **Also uncertain:** what `localizedName` the virtual screen reports. It probably comes from the virtual EDID's product name, which BetterDisplay likely sets to `G95-HiDPI`, but I haven't verified that.

How each state should look to WinMux (inferred from the code above plus the script; not observed):

| State | `NSScreen.screens` (expected) | Built-in? | WinMux `name` |
|---|---|---|---|
| Laptop only | Built-in panel | yes | "Built-in Retina Display" (observed) |
| Clamshell, after `reset` / native | Physical G95NC, 3840x1080 HiDPI | no | "Odyssey G95NC" (EDID name; expected) |
| Clamshell, after `set` | Virtual screen as mirror-set master, `land` resolution HiDPI (default 4864x1368) | no | probably "G95-HiDPI" |
| Mid-`set` transient | Physical panel plus virtual screen *extended* (between `:155` and `:161`), with the physical panel at 5120x1440 LoDPI | no | two monitors |

## 5. Event sequence WinMux sees

WinMux sees only bursts of `didChangeScreenParametersNotification`. For each burst it runs an immediate `refreshMonitorPolicy` and, 750 ms after the last notification, a settled pass. Each pass schedules a refresh session that ends in `gcMonitors()` and a relayout (§2).

- **`g95nc set`** involves at least six display-state steps separated by `sleep 1`/`sleep 2` (`:65,155-167`): discard, connect the virtual screen, change the panel mode, change the virtual screen mode, mirror on, make it main, and maybe a retry. The gaps are longer than 750 ms, so the **settled pass fires several times on intermediate states**. Those include the two-monitor extended state and the panel at 5120x1440 LoDPI. Profile resolution has to be idempotent and tolerate transient states.
- **`g95nc reset`**: discard (the mirror master disappears and the physical panel comes back as its own screen), main on, reinitialize (probably a disconnect/reconnect blip), mode change, HiDPI change, and possibly a second round (`:185-205`). Again several settled passes.
- **Clamshell close with the ultrawide attached**: the built-in drops out, leaving a single external display. If a BetterDisplay association is configured, the virtual screen may auto-connect afterwards and trigger another burst (strings in the BetterDisplay binary: "A virtual screen which is associated with a display will automatically connect or disconnect when the associated display is connected or disconnected").
- **Callbacks never fire for these swaps**: the focused `monitorId_oneBased` stays 1 (§2 step 5).

I haven't captured an actual event trace. The next implementation step should log `(timestamp, [displayID, UUID, name, frame, isBuiltin, isMain])` from `refreshMonitorPolicy` while running `g95nc set`/`reset` and closing the lid.

## 6. Recommendation: matching and the hook

**Matching.** Add a monitor descriptor built from `NSScreen.displayId` (`Monitor.swift:63-65`) with these fields: `uuid` (`CGDisplayCreateUUIDFromDisplayID`), `vendor`/`model`/`serial`, `isBuiltin` (`CGDisplayIsBuiltin`), `name` (`localizedName`), pixel size, and backing scale. A Display profile matches with any of:
- `builtin = true` for the laptop profile. This avoids the localized name.
- A list of UUIDs or vendor/model(/serial) tuples for the ultrawide profile, covering **both** the physical Odyssey (19501/29813) and the pinned virtual screen (2198?/9057/90570057). Native and `set` modes are different displays to macOS.
- A `name` regex fallback, reusing `MonitorDescription.pattern` semantics (`MonitorDescription.swift:35-37`), e.g. `Odyssey|G95`. Low effort, but it breaks if the names change.

With one display at a time, the active profile is the one matching the sole monitor. When more than one monitor is attached (mid-`set` transients, or lid open with the ultrawide), resolve by explicit profile priority, or keep the current profile until the state settles. The grilling ticket should decide which. The descriptor also belongs in the Filter context (monitor, Display profile) and in `list-monitors` format vars (`format.swift:153-158`), so users can discover their UUIDs.

**Hook.** Use `MonitorConfigurationObserver.refreshMonitorPolicy` (`AppBundle/ui/core/MonitorConfigurationObserver.swift:34-40`), acting on the `.settled` pass and at `prepareForStartup` (`:12-14`), and re-resolve after config reload. Steps:
1. Resolve the active profile.
2. If it changed, swap the effective layout settings (Column count, Overflow policy, sidebar mode, gaps).
3. Schedule a refresh session so `layoutWorkspaces()` reflows. The existing session does this already (`refresh.swift:141-165`).
4. Broadcast a new `displayProfileChanged` server event and an optional `on-display-profile-changed` callback. `on-focused-monitor-changed` won't fire for these swaps.

Also consider lengthening the settle delay or adding hysteresis, because `g95nc`'s internal sleeps (1-2 s) exceed 750 ms. An optional nudge is to have `g95nc` call `winmux` (e.g. a `reload-display-profile` command) at the end of `set`/`reset`. That turns glue timing into an explicit edge, and it fits the standing decision that `g95nc` stays the driver.

## Open questions

- Does AppKit list the virtual screen or the physical panel as the `NSScreen` for the `set` mirror set, and what is its `localizedName`? Needs a live capture during `g95nc set`.
- Is the virtual screen's vendor really 2198, and is its UUID actually identical across two `set` runs? Check with `betterdisplaycli get -identifiers` after two runs, with Prateek present.
- Does `discard` erase the virtual screen's display association? The prefs suggest yes, which would mean `g95nc`'s "set it once" advice doesn't hold.
- Profile choice when two monitors are attached (lid open plus ultrawide, or mid-transition): priority, hysteresis, or "keep current"?
