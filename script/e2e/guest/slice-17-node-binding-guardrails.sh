#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE17_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice17-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice17-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice17"
LAUNCH_PLIST="/tmp/winmux-e2e-slice17.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice17.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-17-node-binding-guardrails-setup.log"
BOARD_LOG="${ARTIFACTS_DIR}/logs/slice-17-live-state-board.log"
BOARD_FRESHNESS_LOG="${ARTIFACTS_DIR}/logs/slice-17-board-freshness.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-17-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-17-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-17-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-17-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-17-node-binding-guardrails.done"
PROOF="${ARTIFACTS_DIR}/slice-17-node-binding-guardrails-proof.txt"

WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-17-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-17-windows-before.log"
WINDOW_REBIND_LOG="${ARTIFACTS_DIR}/logs/slice-17-windows-after-rebind.log"
WINDOW_STALE_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-17-windows-before-stale-prune.log"
WINDOW_STALE_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-17-windows-after-stale-prune.log"
ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-17-zones.log"
READY_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-zone-bindings-ready.log"
ESCAPED_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-17-escaped-title-command.log"
ESCAPED_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-escaped-title-bindings.log"
REBIND_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-17-rebind-command.log"
REBIND_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-rebind-bindings.log"
DISABLED_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-17-disabled-zone-command.log"
DISABLED_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-disabled-zone-bindings.log"
MISSING_UNBIND_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-17-missing-unbind-command.log"
MISSING_UNBIND_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-missing-unbind-bindings.log"
STALE_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-17-stale-prune-command.log"
STALE_BEFORE_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-stale-prune-before-bindings.log"
STALE_AFTER_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-stale-prune-after-bindings.log"
FINAL_BINDINGS_LOG="${ARTIFACTS_DIR}/logs/slice-17-zone-bindings-final.log"

DOC_DIR="${HOME}/winmux-e2e/node-binding-guardrails"
BOARD_DIR="${DOC_DIR}/board"
BOARD_HTML="${BOARD_DIR}/index.html"
BOARD_STATE="${BOARD_DIR}/state.txt"
BOARD_SERVER_LOG="${ARTIFACTS_DIR}/logs/slice-17-board-http.log"
BOARD_SERVER_PID="${ARTIFACTS_DIR}/logs/slice-17-board-http.pid"
BOARD_PORT=51317
BOARD_TITLE="WinMux Node Binding Guardrails"
ESCAPED_DOC="${DOC_DIR}/escaped|equals=guardrail.rtf"
REBIND_DOC="${DOC_DIR}/rebind-guardrail.rtf"
UNBOUND_DOC="${DOC_DIR}/unbound-guardrail.rtf"
STALE_ALPHA_DOC="${DOC_DIR}/stale-alpha-guardrail.rtf"
STALE_BETA_DOC="${DOC_DIR}/stale-beta-guardrail.rtf"

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
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs70\b ${headline}\b0\par\f1\fs32 ${subtitle}\par ${detail}\par}
RTF
}

