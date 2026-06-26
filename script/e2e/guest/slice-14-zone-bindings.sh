#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE14_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice14-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice14-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice14"
LAUNCH_PLIST="/tmp/winmux-e2e-slice14.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice14.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-14-zone-bindings-setup.log"
BINDINGS_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-14-bindings-before.log"
BINDINGS_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-14-bindings-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-14-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-14-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-14-windows-after.log"
APPLY_LOG="${ARTIFACTS_DIR}/logs/slice-14-apply-zone-bindings.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-14-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-14-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-14-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-14-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-14-zone-bindings.done"
PROOF="${ARTIFACTS_DIR}/slice-14-zone-bindings-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-bindings-docs"
BEFORE_REFERENCE_DOC="${DOC_DIR}/before-reference-zone-binding.rtf"
BEFORE_WORK_DOC="${DOC_DIR}/before-work-zone-binding.rtf"
BEFORE_COMMS_DOC="${DOC_DIR}/before-comms-zone-binding.rtf"
BOUND_REFERENCE_DOC="${DOC_DIR}/bound-reference-desk.rtf"
BOUND_WORK_DOC="${DOC_DIR}/bound-work-desk.rtf"
BOUND_COMMS_DOC="${DOC_DIR}/bound-comms-desk.rtf"

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
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\qc\f0\fs92\b ${headline}\b0\par\fs46 ${subtitle}\par\f1\fs32 ${detail}\par}
RTF
}

write_bindings_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

binding_field_for_zone() {
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

workspace_for_zone() {
    binding_field_for_zone "$1" "$2" workspace
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

move_window_to_workspace() {
    local id="$1"
    local title="$2"
    local workspace="$3"
    {
        echo "setup: ${title} -> workspace ${workspace}"
        echo "$ winmux move-node-to-workspace --window-id ${id} ${workspace}"
        "${CLI}" move-node-to-workspace --window-id "${id}" "${workspace}"
    } | tee -a "${CLI_LOG}"
}

move_window_to_zone() {
    local id="$1"
    local title="$2"
    local zone="$3"
    {
        echo "setup: ${title} -> zone ${zone}"
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone}"
    } | tee -a "${CLI_LOG}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-14-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
        "${APPLY_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 14: workspace zone bindings'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-bindings]] ReferenceDesk + WorkDesk + CommsDesk'
        echo 'Command: apply-zone-bindings'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${BEFORE_REFERENCE_DOC}" 'BEFORE REFERENCE' 'unbound workspace before apply-zone-bindings' 'zone: Reference / left'
    write_doc "${BEFORE_WORK_DOC}" 'BEFORE WORK' 'unbound workspace before apply-zone-bindings' 'zone: Work / main'
    write_doc "${BEFORE_COMMS_DOC}" 'BEFORE COMMS' 'unbound workspace before apply-zone-bindings' 'zone: Comms / right'
    write_doc "${BOUND_REFERENCE_DOC}" 'BOUND REFERENCE' 'workspace: ReferenceDesk' 'appears after winmux apply-zone-bindings'
    write_doc "${BOUND_WORK_DOC}" 'BOUND WORK' 'workspace: WorkDesk' 'appears after winmux apply-zone-bindings'
    write_doc "${BOUND_COMMS_DOC}" 'BOUND COMMS' 'workspace: CommsDesk' 'appears after winmux apply-zone-bindings'

    launch_winmux

    /usr/bin/open -a TextEdit "${BEFORE_REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${BEFORE_WORK_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${BEFORE_COMMS_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${BOUND_REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${BOUND_WORK_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${BOUND_COMMS_DOC}"

    if ! wait_for_textedit_windows 6; then
        echo 'TextEdit windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi

    BEFORE_REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'before-reference-zone-binding.rtf')"
    BEFORE_WORK_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'before-work-zone-binding.rtf')"
    BEFORE_COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'before-comms-zone-binding.rtf')"
    BOUND_REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'bound-reference-desk.rtf')"
    BOUND_WORK_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'bound-work-desk.rtf')"
    BOUND_COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'bound-comms-desk.rtf')"

    for id in "${BEFORE_REFERENCE_ID}" "${BEFORE_WORK_ID}" "${BEFORE_COMMS_ID}" "${BOUND_REFERENCE_ID}" "${BOUND_WORK_ID}" "${BOUND_COMMS_ID}"; do
        if [ -z "${id}" ]; then
            echo 'Could not resolve all TextEdit window ids' >&2
            cat "${WINDOW_SETUP_LOG}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
        fi
    done

    move_window_to_zone "${BEFORE_REFERENCE_ID}" 'before-reference-zone-binding.rtf' Reference
    move_window_to_zone "${BEFORE_WORK_ID}" 'before-work-zone-binding.rtf' Work
    move_window_to_zone "${BEFORE_COMMS_ID}" 'before-comms-zone-binding.rtf' Comms
    move_window_to_workspace "${BOUND_REFERENCE_ID}" 'bound-reference-desk.rtf' ReferenceDesk
    move_window_to_workspace "${BOUND_WORK_ID}" 'bound-work-desk.rtf' WorkDesk
    move_window_to_workspace "${BOUND_COMMS_ID}" 'bound-comms-desk.rtf' CommsDesk

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${BEFORE_WORK_ID}"
    write_bindings_log "${BINDINGS_BEFORE_LOG}" | tee -a "${SETUP_LOG}" >/dev/null
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'before-reference-zone-binding.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'before-work-zone-binding.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'before-comms-zone-binding.rtf' right
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'bound-reference-desk.rtf'
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'bound-work-desk.rtf'
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'bound-comms-desk.rtf'

    cat >"${STATE_FILE}" <<STATE
