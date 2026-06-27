#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE19_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice19-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice19-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice19"
LAUNCH_PLIST="/tmp/winmux-e2e-slice19.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice19.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-19-zone-style-cycle-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-19-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-19-windows-before.log"
WINDOW_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-19-windows-urgent.log"
WINDOW_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-19-windows-calm.log"
WINDOW_WRAP_LOG="${ARTIFACTS_DIR}/logs/slice-19-windows-wrap.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-19-zones-before.log"
ZONES_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-19-zones-urgent.log"
ZONES_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-19-zones-calm.log"
ZONES_WRAP_LOG="${ARTIFACTS_DIR}/logs/slice-19-zones-wrap.log"
CYCLE_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-19-cycle-zone-style-urgent.log"
CYCLE_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-19-cycle-zone-style-calm.log"
CYCLE_WRAP_LOG="${ARTIFACTS_DIR}/logs/slice-19-cycle-zone-style-wrap.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-19-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-19-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-19-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-19-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-19-zone-style-cycle.done"
PROOF="${ARTIFACTS_DIR}/slice-19-zone-style-cycle-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-style-cycle-docs"
REFERENCE_DOC="${DOC_DIR}/reference-style-cycle.rtf"
WORK_DOC="${DOC_DIR}/work-style-cycle.rtf"
COMMS_DOC="${DOC_DIR}/comms-style-cycle.rtf"

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
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b ${title}\b0\par\f1\fs32 zone-id: ${zone_id}\par active-workspace: ${workspace}\par\par Cycle style proof:\par start: no style token\par cycle 1: urgent #D3455B\par cycle 2: calm #3EA2FF\par cycle 3: urgent wraparound\par\par Watch the sidebar zone row, not this document, for the visual style cycle.\par}
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

doc_path_for_title() {
    case "$1" in
        reference-style-cycle.rtf) printf '%s\n' "${REFERENCE_DOC}" ;;
        work-style-cycle.rtf) printf '%s\n' "${WORK_DOC}" ;;
        comms-style-cycle.rtf) printf '%s\n' "${COMMS_DOC}" ;;
        *) return 1 ;;
    esac
}

