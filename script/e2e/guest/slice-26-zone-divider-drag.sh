#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE26_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-26-zone-divider-drag"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice26-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice26-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice26"
LAUNCH_PLIST="/tmp/winmux-e2e-slice26.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice26.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-26-zone-divider-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/slice-26-zone-divider-action.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-26-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-26-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-26-windows-after.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-26-zones-before.log"
ZONES_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-26-zones-after.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-26-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-26-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-26-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-26-window-ids.env"
ACTION_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
MOUSE_EVENTS_LOG="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.mouse-events.tsv"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-26-zone-divider-drag-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

HOVER_NAME="02-divider-hover-slice-26.png"
PICKUP_NAME="03-divider-pickup-slice-26.png"
PATH_NAME="04-divider-drag-path-slice-26.png"
PREVIEW_NAME="05-divider-preview-slice-26.png"
RELEASE_NAME="06-divider-release-slice-26.png"
AFTER_NAME="07-after-divider-resize-slice-26.png"
HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/${HOVER_NAME}"
PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/${PICKUP_NAME}"
PATH_SCREENSHOT="${SCREENSHOTS_DIR}/${PATH_NAME}"
PREVIEW_SCREENSHOT="${SCREENSHOTS_DIR}/${PREVIEW_NAME}"
RELEASE_SCREENSHOT="${SCREENSHOTS_DIR}/${RELEASE_NAME}"
AFTER_SCREENSHOT="${SCREENSHOTS_DIR}/${AFTER_NAME}"

DOC_DIR="${HOME}/winmux-e2e/zone-divider-docs"
REFERENCE_DOC="${DOC_DIR}/reference-divider.rtf"
WORK_DOC="${DOC_DIR}/work-divider.rtf"
COMMS_DOC="${DOC_DIR}/comms-divider.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit 86
}

artifact_relative_path() {
    local path="$1"
    case "$path" in
        "${ARTIFACTS_DIR}/"*) printf '%s\n' "${path#"${ARTIFACTS_DIR}/"}" ;;
        *) printf '%s\n' "$path" ;;
    esac
}

config_sha256() {
    /usr/bin/shasum -a 256 "$CONFIG" | /usr/bin/awk '{ print $1 }'
}

write_zone_doc() {
    local path="$1"
    local title="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs82\b ${title}\b0\par\f1\fs34 zone: ${zone_name}\par ${detail}\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|top=%{monitor-top}|width=%{monitor-width}|height=%{monitor-height}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local key="$3"
    /usr/bin/awk -F'|' -v title="${title}" -v key="${key}" '$2 == title {
        if (key == "id") { print $1; exit }
        for (i = 3; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "${path}"
}

zone_field() {
    local path="$1"
    local zone_id="$2"
    local key="$3"
    /usr/bin/awk -F'|' -v zone="zone=${zone_id}" -v key="${key}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "${path}"
}

zone_for_title() {
    field_for_title "$1" "$2" zone
}

workspace_for_title() {
    field_for_title "$1" "$2" workspace
}

window_id_for_title() {
    field_for_title "$1" "$2" id
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(zone_for_title "${path}" "${title}")"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}"
    fi
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} > ${right}"
}

assert_float_lt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left < right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} < ${right}"
}

assert_float_approximately_equal() {
    local left="$1"
    local right="$2"
    local tolerance="$3"
    local message="$4"
    /usr/bin/awk -v left="${left}" -v right="${right}" -v tolerance="${tolerance}" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - right) <= tolerance ? 0 : 1) }
    ' || semantic_fail "${message}: expected ${left} ~= ${right} within ${tolerance}"
}

wait_for_textedit_windows() {
    local expected="$1"
    for _ in $(seq 1 60); do
        if refresh_window_log "${WINDOW_SETUP_LOG}"; then
            local count
            count="$(/usr/bin/grep -c '^' "${WINDOW_SETUP_LOG}" || true)"
            if [ "${count}" -ge "${expected}" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

move_window_to_zone() {
    local id="$1"
    local title="$2"
    local zone_name="$3"
    local expected_zone="$4"
    {
        echo "setup: ${title} -> ${zone_name}"
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone_name}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone_name}"
    } | tee -a "${CLI_LOG}"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_zone}"
}

