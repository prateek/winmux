#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE6_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice6-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice6-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice6"
LAUNCH_PLIST="/tmp/winmux-e2e-slice6.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice6.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-6-layout-setup.log"
LAYOUT_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-6-layout-before.log"
LAYOUT_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-6-layout-after.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-6-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-6-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-6-windows-after.log"
SWITCH_LOG="${ARTIFACTS_DIR}/logs/slice-6-use-zone-layout.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-6-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-6-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-6-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-6-zone-layout-presets.done"
PROOF="${ARTIFACTS_DIR}/slice-6-zone-layout-presets-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-layout-docs"
LEFT_DOC="${DOC_DIR}/left-reference.rtf"
MAIN_DOC="${DOC_DIR}/main-work.rtf"
RIGHT_DOC="${DOC_DIR}/right-comms.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

write_zone_doc() {
    local path="$1"
    local headline="$2"
    local subtitle="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\pard\qc\f0\fs120 ${headline}\par\fs64 ${subtitle}\par\fs40 ${detail}\par}
RTF
}

write_layout_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|layout=%{monitor-zone-layout-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --monitor all --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"${path}" 2>>"${WAIT_ERR}"
}

layout_for_zone() {
    local path="$1"
    local zone="$2"
    /usr/bin/awk -F'|' -v zone="zone=${zone}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, "layout=") == 1) {
                print substr($i, 8)
                exit
            }
        }
    }' "${path}"
}

width_for_zone() {
    local path="$1"
    local zone="$2"
    /usr/bin/awk -F'|' -v zone="zone=${zone}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, "width=") == 1) {
                print substr($i, 7)
                exit
            }
        }
    }' "${path}"
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

assert_layout_id() {
    local path="$1"
    local expected="$2"
    local zone
    for zone in left main right; do
        if [ "$(layout_for_zone "${path}" "${zone}")" != "${expected}" ]; then
            echo "Expected zone ${zone} to use layout ${expected}" >&2
            cat "${path}" >&2 || true
            exit 1
        fi
    done
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || {
            echo "${message}: expected ${left} > ${right}" >&2
            exit 1
        }
}

