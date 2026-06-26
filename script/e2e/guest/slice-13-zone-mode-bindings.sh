#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE13_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice13-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice13-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice13"
LAUNCH_PLIST="/tmp/winmux-e2e-slice13.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice13.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-13-zone-mode-bindings-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/slice-13-zone-mode-bindings-action.log"
STATE_BOARD_LOG="${ARTIFACTS_DIR}/logs/slice-13-live-state-board.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-13-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-13-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-13-cli-wait.err"
DOC_CONTENT_LOG="${ARTIFACTS_DIR}/logs/slice-13-demo-doc-content.rtf"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-13-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-13-zone-mode-bindings.done"
PROOF="${ARTIFACTS_DIR}/slice-13-zone-mode-bindings-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-setup.log"
WINDOW_BEFORE_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-before-focus-next.log"
WINDOW_AFTER_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-focus-next.log"
WINDOW_AFTER_MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-move-next.log"
WINDOW_AFTER_RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-resize.log"
WINDOW_AFTER_BALANCE_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-balance.log"
WINDOW_AFTER_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-toggle-hidden.log"
WINDOW_AFTER_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-13-windows-after-toggle-restored.log"

ZONES_BEFORE_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-before-focus-next.log"
ZONES_AFTER_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-focus-next.log"
ZONES_AFTER_MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-move-next.log"
ZONES_AFTER_RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-resize.log"
ZONES_AFTER_BALANCE_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-balance.log"
ZONES_AFTER_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-toggle-hidden.log"
ZONES_AFTER_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-13-zones-after-toggle-restored.log"

FOCUS_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-before-focus-next.log"
FOCUS_AFTER_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-focus-next.log"
FOCUS_AFTER_MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-move-next.log"
FOCUS_AFTER_RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-resize.log"
FOCUS_AFTER_BALANCE_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-balance.log"
FOCUS_AFTER_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-toggle-hidden.log"
FOCUS_AFTER_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-13-focused-after-toggle-restored.log"

DOC_DIR="${HOME}/winmux-e2e/zone-mode-bindings-docs"
BOARD_DIR="${DOC_DIR}/board"
BOARD_HTML="${BOARD_DIR}/index.html"
BOARD_STATE="${BOARD_DIR}/state.txt"
BOARD_SERVER_LOG="${ARTIFACTS_DIR}/logs/slice-13-board-http.log"
BOARD_SERVER_PID="${ARTIFACTS_DIR}/logs/slice-13-board-http.pid"
BOARD_PORT=51313
BOARD_TITLE="WinMux Zone Mode Board"
WORK_ALPHA_DOC="${DOC_DIR}/work-alpha-zone-mode.rtf"
WORK_BETA_DOC="${DOC_DIR}/work-beta-zone-mode.rtf"
COMMS_DOC="${DOC_DIR}/comms-zone-mode.rtf"

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
WINMUX ZONE MODE

