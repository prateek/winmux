#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE41_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE41_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE41_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-41-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_SOURCE_APP="${ARTIFACTS_DIR}/slice-41-self-test-bin/WinMuxApp"
    export WINMUX_E2E_SOURCE_CLI="${ARTIFACTS_DIR}/slice-41-self-test-bin/winmux"
    export WINMUX_E2E_SLICE41_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
APP_DEFAULT_CONFIG="${BIN_DIR}/default-config.toml"
STARTER_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
USER_CONFIG_DIR="${HOME}/.config/winmux"
USER_CONFIG="${USER_CONFIG_DIR}/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-41-zone-affinity-beta"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice41-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice41-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice41"
LAUNCH_PLIST="/tmp/winmux-e2e-slice41.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice41.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-41-setup.log"
CONFIG_INITIAL_COPY="${ARTIFACTS_DIR}/logs/slice-41-user-config-initial.toml"
CONFIG_RELOADED_COPY="${ARTIFACTS_DIR}/logs/slice-41-user-config-reloaded.toml"
WINDOW_READY_LOG="${ARTIFACTS_DIR}/logs/slice-41-ready-windows.log"
WINDOW_AFTER_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-comms.log"
WINDOW_AFTER_REFERENCE_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-reference.log"
WINDOW_AFTER_WORK_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-work.log"
WINDOW_AFTER_NOMATCH_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-no-match.log"
WINDOW_AFTER_DISABLED_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-disabled.log"
WINDOW_AFTER_RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-reload.log"
WINDOW_AFTER_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-relaunch.log"
FINAL_VISUAL_READY_LOG="${ARTIFACTS_DIR}/logs/slice-41-final-visual-ready.log"
WINDOW_FINAL_LOG="${ARTIFACTS_DIR}/logs/slice-41-final-windows.log"
ZONES_FINAL_LOG="${ARTIFACTS_DIR}/logs/slice-41-final-zones.log"
CONFIG_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-41-config-path.log"
RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-41-reload-config.log"
RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-41-relaunch.log"
APPLY_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-41-apply-zone-bindings.log"
ZONES_AFTER_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-41-after-apply-zone-bindings-zones.log"
DEBUG_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-comms.log"
DEBUG_WORK_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-work.log"
DEBUG_NOMATCH_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-no-match.log"
DEBUG_DISABLED_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-disabled.log"
DEBUG_RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-reload.log"
DEBUG_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-41-debug-relaunch.log"
ROUTING_LOG="${ARTIFACTS_DIR}/logs/slice-41-routing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-41-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-41-command-timing.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-41-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-41-zone-affinity-beta-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-affinity-beta-docs"
READY_DOC="${DOC_DIR}/slice-41-affinity-ready.rtf"
COMMS_DOC="${DOC_DIR}/slice41-mail-comms.rtf"
REFERENCE_DOC="${DOC_DIR}/slice41-reference-browser.rtf"
WORK_DOC="${DOC_DIR}/slice41-work-editor.rtf"
NOMATCH_DOC="${DOC_DIR}/slice41-nomatch.rtf"
DISABLED_DOC="${DOC_DIR}/slice41-disabled-comms.rtf"
RELOAD_DOC="${DOC_DIR}/slice41-reload-reference.rtf"
RELAUNCH_DOC="${DOC_DIR}/slice41-relaunch-comms.rtf"
DIAGNOSTIC_DOC="${DOC_DIR}/slice-41-affinity-diagnostics.rtf"
FINAL_DOC="${DOC_DIR}/slice-41-affinity-final.rtf"

uid="$(/usr/bin/id -u)"
mutation_marked=0

# shellcheck disable=SC1091
# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
source "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

mark_mutation_once() {
    if [ "${mutation_marked}" = "0" ]; then
        echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
        mutation_marked=1
    fi
}

rtf_escape_line() {
    /usr/bin/sed -e 's/\\/\\\\/g' -e 's/{/\\{/g' -e 's/}/\\}/g'
}

