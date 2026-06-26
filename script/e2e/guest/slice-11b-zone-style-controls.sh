#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE11B_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice11b-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice11b-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice11b"
LAUNCH_PLIST="/tmp/winmux-e2e-slice11b.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice11b.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11b-style-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11b-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11b-windows-before.log"
WINDOW_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-11b-windows-urgent.log"
WINDOW_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-11b-windows-calm.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11b-zones-before.log"
ZONES_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-11b-zones-urgent.log"
ZONES_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-11b-zones-calm.log"
SET_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-11b-set-zone-style-urgent.log"
SET_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-11b-set-zone-style-calm.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-11b-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-11b-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-11b-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-11b-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-11b-zone-style-controls.done"
PROOF="${ARTIFACTS_DIR}/slice-11b-zone-style-controls-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-style-docs"
REFERENCE_DOC="${DOC_DIR}/reference-style.rtf"
WORK_DOC="${DOC_DIR}/work-style.rtf"
COMMS_DOC="${DOC_DIR}/comms-style.rtf"

uid="$(/usr/bin/id -u)"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

write_style_doc() {
    local path="$1"
    local title="$2"
    local zone_id="$3"
    local workspace="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b ${title}\b0\par\f1\fs32 zone-id: ${zone_id}\par active-workspace: ${workspace}\par\par Style proof:\par before: no style token\par urgent: #D3455B\par calm: #3EA2FF\par\par Watch the sidebar zone row, not this document, for the visual style change.\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x "${ARTIFACTS_DIR}/screenshots/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|style=%{monitor-zone-style-id}|color=%{monitor-zone-style-color}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
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

zone_for_title() {
    field_for_title "$1" "$2" zone
}

workspace_for_title() {
    field_for_title "$1" "$2" workspace
}

window_id_for_title() {
    field_for_title "$1" "$2" id
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

assert_zone_style() {
    local path="$1"
    local zone_id="$2"
    local expected_style="$3"
    local expected_color="$4"
    local actual_style actual_color
    actual_style="$(zone_field "${path}" "${zone_id}" style)"
    actual_color="$(zone_field "${path}" "${zone_id}" color)"
    if [ "${actual_style}" != "${expected_style}" ] || [ "${actual_color}" != "${expected_color}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${zone_id} style=${expected_style} color=${expected_color}, got style=${actual_style:-missing} color=${actual_color:-missing}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-11b-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${WINDOW_URGENT_LOG}" "${WINDOW_CALM_LOG}" "${ZONES_BEFORE_LOG}" \
        "${ZONES_URGENT_LOG}" "${ZONES_CALM_LOG}" "${SET_URGENT_LOG}" \
        "${SET_CALM_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 11B: zone style controls'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-styles]] urgent=#D3455B calm=#3EA2FF'
        echo "Command: set-zone-style Comms urgent; set-zone-style Comms calm"
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_style_doc "${REFERENCE_DOC}" Reference left 1
    write_style_doc "${WORK_DOC}" Work main 2
    write_style_doc "${COMMS_DOC}" Comms right 3

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 || {
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'TextEdit windows did not appear'
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-style.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-style.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-style.rtf')"
    [ -n "${reference_id}" ] || semantic_fail 'Missing reference-style.rtf window id'
    [ -n "${work_id}" ] || semantic_fail 'Missing work-style.rtf window id'
    [ -n "${comms_id}" ] || semantic_fail 'Missing comms-style.rtf window id'

    move_window_to_zone "${reference_id}" 'reference-style.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-style.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-style.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-style.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-style.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-style.rtf' right
    assert_zone_style "${ZONES_BEFORE_LOG}" right "" ""

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=reference-work-comms-visible-sidebar-open'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    [ -f "${STATE_FILE}" ] || semantic_fail "Missing Slice 11B state file"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    [ -n "${WORK_ID:-}" ] || semantic_fail 'Missing WORK_ID in Slice 11B state file'
    [ -n "${COMMS_ID:-}" ] || semantic_fail 'Missing COMMS_ID in Slice 11B state file'

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    capture_guest_screenshot '02-before-style-slice-11b'
    sleep 13

    echo "urgent-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux set-zone-style Comms urgent'
        "${CLI}" set-zone-style Comms urgent
    } | tee "${SET_URGENT_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_URGENT_LOG}"
    write_zones_log "${ZONES_URGENT_LOG}" >/dev/null
    assert_zone_style "${ZONES_URGENT_LOG}" right urgent "#D3455B"
    capture_guest_screenshot '03-after-urgent-style-slice-11b'
    sleep 15

    echo "calm-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux set-zone-style Comms calm'
        "${CLI}" set-zone-style Comms calm
    } | tee "${SET_CALM_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_CALM_LOG}"
    write_zones_log "${ZONES_CALM_LOG}" >/dev/null
    assert_zone_style "${ZONES_CALM_LOG}" right calm "#3EA2FF"
    capture_guest_screenshot '04-after-calm-style-slice-11b'
    sleep 8

    assert_window_zone "${WINDOW_URGENT_LOG}" 'reference-style.rtf' left
    assert_window_zone "${WINDOW_URGENT_LOG}" 'work-style.rtf' main
    assert_window_zone "${WINDOW_URGENT_LOG}" 'comms-style.rtf' right
    assert_window_zone "${WINDOW_CALM_LOG}" 'reference-style.rtf' left
    assert_window_zone "${WINDOW_CALM_LOG}" 'work-style.rtf' main
    assert_window_zone "${WINDOW_CALM_LOG}" 'comms-style.rtf' right

    cat \
        "${WINDOW_BEFORE_LOG}" "${SET_URGENT_LOG}" "${WINDOW_URGENT_LOG}" \
        "${SET_CALM_LOG}" "${WINDOW_CALM_LOG}" "${ZONES_CALM_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 11B: zone style controls'
        echo
        echo 'Commands:'
        cat "${SET_URGENT_LOG}"
        cat "${SET_CALM_LOG}"
        echo
        echo 'Before style:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'Urgent style:'
        cat "${ZONES_URGENT_LOG}"
        echo
        echo 'Calm style:'
        cat "${ZONES_CALM_LOG}"
        echo
        cat "${TIMING_LOG}"
        echo "comms-window-id=${COMMS_ID:-}"
        echo "comms-workspace=$(workspace_for_title "${WINDOW_CALM_LOG}" 'comms-style.rtf')"
        echo
        echo 'PASS: set-zone-style applies configured urgent and calm style tokens to the Comms zone while windows and workspaces stay in the same zone ids.'
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
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
        echo "Unknown Slice 11B phase: ${PHASE}" >&2
        exit 2
        ;;
esac