launch_winmux() {
    cat >"${LAUNCH_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_LABEL}</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP}</string>
        <string>--config-path</string>
        <string>${CONFIG}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>WINMUX_DEFAULT_CONFIG_PATH</key>
        <string>${CONFIG}</string>
        <key>WINMUX_E2E_SKIP_PERMISSION_PROMPTS</key>
        <string>1</string>
        <key>WINMUX_E2E_STARTUP_TRACE</key>
        <string>${STARTUP_TRACE_LOCAL}</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>${BIN_DIR}</string>
    <key>StandardOutPath</key>
    <string>${APP_LOG_LOCAL}</string>
    <key>StandardErrorPath</key>
    <string>${APP_LOG_LOCAL}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        /usr/bin/awk '/pid =/ { print $3; exit }' "${LAUNCH_STATUS}" >"${ARTIFACTS_DIR}/logs/winmux-app.pid" || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-26-zone-count.txt" 2>"${WAIT_ERR}"; then
            return
        fi
        sleep 1
    done

    echo 'WinMux CLI did not become ready' >&2
    cat "${LAUNCH_STATUS}" >&2 || true
    copy_runtime_logs
    cat "${APP_LOG}" >&2 || true
    cat "${STARTUP_TRACE}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    exit 1
}

setup_slice() {
    rm -f \
        "${DONE}" "${SETUP_LOG}" "${ACTION_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${WINDOW_AFTER_LOG}" "${ZONES_BEFORE_LOG}" "${ZONES_AFTER_LOG}" "${TIMING_LOG}" \
        "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${ACTION_MANIFEST}" "${MOUSE_EVENTS_LOG}" \
        "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" \
        "${HOVER_SCREENSHOT}" "${PICKUP_SCREENSHOT}" "${PATH_SCREENSHOT}" \
        "${PREVIEW_SCREENSHOT}" "${RELEASE_SCREENSHOT}" "${AFTER_SCREENSHOT}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 26: draggable zone dividers'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo "Config: [[zone-layouts]] Reference/Work/Comms columns"
        echo "Action: drag the Work|Comms divider to resize adjacent zones"
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${REFERENCE_DOC}" 'REFERENCE' 'Reference' 'Unaffected control zone. It must keep its width while the Work|Comms divider moves.'
    write_zone_doc "${WORK_DOC}" 'WORK' 'Work' 'Drag the right divider handle. Work should grow and keep its workspace.'
    write_zone_doc "${COMMS_DOC}" 'COMMS' 'Comms' 'Adjacent zone. It should shrink when the divider moves right.'

    launch_winmux
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${WORK_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${COMMS_DOC}"

    if ! wait_for_textedit_windows 3; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        semantic_fail 'TextEdit windows did not become visible to WinMux'
    fi

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-divider.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-divider.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-divider.rtf')"
    test -n "${reference_id}"
    test -n "${work_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'reference-divider.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-divider.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-divider.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-divider.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-divider.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-divider.rtf' right

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=reference-work-comms-visible'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

awk_int() {
    awk "BEGIN { printf \"%d\", $* }"
}

init_mouse_events_log() {
    : >"${MOUSE_EVENTS_LOG}"
    printf '# event-id\tkind\toffset-seconds\tnote\n' >>"${MOUSE_EVENTS_LOG}"
}

append_mouse_event() {
    local event_id="$1"
    local kind="$2"
    local scenario_start_ms="$3"
    local note="$4"
    local now_ms
    now_ms="$(/bin/date +%s)000"
    awk -v event_id="$event_id" -v kind="$kind" -v start="$scenario_start_ms" -v now="$now_ms" -v note="$note" 'BEGIN {
        printf "%s\t%s\t%.3f\t%s\n", event_id, kind, (now - start) / 1000, note
    }' >>"${MOUSE_EVENTS_LOG}"
}

append_action_log_value() {
    local key="$1"
    local value="$2"
    printf '%s=%s\n' "$key" "$value" >>"${ACTION_LOG}"
}

append_action_manifest_value() {
    local kind="$1"
    local key="$2"
    local value="$3"
    local log_key="${4:-}"
    printf '%s\t%s\t%s\n' "$kind" "$key" "$value" >>"${ACTION_MANIFEST}"
    if [ -n "$log_key" ]; then
        append_action_log_value "$log_key" "$value"
    fi
}

drag_divider_jxa() {
    local start_x="$1"
    local start_y="$2"
    local target_x="$3"
    local target_y="$4"
    local scenario_start_ms="$5"
    /usr/bin/osascript -l JavaScript <<JXA
ObjC.import('ApplicationServices')

const app = Application.currentApplication()
app.includeStandardAdditions = true
const mouseEventsLog = '${MOUSE_EVENTS_LOG}'
const scenarioStartMs = Number('${scenario_start_ms}')

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function postLeftMouse(type, x, y) {
  const event = $.CGEventCreateMouseEvent(null, type, $.CGPointMake(Number(x), Number(y)), $.kCGMouseButtonLeft)
  $.CGEventPost($.kCGHIDEventTap, event)
}

function dragTo(x1, y1, x2, y2, steps, stepDelay) {
  for (let i = 1; i <= steps; i++) {
    const t = i / Number(steps)
    const x = Number(x1) + ((Number(x2) - Number(x1)) * t)
    const y = Number(y1) + ((Number(y2) - Number(y1)) * t)
    postLeftMouse($.kCGEventLeftMouseDragged, x, y)
    delay(stepDelay)
  }
}

function capture(path) {
  delay(0.35)
  app.doShellScript('/usr/sbin/screencapture -x -D ${GUEST_DISPLAY_ID} ' + shellQuote(path))
}

function offsetSeconds() {
  return ((Date.now() - scenarioStartMs) / 1000).toFixed(3)
}

function emit(eventId, kind, note) {
  const line = [eventId, kind, offsetSeconds(), note].join('\t')
  app.doShellScript("/usr/bin/printf '%s\\n' " + shellQuote(line) + " >> " + shellQuote(mouseEventsLog))
}

const sx = Number('${start_x}')
const sy = Number('${start_y}')
const tx = Number('${target_x}')
const ty = Number('${target_y}')
const pathX = sx + ((tx - sx) * 0.45)
const pathY = sy
const previewX = sx + ((tx - sx) * 0.86)
const previewY = ty

postLeftMouse($.kCGEventMouseMoved, sx, sy)
delay(0.9)
capture('${HOVER_SCREENSHOT}')
emit('divider-hover', 'overlay', 'hover affordance screenshot captured before mouse down')

postLeftMouse($.kCGEventLeftMouseDown, sx, sy)
delay(0.45)
capture('${PICKUP_SCREENSHOT}')
emit('divider-pickup', 'drag', 'divider picked up at Work|Comms boundary')

dragTo(sx, sy, pathX, pathY, 22, 0.055)
capture('${PATH_SCREENSHOT}')
emit('divider-drag-path', 'drag', 'divider drag path screenshot captured')

dragTo(pathX, pathY, previewX, previewY, 22, 0.065)
capture('${PREVIEW_SCREENSHOT}')
emit('divider-live-preview', 'overlay', 'live width preview screenshot captured before release')
delay(2.2)

dragTo(previewX, previewY, tx, ty, 10, 0.06)
delay(0.8)
postLeftMouse($.kCGEventLeftMouseUp, tx, ty)
delay(0.8)
capture('${RELEASE_SCREENSHOT}')
emit('divider-release', 'drag', 'mouse released after divider resize')
JXA
}

write_timing_log_from_mouse_events() {
    /usr/bin/awk -F'\t' '
        $0 == "" || $1 ~ /^#/ { next }
        $1 == "divider-pickup" { printf "divider-pickup-offset-seconds=%s\n", $3 }
        $1 == "divider-drag-path" { printf "divider-drag-path-offset-seconds=%s\n", $3 }
        $1 == "divider-live-preview" { printf "divider-live-preview-offset-seconds=%s\n", $3 }
        $1 == "divider-release" { printf "divider-release-offset-seconds=%s\n", $3 }
        $1 == "after-divider-resize" { printf "after-divider-resize-offset-seconds=%s\n", $3 }
    ' "${MOUSE_EVENTS_LOG}" >"${TIMING_LOG}"
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    REFERENCE_ID="${REFERENCE_ID:-}"
    WORK_ID="${WORK_ID:-}"
    COMMS_ID="${COMMS_ID:-}"
    test -n "${REFERENCE_ID}"
    test -n "${WORK_ID:-}"
    test -n "${COMMS_ID}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-divider.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-divider.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-divider.rtf' right

    local before_sha before_left_width before_main_width before_right_width
    local before_reference_workspace before_work_workspace before_comms_workspace
    before_sha="$(config_sha256)"
    before_left_width="$(zone_field "${ZONES_BEFORE_LOG}" left width)"
    before_main_width="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    before_right_width="$(zone_field "${ZONES_BEFORE_LOG}" right width)"
    before_reference_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'reference-divider.rtf')"
    before_work_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'work-divider.rtf')"
    before_comms_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'comms-divider.rtf')"

    local main_left main_top main_width main_height right_width boundary_x start_x start_y drag_delta target_x target_y hit_band_offset
    main_left="$(zone_field "${ZONES_BEFORE_LOG}" main left)"
    main_top="$(zone_field "${ZONES_BEFORE_LOG}" main top)"
    main_width="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    main_height="$(zone_field "${ZONES_BEFORE_LOG}" main height)"
    right_width="$(zone_field "${ZONES_BEFORE_LOG}" right width)"
    boundary_x="$(awk_int "${main_left} + ${main_width}")"
    hit_band_offset=8
    start_x="$(awk_int "${boundary_x} + ${hit_band_offset}")"
    start_y="$(awk_int "${main_top} + (${main_height} * 0.42)")"
    drag_delta="$(awk_int "${right_width} * 0.30")"
    if /usr/bin/awk -v value="${drag_delta}" 'BEGIN { exit(value < 180 ? 0 : 1) }'; then
        drag_delta=180
    fi
    if /usr/bin/awk -v value="${drag_delta}" -v width="${right_width}" 'BEGIN { exit(value > width - 120 ? 0 : 1) }'; then
        drag_delta="$(awk_int "${right_width} - 120")"
    fi
    target_x="$(awk_int "${start_x} + ${drag_delta}")"
    target_y="${start_y}"

    : >"${ACTION_LOG}"
    : >"${ACTION_MANIFEST}"
    printf '# kind\tkey\tvalue\n' >>"${ACTION_MANIFEST}"
    append_action_log_value action draggable-zone-divider
    append_action_log_value interaction-model zone-divider-drag
    append_action_manifest_value divider-policy target adjacent-zone-boundary target
    append_action_manifest_value divider-policy not-target window-within-zone not-target
    append_action_manifest_value divider-policy runtime-state zone-width-overrides runtime-state
    append_action_manifest_value divider-policy config-persistence no-config-rewrite config-persistence
    append_action_manifest_value divider-source left-zone-id main left-zone-id
    append_action_manifest_value divider-source left-zone-name Work left-zone-name
    append_action_manifest_value divider-target right-zone-id right right-zone-id
    append_action_manifest_value divider-target right-zone-name Comms right-zone-name
    append_action_manifest_value drag-source title 'Work|Comms divider'
    append_action_manifest_value drag-target zone-id right
    append_action_manifest_value drag-target zone-name Comms
    append_action_manifest_value drag-target snap-target zone-divider
    append_action_manifest_value drag-target not-snap-target window-within-zone
    append_action_manifest_value drag-points source "${start_x},${start_y}"
    append_action_manifest_value drag-points target "${target_x},${target_y}"
    append_action_manifest_value drag-points target-hover-hold-seconds '3.2'
    append_action_manifest_value drag-points coordinate-policy 'derived-from-list-zones: boundary is the Work/main right edge; source clicks eight pixels inside the divider hit band so the gesture targets WinMux instead of TextEdit window resize'
    append_action_manifest_value visual-floor required-frames 'source divider, proxy preview, highlighted boundary, path frames, release, and final adjacent-zone widths'
    append_action_manifest_value caption chip 'Action: drag divider right'
    append_action_manifest_value divider-points boundary "${boundary_x},${start_y}" boundary-point
    append_action_manifest_value divider-points hit-band-offset-pixels "${hit_band_offset}" hit-band-offset-pixels
    append_action_manifest_value divider-points start "${start_x},${start_y}" source-point
    append_action_manifest_value divider-points target "${target_x},${target_y}" target-point
    append_action_manifest_value divider-points requested-delta-pixels "${drag_delta}" requested-delta-pixels
    append_action_manifest_value drag-screenshots hover "${HOVER_NAME}" divider-hover-screenshot
    append_action_manifest_value drag-screenshots pickup "${PICKUP_NAME}" divider-pickup-screenshot
    append_action_manifest_value drag-screenshots path "${PATH_NAME}" divider-path-screenshot
    append_action_manifest_value drag-screenshots preview "${PREVIEW_NAME}" divider-preview-screenshot
    append_action_manifest_value drag-screenshots release "${RELEASE_NAME}" divider-release-screenshot
    append_action_manifest_value drag-screenshots after "${AFTER_NAME}" after-divider-screenshot
    append_action_manifest_value caption config "Config: [[zone-layouts]] columns left/main/right"
    append_action_manifest_value caption hover "Action: hover Work|Comms divider"
    append_action_manifest_value caption drag "Action: drag divider right"
    append_action_manifest_value caption inspect "Run: winmux list-zones"
    append_action_manifest_value verification before-zone-log "$(artifact_relative_path "${ZONES_BEFORE_LOG}")"
    append_action_manifest_value verification before-window-log "$(artifact_relative_path "${WINDOW_BEFORE_LOG}")"
    append_action_manifest_value verification config-sha-before "${before_sha}" config-sha-before

    init_mouse_events_log
    sleep 7
    local scenario_start_ms
    scenario_start_ms="$(/bin/date +%s)000"
    drag_divider_jxa "${start_x}" "${start_y}" "${target_x}" "${target_y}" "${scenario_start_ms}"
    sleep 2

    local after_left_width after_main_width after_right_width after_sha
    for _ in $(seq 1 30); do
        write_zones_log "${ZONES_AFTER_LOG}" >/dev/null
        after_left_width="$(zone_field "${ZONES_AFTER_LOG}" left width)"
        after_main_width="$(zone_field "${ZONES_AFTER_LOG}" main width)"
        after_right_width="$(zone_field "${ZONES_AFTER_LOG}" right width)"
        if /usr/bin/awk -v before="${before_main_width}" -v after="${after_main_width}" -v before_right="${before_right_width}" -v after_right="${after_right_width}" 'BEGIN {
            exit(after > before + 60 && after_right < before_right - 60 ? 0 : 1)
        }'; then
            break
        fi
        sleep 1
    done
    refresh_window_log "${WINDOW_AFTER_LOG}"
    capture_guest_screenshot "${AFTER_NAME%.png}"
    append_mouse_event after-divider-resize inspection "${scenario_start_ms}" "post-release list-zones and screenshot captured"
    after_sha="$(config_sha256)"

    after_left_width="$(zone_field "${ZONES_AFTER_LOG}" left width)"
    after_main_width="$(zone_field "${ZONES_AFTER_LOG}" main width)"
    after_right_width="$(zone_field "${ZONES_AFTER_LOG}" right width)"
    assert_float_gt "${after_main_width}" "${before_main_width}" 'Work/main width did not grow after divider drag'
    assert_float_lt "${after_right_width}" "${before_right_width}" 'Comms/right width did not shrink after divider drag'
    assert_float_approximately_equal "${after_left_width}" "${before_left_width}" 2 'Reference/left width changed during adjacent divider drag'
    [ "${before_sha}" = "${after_sha}" ] || semantic_fail 'Config file changed during runtime divider drag'

    assert_window_zone "${WINDOW_AFTER_LOG}" 'reference-divider.rtf' left
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-divider.rtf' main
    assert_window_zone "${WINDOW_AFTER_LOG}" 'comms-divider.rtf' right
    [ "$(window_id_for_title "${WINDOW_AFTER_LOG}" 'reference-divider.rtf')" = "${REFERENCE_ID}" ] \
        || semantic_fail 'Reference window id changed'
    [ "$(window_id_for_title "${WINDOW_AFTER_LOG}" 'work-divider.rtf')" = "${WORK_ID}" ] \
        || semantic_fail 'Work window id changed'
    [ "$(window_id_for_title "${WINDOW_AFTER_LOG}" 'comms-divider.rtf')" = "${COMMS_ID}" ] \
        || semantic_fail 'Comms window id changed'
    [ "$(workspace_for_title "${WINDOW_AFTER_LOG}" 'reference-divider.rtf')" = "${before_reference_workspace}" ] \
        || semantic_fail 'Reference workspace changed'
    [ "$(workspace_for_title "${WINDOW_AFTER_LOG}" 'work-divider.rtf')" = "${before_work_workspace}" ] \
        || semantic_fail 'Work workspace changed'
    [ "$(workspace_for_title "${WINDOW_AFTER_LOG}" 'comms-divider.rtf')" = "${before_comms_workspace}" ] \
        || semantic_fail 'Comms workspace changed'

    for screenshot in "${HOVER_SCREENSHOT}" "${PICKUP_SCREENSHOT}" "${PATH_SCREENSHOT}" "${PREVIEW_SCREENSHOT}" "${RELEASE_SCREENSHOT}" "${AFTER_SCREENSHOT}"; do
        test -s "${screenshot}"
    done

    append_action_manifest_value verification after-zone-log "$(artifact_relative_path "${ZONES_AFTER_LOG}")"
    append_action_manifest_value verification after-window-log "$(artifact_relative_path "${WINDOW_AFTER_LOG}")"
    append_action_manifest_value verification config-sha-after "${after_sha}" config-sha-after
    append_action_manifest_value divider-result left-zone-before-width "${before_main_width}" left-zone-before-width
    append_action_manifest_value divider-result left-zone-after-width "${after_main_width}" left-zone-after-width
    append_action_manifest_value divider-result right-zone-before-width "${before_right_width}" right-zone-before-width
    append_action_manifest_value divider-result right-zone-after-width "${after_right_width}" right-zone-after-width
    append_action_manifest_value divider-result unaffected-zone-id left unaffected-zone-id
    append_action_manifest_value divider-result unaffected-before-width "${before_left_width}" unaffected-before-width
    append_action_manifest_value divider-result unaffected-after-width "${after_left_width}" unaffected-after-width
    append_action_manifest_value divider-result result success divider-result

    write_timing_log_from_mouse_events

    cat \
        "${ZONES_BEFORE_LOG}" "${WINDOW_BEFORE_LOG}" "${ACTION_LOG}" \
        "${ZONES_AFTER_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 26: draggable zone dividers'
        echo
        echo 'Config under proof:'
        echo '[[zone-layouts]] balanced columns'
        echo
        echo 'Before zones:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'After zones:'
        cat "${ZONES_AFTER_LOG}"
        echo
        echo 'Before windows:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'After windows:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo 'Action manifest:'
        cat "${ACTION_MANIFEST}"
        echo
        echo "widths-before=left:${before_left_width},main:${before_main_width},right:${before_right_width}"
        echo "widths-after=left:${after_left_width},main:${after_main_width},right:${after_right_width}"
        echo "config-sha-before=${before_sha}"
        echo "config-sha-after=${after_sha}"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: dragging the Work|Comms zone divider changes adjacent runtime widths only; Work grows, Comms shrinks, Reference keeps its width, windows/workspaces stay attached, and config is unchanged.'
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 6
    printf 'result=success\n' >"${DONE}"
    copy_runtime_logs
}

