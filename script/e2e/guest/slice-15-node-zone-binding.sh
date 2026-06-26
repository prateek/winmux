#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE15_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice15-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice15-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice15"
LAUNCH_PLIST="/tmp/winmux-e2e-slice15.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice15.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-15-node-binding-setup.log"
BINDINGS_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-15-zone-bindings-before.log"
BINDINGS_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-15-zone-bindings-after.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-15-zones-before.log"
ZONES_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-15-zones-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-15-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-15-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-15-windows-after.log"
STACK_LOG="${ARTIFACTS_DIR}/logs/slice-15-stack-tab-group.log"
BIND_LOG="${ARTIFACTS_DIR}/logs/slice-15-bind-node-to-zone.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-15-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-15-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-15-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-15-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-15-node-zone-binding.done"
PROOF="${ARTIFACTS_DIR}/slice-15-node-zone-binding-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/node-zone-binding-docs"
REFERENCE_DOC="${DOC_DIR}/reference-node-binding.rtf"
WORK_ALPHA_DOC="${DOC_DIR}/work-alpha-node-binding.rtf"
WORK_BETA_DOC="${DOC_DIR}/work-beta-node-binding.rtf"

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
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\qc\f0\fs88\b ${headline}\b0\par\fs42 ${subtitle}\par\f1\fs30 ${detail}\par}
RTF
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
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

write_bindings_count() {
    "${CLI}" list-zone-bindings --count 2>>"${WAIT_ERR}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|layout=%{window-layout}|parent=%{window-parent-container-layout}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local field="$3"
    /usr/bin/awk -F'|' -v title="${title}" -v field="${field}" '$2 == title {
        if (field == "id") { print $1; exit }
        prefix = field "="
        for (i = 1; i <= NF; i++) {
            if (index($i, prefix) == 1) {
                print substr($i, length(prefix) + 1)
                exit
            }
        }
    }' "${path}"
}

zone_log_value() {
    local path="$1"
    local zone="$2"
    local field="$3"
    /usr/bin/awk -F'|' -v zone="zone=${zone}" -v field="${field}" '$1 == zone {
        prefix = field "="
        for (i = 1; i <= NF; i++) {
            if (index($i, prefix) == 1) {
                print substr($i, length(prefix) + 1)
                exit
            }
        }
    }' "${path}"
}

window_id_for_title() {
    field_for_title "$1" "$2" id
}

sorted_tab_group_key() {
    local first="$1"
    local second="$2"
    local ids
    ids="$(printf '%s\n%s\n' "${first}" "${second}" | /usr/bin/sort -n | /usr/bin/paste -sd, -)"
    printf 'tab-group:%s\n' "${ids}"
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(field_for_title "${path}" "${title}" zone)"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        echo "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}" >&2
        cat "${path}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi
}

assert_window_parent_is_tab_group() {
    local path="$1"
    local title="$2"
    local parent
    parent="$(field_for_title "${path}" "${title}" parent)"
    case "${parent}" in
        *tab_group*) ;;
        *)
            echo "Expected ${title} to be in a tab group, got parent=${parent:-missing}" >&2
            cat "${path}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
            ;;
    esac
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