BEFORE_REFERENCE_ID=${BEFORE_REFERENCE_ID}
BEFORE_WORK_ID=${BEFORE_WORK_ID}
BEFORE_COMMS_ID=${BEFORE_COMMS_ID}
BOUND_WORK_ID=${BOUND_WORK_ID}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=unbound-before-documents-visible'
        echo "before-work-window-id=${BEFORE_WORK_ID}"
        echo "bound-work-window-id=${BOUND_WORK_ID}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${BEFORE_REFERENCE_ID:-}"
    test -n "${BEFORE_WORK_ID:-}"
    test -n "${BEFORE_COMMS_ID:-}"
    test -n "${BOUND_WORK_ID:-}"

    write_bindings_log "${BINDINGS_BEFORE_LOG}" >/dev/null
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'before-work-zone-binding.rtf' main
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'bound-work-desk.rtf'
    sleep 18

    local apply_offset
    apply_offset="${SECONDS}"
    echo "apply-command-offset-seconds=${apply_offset}" >>"${TIMING_LOG}"
    {
        echo 'winmux-e2e-mutation-started=1'
        echo '$ winmux apply-zone-bindings'
        "${CLI}" apply-zone-bindings
    } | tee "${APPLY_LOG}"
    sleep 4

    for _ in $(seq 1 30); do
        write_bindings_log "${BINDINGS_AFTER_LOG}" >/dev/null
        if [ "$(workspace_for_zone "${BINDINGS_AFTER_LOG}" main)" = WorkDesk ]; then
            break
        fi
        sleep 1
    done

    [ "$(workspace_for_zone "${BINDINGS_AFTER_LOG}" left)" = ReferenceDesk ] \
        || semantic_fail 'Expected ReferenceDesk active in left zone'
    [ "$(workspace_for_zone "${BINDINGS_AFTER_LOG}" main)" = WorkDesk ] \
        || semantic_fail 'Expected WorkDesk active in main zone'
    [ "$(workspace_for_zone "${BINDINGS_AFTER_LOG}" right)" = CommsDesk ] \
        || semantic_fail 'Expected CommsDesk active in right zone'

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${BOUND_WORK_ID}"
    refresh_window_log "${WINDOW_AFTER_LOG}"
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-reference-desk.rtf' left
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-work-desk.rtf' main
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-comms-desk.rtf' right
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-reference-zone-binding.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-work-zone-binding.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-comms-zone-binding.rtf'
    sleep 10
    refresh_window_log "${WINDOW_AFTER_LOG}"
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-reference-desk.rtf' left
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-work-desk.rtf' main
    assert_window_zone "${WINDOW_AFTER_LOG}" 'bound-comms-desk.rtf' right
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-reference-zone-binding.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-work-zone-binding.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'before-comms-zone-binding.rtf'

    cat "${BINDINGS_BEFORE_LOG}" "${APPLY_LOG}" "${TIMING_LOG}" "${BINDINGS_AFTER_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" >>"${CLI_LOG}"

    {
        echo 'WinMux Slice 14: workspace zone bindings'
        echo
        echo 'Bindings before command:'
        cat "${BINDINGS_BEFORE_LOG}"
        echo
        echo 'Apply command:'
        cat "${APPLY_LOG}"
        echo
        echo 'Command timing:'
        cat "${TIMING_LOG}"
        echo
        echo 'Bindings after command:'
        cat "${BINDINGS_AFTER_LOG}"
        echo
        echo 'Windows before command:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Windows after command:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo "apply-command-offset-seconds=${apply_offset}"
        echo 'PASS: apply-zone-bindings activated ReferenceDesk, WorkDesk, and CommsDesk in the left, main, and right zones without changing zone geometry.'
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
        echo "Unknown WINMUX_E2E_SLICE14_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
