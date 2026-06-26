#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE10_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice10-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice10-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice10"
LAUNCH_PLIST="/tmp/winmux-e2e-slice10.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice10.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-10-availability-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-10-availability-setup-windows.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-10-windows-before.log"
WINDOW_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-10-windows-hidden.log"
WINDOW_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-10-windows-restored.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-10-zones-before.log"
ZONES_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-10-zones-hidden.log"
ZONES_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-10-zones-restored.log"
SIDEBAR_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-10-sidebar-before.log"
SIDEBAR_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-10-sidebar-hidden.log"
SIDEBAR_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-10-sidebar-restored.log"
DISABLE_LOG="${ARTIFACTS_DIR}/logs/slice-10-disable-zone.log"
ENABLE_LOG="${ARTIFACTS_DIR}/logs/slice-10-enable-zone.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-10-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-10-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-10-zone-availability-state.env"
DONE="${ARTIFACTS_DIR}/logs/slice-10-zone-availability.done"
PROOF="${ARTIFACTS_DIR}/slice-10-zone-availability-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-availability-docs"
REFERENCE_DOC="${DOC_DIR}/reference-availability.rtf"
WORK_DOC="${DOC_DIR}/work-availability.rtf"
COMMS_DOC="${DOC_DIR}/comms-availability.rtf"

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
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs112 ${headline}\par\fs60 ${subtitle}\par\fs38 ${detail}\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x "${ARTIFACTS_DIR}/screenshots/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
}

write_sidebar_log() {
    local path="$1"
    {
        echo 'sidebar=enabled'
        write_zones_log /tmp/winmux-e2e-slice10-sidebar-zones.log
    } >"${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
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

zone_width() {
    local path="$1"
    local zone_id="$2"
    /usr/bin/awk -F'|' -v zone="zone=${zone_id}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, "width=") == 1) {
                print substr($i, 7)
                exit
            }
        }
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
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi
}

assert_title_absent() {
    local path="$1"
    local title="$2"
    if /usr/bin/grep -F "|${title}|" "${path}" >/dev/null; then
        echo "Expected ${title} to be hidden from visible window log" >&2
        cat "${path}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi
}

