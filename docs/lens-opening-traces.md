# Lens opening traces

Hold Cmd and press Tab to open the strip; release Cmd to commit. A strip opened from a CLI without held modifiers commits immediately and has no presented frame. Open the list with `winmux lens recent --presentation list`, or miniatures with `winmux lens overview`.

Read the last five openings:

```sh
winmux debug-lens-trace
winmux debug-lens-trace --last 5
winmux debug-lens-trace --json --last 5
winmux debug-lens-trace --help
```

The command ships in release builds. Twenty openings are retained in memory; restarting the process clears them. `--last` must be positive. Each table names the Presentation, input source, total milliseconds and presentation signal. JSON also records the Mach-clock start and whether signpost recording was enabled. A dismissed opening ends with `opening cancelled` and `cancelled before first frame`, rather than pretending it presented.

The stages, with start and duration relative to the input, are:

| Stage | What it measures |
|---|---|
| event reaching WinMux | Event timestamp to handler receipt; for a CLI, client send to server receipt |
| binding resolved | Binding dispatch and Lens settings resolution |
| windows collected | Window enumeration and Filter context construction |
| Filter evaluated | The helper's Filter evaluation |
| session ready | Result resolution, sorting and session construction |
| view built | Hosting root assignment and panel sizing |
| first layout | The hosting view's first synchronous layout |
| first-frame thumbnails ready | Cached images or placeholders available for that layout; fresh captures are not required |
| display delay | Strip's remaining wait until its original 100 ms gesture deadline |
| panel ordered front | The AppKit ordering request |
| first frame presented | The calibrated display-link presentation observation after ordering |
| gap | Time between recorded intervals, printed explicitly |

The strip prepares its real view while hidden during the display delay, so view construction and first layout precede the delay row. The list and miniatures omit the delay entirely. Event sources that do not apply are absent. Cold SwiftUI drawing is prepared at startup using existing window snapshots and cached pictures, with neutral picture, placeholder and workspace-badge branches as the empty-desktop fallback. This neither orders a panel nor requests fresh thumbnails. Full bitmap rasterization happens only at startup; ordinary preparations use the hosting view’s display pass. Startup therefore pays work that previously blocked the first gesture: it runs on the main actor after WinMux is ready and any config saved during startup has reloaded, draws each Presentation once at the focused monitor's size with default Lens settings, and writes its duration to the unified log (`/usr/bin/log show --last 5m --predicate 'subsystem == "<app id>" && category == "lens"'`, the line starting `Lens startup preparation took`). A Lens that is open or opening when it would run owns the panel, so that launch skips it and its first opening is cold.

Stage ownership stays with the work: `LensCommand` records binding/collection/Filter work; `LensLifecycle` owns the active trace, delay and cancellation; the panel records AppKit stages on that same trace. `LensTraceStore` bounds history and owns the reader/injectable stamps. Instrumentation does not move business logic between those owners.

All stamps use Mach absolute seconds since boot, excluding sleep. `NSEvent.timestamp` and a Carbon event's time are already on it, so they are used as they are; an event stamped later than its own receipt is treated as received when it was stamped. The CLI sends its stamp in the socket request: client and server share the same machine's kernel clock. Older clients without that stamp fall back to receipt time.

AppKit offers no public first-window-composite acknowledgement. The hosting view's display link observes the initial render tick and two following compositor cycles, so `first frame presented` ends on the third tick after the panel is ordered front. The count was chosen against film of a 60 Hz guest, and the trace's signal line names the refresh interval it ran at (`third display-link tick at 16.7 ms refresh`). The stage is therefore about three refreshes long by construction, longer only when the main thread is busy: at 120 Hz it reads about 25 ms whether or not the frame was on the glass by then. Compare it between machines only at the same refresh rate, and settle a doubt with film. This is a calibrated proxy, not a hardware presentation guarantee. Recheck it against film when the rendering path changes or the compositor is busy. A moving desk can deliver a later frame than this fixed-cycle observation; a successful calibrated take is evidence for that setup, not every load condition. `viewDidDraw` did not fire reliably on repeated layer-backed openings; a one-tick display link fired too early in the guest.

## Instruments

On the machine running the debug build, with Xcode installed:

```sh
script/record-lens-instruments 15 LensOpening.trace
```

