#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE8_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice8-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice8-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice8"
LAUNCH_PLIST="/tmp/winmux-e2e-slice8.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice8.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-8-routing-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-8-routing-setup-windows.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-8-routing-before.log"
OPEN_LOG="${ARTIFACTS_DIR}/logs/slice-8-open-routed-window.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-8-routing-after.log"
ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-8-zones.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-8-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-8-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-8-window-routing-state.env"
DONE="${ARTIFACTS_DIR}/logs/slice-8-window-routing.done"
PROOF="${ARTIFACTS_DIR}/slice-8-window-routing-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/window-routing-docs"
REFERENCE_DOC="${DOC_DIR}/reference-anchor.rtf"
WORK_DOC="${DOC_DIR}/work-anchor.rtf"
COMMS_DOC="${DOC_DIR}/comms-anchor.rtf"
ROUTE_DOC="${DOC_DIR}/route-comms.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

write_route_doc() {
    local path="$1"
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs112 ${headline}\par\fs60 ${subtitle}\par\fs38 ${detail}\par}
RTF
}

write_zones_log() {
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${ZONES_LOG}"
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
        echo "Expected ${title} to be absent from visible window log" >&2
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-8-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${OPEN_LOG}" "${WINDOW_AFTER_LOG}" "${ZONES_LOG}" "${CLI_LOG}" \
        "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 8: window rules route to zones'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[on-window-detected]] route-comms -> move-node-to-zone Comms --fail-if-noop'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_route_doc "${REFERENCE_DOC}" 'REFERENCE' 'Anchor window' 'left zone before routing proof'
    write_route_doc "${WORK_DOC}" 'WORK' 'Active window' 'new matching document opens from here'
    write_route_doc "${COMMS_DOC}" 'COMMS' 'Destination window' 'right zone before routing proof'
    write_route_doc "${ROUTE_DOC}" 'ROUTE COMMS' 'Matches window-title regex' 'on-window-detected moves this to Comms'

    launch_winmux
    write_zones_log | tee -a "${SETUP_LOG}" >/dev/null
    grep -F 'zone=left|name=Reference|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=main|name=Work|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=right|name=Comms|' "${ZONES_LOG}" >/dev/null

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

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-anchor.rtf')"
    WORK_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-anchor.rtf')"
    COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-anchor.rtf')"
    for id in "${REFERENCE_ID}" "${WORK_ID}" "${COMMS_ID}"; do
        if [ -z "${id}" ]; then
            echo 'Could not resolve all TextEdit anchor window ids' >&2
            cat "${WINDOW_SETUP_LOG}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
        fi
    done

    setup_window_zone "${REFERENCE_ID}" 'reference-anchor.rtf' Reference left
    setup_window_zone "${WORK_ID}" 'work-anchor.rtf' Work main
    setup_window_zone "${COMMS_ID}" 'comms-anchor.rtf' Comms right
    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    sleep 2

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-anchor.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-anchor.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-anchor.rtf' right
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'route-comms.rtf'

    cat >"${STATE_FILE}" <<STATE
WORK_ID=${WORK_ID}
ROUTE_DOC=${ROUTE_DOC}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=reference-work-comms-visible'
        echo "work-window-id=${WORK_ID}"
        echo "route-doc=${ROUTE_DOC}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${WORK_ID:-}"
    test -f "${ROUTE_DOC}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-anchor.rtf' main
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'route-comms.rtf'
    sleep 16

    {
        echo '$ open -a TextEdit route-comms.rtf'
        /usr/bin/open -a TextEdit "${ROUTE_DOC}"
    } | tee "${OPEN_LOG}"

    for _ in $(seq 1 60); do
        refresh_window_log "${WINDOW_AFTER_LOG}"
        if [ "$(zone_for_title "${WINDOW_AFTER_LOG}" 'route-comms.rtf')" = right ]; then
            break
        fi
        sleep 1
    done

    ROUTE_ID="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'route-comms.rtf')"
    ROUTE_ZONE="$(zone_for_title "${WINDOW_AFTER_LOG}" 'route-comms.rtf')"
    ROUTE_WORKSPACE="$(workspace_for_title "${WINDOW_AFTER_LOG}" 'route-comms.rtf')"
    [ -n "${ROUTE_ID}" ] || semantic_fail 'route-comms.rtf did not appear in visible windows'
    [ "${ROUTE_ZONE}" = right ] || semantic_fail "route-comms.rtf did not route to Comms/right; got ${ROUTE_ZONE:-missing}"
    [ -n "${ROUTE_WORKSPACE}" ] || semantic_fail 'route-comms.rtf missing workspace after routing'

    "${CLI}" focus-zone Comms
    "${CLI}" focus --window-id "${ROUTE_ID}"
    refresh_window_log "${WINDOW_AFTER_LOG}"
    write_zones_log >/dev/null
    sleep 8

    cat "${WINDOW_BEFORE_LOG}" "${OPEN_LOG}" "${WINDOW_AFTER_LOG}" "${ZONES_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 8: window rules route to zones'
        echo
        echo 'Configured rule:'
        echo "[[on-window-detected]] if.window-title-regex-substring = 'route-comms'"
        echo "run = ['move-node-to-zone Comms --fail-if-noop']"
        echo
        echo 'Windows before opening routed document:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'User action:'
        cat "${OPEN_LOG}"
        echo
        echo 'Windows after rule routing:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo 'Zones after routing:'
        cat "${ZONES_LOG}"
        echo
        echo "routed-window-id=${ROUTE_ID}"
        echo "routed-zone=${ROUTE_ZONE}"
        echo "routed-workspace=${ROUTE_WORKSPACE}"
        echo
        echo 'PASS: on-window-detected routed route-comms.rtf to the Comms zone through move-node-to-zone.'
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
        echo "Unknown WINMUX_E2E_SLICE8_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