mouse_event_writer_self_test() {
    mkdir -p "${ARTIFACTS_DIR}/logs"
    init_mouse_events_log
    scenario_start_ms="$(/bin/date +%s)000"
    append_mouse_event divider-hover overlay "${scenario_start_ms}" 'hover event'
    append_mouse_event divider-pickup drag "${scenario_start_ms}" 'pickup event'
    append_mouse_event divider-drag-path drag "${scenario_start_ms}" 'path event'
    append_mouse_event divider-live-preview overlay "${scenario_start_ms}" 'preview event'
    append_mouse_event divider-release drag "${scenario_start_ms}" 'release event'
    append_mouse_event after-divider-resize inspection "${scenario_start_ms}" 'inspection event'
    /usr/bin/awk -F'\t' '
        /^#/ { next }
        NF != 4 {
            printf("mouse event self-test row has %d fields: %s\n", NF, $0) > "/dev/stderr"
            exit 1
        }
        $1 in seen {
            printf("mouse event self-test duplicate id: %s\n", $1) > "/dev/stderr"
            exit 1
        }
        { seen[$1] = 1; count += 1 }
        END {
            if (count != 6 || !seen["divider-hover"] || !seen["divider-pickup"] || !seen["divider-drag-path"] || !seen["divider-live-preview"] || !seen["divider-release"] || !seen["after-divider-resize"]) {
                print "mouse event self-test missing required ids" > "/dev/stderr"
                exit 1
            }
        }
    ' "${MOUSE_EVENTS_LOG}"
    printf 'result=success\n'
    cat "${MOUSE_EVENTS_LOG}"
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    self-test)
        mouse_event_writer_self_test
        ;;
    *)
        echo "Unknown Slice 26 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
