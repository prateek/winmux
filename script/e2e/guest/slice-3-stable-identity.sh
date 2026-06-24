#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
INITIAL_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
CONFIG="${ARTIFACTS_DIR}/config/winmux-active.toml"
RELOAD_CONFIG="${ARTIFACTS_DIR}/config/winmux-shifted.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice3-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice3-startup.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-3-cli.log"
MONITOR_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-3-monitors-before.log"
MONITOR_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-3-monitors-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-3-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-3-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-3-windows-after.log"
MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-3-moves.log"
RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-3-reload.log"
WORKSPACE_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-3-workspaces-before.log"
WORKSPACE_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-3-workspaces-after.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
DONE="${ARTIFACTS_DIR}/logs/slice-3-stable-identity.done"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-3-cli-wait.err"
PROOF="${ARTIFACTS_DIR}/slice-3-stable-identity-proof.txt"

ZONE_DOC_DIR="${HOME}/winmux-e2e/zone-docs"
LEFT_DOC="${ZONE_DOC_DIR}/left-reference.rtf"
MAIN_DOC="${ZONE_DOC_DIR}/main-work.rtf"
RIGHT_DOC="${ZONE_DOC_DIR}/right-comms.rtf"
LAUNCH_LABEL="local.winmux.e2e.slice3"
LAUNCH_PLIST="/tmp/winmux-e2e-slice3.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice3.plist"

rm -f \
    "${DONE}" "${CLI_LOG}" "${MONITOR_BEFORE_LOG}" "${MONITOR_AFTER_LOG}" \
    "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
    "${MOVE_LOG}" "${RELOAD_LOG}" "${WORKSPACE_BEFORE_LOG}" "${WORKSPACE_AFTER_LOG}" \
    "${WAIT_ERR}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
    "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
    "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
rm -rf "${ZONE_DOC_DIR}"

echo 'WinMux Slice 3: stable zone viewport identity across config reload'
echo 'Environment: config-backed zones, shifted-width reload config'
echo
echo "Source App: ${SOURCE_APP}"
echo "Source CLI: ${SOURCE_CLI}"
echo "App: ${APP}"
echo "CLI: ${CLI}"
echo "Initial config: ${INITIAL_CONFIG}"
echo "Active config: ${CONFIG}"
echo "Reload config: ${RELOAD_CONFIG}"
echo

test -x "${SOURCE_APP}"
test -x "${SOURCE_CLI}"
test -f "${INITIAL_CONFIG}"
test -f "${RELOAD_CONFIG}"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}" "${ZONE_DOC_DIR}"
/bin/cp "${INITIAL_CONFIG}" "${CONFIG}"
/bin/cp "${SOURCE_APP}" "${APP}"
/bin/cp "${SOURCE_CLI}" "${CLI}"
chmod +x "${APP}" "${CLI}"

write_zone_doc() {
    local path="$1"
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs120 ${headline}\par\fs64 ${subtitle}\par\fs40 ${detail}\par}
RTF
}

write_zone_doc "${LEFT_DOC}" 'LEFT ZONE' 'Reference' 'config id: left'
write_zone_doc "${MAIN_DOC}" 'MAIN ZONE' 'Work' 'config id: main'
write_zone_doc "${RIGHT_DOC}" 'RIGHT ZONE' 'Comms' 'config id: right'

uid="$(/usr/bin/id -u)"
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

cleanup() {
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

/bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
/bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

for _ in $(seq 1 60); do
    /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
    /usr/bin/awk '/pid =/ { print $3; exit }' "${LAUNCH_STATUS}" >"${ARTIFACTS_DIR}/logs/winmux-app.pid" || true
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
    if "${CLI}" list-monitors --count >"${ARTIFACTS_DIR}/logs/slice-3-monitor-count.txt" 2>"${WAIT_ERR}"; then
        break
    fi
    sleep 1
done

if ! "${CLI}" list-monitors --count >/tmp/winmux-slice-3-count 2>>"${WAIT_ERR}"; then
    echo 'WinMux CLI did not become ready' >&2
    echo 'LaunchAgent status:' >&2
    cat "${LAUNCH_STATUS}" >&2 || true
    echo 'WinMux app log:' >&2
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    cat "${APP_LOG}" >&2 || true
    echo 'WinMux startup trace:' >&2
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
    cat "${STARTUP_TRACE}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    exit 1
fi

write_monitor_log() {
    local path="$1"
    "${CLI}" list-monitors \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-name}|left=%{monitor-left}|top=%{monitor-top}|width=%{monitor-width}|height=%{monitor-height}' \
        | tee "${path}"
}

