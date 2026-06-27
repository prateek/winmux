#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE21_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice21-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice21-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice21"
LAUNCH_PLIST="/tmp/winmux-e2e-slice21.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice21.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-21-zone-mode-v2-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/slice-21-zone-mode-v2-action.log"
STATE_BOARD_LOG="${ARTIFACTS_DIR}/logs/slice-21-live-state-board.log"
BOARD_FRESHNESS_LOG="${ARTIFACTS_DIR}/logs/slice-21-board-freshness.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-21-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-21-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-21-cli-wait.err"
DOC_CONTENT_LOG="${ARTIFACTS_DIR}/logs/slice-21-demo-doc-content.rtf"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-21-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-21-zone-mode-v2.done"
PROOF="${ARTIFACTS_DIR}/slice-21-zone-mode-v2-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

ZONES_READY_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-ready.log"
ZONES_AFTER_SNAP_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-after-snap-policy.log"
ZONES_AFTER_LAYOUT_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-after-layout-focus.log"
ZONES_AFTER_FOCUS_ONLY_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-after-availability-focus-only.log"
ZONES_AFTER_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-after-availability-communications.log"
ZONES_AFTER_STYLE_LOG="${ARTIFACTS_DIR}/logs/slice-21-zones-after-style-urgent.log"

FOCUS_READY_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-ready.log"
FOCUS_AFTER_SNAP_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-after-snap-policy.log"
FOCUS_AFTER_LAYOUT_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-after-layout-focus.log"
FOCUS_AFTER_FOCUS_ONLY_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-after-availability-focus-only.log"
FOCUS_AFTER_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-after-availability-communications.log"
FOCUS_AFTER_STYLE_LOG="${ARTIFACTS_DIR}/logs/slice-21-focused-after-style-urgent.log"

DOC_DIR="${HOME}/winmux-e2e/zone-mode-v2-docs"
BOARD_DIR="${DOC_DIR}/board"
BOARD_HTML="${BOARD_DIR}/index.html"
BOARD_STATE="${BOARD_DIR}/state.txt"
BOARD_SERVER_LOG="${ARTIFACTS_DIR}/logs/slice-21-board-http.log"
BOARD_SERVER_PID="${ARTIFACTS_DIR}/logs/slice-21-board-http.pid"
BOARD_PORT=51321
CURRENT_BOARD_TITLE=""
REFERENCE_DOC="${DOC_DIR}/reference-zone-mode-v2.rtf"
COMMS_DOC="${DOC_DIR}/comms-zone-mode-v2.rtf"

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
    local role="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs78\b ${title}\b0\par\f1\fs34 role: ${role}\par ${detail}\par}
RTF
}

