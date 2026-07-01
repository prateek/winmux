#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

SLICE_PREFIX="${WINMUX_E2E_ZONE_SCENE_SLICE_PREFIX:-slice-6b}"
PHASE="${WINMUX_E2E_ZONE_SCENE_PHASE:-${WINMUX_E2E_SLICE6B_PHASE:-proof}}"
COMMAND_ARGS_TEXT="${WINMUX_E2E_ZONE_SCENE_COMMAND_ARGS:-use-zone-scene deep-work}"
COMMAND_LOG_BASENAME="${WINMUX_E2E_ZONE_SCENE_COMMAND_LOG_BASENAME:-${SLICE_PREFIX}-use-zone-scene.log}"
WRAP_LOG_BASENAME="${WINMUX_E2E_ZONE_SCENE_WRAP_LOG_BASENAME:-${SLICE_PREFIX}-cycle-zone-scene-wrap.log}"
PROOF_MODE="${WINMUX_E2E_ZONE_SCENE_PROOF_MODE:-single-switch}"
CYCLING_PASS_CLAIM="${WINMUX_E2E_ZONE_SCENE_CYCLE_WRAP_PASS_CLAIM:-PASS: cycle-zone-scene advanced from triage to deep-work, then wrapped back to triage with the same command while preserving scene layout and workspace bindings.}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.${SLICE_PREFIX//-/.}"
LAUNCH_PLIST="/tmp/winmux-e2e-${SLICE_PREFIX}.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-${SLICE_PREFIX}.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-scene-setup.log"
SCENE_BEFORE_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-scene-before.log"
SCENE_AFTER_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-scene-after.log"
SCENE_WRAP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-scene-wrap.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after.log"
WINDOW_WRAP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-wrap.log"
SWITCH_LOG="${ARTIFACTS_DIR}/logs/${COMMAND_LOG_BASENAME}"
WRAP_LOG="${ARTIFACTS_DIR}/logs/${WRAP_LOG_BASENAME}"
CLI_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli-wait.err"
ZONE_COUNT_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zone-count.txt"
TIMING_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-command-timing.log"
STATE_FILE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zone-scene.done"
PROOF="${ARTIFACTS_DIR}/${SLICE_PREFIX}-zone-scene-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-scene-docs"
TRIAGE_INBOX_DOC="${DOC_DIR}/triage-inbox.rtf"
TRIAGE_DRAFT_DOC="${DOC_DIR}/triage-draft.rtf"
TRIAGE_UPDATES_DOC="${DOC_DIR}/triage-updates.rtf"
FOCUS_QUEUE_DOC="${DOC_DIR}/focus-queue.rtf"
FOCUS_BUILD_DOC="${DOC_DIR}/focus-build.rtf"
FOCUS_NOTES_DOC="${DOC_DIR}/focus-notes.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

write_scene_doc() {
    local path="$1"
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs112 ${headline}\par\fs60 ${subtitle}\par\fs38 ${detail}\par}
RTF
}

write_scene_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|layout=%{monitor-zone-layout-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

scene_field_for_zone() {
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

layout_for_zone() {
    scene_field_for_zone "$1" "$2" layout
}

workspace_for_zone() {
    scene_field_for_zone "$1" "$2" workspace
}

width_for_zone() {
    scene_field_for_zone "$1" "$2" width
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

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} > ${right}"
}

assert_float_lt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left < right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} < ${right}"
}