Open several Lenses after recording starts, during those fifteen seconds. Verify `signposting: true` in their JSON; a key posted while xctrace is still initializing is not an instrumented opening. The wrapper compiles `script/LensOpening.instrpkg` beside the trace, records Time Profiler plus **Lens Opening**, and restores its temporary log configuration on exit. Keep the `.instrdst` package with the trace; open the package to import the custom instrument into Instruments before opening the trace. It needs sudo for that configuration. Open the result in Instruments; select **Lens Opening**, its **Stages** list and interval lane. Filter by WinMux's subsystem (`com.zimengxiong.winmux.debug` for debug, `com.zimengxiong.winmux` for release) and category `lens-opening`. Interval names are the stage names.

A `DynamicTracing` gate enables intervals only while the custom instrument records. Ordinary logging categories alone stay enabled outside Instruments, so their `isEnabled` value is insufficient. The command's bounded tables remain available without recording.

For a headless export:

```sh
xcrun xctrace export --input LensOpening.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="lens-opening-stages"]' > LensOpening.xml
```

For a release trace, the schema is `lens-opening-release-stages`. Input receipt is known retrospectively when the trace is constructed: its signpost is a zero-length marker, while its duration is in the table. Instantaneous first-frame thumbnail readiness also has a marker. Binding resolution starts before a trace exists: its table includes dispatch time, while its signpost covers only the live remainder. The remaining intervals cover their live stages. Instruments timestamps use its own recording origin; compare durations with the CLI, not absolute start values.

## Check against a guest recording

Use the `vm` skill to sync, build and stage the standing desk at 1280 × 720. Direct-display ScreenCaptureKit recording also needs the system private-picker bypass permission for its driving process; the ordinary Screen Recording preflight alone does not prove that grant. In an acceptance guest, a prompt is an image defect and stops the run. Push this repository's demo directory beside the desk. Park the pointer bottom-right. Start a fresh WinMux process and record five real Cmd-Tab openings; the first must be that process's first Lens:

```sh
~/desk/trace-film strip 14 \
  down:cmd tap:tab wait:1 up:cmd wait:1 \
  down:cmd tap:tab wait:1 up:cmd wait:1 \
  down:cmd tap:tab wait:1 up:cmd wait:1 \
  down:cmd tap:tab wait:1 up:cmd wait:1 \
  down:cmd tap:tab wait:1 up:cmd
winmux debug-lens-trace --json --last 5 > strip.json
```

`trace-film` uses ScreenCaptureKit, copies each complete pixel buffer before the guest can reuse it, stamps that copy on receipt using the keys' Mach clock, and saves the measured first-sample time in `strip.mov.clock.json`. The event log carries each posted CG event's boot seconds. This establishes frame zero; the ordinary demo `film` helper's wall-clock origin alone does not. Source display times and receipt times are retained for audit. Receipt stamping includes capture delivery latency; it must not be called a hardware scanout measurement.

The output repeats idle samples on a constant 60 fps timeline. Pull the movie, its `.raw.mov`, both `.clock.json` files, the event log and trace JSON, then run on a machine with ffmpeg, ffprobe and Pillow:

```sh
python3 .claude/skills/demo/check-lens-film.py strip.mov strip.json --probe 500,280,250,180 --strip-edge 350,267,580
```

At this desk size, the additional straight top-border probe rejects workspace motion that can fool centre pixels. It requires the bright strip edge to span most of its width, with darker pixels outside and inside; adjust the geometry for another Presentation size. Inspect the extracted PNGs before accepting the probes: it must detect the strip surface, including placeholders, rather than wait for fresh thumbnails. The helper first checks every encoded raw-frame timestamp against the measured receipt metadata, rejecting encoder reordering or an incorrect movie origin. The checker reads the movie's actual frame timestamps and rates, verifies 60 fps spacing, and prints each key time, first visible frame, trace total, difference in milliseconds and difference in frames. It also prints the posted-key to trace-origin shift and the actual endpoint difference on the shared clock; frame indices use the recorded trace origin, not an assumption that both starts coincide. It rejects missing openings, pending traces and disagreement over two frames. One frame is 16.667 ms in this file. Keep frames at the key press, the trace's first-frame estimate and the first frame a viewer calls present. Read back focused workspace and windows after the take.

## Session keys

`debug-lens-trace` also reads a separate **Keys** table, retained after the first
frame until dismissal. JSON's `keys` contains the last 256 rows per opening.
The opening stages and total do not include these rows. Each row carries the
physical key code, characters, modifier flags, event and receipt boot seconds on
`LensTimebase`, Presentation, Hold, entry path, destination, Search and selected
window id. `fieldEditor` tells whether Search had its AppKit editor at receipt;
`focus` rows mark when that editor became first responder. Read the table from
the same guest's debug CLI; no debugger or environment flag is needed.