write_text_doc() {
    local source_path="$1"
    local title="$2"
    local out_path="$3"
    {
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs48\\b %s\\b0\\par\\f1\\fs25\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

write_doc() {
    local path="$1"
    local headline="$2"
    local body="$3"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs80 ${headline}\par\fs36 ${body}\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_launch_plist() {
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
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>WINMUX_E2E_SKIP_PERMISSION_PROMPTS</key>
        <string>1</string>
        <key>WINMUX_E2E_STARTUP_TRACE</key>
        <string>${STARTUP_TRACE_LOCAL}</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>${HOME}</string>
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
}

assert_launch_plist_is_normal_path() {
    if /usr/bin/grep -F -- '--config-path' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 41 LaunchAgent must not pass --config-path'
    fi
    if /usr/bin/grep -F 'WINMUX_DEFAULT_CONFIG_PATH' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 41 LaunchAgent must not set WINMUX_DEFAULT_CONFIG_PATH'
    fi
    /usr/bin/grep -F "<string>${APP}</string>" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'Slice 41 LaunchAgent must launch the staged WinMuxApp executable'
}

launch_winmux_normal() {
    write_launch_plist
    assert_launch_plist_is_normal_path
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-41-zone-count.txt" 2>"${WAIT_ERR}"; then
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

refresh_window_log() {
    local path="$1"
    refresh_window_log_for_scope visible "${path}"
}

refresh_window_log_for_scope() {
    local scope="$1"
    local path="$2"
    "${CLI}" list-windows --workspace "${scope}" --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

refresh_all_window_log() {
    local path="$1"
    "${CLI}" list-windows --all \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

write_zones_log() {
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${ZONES_FINAL_LOG}" 2>>"${WAIT_ERR}"
}

write_zones_snapshot() {
    local path="$1"
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${path}" 2>>"${WAIT_ERR}"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local field="$3"
    /usr/bin/awk -F'|' -v title="${title}" -v field="${field}" '$2 == title {
        if (field == "id") { print $1; exit }
        if (field == "zone") { sub(/^zone=/, "", $3); print $3; exit }
        if (field == "workspace") { sub(/^workspace=/, "", $4); print $4; exit }
    }' "${path}"
}

window_id_for_title() {
    field_for_title "$1" "$2" id
}

zone_for_title() {
    field_for_title "$1" "$2" zone
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

assert_window_not_zone() {
    local path="$1"
    local title="$2"
    local rejected_zone="$3"
    local actual_zone
    actual_zone="$(zone_for_title "${path}" "${title}")"
    [ -n "${actual_zone}" ] || semantic_fail "${title} missing from ${path}"
    if [ "${actual_zone}" = "${rejected_zone}" ]; then
        echo "Expected ${title} not to be in zone ${rejected_zone}" >&2
        cat "${path}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi
}

assert_window_present_in_log() {
    local path="$1"
    local title="$2"
    [ -n "$(window_id_for_title "${path}" "${title}")" ] \
        || semantic_fail "${title} missing from ${path}"
}

wait_for_window_zone() {
    local title="$1"
    local expected_zone="$2"
    local path="$3"
    for _ in $(seq 1 60); do
        refresh_window_log "${path}"
        if [ "$(zone_for_title "${path}" "${title}")" = "${expected_zone}" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

wait_for_window_present() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_window_log "${path}"
        if [ -n "$(window_id_for_title "${path}" "${title}")" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

debug_window_by_title() {
    local windows_log="$1"
    local title="$2"
    local debug_log="$3"
    local window_id
    window_id="$(window_id_for_title "${windows_log}" "${title}")"
    [ -n "${window_id}" ] || semantic_fail "Missing window id for ${title}"
    {
        echo "$ winmux debug-windows --window-id ${window_id}"
        "${CLI}" debug-windows --window-id "${window_id}"
    } >"${debug_log}" 2>>"${WAIT_ERR}"
}

append_command_log() {
    local label="$1"
    local log_path="$2"
    {
        echo
        echo "## ${label}"
        cat "${log_path}"
    } >>"${ROUTING_LOG}"
}

write_ready_doc() {
    local visible_ready="${ARTIFACTS_DIR}/logs/slice-41-visible-ready.txt"
    {
        echo 'Slice 41 beta affinity proof'
        echo
        echo "Normal user config: ${USER_CONFIG}"
        echo 'Launch path: WinMuxApp with no --config-path and no WINMUX_DEFAULT_CONFIG_PATH'
        echo
        echo 'Config excerpt:'
        echo "[[zone-bindings]] left -> reference, main -> work, right -> comms"
        echo "[[zone-affinities]] zone='Comms' if.app-id='com.apple.TextEdit' if.window-title-regex-substring='slice41-mail'"
        echo "[[zone-affinities]] zone='Reference' if.app-name-regex-substring='TextEdit' if.window-title-regex-substring='slice41-reference'"
        echo "[[zone-affinities]] zone='Work' if.window-title-regex-substring='slice41-work' if.workspace='work'"
        echo "[[zone-affinities]] zone='Reference' if.app-id='com.apple.mail' if.window-title-regex-substring='slice41-nomatch'"
        echo "[[zone-affinities]] zone='Comms' if.window-title-regex-substring='slice41-disabled'"
        echo
        echo 'Commands shown in this recording:'
        echo 'winmux config --config-path'
        echo 'open -a TextEdit slice41-mail-comms.rtf'
        echo 'winmux debug-windows --window-id <matched>'
        echo 'winmux apply-zone-bindings'
        echo 'open -a TextEdit slice41-nomatch.rtf'
        echo 'winmux disable-zone Comms'
        echo 'winmux reload-config'
        echo 'relaunch WinMuxApp'
    } >"${visible_ready}"
    write_text_doc "${visible_ready}" 'Slice 41 routes windows by affinity rules' "${READY_DOC}"
}

write_diagnostic_doc() {
    local visible_diagnostic="${ARTIFACTS_DIR}/logs/slice-41-visible-diagnostics.txt"
    {
        echo 'Slice 41 diagnostics'
        echo
        echo '$ winmux debug-windows --window-id <matched>'
        echo 'WinMux.zone-affinities: matched=true, target=enabled/Comms'
        echo
        echo '$ winmux debug-windows --window-id <no-match>'
        echo 'failed-terms explain why the rule did not route the window'
        echo
        echo '$ winmux disable-zone Comms'
        echo '$ winmux debug-windows --window-id <disabled-target>'
        echo 'target.state=disabled; the window does not silently claim success'
    } >"${visible_diagnostic}"
    write_text_doc "${visible_diagnostic}" 'debug-windows explains match, no-match, and disabled target' "${DIAGNOSTIC_DOC}"
}

write_final_doc() {
    local visible_final="${ARTIFACTS_DIR}/logs/slice-41-visible-final.txt"
    {
        echo 'Slice 41 result'
        echo
        echo '$ winmux reload-config'
        echo 'slice41-reload-reference.rtf routes after the config swap'
        echo
        echo 'Action: relaunch WinMuxApp'
        echo 'slice41-relaunch-comms.rtf routes after restart'
        echo
        echo "$ winmux list-windows --all"
        cat "${WINDOW_FINAL_LOG}"
        echo
        echo "$ winmux list-zones"
        cat "${ZONES_FINAL_LOG}"
    } >"${visible_final}"
    write_text_doc "${visible_final}" 'Affinity routing survives reload and relaunch' "${FINAL_DOC}"
}

write_reloaded_config() {
    cat >"${USER_CONFIG}" <<'TOML'
config-version = 2
auto-reload-config = false
persistent-workspaces = []

[[zones]]
monitor = 1
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[[zone-bindings]]
zone = 'left'
workspace = 'reference'

[[zone-bindings]]
zone = 'main'
workspace = 'work'

[[zone-bindings]]
zone = 'right'
workspace = 'comms'

[[zone-affinities]]
zone = 'Comms'
if.app-id = 'com.apple.TextEdit'
if.window-title-regex-substring = 'slice41-mail'
fail-if-noop = true

[[zone-affinities]]
zone = 'Reference'
if.app-name-regex-substring = 'TextEdit'
if.window-title-regex-substring = 'slice41-reference'
fail-if-noop = true

[[zone-affinities]]
zone = 'Work'
if.window-title-regex-substring = 'slice41-work'
if.workspace = 'work'

[[zone-affinities]]
zone = 'Reference'
if.app-id = 'com.apple.mail'
if.window-title-regex-substring = 'slice41-nomatch'

[[zone-affinities]]
zone = 'Comms'
if.window-title-regex-substring = 'slice41-disabled'
fail-if-noop = true

[[zone-affinities]]
zone = 'Reference'
if.window-title-regex-substring = 'slice41-reload'
fail-if-noop = true

[[zone-affinities]]
zone = 'Comms'
if.window-title-regex-substring = 'slice41-relaunch'
fail-if-noop = true

[workspace-sidebar]
enabled = false
TOML
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_INITIAL_COPY}" "${CONFIG_RELOADED_COPY}" "${WINDOW_READY_LOG}" \
        "${WINDOW_AFTER_COMMS_LOG}" "${WINDOW_AFTER_REFERENCE_LOG}" "${WINDOW_AFTER_WORK_LOG}" \
        "${WINDOW_AFTER_NOMATCH_LOG}" "${WINDOW_AFTER_DISABLED_LOG}" "${WINDOW_AFTER_RELOAD_LOG}" \
        "${WINDOW_AFTER_RELAUNCH_LOG}" "${FINAL_VISUAL_READY_LOG}" "${WINDOW_FINAL_LOG}" "${ZONES_FINAL_LOG}" "${CONFIG_PATH_LOG}" \
        "${RELOAD_LOG}" "${RELAUNCH_LOG}" "${APPLY_BINDINGS_LOG}" "${ZONES_AFTER_BINDINGS_LOG}" \
        "${DEBUG_COMMS_LOG}" "${DEBUG_WORK_LOG}" "${DEBUG_NOMATCH_LOG}" \
        "${DEBUG_DISABLED_LOG}" "${DEBUG_RELOAD_LOG}" "${DEBUG_RELAUNCH_LOG}" "${ROUTING_LOG}" \
        "${CLI_LOG}" "${TIMING_LOG}" "${WAIT_ERR}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" \
        "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${USER_CONFIG_DIR}" "${BIN_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${APP_DEFAULT_CONFIG}"
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_INITIAL_COPY}"

    for expected in '[[zones]]' '[[zone-bindings]]' '[[zone-affinities]]' "workspace = 'work'" "if.app-id = 'com.apple.TextEdit'" "if.app-name-regex-substring = 'TextEdit'" "if.workspace = 'work'"; do
        /usr/bin/grep -F "$expected" "${USER_CONFIG}" >/dev/null \
            || semantic_fail "Slice 41 user config missing ${expected}"
    done

    write_ready_doc
    write_doc "${COMMS_DOC}" 'MAIL / COMMS' 'slice41-mail-comms should route to Comms by bundle id plus title'
    write_doc "${REFERENCE_DOC}" 'REFERENCE' 'slice41-reference-browser should route to Reference by app-name regex plus title'
    write_doc "${WORK_DOC}" 'WORK EDITOR' 'slice41-work-editor should match title plus workspace=work'
    write_doc "${NOMATCH_DOC}" 'NO MATCH' 'slice41-nomatch should stay put and explain failed terms'
    write_doc "${DISABLED_DOC}" 'DISABLED COMMS' 'slice41-disabled-comms targets Comms after the zone is disabled'
    write_doc "${RELOAD_DOC}" 'RELOAD ROUTE' 'slice41-reload-reference should route only after reload-config'
    write_doc "${RELAUNCH_DOC}" 'RELAUNCH ROUTE' 'slice41-relaunch-comms should route after WinMux relaunch'
    /usr/bin/open -a TextEdit "${READY_DOC}"
    sleep 3

    {
        echo 'WinMux Slice 41: beta-hardened zone affinities'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "User config: ${USER_CONFIG}"
        echo 'Launch: normal app path; no --config-path; no WINMUX_DEFAULT_CONFIG_PATH'
        echo 'Bindings: [[zone-bindings]] left=reference, main=work, right=comms via apply-zone-bindings'
        echo 'Rules: app-id+title -> Comms; app-name+title -> Reference; title+workspace -> Work; no-match; disabled target; reload; relaunch'
        echo 'Non-claim: no ML placement and no automatic rebinding of already-open windows'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

run_proof() {
    : >"${ROUTING_LOG}"
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"

    sleep_until_recording_offset 8 18 "Run: WinMuxApp"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ WinMuxApp'
        launch_winmux_normal
    } | tee -a "${CLI_LOG}" "${ROUTING_LOG}"
    capture_guest_screenshot "02-normal-launch-slice-41"

    sleep_until_recording_offset 18 28 "Run: winmux config --config-path"
    echo "config-path-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --config-path'
        "${CLI}" config --config-path
    } >"${CONFIG_PATH_LOG}" 2>>"${WAIT_ERR}"
    /usr/bin/grep -F "${USER_CONFIG}" "${CONFIG_PATH_LOG}" >/dev/null \
        || semantic_fail 'config --config-path did not report normal user config'
    append_command_log 'config-path' "${CONFIG_PATH_LOG}"

    sleep_until_recording_offset 28 44 "Run: open -a TextEdit slice41-mail-comms.rtf"
    echo "open-comms-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    {
        echo '$ open -a TextEdit slice41-mail-comms.rtf'
        /usr/bin/open -a TextEdit "${COMMS_DOC}"
    } | tee "${ARTIFACTS_DIR}/logs/slice-41-open-comms.log" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_zone 'slice41-mail-comms.rtf' right "${WINDOW_AFTER_COMMS_LOG}" \
        || semantic_fail 'slice41-mail-comms.rtf did not route to Comms/right'
    debug_window_by_title "${WINDOW_AFTER_COMMS_LOG}" 'slice41-mail-comms.rtf' "${DEBUG_COMMS_LOG}"
    append_command_log 'after-comms' "${WINDOW_AFTER_COMMS_LOG}"
    append_command_log 'debug-comms' "${DEBUG_COMMS_LOG}"
    capture_guest_screenshot "03-routed-comms-slice-41"

    sleep_until_recording_offset 44 56 "Run: winmux apply-zone-bindings; open Reference and Work windows"
    echo "open-reference-work-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    {
        echo '$ winmux apply-zone-bindings'
        "${CLI}" apply-zone-bindings
    } | tee "${APPLY_BINDINGS_LOG}" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    for _ in $(seq 1 30); do
        write_zones_snapshot "${ZONES_AFTER_BINDINGS_LOG}"
        if /usr/bin/grep -F 'zone=main|name=Work|workspace=work|' "${ZONES_AFTER_BINDINGS_LOG}" >/dev/null; then
            break
        fi
        sleep 1
    done
    /usr/bin/grep -F 'zone=left|name=Reference|workspace=reference|' "${ZONES_AFTER_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'apply-zone-bindings did not activate workspace=reference in Reference/left'
    /usr/bin/grep -F 'zone=main|name=Work|workspace=work|' "${ZONES_AFTER_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'apply-zone-bindings did not activate workspace=work in Work/main'
    /usr/bin/grep -F 'zone=right|name=Comms|workspace=comms|' "${ZONES_AFTER_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'apply-zone-bindings did not activate workspace=comms in Comms/right'
    append_command_log 'after-apply-zone-bindings' "${ZONES_AFTER_BINDINGS_LOG}"
    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    {
        echo '$ open -a TextEdit slice41-reference-browser.rtf'
        /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    } | tee "${ARTIFACTS_DIR}/logs/slice-41-open-reference.log" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_zone 'slice41-reference-browser.rtf' left "${WINDOW_AFTER_REFERENCE_LOG}" \
        || semantic_fail 'slice41-reference-browser.rtf did not route to Reference/left'
    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    {
        echo '$ open -a TextEdit slice41-work-editor.rtf'
        /usr/bin/open -a TextEdit "${WORK_DOC}"
    } | tee "${ARTIFACTS_DIR}/logs/slice-41-open-work.log" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_zone 'slice41-work-editor.rtf' main "${WINDOW_AFTER_WORK_LOG}" \
        || semantic_fail 'slice41-work-editor.rtf did not remain in Work/main'
    debug_window_by_title "${WINDOW_AFTER_WORK_LOG}" 'slice41-work-editor.rtf' "${DEBUG_WORK_LOG}"
    /usr/bin/grep -F "window-title-regex-substring matched title 'slice41-work-editor.rtf'" "${DEBUG_WORK_LOG}" >/dev/null \
        || semantic_fail 'Work debug output missing title matcher success'
    /usr/bin/grep -F "workspace matched 'work'" "${DEBUG_WORK_LOG}" >/dev/null \
        || semantic_fail 'Work debug output missing workspace matcher success'
    if /usr/bin/grep -F "workspace expected 'work'" "${DEBUG_WORK_LOG}" >/dev/null; then
        semantic_fail 'Work debug output still reports workspace mismatch'
    fi
    append_command_log 'after-reference' "${WINDOW_AFTER_REFERENCE_LOG}"
    append_command_log 'after-work' "${WINDOW_AFTER_WORK_LOG}"
    append_command_log 'debug-work' "${DEBUG_WORK_LOG}"

    sleep_until_recording_offset 56 72 "Run: open no-match and debug failed terms"
    echo "no-match-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ open -a TextEdit slice41-nomatch.rtf'
        /usr/bin/open -a TextEdit "${NOMATCH_DOC}"
    } | tee "${ARTIFACTS_DIR}/logs/slice-41-open-no-match.log" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_present 'slice41-nomatch.rtf' "${WINDOW_AFTER_NOMATCH_LOG}" \
        || semantic_fail 'slice41-nomatch.rtf did not appear'
    debug_window_by_title "${WINDOW_AFTER_NOMATCH_LOG}" 'slice41-nomatch.rtf' "${DEBUG_NOMATCH_LOG}"
    /usr/bin/grep -F '"failed-terms"' "${DEBUG_NOMATCH_LOG}" >/dev/null \
        || semantic_fail 'no-match debug output missing failed-terms'
    append_command_log 'after-no-match' "${WINDOW_AFTER_NOMATCH_LOG}"
    append_command_log 'debug-no-match' "${DEBUG_NOMATCH_LOG}"

    sleep_until_recording_offset 72 88 "Run: winmux disable-zone Comms; open disabled target"
    echo "disabled-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux disable-zone Comms'
        "${CLI}" disable-zone Comms
        echo '$ open -a TextEdit slice41-disabled-comms.rtf'
        /usr/bin/open -a TextEdit "${DISABLED_DOC}"
    } | tee "${ARTIFACTS_DIR}/logs/slice-41-disabled-actions.log" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_present 'slice41-disabled-comms.rtf' "${WINDOW_AFTER_DISABLED_LOG}" \
        || semantic_fail 'slice41-disabled-comms.rtf did not appear'
    assert_window_not_zone "${WINDOW_AFTER_DISABLED_LOG}" 'slice41-disabled-comms.rtf' right
    debug_window_by_title "${WINDOW_AFTER_DISABLED_LOG}" 'slice41-disabled-comms.rtf' "${DEBUG_DISABLED_LOG}"
    /usr/bin/grep -E '"state"[[:space:]]*:[[:space:]]*"disabled"' "${DEBUG_DISABLED_LOG}" >/dev/null \
        || semantic_fail 'disabled-target debug output missing state=disabled'
    /usr/bin/grep -F 'target zone is hidden' "${DEBUG_DISABLED_LOG}" >/dev/null \
        || semantic_fail 'disabled-target debug output missing hidden-zone reason'
    append_command_log 'after-disabled' "${WINDOW_AFTER_DISABLED_LOG}"
    append_command_log 'debug-disabled' "${DEBUG_DISABLED_LOG}"
    write_diagnostic_doc
    /usr/bin/open -a TextEdit "${DIAGNOSTIC_DOC}"
    capture_guest_screenshot "04-diagnostics-slice-41"
    "${CLI}" enable-zone Comms >>"${CLI_LOG}" 2>>"${WAIT_ERR}"

    sleep_until_recording_offset 88 106 "Run: winmux reload-config; open reload route"
    echo "reload-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_reloaded_config
    /bin/cp "${USER_CONFIG}" "${CONFIG_RELOADED_COPY}"
    {
        echo '$ winmux reload-config'
        "${CLI}" reload-config
        echo '$ open -a TextEdit slice41-reload-reference.rtf'
        /usr/bin/open -a TextEdit "${RELOAD_DOC}"
    } >"${RELOAD_LOG}" 2>>"${WAIT_ERR}"
    cat "${RELOAD_LOG}" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_zone 'slice41-reload-reference.rtf' left "${WINDOW_AFTER_RELOAD_LOG}" \
        || semantic_fail 'slice41-reload-reference.rtf did not route to Reference/left after reload'
    debug_window_by_title "${WINDOW_AFTER_RELOAD_LOG}" 'slice41-reload-reference.rtf' "${DEBUG_RELOAD_LOG}"
    append_command_log 'after-reload' "${WINDOW_AFTER_RELOAD_LOG}"
    append_command_log 'debug-reload' "${DEBUG_RELOAD_LOG}"

    sleep_until_recording_offset 106 124 "Action: relaunch WinMuxApp; open relaunch route"
    echo "relaunch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ launchctl bootout/kickstart WinMuxApp'
        /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
        echo 'stopped=yes'
        launch_winmux_normal
        echo '$ open -a TextEdit slice41-relaunch-comms.rtf'
        /usr/bin/open -a TextEdit "${RELAUNCH_DOC}"
    } >"${RELAUNCH_LOG}" 2>>"${WAIT_ERR}"
    cat "${RELAUNCH_LOG}" | tee -a "${CLI_LOG}" "${ROUTING_LOG}" >/dev/null
    wait_for_window_zone 'slice41-relaunch-comms.rtf' right "${WINDOW_AFTER_RELAUNCH_LOG}" \
        || semantic_fail 'slice41-relaunch-comms.rtf did not route to Comms/right after relaunch'
    debug_window_by_title "${WINDOW_AFTER_RELAUNCH_LOG}" 'slice41-relaunch-comms.rtf' "${DEBUG_RELAUNCH_LOG}"
    append_command_log 'after-relaunch' "${WINDOW_AFTER_RELAUNCH_LOG}"
    append_command_log 'debug-relaunch' "${DEBUG_RELAUNCH_LOG}"
    capture_guest_screenshot "05-after-relaunch-slice-41"

    sleep_until_recording_offset 124 144 "Run: winmux list-windows --all; winmux list-zones"
    echo "final-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    refresh_all_window_log "${WINDOW_FINAL_LOG}"
    write_zones_log
    cat "${WINDOW_FINAL_LOG}" "${ZONES_FINAL_LOG}" >>"${CLI_LOG}"
    write_final_doc
    /usr/bin/open -a TextEdit "${FINAL_DOC}"
    wait_for_window_present 'slice-41-affinity-final.rtf' "${FINAL_VISUAL_READY_LOG}" \
        || semantic_fail 'slice-41-affinity-final.rtf did not become visible before final screenshot'
    sleep 2
    capture_guest_screenshot "06-final-affinity-proof-slice-41"

    # The per-beat logs above prove each route at the time it happens. The final
    # all-workspaces log is an audit that those windows remain discoverable after
    # later workspace binding, reload, and relaunch changes.
    assert_window_present_in_log "${WINDOW_FINAL_LOG}" 'slice41-mail-comms.rtf'
    assert_window_present_in_log "${WINDOW_FINAL_LOG}" 'slice41-reference-browser.rtf'
    assert_window_present_in_log "${WINDOW_FINAL_LOG}" 'slice41-work-editor.rtf'
    assert_window_present_in_log "${WINDOW_FINAL_LOG}" 'slice41-disabled-comms.rtf'
    assert_window_present_in_log "${WINDOW_FINAL_LOG}" 'slice41-reload-reference.rtf'
    assert_window_zone "${WINDOW_FINAL_LOG}" 'slice41-relaunch-comms.rtf' right

    for debug_log in "${DEBUG_COMMS_LOG}" "${DEBUG_WORK_LOG}" "${DEBUG_NOMATCH_LOG}" "${DEBUG_DISABLED_LOG}" "${DEBUG_RELOAD_LOG}" "${DEBUG_RELAUNCH_LOG}"; do
        /usr/bin/grep -F 'WinMux.zone-affinities' "${debug_log}" >/dev/null \
            || semantic_fail "debug output missing WinMux.zone-affinities: ${debug_log}"
    done
    for proof_phase_log in "${ROUTING_LOG}" "${CLI_LOG}" "${RELOAD_LOG}" "${RELAUNCH_LOG}"; do
        /usr/bin/grep -F '$ winmux move-node-to-zone' "${proof_phase_log}" >/dev/null \
            && semantic_fail "Slice 41 proof must not use manual move-node-to-zone: ${proof_phase_log}"
        /usr/bin/grep -F 'Run: winmux move-node-to-zone' "${proof_phase_log}" >/dev/null \
            && semantic_fail "Slice 41 proof must not annotate manual move-node-to-zone: ${proof_phase_log}"
    done

    {
        echo 'WinMux Slice 41: beta-hardened app and window affinities'
        echo
        echo 'PASS: zone-affinities routed representative windows by app id, app-name regex, title regex, and workspace; debug-windows explained match, no-match, disabled target, reload, and relaunch behavior.'
        echo "normal-config=${USER_CONFIG}"
        echo "launch-plist=${LAUNCH_PLIST_COPY}"
        echo 'manual-move-node-to-zone-during-proof=no'
        echo 'workspace-bindings=applied reference/work/comms before title+workspace match'
        echo 'matched-window=slice41-mail-comms.rtf zone=right'
        echo 'app-name-window=slice41-reference-browser.rtf zone=left'
        echo 'workspace-window=slice41-work-editor.rtf zone=main workspace-matcher=matched-title-and-workspace'
        echo 'no-match-window=slice41-nomatch.rtf failed-terms=yes'
        echo 'disabled-target-window=slice41-disabled-comms.rtf target=disabled'
        echo 'reload-window=slice41-reload-reference.rtf zone=left'
        echo 'relaunch-window=slice41-relaunch-comms.rtf zone=right'
        echo 'non-claim=no ML placement, no automatic rebinding of already-open windows, no durable tab-group identity'
    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

write_fake_cli() {
    cat >"${SOURCE_CLI}" <<'CLI'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    config)
        if [ "${2:-}" = "--config-path" ]; then echo "${HOME}/.config/winmux/winmux.toml"; exit 0; fi
        ;;
	    list-zones)
	        if [ "${2:-}" = "--count" ]; then echo 3; exit 0; fi
	        echo 'zone=left|name=Reference|workspace=reference|layout=columns|enabled=true|left=0|width=860|physical=1'
	        echo 'zone=main|name=Work|workspace=work|layout=columns|enabled=true|left=860|width=1720|physical=1'
	        echo 'zone=right|name=Comms|workspace=comms|layout=columns|enabled=true|left=2580|width=860|physical=1'
	        exit 0
	        ;;
	    list-windows)
	        if [ "${2:-}" = "--all" ]; then
	            for arg in "$@"; do
	                case "$arg" in
	                    --app-bundle-id|--app-id|--focused|--monitor|--pid|--workspace)
	                        echo '--all conflicts with "filtering" flags. Please use '\''--monitor all'\'' instead of '\''--all'\'' alias' >&2
	                        exit 64
	                        ;;
	                esac
	            done
	        fi
	        echo '1|slice41-mail-comms.rtf|zone=right|workspace=comms|monitor=Comms'
	        echo '2|slice41-reference-browser.rtf|zone=left|workspace=reference|monitor=Reference'
	        echo '3|slice41-work-editor.rtf|zone=main|workspace=work|monitor=Work'
	        exit 0
	        ;;
	    debug-windows)
	        echo 'com.apple.TextEdit.1 ||| {"WinMux.zone-affinities":[{"matched":true,"target":{"state":"enabled"}},{"matched":false,"matcher":{"failed-terms":["app-id expected"]}},{"matched":true,"target":{"state":"disabled","reason":"target zone is hidden"}}]}'
	        exit 0
        ;;
    reload-config|disable-zone|enable-zone|focus-zone|apply-zone-bindings)
        echo "ok: $*"
        exit 0
        ;;
