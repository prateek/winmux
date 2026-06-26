#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE11C_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice11c-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice11c-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice11c"
LAUNCH_PLIST="/tmp/winmux-e2e-slice11c.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice11c.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11c-availability-sets-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11c-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11c-windows-before.log"
WINDOW_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-11c-windows-focus-only.log"
WINDOW_RESTORING_LOG="${ARTIFACTS_DIR}/logs/slice-11c-windows-restoring.log"
WINDOW_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-11c-windows-restored.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11c-zones-before.log"
ZONES_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-11c-zones-urgent.log"
ZONES_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-11c-zones-focus-only.log"
ZONES_RESTORING_LOG="${ARTIFACTS_DIR}/logs/slice-11c-zones-restoring.log"
ZONES_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-11c-zones-restored.log"
SET_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-11c-set-zone-style-urgent.log"
USE_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-11c-use-focus-only.log"
USE_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-11c-use-communications.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-11c-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-11c-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-11c-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-11c-window-ids.env"
COLOR_SENTINEL="${ARTIFACTS_DIR}/logs/slice-11c-zone-availability-sets.color-sentinel.tsv"
DONE="${ARTIFACTS_DIR}/logs/slice-11c-zone-availability-sets.done"
PROOF="${ARTIFACTS_DIR}/slice-11c-zone-availability-sets-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-availability-set-docs"
REFERENCE_DOC="${DOC_DIR}/reference-availability-set.rtf"
WORK_DOC="${DOC_DIR}/work-availability-set.rtf"
COMMS_DOC="${DOC_DIR}/comms-availability-set.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