assert_scene_state() {
    local path="$1"
    local expected_layout="$2"
    local left_workspace="$3"
    local main_workspace="$4"
    local right_workspace="$5"

    [ "$(layout_for_zone "${path}" left)" = "${expected_layout}" ] || semantic_fail "Expected left zone layout ${expected_layout}"
    [ "$(layout_for_zone "${path}" main)" = "${expected_layout}" ] || semantic_fail "Expected main zone layout ${expected_layout}"
    [ "$(layout_for_zone "${path}" right)" = "${expected_layout}" ] || semantic_fail "Expected right zone layout ${expected_layout}"
    [ "$(workspace_for_zone "${path}" left)" = "${left_workspace}" ] || semantic_fail "Expected left zone workspace ${left_workspace}"
    [ "$(workspace_for_zone "${path}" main)" = "${main_workspace}" ] || semantic_fail "Expected main zone workspace ${main_workspace}"
    [ "$(workspace_for_zone "${path}" right)" = "${right_workspace}" ] || semantic_fail "Expected right zone workspace ${right_workspace}"
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

sleep_until_proof_second() {
    local target_seconds="$1"
    if [ "${SECONDS}" -lt "${target_seconds}" ]; then
        sleep $((target_seconds - SECONDS))
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
        if "${CLI}" list-zones --count >"${ZONE_COUNT_LOG}" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${SCENE_BEFORE_LOG}" "${SCENE_AFTER_LOG}" "${SCENE_WRAP_LOG}" \
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" "${WINDOW_WRAP_LOG}" \
        "${SWITCH_LOG}" "${WRAP_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo "WinMux ${SLICE_PREFIX}: zone scenes"
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-scenes]] triage and deep-work'
        echo "Command: winmux ${COMMAND_ARGS_TEXT}"
        echo "Proof mode: ${PROOF_MODE}"
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_scene_doc "${TRIAGE_INBOX_DOC}" 'TRIAGE INBOX' 'scene: triage' "left zone before ${COMMAND_ARGS_TEXT}"
    write_scene_doc "${TRIAGE_DRAFT_DOC}" 'TRIAGE DRAFT' 'scene: triage' "main zone before ${COMMAND_ARGS_TEXT}"
    write_scene_doc "${TRIAGE_UPDATES_DOC}" 'TRIAGE UPDATES' 'scene: triage' "right zone before ${COMMAND_ARGS_TEXT}"
    write_scene_doc "${FOCUS_QUEUE_DOC}" 'FOCUS QUEUE' 'scene: deep-work' "left zone after ${COMMAND_ARGS_TEXT}"
    write_scene_doc "${FOCUS_BUILD_DOC}" 'FOCUS BUILD' 'scene: deep-work' "main zone after ${COMMAND_ARGS_TEXT}"
    write_scene_doc "${FOCUS_NOTES_DOC}" 'FOCUS NOTES' 'scene: deep-work' "right zone after ${COMMAND_ARGS_TEXT}"

    launch_winmux

    /usr/bin/open -a TextEdit "${TRIAGE_INBOX_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${TRIAGE_DRAFT_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${TRIAGE_UPDATES_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${FOCUS_QUEUE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${FOCUS_BUILD_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${FOCUS_NOTES_DOC}"

    if ! wait_for_textedit_windows 6; then
        echo 'TextEdit windows did not become visible to WinMux' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        exit "${SEMANTIC_FAILURE_EXIT}"
    fi

    TRIAGE_INBOX_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'triage-inbox.rtf')"
    TRIAGE_DRAFT_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'triage-draft.rtf')"
    TRIAGE_UPDATES_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'triage-updates.rtf')"
    FOCUS_QUEUE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'focus-queue.rtf')"
    FOCUS_BUILD_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'focus-build.rtf')"
    FOCUS_NOTES_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'focus-notes.rtf')"

    for id in "${TRIAGE_INBOX_ID}" "${TRIAGE_DRAFT_ID}" "${TRIAGE_UPDATES_ID}" "${FOCUS_QUEUE_ID}" "${FOCUS_BUILD_ID}" "${FOCUS_NOTES_ID}"; do
        if [ -z "${id}" ]; then
            echo 'Could not resolve all TextEdit window ids' >&2
            cat "${WINDOW_SETUP_LOG}" >&2 || true
            exit "${SEMANTIC_FAILURE_EXIT}"
        fi
    done

    move_window_to_workspace "${TRIAGE_INBOX_ID}" 'triage-inbox.rtf' TriageInbox
    move_window_to_workspace "${TRIAGE_DRAFT_ID}" 'triage-draft.rtf' TriageDraft
    move_window_to_workspace "${TRIAGE_UPDATES_ID}" 'triage-updates.rtf' TriageUpdates
    move_window_to_workspace "${FOCUS_QUEUE_ID}" 'focus-queue.rtf' FocusQueue
    move_window_to_workspace "${FOCUS_BUILD_ID}" 'focus-build.rtf' FocusBuild
    move_window_to_workspace "${FOCUS_NOTES_ID}" 'focus-notes.rtf' FocusNotes

    "${CLI}" use-zone-scene triage >/dev/null
    sleep 2
    "${CLI}" focus-zone main
    "${CLI}" focus --window-id "${TRIAGE_DRAFT_ID}"
    write_scene_log "${SCENE_BEFORE_LOG}" | tee -a "${SETUP_LOG}" >/dev/null
    assert_scene_state "${SCENE_BEFORE_LOG}" balanced TriageInbox TriageDraft TriageUpdates
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-inbox.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-draft.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-updates.rtf' right
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'focus-queue.rtf'
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'focus-build.rtf'
    assert_title_absent "${WINDOW_BEFORE_LOG}" 'focus-notes.rtf'

    cat >"${STATE_FILE}" <<STATE