wait_for_textedit_windows() {
    local expected="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        if refresh_window_log "${path}"; then
            local count
            count="$(/usr/bin/grep -c '^' "${path}" || true)"
            if [ "${count}" -ge "${expected}" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

setup_window_zone() {
    local id="$1"
    local title="$2"
    local zone_name="$3"
    local expected_zone="$4"

    refresh_window_log "${WINDOW_SETUP_LOG}"
    if [ "$(zone_for_title "${WINDOW_SETUP_LOG}" "${title}")" = "${expected_zone}" ]; then
        echo "setup: ${title} already in zone ${expected_zone}" | tee -a "${CLI_LOG}"
        return
    fi

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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-10-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${WINDOW_HIDDEN_LOG}" "${WINDOW_RESTORED_LOG}" "${ZONES_BEFORE_LOG}" \
        "${ZONES_HIDDEN_LOG}" "${ZONES_RESTORED_LOG}" "${SIDEBAR_BEFORE_LOG}" \
        "${SIDEBAR_HIDDEN_LOG}" "${SIDEBAR_RESTORED_LOG}" "${DISABLE_LOG}" \
        "${ENABLE_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 10: runtime zone availability'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Commands: disable-zone Comms; enable-zone Comms'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" 'REFERENCE' 'Anchor window' 'left zone before availability proof'
    write_doc "${WORK_DOC}" 'WORK' 'Expanded window' 'main zone expands when Comms is hidden'
    write_doc "${COMMS_DOC}" 'COMMS' 'Parked window' 'this workspace returns when Comms is enabled'

    launch_winmux
    write_zones_log "${ZONES_BEFORE_LOG}" | tee -a "${SETUP_LOG}" >/dev/null
    grep -F 'zone=left|name=Reference|' "${ZONES_BEFORE_LOG}" >/dev/null
    grep -F 'zone=main|name=Work|' "${ZONES_BEFORE_LOG}" >/dev/null
    grep -F 'zone=right|name=Comms|' "${ZONES_BEFORE_LOG}" >/dev/null

    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${WORK_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${COMMS_DOC}"

    if ! wait_for_textedit_windows 3 "${WINDOW_SETUP_LOG}"; then
        echo 'TextEdit anchor windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-availability.rtf')"
    WORK_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-availability.rtf')"
    COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-availability.rtf')"
    for id in "${REFERENCE_ID}" "${WORK_ID}" "${COMMS_ID}"; do
        if [ -z "${id}" ]; then
            echo 'Could not resolve all TextEdit anchor window ids' >&2
            cat "${WINDOW_SETUP_LOG}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
        fi
    done

    setup_window_zone "${REFERENCE_ID}" 'reference-availability.rtf' Reference left
    setup_window_zone "${WORK_ID}" 'work-availability.rtf' Work main
    setup_window_zone "${COMMS_ID}" 'comms-availability.rtf' Comms right
    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    sleep 2

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-availability.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-availability.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-availability.rtf' right
    write_sidebar_log "${SIDEBAR_BEFORE_LOG}"

    cat >"${STATE_FILE}" <<STATE
WORK_ID=${WORK_ID}
COMMS_ID=${COMMS_ID}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=reference-work-comms-visible'
        echo "work-window-id=${WORK_ID}"
        echo "comms-window-id=${COMMS_ID}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${WORK_ID:-}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-availability.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-availability.rtf' right
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    sleep 8

    {
        echo '$ winmux disable-zone Comms'
        "${CLI}" disable-zone Comms
    } | tee "${DISABLE_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_HIDDEN_LOG}"
    write_zones_log "${ZONES_HIDDEN_LOG}" >/dev/null
    write_sidebar_log "${SIDEBAR_HIDDEN_LOG}"
    assert_window_zone "${WINDOW_HIDDEN_LOG}" 'reference-availability.rtf' left
    assert_window_zone "${WINDOW_HIDDEN_LOG}" 'work-availability.rtf' main
    assert_title_absent "${WINDOW_HIDDEN_LOG}" 'comms-availability.rtf'
    grep -F 'zone=right|name=Comms|enabled=true|' "${ZONES_HIDDEN_LOG}" >/dev/null \
        && semantic_fail 'Comms/right still appeared as an enabled zone after disable-zone'
    grep -F 'zone=main|name=Work|' "${ZONES_HIDDEN_LOG}" >/dev/null \
        || semantic_fail 'Work/main missing after disable-zone'
    main_before_width="$(zone_width "${ZONES_BEFORE_LOG}" main)"
    main_hidden_width="$(zone_width "${ZONES_HIDDEN_LOG}" main)"
    /usr/bin/awk -v before="${main_before_width}" -v hidden="${main_hidden_width}" 'BEGIN { exit(hidden > before ? 0 : 1) }' \
        || semantic_fail "Work/main did not expand after Comms was hidden; before=${main_before_width:-missing} hidden=${main_hidden_width:-missing}"
    capture_guest_screenshot '02-hidden-slice-10'
    sleep 8

    {
        echo '$ winmux enable-zone Comms'
        "${CLI}" enable-zone Comms
    } | tee "${ENABLE_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_RESTORED_LOG}"
    write_zones_log "${ZONES_RESTORED_LOG}" >/dev/null
    write_sidebar_log "${SIDEBAR_RESTORED_LOG}"
    assert_window_zone "${WINDOW_RESTORED_LOG}" 'reference-availability.rtf' left
    assert_window_zone "${WINDOW_RESTORED_LOG}" 'work-availability.rtf' main
    assert_window_zone "${WINDOW_RESTORED_LOG}" 'comms-availability.rtf' right
    grep -F 'zone=right|name=Comms|' "${ZONES_RESTORED_LOG}" >/dev/null \
        || semantic_fail 'Comms/right missing after enable-zone'
    capture_guest_screenshot '03-restored-slice-10'
    sleep 8

    cat \
        "${WINDOW_BEFORE_LOG}" "${DISABLE_LOG}" "${WINDOW_HIDDEN_LOG}" \
        "${ENABLE_LOG}" "${WINDOW_RESTORED_LOG}" "${ZONES_RESTORED_LOG}" \
        >"${CLI_LOG}"

    local comms_workspace
    comms_workspace="$(workspace_for_title "${WINDOW_RESTORED_LOG}" 'comms-availability.rtf')"

    {
        echo 'WinMux Slice 10: runtime zone availability'
        echo
        echo 'Commands:'
        cat "${DISABLE_LOG}"
        cat "${ENABLE_LOG}"
        echo
        echo 'Zones before disable:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'Visible windows while Comms is hidden:'
        cat "${WINDOW_HIDDEN_LOG}"
        echo
        echo 'Zones after restore:'
        cat "${ZONES_RESTORED_LOG}"
        echo
        echo 'Visible windows after restore:'
        cat "${WINDOW_RESTORED_LOG}"
        echo
        echo "restored-comms-workspace=${comms_workspace}"
        echo
        echo 'PASS: disable-zone Comms hides the zone and parks its workspace; enable-zone Comms restores the workspace.'
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 5
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
        echo "Unknown WINMUX_E2E_SLICE10_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