write_workspace_log() {
    local path="$1"
    "${CLI}" list-workspaces --all \
        --format '%{workspace}|visible=%{workspace-is-visible}|focused=%{workspace-is-focused}|zone=%{monitor-zone-id}|monitor=%{monitor-name}' \
        | tee "${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --monitor all --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|left=%{monitor-left}|width=%{monitor-width}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

field_for_zone() {
    local path="$1"
    local zone_id="$2"
    local field_name="$3"
    /usr/bin/awk -F'|' -v zone="zone=${zone_id}" -v key="${field_name}=" '
        $1 == zone {
            for (i = 1; i <= NF; i++) {
                if (index($i, key) == 1) {
                    print substr($i, length(key) + 1)
                    exit
                }
            }
        }
    ' "${path}"
}

require_zone_log() {
    local path="$1"
    grep -F 'zone=left|' "${path}" >/dev/null
    grep -F 'zone=main|' "${path}" >/dev/null
    grep -F 'zone=right|' "${path}" >/dev/null
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

all_windows_in_expected_zones() {
    local path="$1"
    [ "$(zone_for_title "${path}" 'left-reference.rtf')" = left ] &&
        [ "$(zone_for_title "${path}" 'main-work.rtf')" = main ] &&
        [ "$(zone_for_title "${path}" 'right-comms.rtf')" = right ]
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

setup_window_zone() {
    local id="$1"
    local title="$2"
    local target="$3"
    local expected_zone="$4"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    if [ "$(zone_for_title "${WINDOW_SETUP_LOG}" "${title}")" = "${expected_zone}" ]; then
        echo "setup: ${title} already in zone ${expected_zone}; no setup move needed" | tee -a "${MOVE_LOG}"
        return
    fi
    {
        echo "setup: move ${title} to ${target}"
        echo "$ winmux move-node-to-monitor --window-id ${id} ${target}"
        "${CLI}" move-node-to-monitor --window-id "${id}" "${target}"
    } | tee -a "${MOVE_LOG}"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_zone}"
}

strict_move_window_zone() {
    local id="$1"
    local title="$2"
    local target="$3"
    local expected_before="$4"
    local expected_after="$5"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_before}"
    {
        echo "proof: move ${title} from ${expected_before} to ${expected_after} via named target ${target}"
        echo "$ winmux move-node-to-monitor --fail-if-noop --window-id ${id} ${target}"
        "${CLI}" move-node-to-monitor --fail-if-noop --window-id "${id}" "${target}"
    } | tee -a "${MOVE_LOG}"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_after}"
}

assert_geometry_changed() {
    local zone_id="$1"
    local field_name="$2"
    local before
    local after
    before="$(field_for_zone "${MONITOR_BEFORE_LOG}" "${zone_id}" "${field_name}")"
    after="$(field_for_zone "${MONITOR_AFTER_LOG}" "${zone_id}" "${field_name}")"
    if [ -z "${before}" ] || [ -z "${after}" ] || [ "${before}" = "${after}" ]; then
        echo "Expected ${zone_id} ${field_name} to change, before=${before:-missing} after=${after:-missing}" >&2
        echo 'Before monitors:' >&2
        cat "${MONITOR_BEFORE_LOG}" >&2 || true
        echo 'After monitors:' >&2
        cat "${MONITOR_AFTER_LOG}" >&2 || true
        exit 1
    fi
}

/usr/bin/open -a TextEdit "${LEFT_DOC}"
sleep 2
/usr/bin/open -a TextEdit "${MAIN_DOC}"
sleep 2
/usr/bin/open -a TextEdit "${RIGHT_DOC}"

