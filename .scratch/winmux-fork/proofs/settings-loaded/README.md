# Settings live checks

Run these tools through the VM skill in an assigned 1280 by 720 guest, after syncing, building and staging the standing desk. Every guest command goes through `vm ssh`; use `vm push` for this directory and `vm pull` for captures. Export the driver's `TART_HOME` before every host or guest shell. Keep the assigned guest running, grant no permission and publish no release.

Compile `ui.swift` to `~/demo/settings-ui`. It dumps accessibility state, selects a pane, presses a named button or menu item, changes the search field through AXValue, closes Settings and scrolls the detail. Search typing was also checked with a click and `cliclick t:lens` under the VM skill's wrapped debug bundle, launched directly over SSH. The caret and eight matches were visible; the app menu still named the desk's editor.

`read-only.zsh` expects that build running with the standing desk's config and state directories. It installs `shipped.ncl`, captures each pane and its lower content, drives the four named searches, and compares the file hash, mtime and defaults before and after. Open Config runs last. `audit-ax.py <host-captures>` checks those snapshots and the captured accessibility roles/counts; the search field is the only setting editor.

Build the base tree separately in the guest: initialise its `.git`, build its helper and Swift products, and copy Sparkle.framework beside its executable as the VM skill describes. `unchanged.zsh <tree> <executable> <defaults-domain> <capture-directory>` is run unchanged against both trees: it checks Reload From Disk and Open Config on an existing file, then records Lens and binding output for comparison. `no-file.zsh <tree> <executable> <take-name>` proves startup leaves the file absent and Open Config creates a valid starter. Use a fresh take name because it refuses an existing file. The image used here has no `.ncl` association, so Open Config shows macOS's application chooser on both builds. Save that screen, dismiss Cancel, and leave the association unchanged.

Use the rich desk's config for Columns 2 and 3. `broken.ncl` checks the open-window error banner, recovery and cold fallback; it is intentionally invalid. `hooks-and-triggers.ncl` checks function labels, inherited and overridden hooks, inactive hooks with Columns Off, an untriggered disabled Lens, a missing Lens, a tap and a sequence. Wait a fixed interval after each save or launch before reading the CLI once. Do not poll read-only WinMux commands during refreshes.

`other-workspace.ncl` exercises a workspace named Other workspaces, matching the default row's label. Both its Column policy and its separate Hook rows must remain present.

A restage exposed the VM skill's documented Python Local Network screen. Dismiss it by closing UserNotificationCenter without answering, then run the desk checker again before capturing.

The captures index records each search's count and modes. These are builder checks; the demo pass films the final commit for the pull request. Quit the debug build and desk apps after taking the results out.