write_initial_board_doc() {
    mkdir -p "${BOARD_DIR}"
    cat >"${BOARD_STATE}" <<'STATE'
Checkpoint: setup

Runtime node binding guardrails are being staged.
STATE
    cat >"${BOARD_HTML}" <<'HTML'
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WinMux Node Binding Guardrails</title>
<style>
html, body {
    margin: 0;
    min-height: 100%;
    background: #101418;
    color: #f7fafc;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
}
main {
    box-sizing: border-box;
    min-height: 100vh;
    padding: 38px 32px;
    background: linear-gradient(180deg, #17212b 0%, #101418 100%);
}
h1 {
    margin: 0 0 22px 0;
    font-size: 40px;
    font-weight: 780;
    letter-spacing: 0;
}
pre {
    white-space: pre-wrap;
    margin: 0;
    font: 600 24px/1.36 "SF Mono", Menlo, monospace;
}
.rule {
    width: 88px;
    height: 6px;
    margin-bottom: 24px;
    background: #3ea2ff;
}
</style>
</head>
<body>
<main>
    <h1>WinMux Node Binding Guardrails</h1>
    <div class="rule"></div>
    <pre id="board">Loading...</pre>
</main>
<script>
async function refreshBoard() {
    try {
        const response = await fetch("/state.txt?ts=" + Date.now(), { cache: "no-store" });
        document.getElementById("board").textContent = await response.text();
    } catch (error) {
        document.getElementById("board").textContent = "Waiting for state...";
    }
}
refreshBoard();
setInterval(refreshBoard, 500);
</script>
</body>
</html>
HTML
}

start_board_server() {
    if /usr/sbin/lsof -ti "tcp:${BOARD_PORT}" >/tmp/winmux-slice17-lsof 2>/dev/null; then
        /bin/kill "$(/usr/bin/head -n 1 /tmp/winmux-slice17-lsof)" >/dev/null 2>&1 || true
        sleep 1
    fi
    cd "${BOARD_DIR}"
    /usr/bin/nohup /usr/bin/python3 -m http.server "${BOARD_PORT}" --bind 127.0.0.1 >"${BOARD_SERVER_LOG}" 2>&1 &
    echo "$!" >"${BOARD_SERVER_PID}"
    cd - >/dev/null
    for _ in $(seq 1 20); do
        if /usr/bin/curl -fsS "http://127.0.0.1:${BOARD_PORT}/state.txt" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done
    semantic_fail "Slice 17 board HTTP server did not become ready"
}

set_board_text() {
    local checkpoint="$1"
    local text="$2"
    {
        printf 'Checkpoint: %s\n\n' "${checkpoint}"
        printf '%s\n' "${text}"
    } >"${BOARD_STATE}"
    {
        printf 'checkpoint=%s\n' "${checkpoint}"
        printf '%s\n\n' "${text}"
    } >>"${BOARD_LOG}"
    wait_for_board_checkpoint "${checkpoint}"
}

wait_for_board_checkpoint() {
    local checkpoint="$1"
    local response="/tmp/winmux-slice17-board-state.txt"
    local attempt

    for attempt in $(seq 1 30); do
        if /usr/bin/curl -fsS "http://127.0.0.1:${BOARD_PORT}/state.txt?ts=$(/bin/date +%s)" >"${response}" 2>/dev/null &&
            /usr/bin/grep -F "Checkpoint: ${checkpoint}" "${response}" >/dev/null; then
            printf 'checkpoint=%s|attempt=%s|result=success|source=http-state\n' "${checkpoint}" "${attempt}" >>"${BOARD_FRESHNESS_LOG}"
            rm -f "${response}"
            return 0
        fi
        sleep 0.25
    done

    {
        printf 'checkpoint=%s|result=failure|source=http-state\n' "${checkpoint}"
        cat "${response}" 2>/dev/null || true
    } >>"${BOARD_FRESHNESS_LOG}"
    rm -f "${response}"
    semantic_fail "Board did not serve checkpoint ${checkpoint}"
}

write_zones_log() {
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${ZONES_LOG}" 2>>"${WAIT_ERR}"
}

write_bindings_log() {
    local path="$1"
    local tmp
    tmp="$(/usr/bin/mktemp)"
    "${CLI}" list-zone-bindings >"${tmp}" 2>>"${WAIT_ERR}"
    if [ -s "${tmp}" ]; then
        /bin/cp "${tmp}" "${path}"
    else
        printf 'node-bindings=none\n' >"${path}"
    fi
    rm -f "${tmp}"
}

binding_count() {
    "${CLI}" list-zone-bindings --count 2>>"${WAIT_ERR}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|layout=%{window-layout}|parent=%{window-parent-container-layout}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local key="$3"
    /usr/bin/awk -v title="${title}" -v key="${key}" '
        {
            first = index($0, "|")
            marker = index($0, "|zone=")
            if (first == 0 || marker == 0 || marker <= first) {
                next
            }

            row_id = substr($0, 1, first - 1)
            row_title = substr($0, first + 1, marker - first - 1)
            if (row_title != title) {
                next
            }

            if (key == "id") {
                print row_id
                exit
            }

            metadata = substr($0, marker + 1)
            count = split(metadata, fields, "|")
            for (i = 1; i <= count; i++) {
                if (index(fields[i], key "=") == 1) {
                    print substr(fields[i], length(key) + 2)
                    exit
                }
            }
        }
    ' "${path}"
}

window_id_for_title() {
    field_for_title "$1" "$2" id
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(field_for_title "${path}" "${title}" zone)"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}"
    fi
}

assert_title_missing() {
    local path="$1"
    local title="$2"
    [ -z "$(window_id_for_title "${path}" "${title}")" ] \
        || semantic_fail "Expected ${title} to be absent from ${path}"
}

wait_for_demo_windows() {
    for _ in $(seq 1 90); do
        if refresh_window_log "${WINDOW_SETUP_LOG}" &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" "${BOARD_TITLE}")" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'escaped|equals=guardrail.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'rebind-guardrail.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'unbound-guardrail.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'stale-alpha-guardrail.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'stale-beta-guardrail.rtf')" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

run_winmux_capture() {
    local log_path="$1"
    shift
    local segment tmp_out tmp_err rc
    segment="$(/usr/bin/mktemp)"
    tmp_out="$(/usr/bin/mktemp)"
    tmp_err="$(/usr/bin/mktemp)"
    {
        printf '$ winmux'
        printf ' %q' "$@"
        printf '\n'
    } >"${segment}"
    set +e
    "${CLI}" "$@" >"${tmp_out}" 2>"${tmp_err}"
    rc=$?
    set -e
    cat "${tmp_out}" >>"${segment}"
    if [ -s "${tmp_err}" ]; then
        /usr/bin/sed 's/^/stderr: /' "${tmp_err}" >>"${segment}"
    fi
    printf 'exit-code=%s\n\n' "${rc}" >>"${segment}"
    cat "${segment}" >>"${log_path}"
    cat "${segment}" >>"${CLI_LOG}"
    rm -f "${segment}" "${tmp_out}" "${tmp_err}"
    printf '%s\n' "${rc}"
}

expect_success() {
    local log_path="$1"
    shift
    local rc
    rc="$(run_winmux_capture "${log_path}" "$@")"
    [ "${rc}" = 0 ] || semantic_fail "Expected winmux $* to succeed; rc=${rc}"
}

expect_failure() {
    local log_path="$1"
    shift
    local rc
    rc="$(run_winmux_capture "${log_path}" "$@")"
    [ "${rc}" != 0 ] || semantic_fail "Expected winmux $* to fail"
}

move_window_to_zone() {
    local id="$1"
    local title="$2"
    local zone_name="$3"
    local expected_zone="$4"
    expect_success "${CLI_LOG}" move-node-to-zone --window-id "${id}" "${zone_name}"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_zone}"
}