TRIAGE_DRAFT_ID=${TRIAGE_DRAFT_ID}
FOCUS_BUILD_ID=${FOCUS_BUILD_ID}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=triage-scene-visible'
        echo "triage-draft-window-id=${TRIAGE_DRAFT_ID}"
        echo "focus-build-window-id=${FOCUS_BUILD_ID}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    local command_args
    IFS=' ' read -r -a command_args <<<"${COMMAND_ARGS_TEXT}"
    SECONDS=0
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${TRIAGE_DRAFT_ID:-}"
    test -n "${FOCUS_BUILD_ID:-}"

    write_scene_log "${SCENE_BEFORE_LOG}" >/dev/null
    assert_scene_state "${SCENE_BEFORE_LOG}" balanced TriageInbox TriageDraft TriageUpdates
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-inbox.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-draft.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'triage-updates.rtf' right
    sleep_until_proof_second 15

    printf 'first-command-start-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
        echo "$ winmux ${COMMAND_ARGS_TEXT}"
        "${CLI}" "${command_args[@]}"
    } | tee "${SWITCH_LOG}"
    printf 'first-command-end-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
    sleep 5

    for _ in $(seq 1 30); do
        write_scene_log "${SCENE_AFTER_LOG}" >/dev/null
        if [ "$(workspace_for_zone "${SCENE_AFTER_LOG}" main)" = FocusBuild ]; then
            printf 'first-result-detected-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
            break
        fi
        sleep 1
    done
    assert_scene_state "${SCENE_AFTER_LOG}" focus FocusQueue FocusBuild FocusNotes
    "${CLI}" focus-zone main
    "${CLI}" focus --window-id "${FOCUS_BUILD_ID}"
    refresh_window_log "${WINDOW_AFTER_LOG}"
    assert_window_zone "${WINDOW_AFTER_LOG}" 'focus-queue.rtf' left
    assert_window_zone "${WINDOW_AFTER_LOG}" 'focus-build.rtf' main
    assert_window_zone "${WINDOW_AFTER_LOG}" 'focus-notes.rtf' right
    assert_title_absent "${WINDOW_AFTER_LOG}" 'triage-inbox.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'triage-draft.rtf'
    assert_title_absent "${WINDOW_AFTER_LOG}" 'triage-updates.rtf'

    before_left_width="$(width_for_zone "${SCENE_BEFORE_LOG}" left)"
    before_main_width="$(width_for_zone "${SCENE_BEFORE_LOG}" main)"
    before_right_width="$(width_for_zone "${SCENE_BEFORE_LOG}" right)"
    after_left_width="$(width_for_zone "${SCENE_AFTER_LOG}" left)"
    after_main_width="$(width_for_zone "${SCENE_AFTER_LOG}" main)"
    after_right_width="$(width_for_zone "${SCENE_AFTER_LOG}" right)"
    assert_float_lt "${after_left_width}" "${before_left_width}" 'left scene width shrank'
    assert_float_gt "${after_main_width}" "${before_main_width}" 'main scene width grew'
    assert_float_lt "${after_right_width}" "${before_right_width}" 'right scene width shrank'

    if [ "${PROOF_MODE}" = cycle-wrap ]; then
        sleep_until_proof_second 39
        printf 'second-command-start-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
        {
            echo "$ winmux ${COMMAND_ARGS_TEXT}"
            "${CLI}" "${command_args[@]}"
        } | tee "${WRAP_LOG}"
        printf 'second-command-end-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
        sleep 5

        for _ in $(seq 1 30); do
            write_scene_log "${SCENE_WRAP_LOG}" >/dev/null
            if [ "$(workspace_for_zone "${SCENE_WRAP_LOG}" main)" = TriageDraft ]; then
                printf 'wrap-result-detected-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"
                break
            fi
            sleep 1
        done
        assert_scene_state "${SCENE_WRAP_LOG}" balanced TriageInbox TriageDraft TriageUpdates
        "${CLI}" focus-zone main
        "${CLI}" focus --window-id "${TRIAGE_DRAFT_ID}"
        refresh_window_log "${WINDOW_WRAP_LOG}"
        assert_window_zone "${WINDOW_WRAP_LOG}" 'triage-inbox.rtf' left
        assert_window_zone "${WINDOW_WRAP_LOG}" 'triage-draft.rtf' main
        assert_window_zone "${WINDOW_WRAP_LOG}" 'triage-updates.rtf' right
        assert_title_absent "${WINDOW_WRAP_LOG}" 'focus-queue.rtf'
        assert_title_absent "${WINDOW_WRAP_LOG}" 'focus-build.rtf'
        assert_title_absent "${WINDOW_WRAP_LOG}" 'focus-notes.rtf'
        sleep 8
    fi
    sleep 8

    cat \
        "${SCENE_BEFORE_LOG}" "${SWITCH_LOG}" "${SCENE_AFTER_LOG}" \
        "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
        >"${CLI_LOG}"
    if [ "${PROOF_MODE}" = cycle-wrap ]; then
        cat "${WRAP_LOG}" "${SCENE_WRAP_LOG}" "${WINDOW_WRAP_LOG}" >>"${CLI_LOG}"
    fi

    {
        echo "WinMux ${SLICE_PREFIX}: zone scenes"
        echo
        echo 'Scene before command:'
        cat "${SCENE_BEFORE_LOG}"
        echo
        echo 'Scene switch command:'
        cat "${SWITCH_LOG}"
        echo
        echo 'Scene after command:'
        cat "${SCENE_AFTER_LOG}"
        echo
        echo 'Windows before scene switch:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Windows after scene switch:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        if [ "${PROOF_MODE}" = cycle-wrap ]; then
            echo 'Command timing:'
            cat "${TIMING_LOG}"
            echo
            echo 'Wrap command:'
            cat "${WRAP_LOG}"
            echo
            echo 'Scene after wrap command:'
            cat "${SCENE_WRAP_LOG}"
            echo
            echo 'Windows after wrap command:'
            cat "${WINDOW_WRAP_LOG}"
            echo
            echo "${CYCLING_PASS_CLAIM}"
        else
            echo 'PASS: use-zone-scene switched from triage to deep-work, applied the focus layout, and activated the configured workspace in each zone.'
        fi
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
        echo "Unknown zone scene phase: ${PHASE}" >&2
        exit 64
        ;;
esac