write_initial_board_doc() {
    mkdir -p "${BOARD_DIR}"
    cat >"${BOARD_STATE}" <<'STATE'
WINMUX ZONE MODE V2

Waiting for live binding state.
STATE
    cat >"${BOARD_HTML}" <<'HTML'
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WinMux Zone Mode V2</title>
<style>
html, body {
    margin: 0;
    min-height: 100%;
    background: #101419;
    color: #f7fafc;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
}
main {
    box-sizing: border-box;
    min-height: 100vh;
    padding: 38px 34px;
    background: linear-gradient(180deg, #18222c 0%, #101419 100%);
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
    font: 620 25px/1.34 "SF Mono", Menlo, monospace;
}
.rule {
    width: 92px;
    height: 6px;
    margin-bottom: 24px;
    background: #3ea2ff;
}
</style>
</head>
<body>
<main>
    <h1>WinMux Zone Mode V2</h1>
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
    if /usr/sbin/lsof -ti "tcp:${BOARD_PORT}" >/tmp/winmux-slice21-lsof 2>/dev/null; then
        /bin/kill "$(/usr/bin/head -n 1 /tmp/winmux-slice21-lsof)" >/dev/null 2>&1 || true
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
    semantic_fail "Slice 21 board HTTP server did not become ready"
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|layout=%{monitor-zone-layout-id}|style=%{monitor-zone-style-id}|color=%{monitor-zone-style-color}|availability=%{monitor-zone-availability-set-id}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

write_focused_log() {
    local path="$1"
    "${CLI}" list-monitors --focused \
        --format 'focused-zone=%{monitor-zone-id}|focused-name=%{monitor-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}' \
        >"${path}" 2>>"${WAIT_ERR}"
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

window_id_for_title() {
    field_for_title "$1" "$2" id
}

zone_log_value() {
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

focused_field() {
    local path="$1"
    local key="$2"
    /usr/bin/awk -F'|' -v key="${key}" '{
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

assert_zone_field() {
    local path="$1"
    local zone_id="$2"
    local key="$3"
    local expected="$4"
    local actual
    actual="$(zone_log_value "${path}" "${zone_id}" "${key}")"
    if [ "${actual}" != "${expected}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${zone_id}.${key}=${expected}, got ${actual:-missing}"
    fi
}

assert_width_grew() {
    local before_width="$1"
    local after_width="$2"
    /usr/bin/awk -v before="${before_width}" -v after="${after_width}" 'BEGIN { exit(after > before ? 0 : 1) }' \
        || semantic_fail "Expected main width to grow after layout focus: before=${before_width}, after=${after_width}"
}

wait_for_demo_windows() {
    local window_log="${ARTIFACTS_DIR}/logs/slice-21-windows-setup.log"
    for _ in $(seq 1 90); do
        if refresh_window_log "${window_log}" &&
            [ -n "$(window_id_for_title "${window_log}" 'reference-zone-mode-v2.rtf')" ] &&
            [ -n "$(window_id_for_title "${window_log}" 'comms-zone-mode-v2.rtf')" ]; then
            return 0
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
    local window_log="${ARTIFACTS_DIR}/logs/slice-21-windows-setup.log"
    {
        echo "setup: ${title} -> ${zone_name}"
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone_name}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone_name}"
    } | tee -a "${CLI_LOG}"
    refresh_window_log "${window_log}"
    assert_window_zone "${window_log}" "${title}" "${expected_zone}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-21-zone-count.txt" 2>"${WAIT_ERR}"; then
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

set_board_text() {
    local text="$1"
    printf '%s\n' "${text}" >"${BOARD_STATE}"
}

wait_for_board_checkpoint() {
    local checkpoint="$1"
    local board_title="$2"
    local attempt

    for attempt in $(seq 1 30); do
        if refresh_window_log "${ARTIFACTS_DIR}/logs/slice-21-windows-board-${checkpoint}.log" &&
            [ -n "$(window_id_for_title "${ARTIFACTS_DIR}/logs/slice-21-windows-board-${checkpoint}.log" "${board_title}")" ]; then
            printf 'checkpoint=%s|attempt=%s|result=success|source=textedit-board|title=%s\n' "${checkpoint}" "${attempt}" "${board_title}" >>"${BOARD_FRESHNESS_LOG}"
            return 0
        fi
        sleep 0.5
    done

    {
        printf 'checkpoint=%s|result=failure|source=textedit-board|title=%s\n' "${checkpoint}" "${board_title}"
        cat "${ARTIFACTS_DIR}/logs/slice-21-windows-board-${checkpoint}.log" 2>/dev/null || true
    } >>"${BOARD_FRESHNESS_LOG}"
    semantic_fail "Board did not serve checkpoint ${checkpoint} before screenshot"
}

mode_now() {
    "${CLI}" list-modes --current | /usr/bin/tail -n 1 | /usr/bin/tr -d '\r'
}

zone_summary() {
    local zones_log="$1"
    /usr/bin/awk -F'|' '
        /^zone=/ {
            zone = substr($1, 6)
            enabled = style = color = layout = availability = width = "?"
            for (i = 1; i <= NF; i++) {
                if (index($i, "enabled=") == 1) { enabled = substr($i, 9) }
                if (index($i, "layout=") == 1) { layout = substr($i, 8) }
                if (index($i, "style=") == 1) { style = substr($i, 7) }
                if (index($i, "color=") == 1) { color = substr($i, 7) }
                if (index($i, "availability=") == 1) { availability = substr($i, 14) }
                if (index($i, "width=") == 1) { width = substr($i, 7) }
            }
            printf "%s enabled=%s layout=%s availability=%s style=%s color=%s width=%s\n",
                zone, enabled, layout, availability, style, color, width
        }
    ' "${zones_log}"
}

write_board_rtf() {
    local path="$1"
    local text="$2"
    {
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs58\\b WinMux Zone Mode V2\\b0\\par\\f1\\fs30 '
        printf '%s\n' "${text}" | /usr/bin/sed \
            -e 's/\\/\\\\/g' \
            -e 's/{/\\{/g' \
            -e 's/}/\\}/g' \
            -e 's/$/\\par/'
        printf '}\n'
    } >"${path}"
}

open_board_checkpoint() {
    local checkpoint="$1"
    local board_text="$2"
    local board_doc="${DOC_DIR}/board-${checkpoint}.rtf"
    local board_title
    board_title="$(basename "${board_doc}")"

    write_board_rtf "${board_doc}" "${board_text}"
    /usr/bin/open -a TextEdit "${board_doc}"
    wait_for_board_checkpoint "${checkpoint}" "${board_title}"

    local window_log="${ARTIFACTS_DIR}/logs/slice-21-windows-board-${checkpoint}.log"
    local new_board_id old_board_id
    new_board_id="$(window_id_for_title "${window_log}" "${board_title}")"
    [ -n "${new_board_id}" ] || semantic_fail "Missing board window for ${checkpoint}"
    old_board_id="${BOARD_ID:-}"
    BOARD_ID="${new_board_id}"
    CURRENT_BOARD_TITLE="${board_title}"

    move_window_to_zone "${BOARD_ID}" "${CURRENT_BOARD_TITLE}" Work main
    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${BOARD_ID}" >/dev/null 2>>"${WAIT_ERR}" || true
    if [ -n "${old_board_id}" ] && [ "${old_board_id}" != "${BOARD_ID}" ]; then
        "${CLI}" close --window-id "${old_board_id}" >/dev/null 2>>"${WAIT_ERR}" || true
    fi
}

state_board_entry() {
    local checkpoint="$1"
    local key_sequence="$2"
    local winmux_command="$3"
    local observed="$4"
    local zones_log="$5"
    local focus_log="$6"

    write_zones_log "${zones_log}"
    write_focused_log "${focus_log}"

    local focused_zone focused_workspace summary_text
    focused_zone="$(focused_field "${focus_log}" focused-zone)"
    focused_workspace="$(focused_field "${focus_log}" workspace)"
    summary_text="$(zone_summary "${zones_log}")"
    {
        printf 'checkpoint=%s|keys=%s|winmux-command=%s|observed=%s|focused-zone=%s|active-workspace=%s\n' \
            "${checkpoint}" "${key_sequence}" "${winmux_command}" "${observed}" "${focused_zone:-unknown}" "${focused_workspace:-unknown}"
        printf '%s\n' "${summary_text}"
    } >>"${STATE_BOARD_LOG}"

    local board_text
    board_text="$(cat <<BOARD
WINMUX ZONE MODE V2

Keys
${key_sequence}

Command
${winmux_command}

Observed
${observed}

Focused zone
${focused_zone:-unknown}

Zone state
${summary_text}

Checkpoint
${checkpoint}
BOARD
)"
    open_board_checkpoint "${checkpoint}" "${board_text}"
}

run_zone_binding() {
    local key="$1"
    local key_sequence="$2"
    local winmux_command="$3"
    local timing_key="$4"
    local command_log="${ARTIFACTS_DIR}/logs/slice-21-${timing_key}.log"

    echo "${timing_key}-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "keys=${key_sequence}"
        echo "winmux-command=${winmux_command}"
        echo "$ winmux trigger-binding --mode main alt-z"
        "${CLI}" trigger-binding --mode main alt-z
        local mode_after_prefix
        mode_after_prefix="$(mode_now)"
        echo "mode-after-alt-z=${mode_after_prefix}"
        [ "${mode_after_prefix}" = "zone" ] || semantic_fail "Expected zone mode after Alt-Z, got ${mode_after_prefix:-missing}"
        echo "$ winmux trigger-binding --mode zone ${key}"
        "${CLI}" trigger-binding --mode zone "${key}"
        local mode_after_binding
        mode_after_binding="$(mode_now)"
        echo "mode-after-binding=${mode_after_binding}"
        [ "${mode_after_binding}" = "main" ] || semantic_fail "Expected main mode after ${key_sequence}, got ${mode_after_binding:-missing}"
    } | tee "${command_log}" | tee -a "${ACTION_LOG}" >/dev/null
}

setup_slice() {
    rm -f \
        "${DONE}" "${SETUP_LOG}" "${ACTION_LOG}" "${STATE_BOARD_LOG}" "${BOARD_FRESHNESS_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${DOC_CONTENT_LOG}" "${STATE_FILE}" "${PROOF}" \
        "${ZONES_READY_LOG}" "${ZONES_AFTER_SNAP_LOG}" "${ZONES_AFTER_LAYOUT_LOG}" "${ZONES_AFTER_FOCUS_ONLY_LOG}" "${ZONES_AFTER_COMMUNICATIONS_LOG}" "${ZONES_AFTER_STYLE_LOG}" \
        "${FOCUS_READY_LOG}" "${FOCUS_AFTER_SNAP_LOG}" "${FOCUS_AFTER_LAYOUT_LOG}" "${FOCUS_AFTER_FOCUS_ONLY_LOG}" "${FOCUS_AFTER_COMMUNICATIONS_LOG}" "${FOCUS_AFTER_STYLE_LOG}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" "${BOARD_SERVER_LOG}" "${BOARD_SERVER_PID}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 21: ergonomic zone mode V2 bindings'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo "Config: [mode.main.binding] alt-z = 'mode zone'"
        echo "Binding: s -> cycle-zone-snap-policy freeform snap-to-zone"
        echo "Binding: tab -> cycle-zone-layout balanced focus"
        echo "Binding: a -> cycle-zone-availability focus-only communications full-dashboard"
        echo "Binding: y -> cycle-zone-style current urgent calm"
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" "REFERENCE" "left-side material" "Hidden by focus-only, restored by dashboard-style availability."
    write_doc "${COMMS_DOC}" "COMMS" "right-side communications" "Restored by the communications availability set."
    cat "${REFERENCE_DOC}" "${COMMS_DOC}" >"${DOC_CONTENT_LOG}"

    launch_winmux
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${COMMS_DOC}"
    if ! wait_for_demo_windows; then
        cat "${ARTIFACTS_DIR}/logs/slice-21-windows-setup.log" >&2 || true
        semantic_fail 'Demo windows did not appear'
    fi

    local reference_id comms_id
    reference_id="$(window_id_for_title "${ARTIFACTS_DIR}/logs/slice-21-windows-setup.log" 'reference-zone-mode-v2.rtf')"
    comms_id="$(window_id_for_title "${ARTIFACTS_DIR}/logs/slice-21-windows-setup.log" 'comms-zone-mode-v2.rtf')"
    test -n "${reference_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'reference-zone-mode-v2.rtf' Reference left
    move_window_to_zone "${comms_id}" 'comms-zone-mode-v2.rtf' Comms right

    "${CLI}" focus-zone Work
    sleep 1
    state_board_entry \
        'ready-zone-mode-v2' \
        'Alt-Z opens zone mode; S/Tab/A/Y perform the compact controls' \
        'cycle snap policy, layout, availability, and style' \
        'Reference, Work, and Comms visible; Work/main is focused' \
        "${ZONES_READY_LOG}" \
        "${FOCUS_READY_LOG}"

    cat >"${STATE_FILE}" <<STATE
BOARD_ID=${BOARD_ID}
REFERENCE_ID=${reference_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup-result=success'
        echo "board-window-id=${BOARD_ID}"
        echo "reference-window-id=${reference_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${ACTION_LOG}"
    : >"${STATE_BOARD_LOG}"
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${BOARD_ID:-}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${BOARD_ID}"
    state_board_entry \
        'ready-zone-mode-v2' \
        'Alt-Z opens zone mode; S/Tab/A/Y perform the compact controls' \
        'cycle snap policy, layout, availability, and style' \
        'Reference, Work, and Comms visible; Work/main is focused' \
        "${ZONES_READY_LOG}" \
        "${FOCUS_READY_LOG}"
    sleep 1
    capture_guest_screenshot '02-ready-zone-mode-v2-slice-21'
    sleep 5

    run_zone_binding s 'Alt-Z, S' 'cycle-zone-snap-policy freeform snap-to-zone' snap-policy-command-start
    sleep 1
    state_board_entry \
        'after-snap-policy' \
        'Alt-Z, S' \
        'cycle-zone-snap-policy freeform snap-to-zone' \
        'runtime snap policy is snap-to-zone; no config file rewrite' \
        "${ZONES_AFTER_SNAP_LOG}" \
        "${FOCUS_AFTER_SNAP_LOG}"
    capture_guest_screenshot '03-after-snap-policy-slice-21'
    sleep 6

    run_zone_binding tab 'Alt-Z, Tab' 'cycle-zone-layout balanced focus' layout-cycle-command-start
    sleep 2
    state_board_entry \
        'after-layout-focus' \
        'Alt-Z, Tab' \
        'cycle-zone-layout balanced focus' \
        'layout preset is focus; Work/main widens' \
        "${ZONES_AFTER_LAYOUT_LOG}" \
        "${FOCUS_AFTER_LAYOUT_LOG}"
    capture_guest_screenshot '04-after-layout-focus-slice-21'
    sleep 6

    run_zone_binding a 'Alt-Z, A' 'cycle-zone-availability focus-only communications full-dashboard' availability-focus-only-command-start
    sleep 2
    state_board_entry \
        'after-availability-focus-only' \
        'Alt-Z, A' \
        'cycle-zone-availability focus-only communications full-dashboard' \
        'focus-only leaves Work/main available and hides side zones' \
        "${ZONES_AFTER_FOCUS_ONLY_LOG}" \
        "${FOCUS_AFTER_FOCUS_ONLY_LOG}"
    capture_guest_screenshot '05-after-availability-focus-only-slice-21'
    sleep 6

    run_zone_binding a 'Alt-Z, A' 'cycle-zone-availability focus-only communications full-dashboard' availability-communications-command-start
    sleep 2
    state_board_entry \
        'after-availability-communications' \
        'Alt-Z, A' \
        'cycle-zone-availability focus-only communications full-dashboard' \
        'communications restores Comms/right while Reference stays hidden' \
        "${ZONES_AFTER_COMMUNICATIONS_LOG}" \
        "${FOCUS_AFTER_COMMUNICATIONS_LOG}"
    capture_guest_screenshot '06-after-availability-communications-slice-21'
    sleep 6

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${BOARD_ID}"
    run_zone_binding y 'Alt-Z, Y' 'cycle-zone-style current urgent calm' style-cycle-command-start
    sleep 2
    state_board_entry \
        'after-style-urgent' \
        'Alt-Z, Y' \
        'cycle-zone-style current urgent calm' \
        'current Work/main zone uses urgent style #D3455B' \
        "${ZONES_AFTER_STYLE_LOG}" \
        "${FOCUS_AFTER_STYLE_LOG}"
    capture_guest_screenshot '07-after-style-urgent-slice-21'
    sleep 8

    assert_zone_field "${ZONES_READY_LOG}" main layout balanced
    assert_zone_field "${ZONES_AFTER_LAYOUT_LOG}" main layout focus
    assert_width_grew \
        "$(zone_log_value "${ZONES_READY_LOG}" main width)" \
        "$(zone_log_value "${ZONES_AFTER_LAYOUT_LOG}" main width)"
    assert_zone_field "${ZONES_AFTER_FOCUS_ONLY_LOG}" main availability focus-only
    assert_zone_field "${ZONES_AFTER_FOCUS_ONLY_LOG}" main enabled true
    assert_zone_field "${ZONES_AFTER_FOCUS_ONLY_LOG}" left enabled false
    assert_zone_field "${ZONES_AFTER_FOCUS_ONLY_LOG}" right enabled false
    assert_zone_field "${ZONES_AFTER_COMMUNICATIONS_LOG}" main availability communications
    assert_zone_field "${ZONES_AFTER_COMMUNICATIONS_LOG}" main enabled true
    assert_zone_field "${ZONES_AFTER_COMMUNICATIONS_LOG}" right enabled true
    assert_zone_field "${ZONES_AFTER_COMMUNICATIONS_LOG}" left enabled false
    assert_zone_field "${ZONES_AFTER_STYLE_LOG}" main style urgent
    assert_zone_field "${ZONES_AFTER_STYLE_LOG}" main color '#D3455B'

    cat \
        "${ACTION_LOG}" "${STATE_BOARD_LOG}" "${TIMING_LOG}" \
        "${ZONES_READY_LOG}" "${ZONES_AFTER_SNAP_LOG}" "${ZONES_AFTER_LAYOUT_LOG}" \
        "${ZONES_AFTER_FOCUS_ONLY_LOG}" "${ZONES_AFTER_COMMUNICATIONS_LOG}" "${ZONES_AFTER_STYLE_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 21: ergonomic zone mode V2 bindings'
        echo
        echo 'User-facing key sequences and commands exercised through trigger-binding:'
        cat "${ACTION_LOG}"
        echo
        echo 'Live state board checkpoints:'
        cat "${STATE_BOARD_LOG}"
        echo
        echo 'Layout proof:'
        echo "main-layout-before=$(zone_log_value "${ZONES_READY_LOG}" main layout)"
        echo "main-layout-after=$(zone_log_value "${ZONES_AFTER_LAYOUT_LOG}" main layout)"
        echo "main-width-before=$(zone_log_value "${ZONES_READY_LOG}" main width)"
        echo "main-width-after=$(zone_log_value "${ZONES_AFTER_LAYOUT_LOG}" main width)"
        echo
        echo 'Availability proof:'
        echo "focus-only-left-enabled=$(zone_log_value "${ZONES_AFTER_FOCUS_ONLY_LOG}" left enabled)"
        echo "focus-only-main-enabled=$(zone_log_value "${ZONES_AFTER_FOCUS_ONLY_LOG}" main enabled)"
        echo "focus-only-right-enabled=$(zone_log_value "${ZONES_AFTER_FOCUS_ONLY_LOG}" right enabled)"
        echo "communications-right-enabled=$(zone_log_value "${ZONES_AFTER_COMMUNICATIONS_LOG}" right enabled)"
        echo
        echo 'Style proof:'
        echo "main-style-after=$(zone_log_value "${ZONES_AFTER_STYLE_LOG}" main style)"
        echo "main-color-after=$(zone_log_value "${ZONES_AFTER_STYLE_LOG}" main color)"
        echo
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: Alt-Z zone mode V2 bindings expose compact keyboard controls for snap policy, layout preset, availability sets, and current-zone styling; each binding returns to main mode and produces visible/logged zone state changes without editing the config.'
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
        echo "Unknown Slice 21 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
