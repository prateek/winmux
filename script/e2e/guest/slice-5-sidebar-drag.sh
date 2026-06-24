#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE5_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice5-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice5-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice5"
LAUNCH_PLIST="/tmp/winmux-e2e-slice5.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice5.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-action.log"
SIDEBAR_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-state-before.log"
SIDEBAR_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-state-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-5-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-5-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-5-windows-after.log"
ZONE_LOG="${ARTIFACTS_DIR}/logs/slice-5-zones.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-5-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-5-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-5-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-5-sidebar-drag.done"
PROOF="${ARTIFACTS_DIR}/slice-5-sidebar-drag-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/sidebar-zone-docs"
LEFT_DOC="${DOC_DIR}/left-reference.rtf"
MAIN_DOC="${DOC_DIR}/main-work.rtf"
RIGHT_DOC="${DOC_DIR}/right-comms.rtf"
MOVE_DOC="${DOC_DIR}/move-demo.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

write_zone_doc() {
    local path="$1"
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs120 ${headline}\par\fs64 ${subtitle}\par\fs40 ${detail}\par}
RTF
}

write_zone_log() {
    "${CLI}" list-zones \
        --format 'sidebar-zone=%{monitor-zone-name}|zone-id=%{monitor-zone-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        | tee "${ZONE_LOG}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --monitor all --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

zone_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title {
        sub(/^zone=/, "", $3)
        print $3
        exit
    }' "${path}"
}

workspace_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title {
        sub(/^workspace=/, "", $4)
        print $4
        exit
    }' "${path}"
}

window_id_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title { print $1; exit }' "${path}"
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(zone_for_title "${path}" "${title}")"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        echo "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}" >&2
        cat "${path}" >&2 || true
        exit 1
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

write_sidebar_state_log() {
    local output="$1"
    local window_log="$2"
    {
        "${CLI}" list-zones \
            --format 'sidebar-zone=%{monitor-zone-name}|zone-id=%{monitor-zone-id}|workspace=%{monitor-active-workspace}'
        /usr/bin/awk -F'|' '
            $2 != "" {
                zone = $3
                sub(/^zone=/, "", zone)
                workspace = $4
                sub(/^workspace=/, "", workspace)
                printf "sidebar-item=%s|title=%s|zone=%s|workspace=%s\n", $1, $2, zone, workspace
            }
        ' "${window_log}"
    } | tee "${output}"
}

focus_sidebar_source_window() {
    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${MOVE_ID}"
    sleep 1
}

open_sidebar_ready_state() {
    focus_sidebar_source_window
    "${CLI}" open-sidebar
    sleep 2
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-5-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${ACTION_LOG}" "${SIDEBAR_BEFORE_LOG}" "${SIDEBAR_AFTER_LOG}" \
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" "${ZONE_LOG}" \
        "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" \
        "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 5: sidebar zone targets'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [workspace-sidebar] enabled = true'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${LEFT_DOC}" 'REFERENCE' 'Sidebar zone' 'left column'
    write_zone_doc "${MAIN_DOC}" 'WORK' 'Sidebar zone' 'main column'
    write_zone_doc "${RIGHT_DOC}" 'COMMS' 'Sidebar zone' 'right column'
    write_zone_doc "${MOVE_DOC}" 'MOVE DEMO' 'Drag this sidebar item' 'target: Comms'

    launch_winmux
    write_zone_log
    grep -F 'sidebar-zone=Reference|zone-id=left|' "${ZONE_LOG}" >/dev/null
    grep -F 'sidebar-zone=Work|zone-id=main|' "${ZONE_LOG}" >/dev/null
    grep -F 'sidebar-zone=Comms|zone-id=right|' "${ZONE_LOG}" >/dev/null

    /usr/bin/open -a TextEdit "${LEFT_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${MAIN_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${RIGHT_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${MOVE_DOC}"

    if ! wait_for_textedit_windows 4; then
        echo 'TextEdit windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit 1
    fi

    LEFT_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'left-reference.rtf')"
    MAIN_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'main-work.rtf')"
    RIGHT_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'right-comms.rtf')"
    MOVE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'move-demo.rtf')"

    if [ -z "${LEFT_ID}" ] || [ -z "${MAIN_ID}" ] || [ -z "${RIGHT_ID}" ] || [ -z "${MOVE_ID}" ]; then
        echo 'Could not resolve all TextEdit window ids' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        exit 1
    fi

    move_window_to_zone "${LEFT_ID}" 'left-reference.rtf' Reference left
    move_window_to_zone "${MAIN_ID}" 'main-work.rtf' Work main
    move_window_to_zone "${RIGHT_ID}" 'right-comms.rtf' Comms right
    move_window_to_zone "${MOVE_ID}" 'move-demo.rtf' Work main
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'left-reference.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'main-work.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'right-comms.rtf' right
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'move-demo.rtf' main
    write_sidebar_state_log "${SIDEBAR_BEFORE_LOG}" "${WINDOW_BEFORE_LOG}"

    cat >"${STATE_FILE}" <<STATE
