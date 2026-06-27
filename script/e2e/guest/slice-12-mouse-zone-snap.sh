#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_MOUSE_SNAP_PHASE:-${WINMUX_E2E_SLICE12_PHASE:-proof}}"
SLICE_PREFIX="${WINMUX_E2E_MOUSE_SNAP_SLICE_PREFIX:-slice-12}"
SLICE_NUMBER="${SLICE_PREFIX#slice-}"
SLICE_TITLE="${WINMUX_E2E_MOUSE_SNAP_TITLE:-WinMux Slice ${SLICE_NUMBER}: desktop mouse zone snap policy}"
RECORDING_NAME="${WINMUX_E2E_RECORDING_NAME:-${SLICE_PREFIX}-mouse-zone-snap-drag}"
CONFIG_MODIFIER="${WINMUX_E2E_MOUSE_SNAP_CONFIG_MODIFIER:-alt}"
CONFIG_POLICY="${WINMUX_E2E_MOUSE_SNAP_CONFIG_POLICY:-snap-on-modifier}"
PROOF_MODE="${WINMUX_E2E_MOUSE_SNAP_PROOF_MODE:-modifier}"
RUNTIME_SET_POLICY="${WINMUX_E2E_MOUSE_SNAP_RUNTIME_SET_POLICY:-snap-to-zone}"
RUNTIME_CYCLE_POLICIES="${WINMUX_E2E_MOUSE_SNAP_RUNTIME_CYCLE_POLICIES:-freeform snap-to-zone}"
if [ "${SLICE_PREFIX}" = "slice-16" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Option}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold Option while dragging: snap to Comms zone}"
elif [ "${PROOF_MODE}" = "runtime-policy" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Alt}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Run: winmux set-zone-snap-policy snap-to-zone}"
else
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Alt}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold Alt while dragging snap-demo.rtf}"
fi
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.${SLICE_PREFIX}"
LAUNCH_PLIST="/tmp/winmux-e2e-${SLICE_PREFIX}.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-${SLICE_PREFIX}.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap-action.log"
SET_POLICY_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-set-zone-snap-policy.log"
CYCLE_POLICY_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cycle-zone-snap-policy.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-before.log"
WINDOW_FREEFORM_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-freeform.log"
WINDOW_RESET_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-reset.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-snap.log"
ZONES_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zones.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-window-ids.env"
ACTION_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
DONE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap.done"
PROOF="${ARTIFACTS_DIR}/${SLICE_PREFIX}-mouse-zone-snap-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

FREEFORM_PICKUP_NAME="02-freeform-pickup-${SLICE_PREFIX}.png"
FREEFORM_HOVER_NAME="03-freeform-hover-no-overlay-${SLICE_PREFIX}.png"
RESET_NAME="04-reset-before-snap-${SLICE_PREFIX}.png"
SNAP_PICKUP_NAME="05-snap-pickup-${SLICE_PREFIX}.png"
SNAP_PATH_NAME="06-snap-path-${SLICE_PREFIX}.png"
SNAP_HOVER_NAME="07-snap-hover-comms-${SLICE_PREFIX}.png"
FREEFORM_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/${FREEFORM_PICKUP_NAME}"
FREEFORM_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/${FREEFORM_HOVER_NAME}"
RESET_SCREENSHOT="${SCREENSHOTS_DIR}/${RESET_NAME}"
SNAP_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_PICKUP_NAME}"
SNAP_PATH_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_PATH_NAME}"
SNAP_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_HOVER_NAME}"

DOC_DIR="${HOME}/winmux-e2e/${SLICE_PREFIX}-mouse-zone-snap-docs"
REFERENCE_DOC="${DOC_DIR}/reference-mouse-snap.rtf"
SNAP_DOC="${DOC_DIR}/snap-demo.rtf"
COMMS_DOC="${DOC_DIR}/comms-mouse-snap.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

artifact_relative_path() {
    local path="$1"
    case "$path" in
        "${ARTIFACTS_DIR}/"*) printf '%s\n' "${path#"${ARTIFACTS_DIR}/"}" ;;
        *) printf '%s\n' "$path" ;;
    esac
}