assert_float_lt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left < right ? 0 : 1) }' \
        || {
            echo "${message}: expected ${left} < ${right}" >&2
            exit 1
        }
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-6-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${LAYOUT_BEFORE_LOG}" "${LAYOUT_AFTER_LOG}" \
        "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
        "${SWITCH_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 6: named zone layout presets'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: [[zone-layouts]] balanced and focus'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${LEFT_DOC}" 'REFERENCE' 'Balanced preset' 'stays in left zone'
    write_zone_doc "${MAIN_DOC}" 'WORK' 'Focus preset grows this column' 'use-zone-layout focus'
    write_zone_doc "${RIGHT_DOC}" 'COMMS' 'Balanced preset' 'stays in right zone'

    launch_winmux
    "${CLI}" use-zone-layout balanced >/dev/null
    write_layout_log "${LAYOUT_BEFORE_LOG}" | tee -a "${SETUP_LOG}" >/dev/null
    assert_layout_id "${LAYOUT_BEFORE_LOG}" balanced
    grep -F 'zone=left|layout=balanced|name=Reference|' "${LAYOUT_BEFORE_LOG}" >/dev/null
    grep -F 'zone=main|layout=balanced|name=Work|' "${LAYOUT_BEFORE_LOG}" >/dev/null
    grep -F 'zone=right|layout=balanced|name=Comms|' "${LAYOUT_BEFORE_LOG}" >/dev/null

    /usr/bin/open -a TextEdit "${LEFT_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${MAIN_DOC}"
    sleep 1
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

    move_window_to_zone "${LEFT_ID}" 'left-reference.rtf' Reference left
    move_window_to_zone "${MAIN_ID}" 'main-work.rtf' Work main
    move_window_to_zone "${RIGHT_ID}" 'right-comms.rtf' Comms right
    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${MAIN_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'left-reference.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'main-work.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'right-comms.rtf' right

    cat >"${STATE_FILE}" <<STATE
LEFT_ID=${LEFT_ID}
MAIN_ID=${MAIN_ID}
RIGHT_ID=${RIGHT_ID}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=balanced-preset-visible'
        echo "main-window-id=${MAIN_ID}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

assert_window_identity_stable() {
    local title="$1"
    local expected_zone="$2"
    local before_id after_id before_zone after_zone before_workspace after_workspace
    before_id="$(window_id_for_title "${WINDOW_BEFORE_LOG}" "${title}")"
    after_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" "${title}")"
    before_zone="$(zone_for_title "${WINDOW_BEFORE_LOG}" "${title}")"
    after_zone="$(zone_for_title "${WINDOW_AFTER_LOG}" "${title}")"
    before_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" "${title}")"
    after_workspace="$(workspace_for_title "${WINDOW_AFTER_LOG}" "${title}")"
    [ -n "${before_id}" ] && [ -n "${after_id}" ]
    [ "${before_id}" = "${after_id}" ]
    [ "${before_zone}" = "${expected_zone}" ]
    [ "${after_zone}" = "${expected_zone}" ]
    [ "${before_workspace}" = "${after_workspace}" ]
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${MAIN_ID:-}"

    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_layout_log "${LAYOUT_BEFORE_LOG}" >/dev/null
    assert_layout_id "${LAYOUT_BEFORE_LOG}" balanced
    sleep 5

    {
        echo '$ winmux use-zone-layout focus'
        "${CLI}" use-zone-layout focus
    } | tee "${SWITCH_LOG}"
    sleep 5

    for _ in $(seq 1 30); do
        write_layout_log "${LAYOUT_AFTER_LOG}" >/dev/null
        if [ "$(layout_for_zone "${LAYOUT_AFTER_LOG}" main)" = focus ]; then
            break
        fi
        sleep 1
    done
    assert_layout_id "${LAYOUT_AFTER_LOG}" focus
    refresh_window_log "${WINDOW_AFTER_LOG}"

    before_left_width="$(width_for_zone "${LAYOUT_BEFORE_LOG}" left)"
    before_main_width="$(width_for_zone "${LAYOUT_BEFORE_LOG}" main)"
    before_right_width="$(width_for_zone "${LAYOUT_BEFORE_LOG}" right)"
    after_left_width="$(width_for_zone "${LAYOUT_AFTER_LOG}" left)"
    after_main_width="$(width_for_zone "${LAYOUT_AFTER_LOG}" main)"
    after_right_width="$(width_for_zone "${LAYOUT_AFTER_LOG}" right)"

    assert_float_lt "${after_left_width}" "${before_left_width}" 'left preset width shrank'
    assert_float_gt "${after_main_width}" "${before_main_width}" 'main preset width grew'
    assert_float_lt "${after_right_width}" "${before_right_width}" 'right preset width shrank'
    assert_window_identity_stable 'left-reference.rtf' left
    assert_window_identity_stable 'main-work.rtf' main
    assert_window_identity_stable 'right-comms.rtf' right
    sleep 8

    cat "${LAYOUT_BEFORE_LOG}" "${SWITCH_LOG}" "${LAYOUT_AFTER_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 6: named zone layout presets'
        echo
        echo 'Layout before command:'
        cat "${LAYOUT_BEFORE_LOG}"
        echo
        echo 'Layout switch command:'
        cat "${SWITCH_LOG}"
        echo
        echo 'Layout after command:'
        cat "${LAYOUT_AFTER_LOG}"
        echo
        echo 'Windows before layout switch:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Windows after layout switch:'
        cat "${WINDOW_AFTER_LOG}"
        echo
        echo 'PASS: use-zone-layout switched a physical monitor from balanced to focus while windows stayed bound to the same zone ids and workspaces.'
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 5
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
        echo "Unknown WINMUX_E2E_SLICE6_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