Waiting for live command state.
STATE
    cat >"${BOARD_HTML}" <<'HTML'
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WinMux Zone Mode Board</title>
<style>
html, body {
    margin: 0;
    min-height: 100%;
    background: #0c1116;
    color: #f4f7fb;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
}
main {
    box-sizing: border-box;
    min-height: 100vh;
    padding: 42px 34px;
    background: linear-gradient(180deg, #15202b 0%, #0c1116 100%);
}
h1 {
    margin: 0 0 28px 0;
    font-size: 42px;
    font-weight: 780;
    letter-spacing: 0;
}
pre {
    white-space: pre-wrap;
    margin: 0;
    font: 600 28px/1.35 "SF Mono", Menlo, monospace;
}
.rule {
    width: 88px;
    height: 6px;
    margin-bottom: 28px;
    background: #3ea2ff;
}
</style>
</head>
<body>
<main>
    <h1>WinMux Zone Mode</h1>
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
    if /usr/sbin/lsof -ti "tcp:${BOARD_PORT}" >/tmp/winmux-slice13-lsof 2>/dev/null; then
        /bin/kill "$(/usr/bin/head -n 1 /tmp/winmux-slice13-lsof)" >/dev/null 2>&1 || true
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
    semantic_fail "Slice 13 board HTTP server did not become ready"
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
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

refresh_focused_window_log() {
    local path="$1"
    "${CLI}" list-windows --focused \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|layout=%{window-layout}|parent=%{window-parent-container-layout}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}" || true
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

field_for_id() {
    local path="$1"
    local id="$2"
    local key="$3"
    /usr/bin/awk -F'|' -v id="${id}" -v key="${key}" '$1 == id {
        if (key == "title") { print $2; exit }
        for (i = 3; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "${path}"
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

zone_for_title() {
    field_for_title "$1" "$2" zone
}

workspace_for_title() {
    field_for_title "$1" "$2" workspace
}

window_id_for_title() {
    field_for_title "$1" "$2" id
}

window_title_for_id() {
    field_for_id "$1" "$2" title
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

assert_id_zone() {
    local path="$1"
    local id="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(field_for_id "${path}" "${id}" zone)"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected window id ${id} in zone ${expected_zone}, got ${actual_zone:-missing}"
    fi
}

assert_tab_group_parent() {
    local path="$1"
    local title="$2"
    local parent
    parent="$(field_for_title "${path}" "${title}" parent)"
    case "${parent}" in
        *tab_group*) ;;
        *) cat "${path}" >&2 || true; semantic_fail "Expected ${title} parent layout to be a tab group, got ${parent:-missing}" ;;
    esac
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} > ${right}"
}

assert_widths_approximately_equal() {
    local left_width="$1"
    local main_width="$2"
    local right_width="$3"
    /usr/bin/awk -v left="${left_width}" -v main="${main_width}" -v right="${right_width}" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - main) <= 3 && abs(main - right) <= 3 ? 0 : 1) }
    ' || semantic_fail "Expected balanced widths, got left=${left_width} main=${main_width} right=${right_width}"
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

wait_for_demo_windows() {
    for _ in $(seq 1 90); do
        if refresh_window_log "${WINDOW_SETUP_LOG}" &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" "${BOARD_TITLE}")" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-alpha-zone-mode.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-beta-zone-mode.rtf')" ] &&
            [ -n "$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-zone-mode.rtf')" ]; then
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-13-zone-count.txt" 2>"${WAIT_ERR}"; then
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

mode_now() {
    "${CLI}" list-modes --current | /usr/bin/tail -n 1 | /usr/bin/tr -d '\r'
}

width_summary() {
    local zones_log="$1"
    /usr/bin/awk -F'|' '
        /^zone=/ {
            zone = substr($1, 6)
            enabled = "true"
            width = "hidden"
            for (i = 1; i <= NF; i++) {
                if (index($i, "enabled=") == 1) { enabled = substr($i, 9) }
                if (index($i, "width=") == 1) { width = substr($i, 7) }
            }
            if (enabled == "false" || width == "") {
                width = "hidden"
            }
            values[zone] = width
        }
        END {
            printf "L:%s M:%s R:%s",
                (("left" in values) ? values["left"] : "hidden"),
                (("main" in values) ? values["main"] : "hidden"),
                (("right" in values) ? values["right"] : "hidden")
        }
    ' "${zones_log}"
}

state_board_entry() {
    local checkpoint="$1"
    local binding="$2"
    local winmux_command="$3"
    local resolved_target="$4"
    local selected_title_hint="$5"
    local window_log="$6"
    local zones_log="$7"
    local focus_log="$8"

    write_zones_log "${zones_log}"
    write_focused_log "${focus_log}"
    refresh_window_log "${window_log}"

    local focused_zone focused_workspace selected_id selected_title selected_zone selected_workspace widths
    focused_zone="$(focused_field "${focus_log}" focused-zone)"
    focused_workspace="$(focused_field "${focus_log}" workspace)"
    selected_id=""
    selected_title="${selected_title_hint}"
    selected_zone=""
    selected_workspace=""

    if [ -n "${selected_title_hint}" ]; then
        selected_id="$(window_id_for_title "${window_log}" "${selected_title_hint}")"
        selected_zone="$(zone_for_title "${window_log}" "${selected_title_hint}")"
        selected_workspace="$(workspace_for_title "${window_log}" "${selected_title_hint}")"
    fi
    if [ -z "${selected_id}" ]; then
        local focused_window_log="${ARTIFACTS_DIR}/logs/slice-13-focused-window-${checkpoint}.log"
        refresh_focused_window_log "${focused_window_log}"
        selected_id="$(/usr/bin/awk -F'|' 'NR == 1 { print $1 }' "${focused_window_log}")"
        selected_title="$(/usr/bin/awk -F'|' 'NR == 1 { print $2 }' "${focused_window_log}")"
        selected_zone="$(field_for_id "${focused_window_log}" "${selected_id}" zone)"
        selected_workspace="$(field_for_id "${focused_window_log}" "${selected_id}" workspace)"
    fi
    if [ -z "${selected_id}" ]; then
        selected_id="none"
        selected_title="${selected_title_hint:-none}"
        selected_zone="hidden-or-none"
        selected_workspace="hidden-or-none"
    fi

    widths="$(width_summary "${zones_log}")"
    {
        printf 'checkpoint=%s|binding=%s|winmux-command=%s|resolved-target=%s|current-zone=%s|active-workspace=%s|selected-window-id=%s|selected-title=%s|selected-zone=%s|selected-workspace=%s|widths=%s\n' \
            "${checkpoint}" "${binding}" "${winmux_command}" "${resolved_target}" "${focused_zone:-unknown}" "${focused_workspace:-unknown}" \
            "${selected_id}" "${selected_title:-unknown}" "${selected_zone:-unknown}" "${selected_workspace:-unknown}" "${widths}"
    } >>"${STATE_BOARD_LOG}"

    local board_text
    board_text="$(cat <<BOARD
WINMUX ZONE MODE

Step: ${binding}
Action: ${winmux_command}
Target: ${resolved_target}

Current: ${focused_zone:-unknown}
Workspace: ${focused_workspace:-unknown}
Window id: ${selected_id}
Title: ${selected_title:-unknown}
Zone: ${selected_zone:-unknown}

Widths
${widths}

Checkpoint
${checkpoint}
BOARD
)"
    set_board_text "${board_text}"
    if [ "${selected_id}" != "none" ]; then
        "${CLI}" focus --window-id "${selected_id}" >/dev/null 2>>"${WAIT_ERR}" || true
    fi
}