if ! wait_for_textedit_windows 3; then
    echo 'TextEdit windows did not become visible to WinMux' >&2
    cat "${WINDOW_SETUP_LOG}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    exit 1
fi

LEFT_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'left-reference.rtf')"
MAIN_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'main-work.rtf')"
RIGHT_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'right-comms.rtf')"

if [ -z "${LEFT_ID}" ] || [ -z "${MAIN_ID}" ] || [ -z "${RIGHT_ID}" ]; then
    echo 'Could not resolve all TextEdit window ids' >&2
    cat "${WINDOW_SETUP_LOG}" >&2 || true
    exit 1
fi

setup_window_zone "${LEFT_ID}" 'left-reference.rtf' Work main
setup_window_zone "${MAIN_ID}" 'main-work.rtf' Work main
setup_window_zone "${RIGHT_ID}" 'right-comms.rtf' Work main
strict_move_window_zone "${LEFT_ID}" 'left-reference.rtf' Reference main left
sleep 1
strict_move_window_zone "${RIGHT_ID}" 'right-comms.rtf' Comms main right

echo '$ winmux list-monitors --format ...'
write_monitor_log "${MONITOR_BEFORE_LOG}"
require_zone_log "${MONITOR_BEFORE_LOG}"
refresh_window_log "${WINDOW_BEFORE_LOG}"
all_windows_in_expected_zones "${WINDOW_BEFORE_LOG}"
write_workspace_log "${WORKSPACE_BEFORE_LOG}"
sleep 2

{
    echo '$ edit winmux.toml'
    echo '[[zones]] widths: left=0.20 main=0.60 right=0.20'
    /bin/cp "${RELOAD_CONFIG}" "${CONFIG}"
    echo
    echo '$ winmux reload-config'
    "${CLI}" reload-config
} | tee "${RELOAD_LOG}"

for _ in $(seq 1 30); do
    write_monitor_log "${MONITOR_AFTER_LOG}"
    if [ "$(field_for_zone "${MONITOR_AFTER_LOG}" main left)" != "$(field_for_zone "${MONITOR_BEFORE_LOG}" main left)" ]; then
        break
    fi
    sleep 1
done

require_zone_log "${MONITOR_AFTER_LOG}"
assert_geometry_changed left width
assert_geometry_changed main left
assert_geometry_changed main width
assert_geometry_changed right left
assert_geometry_changed right width

for _ in $(seq 1 30); do
    refresh_window_log "${WINDOW_AFTER_LOG}"
    if all_windows_in_expected_zones "${WINDOW_AFTER_LOG}"; then
        break
    fi
    sleep 1
done

assert_window_zone "${WINDOW_AFTER_LOG}" 'left-reference.rtf' left
assert_window_zone "${WINDOW_AFTER_LOG}" 'main-work.rtf' main
assert_window_zone "${WINDOW_AFTER_LOG}" 'right-comms.rtf' right
write_workspace_log "${WORKSPACE_AFTER_LOG}"

cat \
    "${MONITOR_BEFORE_LOG}" "${WINDOW_BEFORE_LOG}" "${WORKSPACE_BEFORE_LOG}" \
    "${RELOAD_LOG}" \
    "${MONITOR_AFTER_LOG}" "${WINDOW_AFTER_LOG}" "${WORKSPACE_AFTER_LOG}" \
    >"${CLI_LOG}"

{
    echo 'WinMux Slice 3: stable zone viewport identity'
    echo
    echo 'Initial zone geometry:'
    cat "${MONITOR_BEFORE_LOG}"
    echo
    echo 'Reloaded zone geometry:'
    cat "${MONITOR_AFTER_LOG}"
    echo
    echo 'Windows before reload:'
    cat "${WINDOW_BEFORE_LOG}"
    echo
    echo 'Windows after reload:'
    cat "${WINDOW_AFTER_LOG}"
    echo
    echo 'PASS: config reload changed zone geometry while labeled windows stayed bound to left/main/right zone ids.'
} >"${PROOF}"

echo
cat "${PROOF}"
sleep 5
printf 'result=success\n' >"${DONE}"