wait_for_textedit_titles() {
    local path="$1"
    shift
    local attempt title doc
    local missing_titles=()

    for attempt in $(seq 1 60); do
        refresh_window_log "${path}" || true
        missing_titles=()
        for title in "$@"; do
            if ! /usr/bin/grep -F "|${title}|" "${path}" >/dev/null 2>&1; then
                missing_titles+=("${title}")
            fi
        done
        if [ "${#missing_titles[@]}" -eq 0 ]; then
            return 0
        fi
        if [ $((attempt % 5)) -eq 0 ]; then
            for title in "${missing_titles[@]}"; do
                if doc="$(doc_path_for_title "${title}")"; then
                    echo "retry-open missing TextEdit title: ${title}" >>"${SETUP_LOG}"
                    /usr/bin/open -a TextEdit "${doc}" || true
                fi
            done
        fi
        sleep 1
    done

    {
        echo 'TextEdit title wait failed'
        echo 'Expected titles:'
        printf '  %s\n' "$@"
        echo 'Observed titles:'
        /usr/bin/awk -F'|' '{ print "  " $2 }' "${path}" | /usr/bin/sort || true
        echo 'Missing titles:'
        printf '  %s\n' "${missing_titles[@]}"
    } >&2
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-19-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${WINDOW_URGENT_LOG}" "${WINDOW_CALM_LOG}" "${WINDOW_WRAP_LOG}" \
        "${ZONES_BEFORE_LOG}" "${ZONES_URGENT_LOG}" "${ZONES_CALM_LOG}" \
        "${ZONES_WRAP_LOG}" "${CYCLE_URGENT_LOG}" "${CYCLE_CALM_LOG}" \
        "${CYCLE_WRAP_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 19: zone style cycling'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-styles]] urgent=#D3455B calm=#3EA2FF'
        echo 'Command: cycle-zone-style Comms urgent calm'
        echo 'Non-claim: no visual editor, draggable divider, snap gesture, or persistence beyond runtime style overlay'
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
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${WORK_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${COMMS_DOC}"
    wait_for_textedit_titles \
        "${WINDOW_SETUP_LOG}" \
        reference-style-cycle.rtf \
        work-style-cycle.rtf \
        comms-style-cycle.rtf || {
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'TextEdit windows did not appear'
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-style-cycle.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-style-cycle.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-style-cycle.rtf')"
    [ -n "${reference_id}" ] || semantic_fail 'Missing reference-style-cycle.rtf window id'
    [ -n "${work_id}" ] || semantic_fail 'Missing work-style-cycle.rtf window id'
    [ -n "${comms_id}" ] || semantic_fail 'Missing comms-style-cycle.rtf window id'

    move_window_to_zone "${reference_id}" 'reference-style-cycle.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-style-cycle.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-style-cycle.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-style-cycle.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-style-cycle.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-style-cycle.rtf' right
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
    [ -f "${STATE_FILE}" ] || semantic_fail "Missing Slice 19 state file"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    [ -n "${WORK_ID:-}" ] || semantic_fail 'Missing WORK_ID in Slice 19 state file'
    [ -n "${COMMS_ID:-}" ] || semantic_fail 'Missing COMMS_ID in Slice 19 state file'

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    capture_guest_screenshot '02-before-style-slice-19'
    sleep 13

    echo "cycle-urgent-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux cycle-zone-style Comms urgent calm'
        "${CLI}" cycle-zone-style Comms urgent calm
    } | tee "${CYCLE_URGENT_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_URGENT_LOG}"
    write_zones_log "${ZONES_URGENT_LOG}" >/dev/null
    assert_zone_style "${ZONES_URGENT_LOG}" right urgent "#D3455B"
    capture_guest_screenshot '03-after-urgent-cycle-slice-19'
    sleep 15

    echo "cycle-calm-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux cycle-zone-style Comms urgent calm'
        "${CLI}" cycle-zone-style Comms urgent calm
    } | tee "${CYCLE_CALM_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_CALM_LOG}"
    write_zones_log "${ZONES_CALM_LOG}" >/dev/null
    assert_zone_style "${ZONES_CALM_LOG}" right calm "#3EA2FF"
    capture_guest_screenshot '04-after-calm-cycle-slice-19'
    sleep 15

    echo "cycle-wrap-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux cycle-zone-style Comms urgent calm'
        "${CLI}" cycle-zone-style Comms urgent calm
    } | tee "${CYCLE_WRAP_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_WRAP_LOG}"
    write_zones_log "${ZONES_WRAP_LOG}" >/dev/null
    assert_zone_style "${ZONES_WRAP_LOG}" right urgent "#D3455B"
    capture_guest_screenshot '05-after-wrap-cycle-slice-19'
    sleep 8

    for path in "${WINDOW_URGENT_LOG}" "${WINDOW_CALM_LOG}" "${WINDOW_WRAP_LOG}"; do
        assert_window_zone "${path}" 'reference-style-cycle.rtf' left
        assert_window_zone "${path}" 'work-style-cycle.rtf' main
        assert_window_zone "${path}" 'comms-style-cycle.rtf' right
    done

    cat \
        "${WINDOW_BEFORE_LOG}" "${CYCLE_URGENT_LOG}" "${WINDOW_URGENT_LOG}" \
        "${CYCLE_CALM_LOG}" "${WINDOW_CALM_LOG}" \
        "${CYCLE_WRAP_LOG}" "${WINDOW_WRAP_LOG}" "${ZONES_WRAP_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 19: zone style cycling'
        echo
        echo 'Commands:'
        cat "${CYCLE_URGENT_LOG}"
        cat "${CYCLE_CALM_LOG}"
        cat "${CYCLE_WRAP_LOG}"
        echo
        echo 'Before style:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'Cycle 1 urgent style:'
        cat "${ZONES_URGENT_LOG}"
        echo
        echo 'Cycle 2 calm style:'
        cat "${ZONES_CALM_LOG}"
        echo
        echo 'Cycle 3 urgent wraparound:'
        cat "${ZONES_WRAP_LOG}"
        echo
        cat "${TIMING_LOG}"
        echo "comms-window-id=${COMMS_ID:-}"
        echo "comms-workspace=$(workspace_for_title "${WINDOW_WRAP_LOG}" 'comms-style-cycle.rtf')"
        echo
        echo 'PASS: cycle-zone-style advances Comms from no style to urgent, then calm, then wraps back to urgent while windows and workspaces stay in the same zone ids.'
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
        echo "Unknown Slice 19 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