sorted_tab_group_key() {
    local first="$1"
    local second="$2"
    local ids
    ids="$(printf '%s\n%s\n' "${first}" "${second}" | /usr/bin/sort -n | /usr/bin/paste -sd, -)"
    printf 'tab-group:%s\n' "${ids}"
}

sleep_until() {
    local target="$1"
    while [ "${SECONDS}" -lt "${target}" ]; do
        sleep 1
    done
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-17-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${BOARD_LOG}" "${BOARD_FRESHNESS_LOG}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_REBIND_LOG}" \
        "${WINDOW_STALE_BEFORE_LOG}" "${WINDOW_STALE_AFTER_LOG}" "${ZONES_LOG}" \
        "${READY_BINDINGS_LOG}" "${ESCAPED_COMMAND_LOG}" "${ESCAPED_BINDINGS_LOG}" \
        "${REBIND_COMMAND_LOG}" "${REBIND_BINDINGS_LOG}" "${DISABLED_COMMAND_LOG}" \
        "${DISABLED_BINDINGS_LOG}" "${MISSING_UNBIND_COMMAND_LOG}" \
        "${MISSING_UNBIND_BINDINGS_LOG}" "${STALE_COMMAND_LOG}" \
        "${STALE_BEFORE_BINDINGS_LOG}" "${STALE_AFTER_BINDINGS_LOG}" \
        "${FINAL_BINDINGS_LOG}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" "${BOARD_SERVER_LOG}" \
        "${BOARD_SERVER_PID}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 17: node binding guardrails'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo "Command: bind-node-to-zone --window-id \"\$ESCAPED_ID\" Comms"
        echo "Command: bind-node-to-zone --window-id \"\$REBIND_ID\" Reference"
        echo "Command: bind-node-to-zone --window-id \"\$REBIND_ID\" Comms"
        echo "Command: unbind-node-zone-binding --window-id \"\$UNBOUND_ID\""
        echo "Command: close --window-id \"\$STALE_BETA_ID\""
        echo 'Non-claim: runtime node bindings are not relaunch-persistent'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_initial_board_doc
    start_board_server
    write_doc "${ESCAPED_DOC}" 'ESCAPED TITLE' 'title contains pipe and equals separators' 'list-zone-bindings must escape this title'
    write_doc "${REBIND_DOC}" 'REBIND TARGET' 'same window is rebound Reference to Comms' 'binding count stays one'
    write_doc "${UNBOUND_DOC}" 'UNBOUND TARGET' 'disabled-zone and missing-unbind failures use this window' 'no binding should be created'
    write_doc "${STALE_ALPHA_DOC}" 'STALE TAB ALPHA' 'tab group binding before membership changes' 'closing beta prunes the runtime binding'
    write_doc "${STALE_BETA_DOC}" 'STALE TAB BETA' 'second tab in the stale-prune proof' 'this tab closes during the recording'

    launch_winmux

    /usr/bin/open -a Safari "http://127.0.0.1:${BOARD_PORT}/index.html"
    sleep 1
    /usr/bin/open -a TextEdit "${ESCAPED_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${REBIND_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${UNBOUND_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${STALE_ALPHA_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${STALE_BETA_DOC}"

    if ! wait_for_demo_windows; then
        echo 'Slice 17 demo windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi

    BOARD_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" "${BOARD_TITLE}")"
    ESCAPED_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'escaped|equals=guardrail.rtf')"
    REBIND_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'rebind-guardrail.rtf')"
    UNBOUND_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'unbound-guardrail.rtf')"
    STALE_ALPHA_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'stale-alpha-guardrail.rtf')"
    STALE_BETA_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'stale-beta-guardrail.rtf')"
    for id in "${BOARD_ID}" "${ESCAPED_ID}" "${REBIND_ID}" "${UNBOUND_ID}" "${STALE_ALPHA_ID}" "${STALE_BETA_ID}"; do
        [ -n "${id}" ] || semantic_fail 'Could not resolve all Slice 17 window ids'
    done

    move_window_to_zone "${BOARD_ID}" "${BOARD_TITLE}" Reference left
    move_window_to_zone "${ESCAPED_ID}" 'escaped|equals=guardrail.rtf' Work main
    move_window_to_zone "${REBIND_ID}" 'rebind-guardrail.rtf' Work main
    move_window_to_zone "${UNBOUND_ID}" 'unbound-guardrail.rtf' Work main
    move_window_to_zone "${STALE_ALPHA_ID}" 'stale-alpha-guardrail.rtf' Work main
    move_window_to_zone "${STALE_BETA_ID}" 'stale-beta-guardrail.rtf' Work main

    expect_success "${CLI_LOG}" focus --window-id "${STALE_ALPHA_ID}"
    stack_rc="$(run_winmux_capture "${CLI_LOG}" stack-with --window-id "${STALE_ALPHA_ID}" right)"
    if [ "${stack_rc}" != 0 ]; then
        expect_success "${CLI_LOG}" stack-with --window-id "${STALE_BETA_ID}" left
    fi
    expect_success "${CLI_LOG}" focus-zone Work
    expect_success "${CLI_LOG}" focus --window-id "${STALE_ALPHA_ID}"

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" "${BOARD_TITLE}" left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'escaped|equals=guardrail.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'rebind-guardrail.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'unbound-guardrail.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'stale-alpha-guardrail.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'stale-beta-guardrail.rtf' main
    write_zones_log
    write_bindings_log "${READY_BINDINGS_LOG}"
    [ "$(binding_count)" = 0 ] || semantic_fail 'Expected zero node zone bindings after setup'

    STALE_TAB_GROUP_KEY="$(sorted_tab_group_key "${STALE_ALPHA_ID}" "${STALE_BETA_ID}")"
    cat >"${STATE_FILE}" <<STATE
