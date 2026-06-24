#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice4-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice4-startup.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-4-cli.log"
ZONE_LOG="${ARTIFACTS_DIR}/logs/slice-4-zones.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-4-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-4-windows-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-4-windows-setup.log"
FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-4-focus-zone.log"
MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-4-move-node-to-zone.log"
FOCUS_MONITOR_LOG="${ARTIFACTS_DIR}/logs/slice-4-focus-monitor-compat.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
DONE="${ARTIFACTS_DIR}/logs/slice-4-zone-commands.done"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-4-cli-wait.err"
PROOF="${ARTIFACTS_DIR}/slice-4-zone-commands-proof.txt"
READY_SCREENSHOT="${ARTIFACTS_DIR}/screenshots/01-ready-slice-4.png"

ZONE_DOC_DIR="${HOME}/winmux-e2e/zone-command-docs"
LEFT_DOC="${ZONE_DOC_DIR}/left-reference.rtf"
MAIN_DOC="${ZONE_DOC_DIR}/main-work.rtf"
RIGHT_DOC="${ZONE_DOC_DIR}/right-comms.rtf"
MOVE_DOC="${ZONE_DOC_DIR}/move-demo.rtf"
LAUNCH_LABEL="local.winmux.e2e.slice4"
LAUNCH_PLIST="/tmp/winmux-e2e-slice4.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice4.plist"

rm -f \
    "${DONE}" "${CLI_LOG}" "${ZONE_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
    "${WINDOW_SETUP_LOG}" "${FOCUS_LOG}" "${MOVE_LOG}" "${FOCUS_MONITOR_LOG}" \
    "${WAIT_ERR}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
    "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
    "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" "${READY_SCREENSHOT}"
rm -rf "${ZONE_DOC_DIR}"

echo 'WinMux Slice 4: zone commands and selectors'
echo 'Environment: config-backed zones, command workflow proof'
echo
echo "Source App: ${SOURCE_APP}"
echo "Source CLI: ${SOURCE_CLI}"
echo "App: ${APP}"
echo "CLI: ${CLI}"
echo "Config: ${CONFIG}"
echo

test -x "${SOURCE_APP}"
test -x "${SOURCE_CLI}"
test -f "${CONFIG}"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}" "${ZONE_DOC_DIR}"
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

write_zone_doc "${LEFT_DOC}" 'REFERENCE' 'Left zone' 'focus-zone Reference'
write_zone_doc "${MAIN_DOC}" 'WORK' 'Main zone' 'focus-zone Work'
write_zone_doc "${RIGHT_DOC}" 'COMMS' 'Right zone' 'move-node-to-zone Comms'
write_zone_doc "${MOVE_DOC}" 'MOVE DEMO' 'Starts in Work' 'moves to Comms with --fail-if-noop'

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
    if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-4-zone-count.txt" 2>"${WAIT_ERR}"; then
        break
    fi
    sleep 1
done

if ! "${CLI}" list-zones --count >/tmp/winmux-slice-4-count 2>>"${WAIT_ERR}"; then
    echo 'WinMux CLI did not become ready' >&2
    cat "${LAUNCH_STATUS}" >&2 || true
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    cat "${APP_LOG}" >&2 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
    cat "${STARTUP_TRACE}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    exit 1
fi