esac
exit 64
CLI
    chmod +x "${SOURCE_CLI}"
}

write_self_test_config() {
    mkdir -p "${ARTIFACTS_DIR}/config"
    cat >"${STARTER_CONFIG}" <<'TOML'
config-version = 2
auto-reload-config = false
persistent-workspaces = []
[[zones]]
monitor = 1
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]
[[zone-bindings]]
zone = 'left'
workspace = 'reference'
[[zone-bindings]]
zone = 'main'
workspace = 'work'
[[zone-bindings]]
zone = 'right'
workspace = 'comms'
[[zone-affinities]]
zone = 'Comms'
if.app-id = 'com.apple.TextEdit'
if.window-title-regex-substring = 'slice41-mail'
[[zone-affinities]]
zone = 'Reference'
if.app-name-regex-substring = 'TextEdit'
if.window-title-regex-substring = 'slice41-reference'
[[zone-affinities]]
zone = 'Work'
if.window-title-regex-substring = 'slice41-work'
if.workspace = 'work'
TOML
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots" "$(dirname "${SOURCE_APP}")" "$(dirname "${SOURCE_CLI}")" "${DOC_DIR}" "${USER_CONFIG_DIR}" "${BIN_DIR}"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${SOURCE_APP}"
    chmod +x "${SOURCE_APP}"
    write_fake_cli
    write_self_test_config
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${APP_DEFAULT_CONFIG}"
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_INITIAL_COPY}"
    write_launch_plist
    assert_launch_plist_is_normal_path
    write_ready_doc
    write_reloaded_config
    /bin/cp "${USER_CONFIG}" "${CONFIG_RELOADED_COPY}"
    grep -F "if.window-title-regex-substring = 'slice41-reload'" "${CONFIG_RELOADED_COPY}" >/dev/null \
        || semantic_fail 'self-test reloaded config missing reload affinity'
    {
        echo '$ winmux config --config-path'
        "${CLI}" config --config-path
    } >"${CONFIG_PATH_LOG}"
    {
        echo '$ winmux debug-windows --window-id 1'
        "${CLI}" debug-windows --window-id 1
    } >"${DEBUG_COMMS_LOG}"
	    grep -F 'WinMux.zone-affinities' "${DEBUG_COMMS_LOG}" >/dev/null \
	        || semantic_fail 'self-test debug output missing zone-affinities'
	    refresh_all_window_log "${WINDOW_FINAL_LOG}"
	    grep -F 'slice41-work-editor.rtf|zone=main|workspace=work' "${WINDOW_FINAL_LOG}" >/dev/null \
	        || semantic_fail 'self-test final all-window audit did not use valid list-windows --all output'
	    {
	        echo 'PASS: self-test validated normal launch plist, user config, reload config, and debug affinity vocabulary.'
	    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
    printf 'result=success\n'
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        run_proof
        ;;
    self-test)
        self_test_slice
        ;;
    *)
        echo "Unknown Slice 41 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