run_zone_binding() {
    local key="$1"
    local binding="$2"
    local winmux_command="$3"
    local timing_key="$4"

    echo "${timing_key}-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "binding=${binding}"
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
        [ "${mode_after_binding}" = "main" ] || semantic_fail "Expected main mode after ${binding}, got ${mode_after_binding:-missing}"
    } | tee -a "${ACTION_LOG}"
}

setup_slice() {
    rm -f \
        "${DONE}" "${SETUP_LOG}" "${ACTION_LOG}" "${STATE_BOARD_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${DOC_CONTENT_LOG}" "${STATE_FILE}" "${PROOF}" \
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_FOCUS_LOG}" "${WINDOW_AFTER_FOCUS_LOG}" "${WINDOW_AFTER_MOVE_LOG}" \
        "${WINDOW_AFTER_RESIZE_LOG}" "${WINDOW_AFTER_BALANCE_LOG}" "${WINDOW_AFTER_HIDDEN_LOG}" "${WINDOW_AFTER_RESTORED_LOG}" \
        "${ZONES_BEFORE_FOCUS_LOG}" "${ZONES_AFTER_FOCUS_LOG}" "${ZONES_AFTER_MOVE_LOG}" "${ZONES_AFTER_RESIZE_LOG}" \
        "${ZONES_AFTER_BALANCE_LOG}" "${ZONES_AFTER_HIDDEN_LOG}" "${ZONES_AFTER_RESTORED_LOG}" \
        "${FOCUS_BEFORE_LOG}" "${FOCUS_AFTER_FOCUS_LOG}" "${FOCUS_AFTER_MOVE_LOG}" "${FOCUS_AFTER_RESIZE_LOG}" \
        "${FOCUS_AFTER_BALANCE_LOG}" "${FOCUS_AFTER_HIDDEN_LOG}" "${FOCUS_AFTER_RESTORED_LOG}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" "${BOARD_SERVER_LOG}" "${BOARD_SERVER_PID}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 13: zone mode bindings and relative selectors'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: alt-z opens [mode.zone.binding]'
        echo 'Bindings: L focus-zone next; Shift-L move-node-to-zone next; Equal resize-zone current; 0 balance-zones; T toggle-zone current'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_initial_board_doc
    start_board_server
    write_doc "${WORK_ALPHA_DOC}" "WORK ALPHA" "tab group member A" "Moves with the focused tab group."
    write_doc "${WORK_BETA_DOC}" "WORK BETA" "tab group member B" "Moves with the focused tab group."
    write_doc "${COMMS_DOC}" "COMMS" "right-side anchor" "Stays in the Comms column while the Work group moves."
    cat "${WORK_ALPHA_DOC}" "${WORK_BETA_DOC}" "${COMMS_DOC}" >"${DOC_CONTENT_LOG}"

    launch_winmux
    /usr/bin/open -a Safari "http://127.0.0.1:${BOARD_PORT}/index.html"
    /usr/bin/open -a TextEdit "${WORK_ALPHA_DOC}" "${WORK_BETA_DOC}" "${COMMS_DOC}"
    wait_for_demo_windows || {
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'Demo windows did not appear'
    }

    local board_id work_alpha_id work_beta_id comms_id
    board_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" "${BOARD_TITLE}")"
    work_alpha_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-alpha-zone-mode.rtf')"
    work_beta_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-beta-zone-mode.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-zone-mode.rtf')"
    test -n "${board_id}"
    test -n "${work_alpha_id}"
    test -n "${work_beta_id}"
    test -n "${comms_id}"

    move_window_to_zone "${board_id}" "${BOARD_TITLE}" Reference left
    move_window_to_zone "${work_alpha_id}" 'work-alpha-zone-mode.rtf' Work main
    move_window_to_zone "${work_beta_id}" 'work-beta-zone-mode.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-zone-mode.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_beta_id}"
    if ! "${CLI}" stack-with left >>"${SETUP_LOG}" 2>>"${WAIT_ERR}"; then
        "${CLI}" stack-with right >>"${SETUP_LOG}" 2>>"${WAIT_ERR}" || semantic_fail 'Could not create Work tab group for Slice 13'
    fi
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_tab_group_parent "${WINDOW_SETUP_LOG}" 'work-alpha-zone-mode.rtf'
    assert_tab_group_parent "${WINDOW_SETUP_LOG}" 'work-beta-zone-mode.rtf'

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_alpha_id}"
    sleep 1
    "${CLI}" focus-zone Reference
    "${CLI}" focus --window-id "${board_id}"
    refresh_window_log "${WINDOW_BEFORE_FOCUS_LOG}"
    write_zones_log "${ZONES_BEFORE_FOCUS_LOG}"
    write_focused_log "${FOCUS_BEFORE_LOG}"

    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" "${BOARD_TITLE}" left
    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" 'work-alpha-zone-mode.rtf' main
    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" 'work-beta-zone-mode.rtf' main
    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" 'comms-zone-mode.rtf' right

    cat >"${STATE_FILE}" <<STATE