write_zone_log() {
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        | tee "${ZONE_LOG}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --monitor all --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

focused_zone() {
    "${CLI}" list-workspaces --focused --format '%{monitor-zone-id}' | /usr/bin/tail -1
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

emit_focused_zone() {
    local label="$1"
    local expected="$2"
    local actual
    actual="$(focused_zone)"
    if [ "${actual}" != "${expected}" ]; then
        echo "Expected ${label}=${expected}, got ${actual:-missing}" >&2
        exit 1
    fi
    printf '%s=%s\n' "${label}" "${actual}"
}

require_focused_zone() {
    local expected="$1"
    local actual
    actual="$(focused_zone)"
    if [ "${actual}" != "${expected}" ]; then
        echo "Expected focused-zone=${expected}, got ${actual:-missing}" >&2
        exit 1
    fi
}

write_zone_log
grep -F 'zone=left|name=Reference|' "${ZONE_LOG}" >/dev/null
grep -F 'zone=main|name=Work|' "${ZONE_LOG}" >/dev/null
grep -F 'zone=right|name=Comms|' "${ZONE_LOG}" >/dev/null

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
/usr/sbin/screencapture -x -D"${GUEST_DISPLAY_ID}" "${READY_SCREENSHOT}" || true
test -s "${READY_SCREENSHOT}"

{
    echo '$ winmux focus-zone Reference'
    "${CLI}" focus-zone Reference
    emit_focused_zone reference-focused-zone left
} | tee "${FOCUS_LOG}"
sleep 4

{
    echo '$ winmux focus-zone Work'
    "${CLI}" focus-zone Work
    emit_focused_zone work-focused-zone main
} | tee -a "${FOCUS_LOG}"
sleep 4

"${CLI}" focus --window-id "${MOVE_ID}"
before_move_zone="$(zone_for_title "${WINDOW_BEFORE_LOG}" 'move-demo.rtf')"
before_move_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'move-demo.rtf')"
{
    echo '$ winmux move-node-to-zone Comms --fail-if-noop'
    printf 'window-id-before=%s\n' "${MOVE_ID}"
    printf 'before-zone=%s\n' "${before_move_zone}"
    printf 'before-workspace=%s\n' "${before_move_workspace}"
    "${CLI}" move-node-to-zone Comms --fail-if-noop
} | tee "${MOVE_LOG}"

for _ in $(seq 1 30); do
    refresh_window_log "${WINDOW_AFTER_LOG}"
    if [ "$(zone_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')" = right ]; then
        break
    fi
    sleep 1
done

after_move_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
after_move_zone="$(zone_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
after_move_workspace="$(workspace_for_title "${WINDOW_AFTER_LOG}" 'move-demo.rtf')"
{
    printf 'window-id-after=%s\n' "${after_move_id}"
    printf 'after-zone=%s\n' "${after_move_zone}"
    printf 'after-workspace=%s\n' "${after_move_workspace}"
} | tee -a "${MOVE_LOG}"
[ "${MOVE_ID}" = "${after_move_id}" ]
[ "${before_move_zone}" = main ]
[ "${after_move_zone}" = right ]
[ "${before_move_workspace}" != "${after_move_workspace}" ]
sleep 5

{
    echo '$ winmux focus-monitor 1'
    "${CLI}" focus-monitor 1
    require_focused_zone main
    emit_focused_zone focused-zone main
    echo 'compat=physical-monitor-default-zone'
} | tee "${FOCUS_MONITOR_LOG}"
sleep 5

cat "${ZONE_LOG}" "${WINDOW_BEFORE_LOG}" "${FOCUS_LOG}" "${MOVE_LOG}" "${FOCUS_MONITOR_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

{
    echo 'WinMux Slice 4: zone commands and selectors'
    echo
    echo 'Zones:'
    cat "${ZONE_LOG}"
    echo
    echo 'Windows before command move:'
    cat "${WINDOW_BEFORE_LOG}"
    echo
    echo 'Focus-zone proof:'
    cat "${FOCUS_LOG}"
    echo
    echo 'Move-node-to-zone proof:'
    cat "${MOVE_LOG}"
    echo
    echo 'Physical monitor compatibility proof:'
    cat "${FOCUS_MONITOR_LOG}"
    echo
    echo 'Windows after command move:'
    cat "${WINDOW_AFTER_LOG}"
    echo
    echo 'PASS: focus-zone, move-node-to-zone, list-zones, and focus-monitor physical compatibility are visible and logged.'
} >"${PROOF}"

echo
cat "${PROOF}"
sleep 5
printf 'result=success\n' >"${DONE}"