write_doc() {
    local path="$1"
    local title="$2"
    local zone_id="$3"
    local workspace="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b ${title}\b0\par\f1\fs32 zone-id: ${zone_id}\par active-workspace: ${workspace}\par\par Availability set proof:\par focus-only: Work only\par communications: Work + Comms\par urgent style: #D3455B\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x "${ARTIFACTS_DIR}/screenshots/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|availability=%{monitor-zone-availability-set-id}|style=%{monitor-zone-style-id}|color=%{monitor-zone-style-color}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
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

assert_title_absent() {
    local path="$1"
    local title="$2"
    if /usr/bin/grep -F "|${title}|" "${path}" >/dev/null; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${title} to be hidden from visible window log"
    fi
}

assert_zone_field() {
    local path="$1"
    local zone_id="$2"
    local key="$3"
    local expected="$4"
    local actual
    actual="$(zone_field "${path}" "${zone_id}" "${key}")"
    if [ "${actual}" != "${expected}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${zone_id} ${key}=${expected}, got ${actual:-missing}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-11c-zone-count.txt" 2>"${WAIT_ERR}"; then
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

write_color_sentinel_manifest() {
    cat >"${COLOR_SENTINEL}" <<EOF
swatch	before-hide-urgent	screenshots/03-before-hide-urgent-slice-11c.png	224	92	18	70	#D3455B	3	80	Comms urgent swatch before focus-only hides side zones
swatch	during-restore-urgent	screenshots/05-during-communications-restore-slice-11c.png	224	92	18	70	#D3455B	3	80	Comms urgent swatch immediately after communications restores right
swatch	after-restore-urgent	screenshots/06-after-communications-restore-slice-11c.png	224	92	18	70	#D3455B	3	80	Comms urgent swatch remains after restore settles
EOF
}

setup_slice() {
    rm -f \
        "${DONE}" "${SETUP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${WINDOW_FOCUS_LOG}" "${WINDOW_RESTORING_LOG}" "${WINDOW_RESTORED_LOG}" \
        "${ZONES_BEFORE_LOG}" "${ZONES_URGENT_LOG}" "${ZONES_FOCUS_LOG}" \
        "${ZONES_RESTORING_LOG}" "${ZONES_RESTORED_LOG}" "${SET_URGENT_LOG}" \
        "${USE_FOCUS_LOG}" "${USE_COMMUNICATIONS_LOG}" "${TIMING_LOG}" \
        "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${COLOR_SENTINEL}" \
        "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" \
        "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" \
        "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 11C: named zone availability sets'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-availability-sets]] focus-only + communications + full-dashboard'
        echo 'Commands: set-zone-style Comms urgent; use-zone-availability focus-only; use-zone-availability communications'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" Reference left 1
    write_doc "${WORK_DOC}" Work main 2
    write_doc "${COMMS_DOC}" Comms right 3

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 || {
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'TextEdit windows did not appear'
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-availability-set.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-availability-set.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-availability-set.rtf')"
    [ -n "${reference_id}" ] || semantic_fail 'Missing reference-availability-set.rtf window id'
    [ -n "${work_id}" ] || semantic_fail 'Missing work-availability-set.rtf window id'
    [ -n "${comms_id}" ] || semantic_fail 'Missing comms-availability-set.rtf window id'

    move_window_to_zone "${reference_id}" 'reference-availability-set.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-availability-set.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-availability-set.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-availability-set.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-availability-set.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-availability-set.rtf' right
    assert_zone_field "${ZONES_BEFORE_LOG}" right style ""
    assert_zone_field "${ZONES_BEFORE_LOG}" right availability ""

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
    [ -f "${STATE_FILE}" ] || semantic_fail "Missing Slice 11C state file"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    [ -n "${WORK_ID:-}" ] || semantic_fail 'Missing WORK_ID in Slice 11C state file'
    [ -n "${COMMS_ID:-}" ] || semantic_fail 'Missing COMMS_ID in Slice 11C state file'

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    capture_guest_screenshot '02-before-availability-slice-11c'
    sleep 8

    echo "urgent-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux set-zone-style Comms urgent'
        "${CLI}" set-zone-style Comms urgent
    } | tee "${SET_URGENT_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_URGENT_LOG}" >/dev/null
    assert_zone_field "${ZONES_URGENT_LOG}" right style urgent
    assert_zone_field "${ZONES_URGENT_LOG}" right color "#D3455B"
    assert_zone_field "${ZONES_URGENT_LOG}" right enabled true
    capture_guest_screenshot '03-before-hide-urgent-slice-11c'
    sleep 12

    echo "focus-only-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-availability focus-only'
        "${CLI}" use-zone-availability focus-only
    } | tee "${USE_FOCUS_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_FOCUS_LOG}"
    write_zones_log "${ZONES_FOCUS_LOG}" >/dev/null
    assert_window_zone "${WINDOW_FOCUS_LOG}" 'work-availability-set.rtf' main
    assert_title_absent "${WINDOW_FOCUS_LOG}" 'reference-availability-set.rtf'
    assert_title_absent "${WINDOW_FOCUS_LOG}" 'comms-availability-set.rtf'
    assert_zone_field "${ZONES_FOCUS_LOG}" left enabled false
    assert_zone_field "${ZONES_FOCUS_LOG}" main enabled true
    assert_zone_field "${ZONES_FOCUS_LOG}" right enabled false
    assert_zone_field "${ZONES_FOCUS_LOG}" main availability focus-only
    assert_zone_field "${ZONES_FOCUS_LOG}" right style urgent
    before_main_width="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    focus_main_width="$(zone_field "${ZONES_FOCUS_LOG}" main width)"
    /usr/bin/awk -v before="${before_main_width}" -v focus="${focus_main_width}" 'BEGIN { exit(focus > before ? 0 : 1) }' \
        || semantic_fail "Work/main did not expand for focus-only; before=${before_main_width:-missing} focus=${focus_main_width:-missing}"
    capture_guest_screenshot '04-after-focus-only-slice-11c'
    sleep 14

    echo "communications-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-availability communications'
        "${CLI}" use-zone-availability communications
    } | tee "${USE_COMMUNICATIONS_LOG}"
    sleep 1
    refresh_window_log "${WINDOW_RESTORING_LOG}"
    write_zones_log "${ZONES_RESTORING_LOG}" >/dev/null
    assert_window_zone "${WINDOW_RESTORING_LOG}" 'work-availability-set.rtf' main
    assert_window_zone "${WINDOW_RESTORING_LOG}" 'comms-availability-set.rtf' right
    assert_title_absent "${WINDOW_RESTORING_LOG}" 'reference-availability-set.rtf'
    assert_zone_field "${ZONES_RESTORING_LOG}" left enabled false
    assert_zone_field "${ZONES_RESTORING_LOG}" main enabled true
    assert_zone_field "${ZONES_RESTORING_LOG}" right enabled true
    assert_zone_field "${ZONES_RESTORING_LOG}" main availability communications
    assert_zone_field "${ZONES_RESTORING_LOG}" right availability communications
    assert_zone_field "${ZONES_RESTORING_LOG}" right style urgent
    assert_zone_field "${ZONES_RESTORING_LOG}" right color "#D3455B"
    capture_guest_screenshot '05-during-communications-restore-slice-11c'
    sleep 4

    refresh_window_log "${WINDOW_RESTORED_LOG}"
    write_zones_log "${ZONES_RESTORED_LOG}" >/dev/null
    assert_window_zone "${WINDOW_RESTORED_LOG}" 'work-availability-set.rtf' main
    assert_window_zone "${WINDOW_RESTORED_LOG}" 'comms-availability-set.rtf' right
    assert_title_absent "${WINDOW_RESTORED_LOG}" 'reference-availability-set.rtf'
    assert_zone_field "${ZONES_RESTORED_LOG}" left enabled false
    assert_zone_field "${ZONES_RESTORED_LOG}" right enabled true
    assert_zone_field "${ZONES_RESTORED_LOG}" right availability communications
    assert_zone_field "${ZONES_RESTORED_LOG}" right style urgent
    assert_zone_field "${ZONES_RESTORED_LOG}" right color "#D3455B"
    capture_guest_screenshot '06-after-communications-restore-slice-11c'
    write_color_sentinel_manifest
    sleep 12

    cat \
        "${WINDOW_BEFORE_LOG}" "${SET_URGENT_LOG}" "${ZONES_URGENT_LOG}" \
        "${USE_FOCUS_LOG}" "${WINDOW_FOCUS_LOG}" "${ZONES_FOCUS_LOG}" \
        "${USE_COMMUNICATIONS_LOG}" "${WINDOW_RESTORED_LOG}" "${ZONES_RESTORED_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 11C: named zone availability sets'
        echo
        echo 'Commands:'
        cat "${SET_URGENT_LOG}"
        cat "${USE_FOCUS_LOG}"
        cat "${USE_COMMUNICATIONS_LOG}"
        echo
        echo 'Zones before availability set:'
        cat "${ZONES_URGENT_LOG}"
        echo
        echo 'Zones after focus-only:'
        cat "${ZONES_FOCUS_LOG}"
        echo
        echo 'Visible windows after focus-only:'
        cat "${WINDOW_FOCUS_LOG}"
        echo
        echo 'Zones after communications:'
        cat "${ZONES_RESTORED_LOG}"
        echo
        echo 'Visible windows after communications:'
        cat "${WINDOW_RESTORED_LOG}"
        echo
        cat "${TIMING_LOG}"
        echo "comms-window-id=${COMMS_ID:-}"
        echo "comms-workspace=$(workspace_for_title "${WINDOW_RESTORED_LOG}" 'comms-availability-set.rtf')"
        echo "main-width-before=${before_main_width}"
        echo "main-width-focus-only=${focus_main_width}"
        echo
        echo 'PASS: named availability sets hide side zones with focus-only, expand Work, then restore Comms/right with its workspace and urgent style intact under communications.'
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
        echo "Unknown Slice 11C phase: ${PHASE}" >&2
        exit 2
        ;;
esac