BOARD_ID=${board_id}
WORK_ALPHA_ID=${work_alpha_id}
WORK_BETA_ID=${work_beta_id}
COMMS_ID=${comms_id}
STATE

    state_board_entry \
        'before-focus-next' \
        'Alt-Z, L' \
        'focus-zone next' \
        'main/Work' \
        "${BOARD_TITLE}" \
        "${WINDOW_BEFORE_FOCUS_LOG}" \
        "${ZONES_BEFORE_FOCUS_LOG}" \
        "${FOCUS_BEFORE_LOG}"

    {
        echo 'setup-result=success'
        echo "board-window-id=${board_id}"
        echo "work-alpha-window-id=${work_alpha_id}"
        echo "work-beta-window-id=${work_beta_id}"
        echo "comms-window-id=${comms_id}"
        echo 'work-tab-group=work-alpha-zone-mode.rtf+work-beta-zone-mode.rtf'
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
    test -n "${WORK_ALPHA_ID:-}"
    test -n "${WORK_BETA_ID:-}"

    "${CLI}" focus-zone Reference
    "${CLI}" focus --window-id "${BOARD_ID}"
    state_board_entry \
        'before-focus-next' \
        'Alt-Z, L' \
        'focus-zone next' \
        'main/Work' \
        "${BOARD_TITLE}" \
        "${WINDOW_BEFORE_FOCUS_LOG}" \
        "${ZONES_BEFORE_FOCUS_LOG}" \
        "${FOCUS_BEFORE_LOG}"
    sleep 1
    capture_guest_screenshot '02-before-focus-next-slice-13'
    sleep 5

    run_zone_binding l 'Alt-Z, L' 'focus-zone next' focus-next
    sleep 1
    state_board_entry \
        'after-focus-next' \
        'Alt-Z, L' \
        'focus-zone next' \
        'main/Work' \
        'work-alpha-zone-mode.rtf' \
        "${WINDOW_AFTER_FOCUS_LOG}" \
        "${ZONES_AFTER_FOCUS_LOG}" \
        "${FOCUS_AFTER_FOCUS_LOG}"
    sleep 1
    capture_guest_screenshot '03-after-focus-next-slice-13'
    sleep 5

    run_zone_binding shift-l 'Alt-Z, Shift-L' 'move-node-to-zone --focus-follows-window next' move-next
    sleep 2
    state_board_entry \
        'after-move-next' \
        'Alt-Z, Shift-L' \
        'move-node-to-zone --focus-follows-window next' \
        'right/Comms' \
        'work-alpha-zone-mode.rtf' \
        "${WINDOW_AFTER_MOVE_LOG}" \
        "${ZONES_AFTER_MOVE_LOG}" \
        "${FOCUS_AFTER_MOVE_LOG}"
    sleep 1
    capture_guest_screenshot '04-after-move-next-slice-13'
    sleep 6

    run_zone_binding equal 'Alt-Z, Equal' 'resize-zone current width +10%' resize-current
    sleep 2
    state_board_entry \
        'after-resize-current' \
        'Alt-Z, Equal' \
        'resize-zone current width +10%' \
        'right/Comms' \
        'work-alpha-zone-mode.rtf' \
        "${WINDOW_AFTER_RESIZE_LOG}" \
        "${ZONES_AFTER_RESIZE_LOG}" \
        "${FOCUS_AFTER_RESIZE_LOG}"
    sleep 1
    capture_guest_screenshot '05-after-resize-slice-13'
    sleep 6

    run_zone_binding 0 'Alt-Z, 0' 'balance-zones' balance-zones
    sleep 2
    state_board_entry \
        'after-balance-zones' \
        'Alt-Z, 0' \
        'balance-zones' \
        'all-enabled-zones' \
        'work-alpha-zone-mode.rtf' \
        "${WINDOW_AFTER_BALANCE_LOG}" \
        "${ZONES_AFTER_BALANCE_LOG}" \
        "${FOCUS_AFTER_BALANCE_LOG}"
    sleep 1
    capture_guest_screenshot '06-after-balance-slice-13'
    sleep 6

    run_zone_binding t 'Alt-Z, T' 'toggle-zone current' toggle-hidden
    sleep 2
    state_board_entry \
        'after-toggle-hidden' \
        'Alt-Z, T' \
        'toggle-zone current' \
        'right/Comms' \
        '' \
        "${WINDOW_AFTER_HIDDEN_LOG}" \
        "${ZONES_AFTER_HIDDEN_LOG}" \
        "${FOCUS_AFTER_HIDDEN_LOG}"
    sleep 1
    capture_guest_screenshot '07-after-toggle-hidden-slice-13'
    sleep 6

    run_zone_binding t 'Alt-Z, T' 'toggle-zone current' toggle-restored
    sleep 2
    state_board_entry \
        'after-toggle-restored' \
        'Alt-Z, T' \
        'toggle-zone current' \
        'right/Comms' \
        'work-alpha-zone-mode.rtf' \
        "${WINDOW_AFTER_RESTORED_LOG}" \
        "${ZONES_AFTER_RESTORED_LOG}" \
        "${FOCUS_AFTER_RESTORED_LOG}"
    sleep 1
    capture_guest_screenshot '08-after-toggle-restored-slice-13'
    sleep 8

    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" 'work-alpha-zone-mode.rtf' main
    assert_window_zone "${WINDOW_BEFORE_FOCUS_LOG}" 'work-beta-zone-mode.rtf' main
    assert_window_zone "${WINDOW_AFTER_MOVE_LOG}" 'work-alpha-zone-mode.rtf' right
    assert_window_zone "${WINDOW_AFTER_MOVE_LOG}" 'work-beta-zone-mode.rtf' right
    assert_window_zone "${WINDOW_AFTER_RESTORED_LOG}" 'work-alpha-zone-mode.rtf' right
    assert_window_zone "${WINDOW_AFTER_RESTORED_LOG}" 'work-beta-zone-mode.rtf' right
    assert_id_zone "${WINDOW_AFTER_MOVE_LOG}" "${WORK_ALPHA_ID}" right
    assert_id_zone "${WINDOW_AFTER_MOVE_LOG}" "${WORK_BETA_ID}" right
    assert_id_zone "${WINDOW_AFTER_RESTORED_LOG}" "${WORK_ALPHA_ID}" right
    assert_id_zone "${WINDOW_AFTER_RESTORED_LOG}" "${WORK_BETA_ID}" right
    assert_tab_group_parent "${WINDOW_AFTER_MOVE_LOG}" 'work-alpha-zone-mode.rtf'
    assert_tab_group_parent "${WINDOW_AFTER_MOVE_LOG}" 'work-beta-zone-mode.rtf'

    local before_right_width resized_right_width balanced_left_width balanced_main_width balanced_right_width
    before_right_width="$(zone_log_value "${ZONES_AFTER_MOVE_LOG}" right width)"
    resized_right_width="$(zone_log_value "${ZONES_AFTER_RESIZE_LOG}" right width)"
    balanced_left_width="$(zone_log_value "${ZONES_AFTER_BALANCE_LOG}" left width)"
    balanced_main_width="$(zone_log_value "${ZONES_AFTER_BALANCE_LOG}" main width)"
    balanced_right_width="$(zone_log_value "${ZONES_AFTER_BALANCE_LOG}" right width)"
    assert_float_gt "${resized_right_width}" "${before_right_width}" 'Comms/right width did not grow after resize-zone current'
    assert_widths_approximately_equal "${balanced_left_width}" "${balanced_main_width}" "${balanced_right_width}"

    local hidden_right_enabled restored_right_enabled
    hidden_right_enabled="$(zone_log_value "${ZONES_AFTER_HIDDEN_LOG}" right enabled)"
    restored_right_enabled="$(zone_log_value "${ZONES_AFTER_RESTORED_LOG}" right enabled)"
    if [ -n "${hidden_right_enabled}" ] && [ "${hidden_right_enabled}" != "false" ]; then
        semantic_fail "Expected right zone hidden/disabled after toggle, got enabled=${hidden_right_enabled}"
    fi
    [ "${restored_right_enabled}" = "true" ] || semantic_fail "Expected right zone restored/enabled, got ${restored_right_enabled:-missing}"

    cat \
        "${ACTION_LOG}" "${STATE_BOARD_LOG}" "${TIMING_LOG}" \
        "${WINDOW_BEFORE_FOCUS_LOG}" "${WINDOW_AFTER_FOCUS_LOG}" "${WINDOW_AFTER_MOVE_LOG}" \
        "${WINDOW_AFTER_RESIZE_LOG}" "${WINDOW_AFTER_BALANCE_LOG}" "${WINDOW_AFTER_HIDDEN_LOG}" "${WINDOW_AFTER_RESTORED_LOG}" \
        "${ZONES_BEFORE_FOCUS_LOG}" "${ZONES_AFTER_FOCUS_LOG}" "${ZONES_AFTER_MOVE_LOG}" \
        "${ZONES_AFTER_RESIZE_LOG}" "${ZONES_AFTER_BALANCE_LOG}" "${ZONES_AFTER_HIDDEN_LOG}" "${ZONES_AFTER_RESTORED_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 13: zone mode bindings and relative selectors'
        echo
        echo 'User-facing commands exercised through trigger-binding:'
        cat "${ACTION_LOG}"
        echo
        echo 'Live state board checkpoints:'
        cat "${STATE_BOARD_LOG}"
        echo
        echo 'Window movement proof:'
        echo "work-alpha-id=${WORK_ALPHA_ID}"
        echo "work-beta-id=${WORK_BETA_ID}"
        echo "before-work-alpha-zone=$(field_for_id "${WINDOW_BEFORE_FOCUS_LOG}" "${WORK_ALPHA_ID}" zone)"
        echo "after-move-work-alpha-zone=$(field_for_id "${WINDOW_AFTER_MOVE_LOG}" "${WORK_ALPHA_ID}" zone)"
        echo "after-restore-work-alpha-zone=$(field_for_id "${WINDOW_AFTER_RESTORED_LOG}" "${WORK_ALPHA_ID}" zone)"
        echo
        echo 'Width proof:'
        echo "right-width-before-resize=${before_right_width}"
        echo "right-width-after-resize=${resized_right_width}"
        echo "balanced-widths=left:${balanced_left_width},main:${balanced_main_width},right:${balanced_right_width}"
        echo
        echo 'Toggle proof:'
        echo "right-enabled-after-hide=${hidden_right_enabled:-absent}"
        echo "right-enabled-after-restore=${restored_right_enabled}"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: Alt-Z zone mode bindings focus next zone, move a focused Work tab group to the next zone, resize current zone, balance zones, and toggle current zone hidden/restored with live state board proof.'
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
        echo "Unknown Slice 13 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