run_logged() {
    local log_path="$1"
    shift
    {
        printf '$'
        printf ' %q' "$@"
        printf '\n'
        "$@"
    } | tee -a "${log_path}" | tee -a "${CLI_LOG}" >/dev/null
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-15-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${BINDINGS_BEFORE_LOG}" "${BINDINGS_AFTER_LOG}" \
        "${ZONES_BEFORE_LOG}" "${ZONES_AFTER_LOG}" "${WINDOW_SETUP_LOG}" \
        "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" "${STACK_LOG}" "${BIND_LOG}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 15: runtime tab-group zone binding'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo "Config: [mode.main.binding] alt-b = 'bind-node-to-zone Comms'"
        echo 'Command: bind-node-to-zone Comms'
        echo 'Command: list-zone-bindings'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" 'REFERENCE' 'left zone context' 'the tab-group binding proof happens in Work and Comms'
    write_doc "${WORK_ALPHA_DOC}" 'WORK TAB ALPHA' 'tab group before bind-node-to-zone' 'window id stays with the tab group'
    write_doc "${WORK_BETA_DOC}" 'WORK TAB BETA' 'same tab group before bind-node-to-zone' 'binding target will be Comms/right'

    launch_winmux

    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${WORK_ALPHA_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${WORK_BETA_DOC}"

    if ! wait_for_textedit_windows 3; then
        echo 'TextEdit windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-node-binding.rtf')"
    WORK_ALPHA_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-alpha-node-binding.rtf')"
    WORK_BETA_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-beta-node-binding.rtf')"
    for id in "${REFERENCE_ID}" "${WORK_ALPHA_ID}" "${WORK_BETA_ID}"; do
        if [ -z "${id}" ]; then
            echo 'Could not resolve all TextEdit window ids' >&2
            cat "${WINDOW_SETUP_LOG}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
        fi
    done

    run_logged "${CLI_LOG}" "${CLI}" move-node-to-zone --window-id "${REFERENCE_ID}" Reference
    run_logged "${CLI_LOG}" "${CLI}" move-node-to-zone --window-id "${WORK_ALPHA_ID}" Work
    run_logged "${CLI_LOG}" "${CLI}" move-node-to-zone --window-id "${WORK_BETA_ID}" Work

    if ! run_logged "${STACK_LOG}" "${CLI}" stack-with --window-id "${WORK_ALPHA_ID}" right; then
        run_logged "${STACK_LOG}" "${CLI}" stack-with --window-id "${WORK_BETA_ID}" left
    fi
    run_logged "${CLI_LOG}" "${CLI}" focus-zone Work
    run_logged "${CLI_LOG}" "${CLI}" focus --window-id "${WORK_ALPHA_ID}"

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-node-binding.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-alpha-node-binding.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-beta-node-binding.rtf' main
    assert_window_parent_is_tab_group "${WINDOW_BEFORE_LOG}" 'work-alpha-node-binding.rtf'
    assert_window_parent_is_tab_group "${WINDOW_BEFORE_LOG}" 'work-beta-node-binding.rtf'
    write_zones_log "${ZONES_BEFORE_LOG}"
    write_bindings_log "${BINDINGS_BEFORE_LOG}"
    before_binding_count="$(write_bindings_count)"
    [ "${before_binding_count}" = 0 ] || semantic_fail "Expected zero node zone bindings before proof, got ${before_binding_count}"

    TAB_GROUP_KEY="$(sorted_tab_group_key "${WORK_ALPHA_ID}" "${WORK_BETA_ID}")"
    COMMS_WORKSPACE_BEFORE="$(zone_log_value "${ZONES_BEFORE_LOG}" right workspace)"
    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${REFERENCE_ID}
WORK_ALPHA_ID=${WORK_ALPHA_ID}
WORK_BETA_ID=${WORK_BETA_ID}
TAB_GROUP_KEY=${TAB_GROUP_KEY}
COMMS_WORKSPACE_BEFORE=${COMMS_WORKSPACE_BEFORE}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=work-tab-group-visible-with-zero-bindings'
        echo "work-alpha-window-id=${WORK_ALPHA_ID}"
        echo "work-beta-window-id=${WORK_BETA_ID}"
        echo "tab-group-key=${TAB_GROUP_KEY}"
        echo "comms-workspace-before=${COMMS_WORKSPACE_BEFORE}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${WORK_ALPHA_ID:-}"
    test -n "${WORK_BETA_ID:-}"
    test -n "${TAB_GROUP_KEY:-}"

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}"
    write_bindings_log "${BINDINGS_BEFORE_LOG}"
    [ "$(write_bindings_count)" = 0 ] || semantic_fail 'Expected zero bindings before bind-node-to-zone'
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-alpha-node-binding.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-beta-node-binding.rtf' main
    assert_window_parent_is_tab_group "${WINDOW_BEFORE_LOG}" 'work-alpha-node-binding.rtf'
    assert_window_parent_is_tab_group "${WINDOW_BEFORE_LOG}" 'work-beta-node-binding.rtf'
    sleep 18

    bind_offset="${SECONDS}"
    echo "bind-command-offset-seconds=${bind_offset}" >>"${TIMING_LOG}"
    {
        echo 'winmux-e2e-mutation-started=1'
        echo '$ winmux bind-node-to-zone Comms'
        "${CLI}" bind-node-to-zone Comms
    } | tee "${BIND_LOG}"
    sleep 4

    for _ in $(seq 1 30); do
        write_bindings_log "${BINDINGS_AFTER_LOG}"
        refresh_window_log "${WINDOW_AFTER_LOG}"
        if /usr/bin/grep -F "node-id=${TAB_GROUP_KEY}|" "${BINDINGS_AFTER_LOG}" >/dev/null &&
           [ "$(field_for_title "${WINDOW_AFTER_LOG}" 'work-alpha-node-binding.rtf' zone)" = right ] &&
           [ "$(field_for_title "${WINDOW_AFTER_LOG}" 'work-beta-node-binding.rtf' zone)" = right ]; then
            break
        fi
        sleep 1
    done

    /usr/bin/grep -F "Bound ${TAB_GROUP_KEY} to zone right on monitor 1" "${BIND_LOG}" >/dev/null \
        || semantic_fail "bind-node-to-zone output did not bind ${TAB_GROUP_KEY} to right"
    /usr/bin/grep -F "node-id=${TAB_GROUP_KEY}|" "${BINDINGS_AFTER_LOG}" >/dev/null \
        || semantic_fail "list-zone-bindings missing ${TAB_GROUP_KEY}"
    /usr/bin/grep -F 'node-type=tab-group' "${BINDINGS_AFTER_LOG}" >/dev/null \
        || semantic_fail 'list-zone-bindings does not report node-type=tab-group'
    /usr/bin/grep -F 'zone=right' "${BINDINGS_AFTER_LOG}" >/dev/null \
        || semantic_fail 'list-zone-bindings does not report zone=right'
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-alpha-node-binding.rtf' right
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-beta-node-binding.rtf' right
    assert_window_parent_is_tab_group "${WINDOW_AFTER_LOG}" 'work-alpha-node-binding.rtf'
    assert_window_parent_is_tab_group "${WINDOW_AFTER_LOG}" 'work-beta-node-binding.rtf'
    write_zones_log "${ZONES_AFTER_LOG}"

    sleep 8
    refresh_window_log "${WINDOW_AFTER_LOG}"
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-alpha-node-binding.rtf' right
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-beta-node-binding.rtf' right
    assert_window_parent_is_tab_group "${WINDOW_AFTER_LOG}" 'work-alpha-node-binding.rtf'
    assert_window_parent_is_tab_group "${WINDOW_AFTER_LOG}" 'work-beta-node-binding.rtf'

    cat "${BINDINGS_BEFORE_LOG}" "${BIND_LOG}" "${TIMING_LOG}" "${BINDINGS_AFTER_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" >>"${CLI_LOG}"

    {
        echo 'WinMux Slice 15: runtime tab-group zone binding'
        echo
        echo 'Before node bindings:'
        cat "${BINDINGS_BEFORE_LOG}"
        echo
        echo 'Before visible windows:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Bind command:'
        cat "${BIND_LOG}"
        echo
        echo 'Command timing:'
        cat "${TIMING_LOG}"
        echo
        echo 'After node bindings:'
        cat "${BINDINGS_AFTER_LOG}"
        echo
        echo 'After visible windows:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo "bind-command-offset-seconds=${bind_offset}"
        echo "tab-group-key=${TAB_GROUP_KEY}"
        echo 'PASS: bind-node-to-zone moved the focused Work tab group into Comms/right and list-zone-bindings recorded the same tab-group node id.'
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
        echo "Unknown WINMUX_E2E_SLICE15_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