BOARD_ID=${BOARD_ID}
ESCAPED_ID=${ESCAPED_ID}
REBIND_ID=${REBIND_ID}
UNBOUND_ID=${UNBOUND_ID}
STALE_ALPHA_ID=${STALE_ALPHA_ID}
STALE_BETA_ID=${STALE_BETA_ID}
STALE_TAB_GROUP_KEY=${STALE_TAB_GROUP_KEY}
STATE

    set_board_text ready "Ready:
count=0
windows=escaped-title, rebind, unbound, stale tab group
commands will run during the recording
non-claim=no relaunch persistence"

    {
        echo 'setup=result=success'
        echo 'ready-state=node-binding-guardrail-board-visible'
        echo "escaped-window-id=${ESCAPED_ID}"
        echo "rebind-window-id=${REBIND_ID}"
        echo "unbound-window-id=${UNBOUND_ID}"
        echo "stale-alpha-window-id=${STALE_ALPHA_ID}"
        echo "stale-beta-window-id=${STALE_BETA_ID}"
        echo "stale-tab-group-key=${STALE_TAB_GROUP_KEY}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"

    write_bindings_log "${READY_BINDINGS_LOG}"
    [ "$(binding_count)" = 0 ] || semantic_fail 'Expected zero bindings before Slice 17 proof'
    set_board_text ready-recording "Run: winmux list-zone-bindings --count
count=0
state=ready for guardrail commands"

    sleep_until 8
    escaped_offset="${SECONDS}"
    echo "escaped-command-offset-seconds=${escaped_offset}" >>"${TIMING_LOG}"
    expect_success "${ESCAPED_COMMAND_LOG}" bind-node-to-zone --window-id "${ESCAPED_ID}" Comms
    write_bindings_log "${ESCAPED_BINDINGS_LOG}"
    /usr/bin/grep -F 'title=escaped\|equals\=guardrail.rtf' "${ESCAPED_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'Escaped binding row did not escape pipe and equals separators'
    [ "$(binding_count)" = 1 ] || semantic_fail 'Expected one binding after escaped title bind'
    set_board_text escaped-title "Run: winmux bind-node-to-zone --window-id ${ESCAPED_ID} Comms
result=success
list-zone-bindings title=escaped\\|equals\\=guardrail.rtf
count=1"
    expect_success "${ESCAPED_COMMAND_LOG}" unbind-node-zone-binding --window-id "${ESCAPED_ID}"
    [ "$(binding_count)" = 0 ] || semantic_fail 'Expected escaped title cleanup to remove binding'

    sleep_until 18
    rebind_offset="${SECONDS}"
    echo "rebind-command-offset-seconds=${rebind_offset}" >>"${TIMING_LOG}"
    expect_success "${REBIND_COMMAND_LOG}" bind-node-to-zone --window-id "${REBIND_ID}" Reference
    rebind_reference_count="$(binding_count)"
    expect_success "${REBIND_COMMAND_LOG}" bind-node-to-zone --window-id "${REBIND_ID}" Comms
    rebind_comms_count="$(binding_count)"
    write_bindings_log "${REBIND_BINDINGS_LOG}"
    refresh_window_log "${WINDOW_REBIND_LOG}"
    [ "${rebind_reference_count}" = 1 ] || semantic_fail "Expected rebind count after Reference=1, got ${rebind_reference_count}"
    [ "${rebind_comms_count}" = 1 ] || semantic_fail "Expected rebind count after Comms=1, got ${rebind_comms_count}"
    /usr/bin/grep -F 'node-id=window:'"${REBIND_ID}"'|' "${REBIND_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'Rebind binding row missing expected window id'
    /usr/bin/grep -F 'zone=right' "${REBIND_BINDINGS_LOG}" >/dev/null \
        || semantic_fail 'Rebind binding row did not end in Comms/right'
    assert_window_zone "${WINDOW_REBIND_LOG}" 'rebind-guardrail.rtf' right
    set_board_text rebind "Run: winmux bind-node-to-zone --window-id ${REBIND_ID} Reference
Run: winmux bind-node-to-zone --window-id ${REBIND_ID} Comms
count-after-reference=${rebind_reference_count}
count-after-comms=${rebind_comms_count}
final-zone=right"
    expect_success "${REBIND_COMMAND_LOG}" unbind-node-zone-binding --window-id "${REBIND_ID}"
    [ "$(binding_count)" = 0 ] || semantic_fail 'Expected rebind cleanup to remove binding'

    sleep_until 28
    disabled_offset="${SECONDS}"
    echo "disabled-command-offset-seconds=${disabled_offset}" >>"${TIMING_LOG}"
    expect_success "${DISABLED_COMMAND_LOG}" disable-zone Comms
    expect_failure "${DISABLED_COMMAND_LOG}" bind-node-to-zone --window-id "${UNBOUND_ID}" Comms
    disabled_count="$(binding_count)"
    write_bindings_log "${DISABLED_BINDINGS_LOG}"
    expect_success "${DISABLED_COMMAND_LOG}" enable-zone Comms
    [ "${disabled_count}" = 0 ] || semantic_fail "Expected disabled target failure to keep count=0, got ${disabled_count}"
    /usr/bin/grep -F "Zone 'Comms' is disabled" "${DISABLED_COMMAND_LOG}" >/dev/null \
        || semantic_fail 'Disabled-zone failure log missing disabled-zone error'
    set_board_text disabled-zone "Run: winmux disable-zone Comms
Run: winmux bind-node-to-zone --window-id ${UNBOUND_ID} Comms
result=failure
stderr=Zone 'Comms' is disabled
count=${disabled_count}"

    sleep_until 38
    missing_offset="${SECONDS}"
    echo "missing-unbind-offset-seconds=${missing_offset}" >>"${TIMING_LOG}"
    expect_failure "${MISSING_UNBIND_COMMAND_LOG}" unbind-node-zone-binding --window-id "${UNBOUND_ID}"
    missing_count="$(binding_count)"
    write_bindings_log "${MISSING_UNBIND_BINDINGS_LOG}"
    [ "${missing_count}" = 0 ] || semantic_fail "Expected missing unbind to keep count=0, got ${missing_count}"
    /usr/bin/grep -F 'No node zone binding exists for window:'"${UNBOUND_ID}" "${MISSING_UNBIND_COMMAND_LOG}" >/dev/null \
        || semantic_fail 'Missing-unbind log missing expected error'
    set_board_text missing-unbind "Run: winmux unbind-node-zone-binding --window-id ${UNBOUND_ID}
result=failure
stderr=No node zone binding exists
count=${missing_count}"

    sleep_until 48
    stale_offset="${SECONDS}"
    echo "stale-prune-offset-seconds=${stale_offset}" >>"${TIMING_LOG}"
    expect_success "${STALE_COMMAND_LOG}" focus-zone Work
    expect_success "${STALE_COMMAND_LOG}" focus --window-id "${STALE_ALPHA_ID}"
    expect_success "${STALE_COMMAND_LOG}" bind-node-to-zone Comms
    stale_count_before="$(binding_count)"
    write_bindings_log "${STALE_BEFORE_BINDINGS_LOG}"
    refresh_window_log "${WINDOW_STALE_BEFORE_LOG}"
    /usr/bin/grep -F "node-id=${STALE_TAB_GROUP_KEY}|" "${STALE_BEFORE_BINDINGS_LOG}" >/dev/null \
        || semantic_fail "Stale prune before log missing ${STALE_TAB_GROUP_KEY}"
    expect_success "${STALE_COMMAND_LOG}" close --window-id "${STALE_BETA_ID}"
    stale_count_after="unknown"
    for _ in $(seq 1 30); do
        stale_count_after="$(binding_count)"
        write_bindings_log "${STALE_AFTER_BINDINGS_LOG}"
        refresh_window_log "${WINDOW_STALE_AFTER_LOG}"
        if [ "${stale_count_after}" = 0 ] && [ -z "$(window_id_for_title "${WINDOW_STALE_AFTER_LOG}" 'stale-beta-guardrail.rtf')" ]; then
            break
        fi
        sleep 1
    done
    [ "${stale_count_before}" = 1 ] || semantic_fail "Expected stale binding count before close=1, got ${stale_count_before}"
    [ "${stale_count_after}" = 0 ] || semantic_fail "Expected stale binding to prune after close, got ${stale_count_after}"
    assert_window_zone "${WINDOW_STALE_AFTER_LOG}" 'stale-alpha-guardrail.rtf' right
    assert_title_missing "${WINDOW_STALE_AFTER_LOG}" 'stale-beta-guardrail.rtf'
    set_board_text stale-prune "Run: winmux bind-node-to-zone Comms
tab-group=${STALE_TAB_GROUP_KEY}
count-before-close=${stale_count_before}
Run: winmux close --window-id ${STALE_BETA_ID}
count-after-close=${stale_count_after}
stale-record=pruned"

    sleep_until 62
    final_offset="${SECONDS}"
    echo "final-count-offset-seconds=${final_offset}" >>"${TIMING_LOG}"
    write_bindings_log "${FINAL_BINDINGS_LOG}"
    final_count="$(binding_count)"
    [ "${final_count}" = 0 ] || semantic_fail "Expected final binding count=0, got ${final_count}"
    set_board_text final "Run: winmux list-zone-bindings --count
count=${final_count}
runtime-binding-persistence=relaunch not claimed
tab-group-identity=current membership"

    cat \
        "${READY_BINDINGS_LOG}" \
        "${ESCAPED_COMMAND_LOG}" "${ESCAPED_BINDINGS_LOG}" \
        "${REBIND_COMMAND_LOG}" "${REBIND_BINDINGS_LOG}" \
        "${DISABLED_COMMAND_LOG}" "${DISABLED_BINDINGS_LOG}" \
        "${MISSING_UNBIND_COMMAND_LOG}" "${MISSING_UNBIND_BINDINGS_LOG}" \
        "${STALE_COMMAND_LOG}" "${STALE_BEFORE_BINDINGS_LOG}" "${STALE_AFTER_BINDINGS_LOG}" \
        "${FINAL_BINDINGS_LOG}" "${BOARD_LOG}" >>"${CLI_LOG}"

    {
        echo 'WinMux Slice 17: node binding guardrails and machine-safe inspection'
        echo
        echo 'Ready bindings:'
        cat "${READY_BINDINGS_LOG}"
        echo
        echo 'Escaped title command and binding row:'
        cat "${ESCAPED_COMMAND_LOG}"
        cat "${ESCAPED_BINDINGS_LOG}"
        echo
        echo 'Rebind command and binding row:'
        cat "${REBIND_COMMAND_LOG}"
        cat "${REBIND_BINDINGS_LOG}"
        echo
        echo 'Disabled-zone failure:'
        cat "${DISABLED_COMMAND_LOG}"
        cat "${DISABLED_BINDINGS_LOG}"
        echo
        echo 'Missing-unbind failure:'
        cat "${MISSING_UNBIND_COMMAND_LOG}"
        cat "${MISSING_UNBIND_BINDINGS_LOG}"
        echo
        echo 'Stale tab-group prune:'
        cat "${STALE_COMMAND_LOG}"
        cat "${STALE_BEFORE_BINDINGS_LOG}"
        cat "${STALE_AFTER_BINDINGS_LOG}"
        echo
        echo 'Final bindings:'
        cat "${FINAL_BINDINGS_LOG}"
        echo
        cat "${TIMING_LOG}"
        echo "stale-tab-group-key=${STALE_TAB_GROUP_KEY}"
        echo "escaped-window-id=${ESCAPED_ID}"
        echo "rebind-window-id=${REBIND_ID}"
        echo "unbound-window-id=${UNBOUND_ID}"
        echo 'non-claim=runtime node bindings are not relaunch-persistent'
        echo 'PASS: node binding commands reject disabled targets, report missing unbinds, overwrite rebinds, escape separator titles, and prune stale tab-group membership without claiming persistence.'
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
        echo "Unknown WINMUX_E2E_SLICE17_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