LEFT_ID=${LEFT_ID}
MAIN_ID=${MAIN_ID}
RIGHT_ID=${RIGHT_ID}
MOVE_ID=${MOVE_ID}
STATE

    open_sidebar_ready_state
    {
        echo 'setup=result=success'
        echo "move-window-id=${MOVE_ID}"
        echo 'ready-state=sidebar-open'
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

run_drag_jxa() {
    local source_x="$1"
    local source_y="$2"
    local target_x="$3"
    local target_y="$4"
    /usr/bin/osascript -l JavaScript <<JXA
ObjC.import('ApplicationServices')

function post(type, x, y) {
  const event = $.CGEventCreateMouseEvent(null, type, $.CGPointMake(Number(x), Number(y)), $.kCGMouseButtonLeft)
  $.CGEventPost($.kCGHIDEventTap, event)
}

const sx = Number('${source_x}')
const sy = Number('${source_y}')
const tx = Number('${target_x}')
const ty = Number('${target_y}')

post($.kCGEventMouseMoved, sx, sy)
delay(0.25)
post($.kCGEventLeftMouseDown, sx, sy)
delay(0.25)
for (let i = 1; i <= 28; i++) {
  const t = i / 28.0
  const x = sx + ((tx - sx) * t)
  const y = sy + ((ty - sy) * t)
  post($.kCGEventLeftMouseDragged, x, y)
  delay(0.035)
}
delay(0.20)
post($.kCGEventLeftMouseUp, tx, ty)
JXA
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${MOVE_ID:-}"

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    if [ "$(zone_for_title "${WINDOW_BEFORE_LOG}" 'move-demo.rtf')" != main ]; then
        "${CLI}" move-node-to-zone --window-id "${MOVE_ID}" Work
        sleep 1
        refresh_window_log "${WINDOW_BEFORE_LOG}"
    fi
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'move-demo.rtf' main
    write_sidebar_state_log "${SIDEBAR_BEFORE_LOG}" "${WINDOW_BEFORE_LOG}"
    focus_sidebar_source_window
    sleep 1

    before_zone="$(zone_for_title "${WINDOW_BEFORE_LOG}" 'move-demo.rtf')"
    before_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'move-demo.rtf')"
    {
        echo 'action=drag-to-zone'
        echo 'source=sidebar-window-item'
        echo "source-title=move-demo.rtf"
        echo "source-window-id=${MOVE_ID}"
        echo "before-zone=${before_zone}"
        echo "before-workspace=${before_workspace}"
        echo 'target-zone=right'
        echo 'target-zone-name=Comms'
        echo 'source-point=96,318'
        echo 'target-point=120,145'
    } | tee "${ACTION_LOG}"

    run_drag_jxa 96 318 120 145
    sleep 4

    for _ in $(seq 1 30); do
        refresh_window_log "${WINDOW_AFTER_LOG}"
        if [ "$(zone_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')" = right ]; then
            break
        fi
        sleep 1
    done

    after_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
    after_zone="$(zone_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
    after_workspace="$(workspace_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
    {
        echo "window-id-after=${after_id}"
        echo "after-zone=${after_zone}"
        echo "after-workspace=${after_workspace}"
        if [ "${after_zone}" = right ]; then
            echo 'drag-result=success'
        else
            echo 'drag-result=failure'
        fi
    } | tee -a "${ACTION_LOG}" | tee -a "${WINDOW_AFTER_LOG}" >/dev/null

    [ "${MOVE_ID}" = "${after_id}" ]
    [ "${after_zone}" = right ]
    [ "${before_workspace}" != "${after_workspace}" ]
    write_sidebar_state_log "${SIDEBAR_AFTER_LOG}" "${WINDOW_AFTER_LOG}"
    write_zone_log

    cat "${ZONE_LOG}" "${SIDEBAR_BEFORE_LOG}" "${ACTION_LOG}" "${SIDEBAR_AFTER_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 5: sidebar zone targets'
        echo
        echo 'Sidebar zones before drag:'
        cat "${SIDEBAR_BEFORE_LOG}"
        echo
        echo 'Visible drag action:'
        cat "${ACTION_LOG}"
        echo
        echo 'Sidebar zones after drag:'
        cat "${SIDEBAR_AFTER_LOG}"
        echo
        echo 'Window placement after drag:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo 'PASS: sidebar zone state and zone-target move are visible and logged.'
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
        echo "Unknown WINMUX_E2E_SLICE5_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