write_doc() {
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
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|top=%{monitor-top}|width=%{monitor-width}|height=%{monitor-height}|physical=%{monitor-physical-id}' \
        >"${ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${ZONES_LOG}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|layout=%{window-layout}|monitor=%{monitor-name}' \
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
    local zone_id="$1"
    local key="$2"
    /usr/bin/awk -F'|' -v zone="zone=${zone_id}" -v key="${key}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "${ZONES_LOG}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${SET_POLICY_LOG}" "${CYCLE_POLICY_LOG}" \
        "${WINDOW_FREEFORM_LOG}" "${WINDOW_RESET_LOG}" "${WINDOW_AFTER_LOG}" "${ZONES_LOG}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${ACTION_MANIFEST}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" \
        "${FREEFORM_PICKUP_SCREENSHOT}" "${FREEFORM_HOVER_SCREENSHOT}" "${RESET_SCREENSHOT}" \
        "${SNAP_PICKUP_SCREENSHOT}" "${SNAP_PATH_SCREENSHOT}" "${SNAP_HOVER_SCREENSHOT}"
    rm -rf "${DOC_DIR}"

    {
        echo "${SLICE_TITLE}"
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo "Config: [mouse.zone-snap] policy = '${CONFIG_POLICY}', modifier = '${CONFIG_MODIFIER}', target = 'zone'"
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo "Runtime command: set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            echo "Runtime toggle: cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
        fi
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" 'REFERENCE' 'Reference' 'Desktop drag snap proof baseline'
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag once in freeform, run set-zone-snap-policy, then drag again with no modifier"
    else
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag this window without ${USER_MODIFIER_LABEL}, then with ${USER_MODIFIER_LABEL}"
    fi
    write_doc "${COMMS_DOC}" 'COMMS' 'Comms' 'Whole-zone snap target'

    launch_winmux
    write_zones_log
    grep -F 'zone=left|name=Reference|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=main|name=Work|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=right|name=Comms|' "${ZONES_LOG}" >/dev/null

    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${SNAP_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${COMMS_DOC}"

    if ! wait_for_textedit_windows 3; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        semantic_fail 'TextEdit windows did not become visible to WinMux'
    fi

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-mouse-snap.rtf')"
    SNAP_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'snap-demo.rtf')"
    COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-mouse-snap.rtf')"

    if [ -z "${REFERENCE_ID}" ] || [ -z "${SNAP_ID}" ] || [ -z "${COMMS_ID}" ]; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'Could not resolve all TextEdit window ids'
    fi

    move_window_to_zone "${REFERENCE_ID}" 'reference-mouse-snap.rtf' Reference left
    move_window_to_zone "${SNAP_ID}" 'snap-demo.rtf' Work main
    move_window_to_zone "${COMMS_ID}" 'comms-mouse-snap.rtf' Comms right
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-mouse-snap.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-mouse-snap.rtf' right

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${REFERENCE_ID}
SNAP_ID=${SNAP_ID}
COMMS_ID=${COMMS_ID}
STATE

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${SNAP_ID}"
    sleep 1
    {
        echo 'setup=result=success'
        echo "snap-window-id=${SNAP_ID}"
        echo 'ready-state=desktop-window-focused'
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

awk_int() {
    awk "BEGIN { printf \"%d\", $* }"
}

drag_window_jxa() {
    local source_x="$1"
    local source_y="$2"
    local target_x="$3"
    local target_y="$4"
    local with_alt="$5"
    local pickup_path="$6"
    local path_path="$7"
    local hover_path="$8"
    /usr/bin/osascript -l JavaScript <<JXA
ObjC.import('ApplicationServices')

const app = Application.currentApplication()
app.includeStandardAdditions = true

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

function postMouse(type, x, y, withAlt) {
  const event = $.CGEventCreateMouseEvent(null, type, $.CGPointMake(Number(x), Number(y)), $.kCGMouseButtonLeft)
  if (withAlt) {
    $.CGEventSetFlags(event, $.kCGEventFlagMaskAlternate)
  }
  $.CGEventPost($.kCGHIDEventTap, event)
}

function postOption(down) {
  const event = $.CGEventCreateKeyboardEvent(null, 58, down)
  if (down) {
    $.CGEventSetFlags(event, $.kCGEventFlagMaskAlternate)
  }
  $.CGEventPost($.kCGHIDEventTap, event)
}

function dragTo(x1, y1, x2, y2, steps, stepDelay, withAlt) {
  for (let i = 1; i <= steps; i++) {
    const t = i / Number(steps)
    const x = Number(x1) + ((Number(x2) - Number(x1)) * t)
    const y = Number(y1) + ((Number(y2) - Number(y1)) * t)
    postMouse($.kCGEventLeftMouseDragged, x, y, withAlt)
    delay(stepDelay)
  }
}

function capture(path) {
  delay(0.35)
  app.doShellScript('/usr/sbin/screencapture -x -D ${GUEST_DISPLAY_ID} ' + shellQuote(path))
}

const sx = Number('${source_x}')
const sy = Number('${source_y}')
const tx = Number('${target_x}')
const ty = Number('${target_y}')
const useAlt = '${with_alt}' === '1'
const pickupX = sx + ((tx - sx) * 0.10)
const pickupY = sy + 12
const pathX = sx + ((tx - sx) * 0.58)
const pathY = sy + ((ty - sy) * 0.58)

postMouse($.kCGEventMouseMoved, sx, sy, useAlt)
delay(0.8)
if (useAlt) {
  postOption(true)
  delay(0.35)
}
postMouse($.kCGEventLeftMouseDown, sx, sy, useAlt)
delay(0.25)
dragTo(sx, sy, pickupX, pickupY, 10, 0.06, useAlt)
capture('${pickup_path}')
dragTo(pickupX, pickupY, pathX, pathY, 34, 0.07, useAlt)
if ('${path_path}' !== '') {
  capture('${path_path}')
}
dragTo(pathX, pathY, tx, ty, 28, 0.08, useAlt)
delay(1.5)
capture('${hover_path}')
delay(1.8)
postMouse($.kCGEventLeftMouseUp, tx, ty, useAlt)
if (useAlt) {
  delay(0.3)
  postOption(false)
}
JXA
}

reset_snap_window_to_work() {
    {
        echo "$ winmux layout --window-id ${SNAP_ID} tiling || true"
        "${CLI}" layout --window-id "${SNAP_ID}" tiling || true
        echo "$ winmux move-node-to-zone --window-id ${SNAP_ID} Work"
        "${CLI}" move-node-to-zone --window-id "${SNAP_ID}" Work || true
        echo "$ winmux focus-zone Work"
        "${CLI}" focus-zone Work
        echo "$ winmux focus --window-id ${SNAP_ID}"
        "${CLI}" focus --window-id "${SNAP_ID}"
    } | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null

    for _ in $(seq 1 20); do
        refresh_window_log "${WINDOW_RESET_LOG}"
        if [ "$(zone_for_title "${WINDOW_RESET_LOG}" 'snap-demo.rtf')" = main ]; then
            return
        fi
        sleep 1
    done
    cat "${WINDOW_RESET_LOG}" >&2 || true
    semantic_fail 'Could not reset snap-demo.rtf to Work/main before modifier drag'
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${SNAP_ID:-}"

    write_zones_log
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf' main
    before_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf')"
    before_id="$(window_id_for_title "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf')"

    main_left="$(zone_field main left)"
    main_top="$(zone_field main top)"
    main_width="$(zone_field main width)"
    right_left="$(zone_field right left)"
    right_top="$(zone_field right top)"
    right_width="$(zone_field right width)"
    right_height="$(zone_field right height)"
    source_x="$(awk_int "${main_left} + (${main_width} * 0.50)")"
    source_y="$(awk_int "${main_top} + 32")"
    target_x="$(awk_int "${right_left} + (${right_width} * 0.50)")"
    target_y="$(awk_int "${right_top} + (${right_height} * 0.38)")"

    positive_drag_with_alt=1
    positive_proof_key='alt-held-whole-zone-snap'
    positive_action_text="positive-proof=hold ${USER_MODIFIER_LABEL} while dragging previews the whole Comms zone and snaps on release"
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        positive_drag_with_alt=0
        positive_proof_key='runtime-set-snap-to-zone'
        positive_action_text='positive-proof=runtime set-zone-snap-policy enables whole-zone snap without a held modifier'
    fi

    {
        echo 'action=desktop-mouse-zone-snap'
        echo 'interaction-model=desktop-window-drag'
        echo 'config=[mouse.zone-snap]'
        echo "policy=${CONFIG_POLICY}"
        echo "modifier=${CONFIG_MODIFIER}"
        echo "gesture=drag"
        echo "target=zone"
        echo "proof-mode=${PROOF_MODE}"
        echo "source-title=snap-demo.rtf"
        echo "source-window-id=${before_id}"
        echo "before-zone=main"
        echo "before-workspace=${before_workspace}"
        echo 'target-zone=right'
        echo 'target-zone-name=Comms'
        echo 'snap-target=whole-zone'
        echo 'not-snap-target=window-within-zone'
        echo "source-point=${source_x},${source_y}"
        echo "target-point=${target_x},${target_y}"
        echo "negative-proof=drag without ${USER_MODIFIER_LABEL} does not show snap overlay or change zone binding"
        echo "${positive_action_text}"
        echo "freeform-pickup-screenshot=${FREEFORM_PICKUP_SCREENSHOT}"
        echo "freeform-hover-screenshot=${FREEFORM_HOVER_SCREENSHOT}"
        echo "snap-pickup-screenshot=${SNAP_PICKUP_SCREENSHOT}"
        echo "snap-path-screenshot=${SNAP_PATH_SCREENSHOT}"
        echo "snap-hover-screenshot=${SNAP_HOVER_SCREENSHOT}"
    } | tee "${ACTION_LOG}"

    {
        printf '%s\t%s\t%s\n' drag-source title 'snap-demo.rtf'
        printf '%s\t%s\t%s\n' drag-source window-id "${before_id}"
        printf '%s\t%s\t%s\n' drag-source before-zone main
        printf '%s\t%s\t%s\n' drag-source before-workspace "${before_workspace}"
        printf '%s\t%s\t%s\n' drag-target zone-id right
        printf '%s\t%s\t%s\n' drag-target zone-name Comms
        printf '%s\t%s\t%s\n' drag-target snap-target whole-zone
        printf '%s\t%s\t%s\n' drag-target not-snap-target window-within-zone
        printf '%s\t%s\t%s\n' drag-policy policy "${CONFIG_POLICY}"
        printf '%s\t%s\t%s\n' drag-policy modifier "${CONFIG_MODIFIER}"
        printf '%s\t%s\t%s\n' drag-policy negative-proof no-alt-no-zone-move
        printf '%s\t%s\t%s\n' drag-policy positive-proof "${positive_proof_key}"
        printf '%s\t%s\t%s\n' drag-policy proof-mode "${PROOF_MODE}"
        printf '%s\t%s\t%s\n' drag-points source "${source_x},${source_y}"
        printf '%s\t%s\t%s\n' drag-points target "${target_x},${target_y}"
        printf '%s\t%s\t%s\n' drag-points target-hover-hold-seconds '3.3'
        printf '%s\t%s\t%s\n' drag-points coordinate-policy 'derived-from-list-zones: source titlebar point is centered in Work/main; target point is centered inside Comms/right'
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            printf '%s\t%s\t%s\n' drag-points mapping-assertion 'freeform keeps snap-demo in Work/main; runtime snap-to-zone moves the same id to Comms/right without a held modifier'
        else
            printf '%s\t%s\t%s\n' drag-points mapping-assertion "freeform keeps snap-demo in Work/main; ${USER_MODIFIER_LABEL}-held drag moves the same id to Comms/right"
        fi
        printf '%s\t%s\t%s\n' drag-screenshots pickup "${SNAP_PICKUP_NAME}"
        printf '%s\t%s\t%s\n' drag-screenshots path "${SNAP_PATH_NAME}"
        printf '%s\t%s\t%s\n' drag-screenshots hover "${SNAP_HOVER_NAME}"
        printf '%s\t%s\t%s\n' drag-screenshots freeform-pickup "${FREEFORM_PICKUP_NAME}"
        printf '%s\t%s\t%s\n' drag-screenshots freeform-hover "${FREEFORM_HOVER_NAME}"
        printf '%s\t%s\t%s\n' visual-floor required-frames 'source window, dragged proxy/path, whole-zone Comms highlight/overlay, release, final placement, and freeform no-overlay negative proof'
        printf '%s\t%s\t%s\n' caption chip "${MODIFIER_CAPTION_CHIP}"
        printf '%s\t%s\t%s\n' verification before-window-log "$(artifact_relative_path "${WINDOW_BEFORE_LOG}")"
        printf '%s\t%s\t%s\n' verification after-freeform-window-log "$(artifact_relative_path "${WINDOW_FREEFORM_LOG}")"
        printf '%s\t%s\t%s\n' verification after-window-log "$(artifact_relative_path "${WINDOW_AFTER_LOG}")"
    } >"${ACTION_MANIFEST}"

    start_epoch="$(date +%s)"
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" 0 \
        "${FREEFORM_PICKUP_SCREENSHOT}" "" "${FREEFORM_HOVER_SCREENSHOT}"
    sleep 2
    freeform_epoch="$(date +%s)"
    refresh_window_log "${WINDOW_FREEFORM_LOG}"
    freeform_id="$(window_id_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_zone="$(zone_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_workspace="$(workspace_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    [ "${freeform_id}" = "${before_id}" ] || semantic_fail "Freeform drag changed window id: ${before_id} -> ${freeform_id:-missing}"
    [ "${freeform_zone}" = main ] || semantic_fail "Freeform drag changed zone binding: ${freeform_zone:-missing}"
    {
        echo "freeform-window-id-after=${freeform_id}"
        echo "freeform-after-zone=${freeform_zone}"
        echo "freeform-after-workspace=${freeform_workspace}"
        echo 'freeform-result=no-zone-move'
    } | tee -a "${ACTION_LOG}"
    {
        printf '%s\t%s\t%s\n' drag-result freeform-window-id-after "${freeform_id}"
        printf '%s\t%s\t%s\n' drag-result freeform-after-zone "${freeform_zone}"
        printf '%s\t%s\t%s\n' drag-result freeform-after-workspace "${freeform_workspace}"
        printf '%s\t%s\t%s\n' drag-result freeform-result no-zone-move
    } >>"${ACTION_MANIFEST}"

    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
        {
            echo "$ winmux set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            "${CLI}" set-zone-snap-policy "${RUNTIME_SET_POLICY}"
        } | tee "${SET_POLICY_LOG}" | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null
        grep -F "Using zone snap policy '${RUNTIME_SET_POLICY}'" "${SET_POLICY_LOG}" >/dev/null \
            || semantic_fail "set-zone-snap-policy did not report ${RUNTIME_SET_POLICY}"
        {
            echo "runtime-policy-command=set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            echo "runtime-policy-after-set=${RUNTIME_SET_POLICY}"
        } | tee -a "${ACTION_LOG}"
        {
            printf '%s\t%s\t%s\n' runtime-policy command "set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            printf '%s\t%s\t%s\n' runtime-policy after-set "${RUNTIME_SET_POLICY}"
        } >>"${ACTION_MANIFEST}"
        sleep 3
    fi

    reset_snap_window_to_work
    sleep 1
    capture_guest_screenshot "${RESET_NAME%.png}"
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
    fi

    snap_start_epoch="$(date +%s)"
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" "${positive_drag_with_alt}" \
        "${SNAP_PICKUP_SCREENSHOT}" "${SNAP_PATH_SCREENSHOT}" "${SNAP_HOVER_SCREENSHOT}"
    sleep 4
    snap_end_epoch="$(date +%s)"

    test -s "${FREEFORM_PICKUP_SCREENSHOT}"
    test -s "${FREEFORM_HOVER_SCREENSHOT}"
    test -s "${RESET_SCREENSHOT}"
    test -s "${SNAP_PICKUP_SCREENSHOT}"
    test -s "${SNAP_PATH_SCREENSHOT}"
    test -s "${SNAP_HOVER_SCREENSHOT}"

    for _ in $(seq 1 30); do
        refresh_window_log "${WINDOW_AFTER_LOG}"
        if [ "$(zone_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')" = right ]; then
            break
        fi
        sleep 1
    done
    after_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    after_zone="$(zone_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    after_workspace="$(workspace_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        snap_error_label='runtime snap-to-zone'
    else
        snap_error_label="${USER_MODIFIER_LABEL} snap"
    fi
    [ "${after_id}" = "${before_id}" ] || semantic_fail "${snap_error_label} changed window id: ${before_id} -> ${after_id:-missing}"
    [ "${after_zone}" = right ] || semantic_fail "${snap_error_label} did not move to Comms/right: ${after_zone:-missing}"
    [ -n "${before_workspace}" ] && [ -n "${after_workspace}" ] && [ "${before_workspace}" != "${after_workspace}" ] \
        || semantic_fail "${snap_error_label} did not move to the target zone active workspace"

    {
        echo "window-id-after=${after_id}"
        echo "after-zone=${after_zone}"
        echo "after-workspace=${after_workspace}"
        echo 'snap-result=success'
    } | tee -a "${ACTION_LOG}"
    {
        printf '%s\t%s\t%s\n' drag-result window-id-after "${after_id}"
        printf '%s\t%s\t%s\n' drag-result after-zone "${after_zone}"
        printf '%s\t%s\t%s\n' drag-result after-workspace "${after_workspace}"
        printf '%s\t%s\t%s\n' drag-result result success
    } >>"${ACTION_MANIFEST}"

    cycle_start_epoch=""
    cycle_end_epoch=""
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
        cycle_start_epoch="$(date +%s)"
        # shellcheck disable=SC2086
        {
            echo "$ winmux cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
            "${CLI}" cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}
        } | tee "${CYCLE_POLICY_LOG}" | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null
        cycle_end_epoch="$(date +%s)"
        grep -F "Using zone snap policy 'freeform'" "${CYCLE_POLICY_LOG}" >/dev/null \
            || semantic_fail 'cycle-zone-snap-policy did not return to freeform'
        {
            echo "runtime-cycle-command=cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
            echo 'runtime-policy-after-cycle=freeform'
        } | tee -a "${ACTION_LOG}"
        {
            printf '%s\t%s\t%s\n' runtime-policy cycle-command "cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
            printf '%s\t%s\t%s\n' runtime-policy after-cycle freeform
        } >>"${ACTION_MANIFEST}"
        sleep 3
    fi

    {
        printf 'freeform-drag-start-offset-seconds=%s\n' "$((start_epoch - start_epoch))"
        printf 'freeform-drag-end-offset-seconds=%s\n' "$((freeform_epoch - start_epoch))"
        printf 'snap-drag-start-offset-seconds=%s\n' "$((snap_start_epoch - start_epoch))"
        printf 'snap-drag-end-offset-seconds=%s\n' "$((snap_end_epoch - start_epoch))"
        if [ -n "${cycle_start_epoch}" ] && [ -n "${cycle_end_epoch}" ]; then
            printf 'cycle-command-start-offset-seconds=%s\n' "$((cycle_start_epoch - start_epoch))"
            printf 'cycle-command-end-offset-seconds=%s\n' "$((cycle_end_epoch - start_epoch))"
        fi
    } >"${TIMING_LOG}"

    cat "${ZONES_LOG}" "${WINDOW_BEFORE_LOG}" "${ACTION_LOG}" "${WINDOW_FREEFORM_LOG}" \
        "${WINDOW_RESET_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

    {
        echo "${SLICE_TITLE}"
        echo
        echo 'Config under proof:'
        echo "[mouse.zone-snap]"
        echo "policy = '${CONFIG_POLICY}'"
        echo "modifier = 'alt'"
        echo "gesture = 'drag'"
        echo "target = 'zone'"
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo
            echo 'Runtime commands under proof:'
            echo "winmux set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            echo "winmux cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
        fi
        echo
        echo 'Zones:'
        cat "${ZONES_LOG}"
        echo
        echo 'Before drag:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Action log:'
        cat "${ACTION_LOG}"
        echo
        echo 'Proof manifest:'
        cat "${ACTION_MANIFEST}"
        echo
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo 'After runtime snap-to-zone drag:'
        else
            echo "After ${USER_MODIFIER_LABEL} snap:"
        fi
        cat "${WINDOW_AFTER_LOG}"
        echo
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo "PASS: desktop drag starts from config freeform/no-zone-move; winmux set-zone-snap-policy snap-to-zone makes the next no-modifier drag preview a whole Comms zone target and move the same window into Comms/right on release; winmux cycle-zone-snap-policy freeform snap-to-zone returns the runtime policy to freeform."
        else
            echo "PASS: desktop drag without ${USER_MODIFIER_LABEL} stays freeform/no-zone-move; holding ${USER_MODIFIER_LABEL} previews a whole Comms zone target and moves the same window into Comms/right on release."
        fi
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 6
    printf 'result=success\n' >"${DONE}"
    copy_runtime_logs
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    *)
        echo "Unknown WINMUX_E2E_MOUSE_SNAP_PHASE/WINMUX_E2E_SLICE12_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
