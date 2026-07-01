#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE42_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE42_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE42_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-42-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_SOURCE_APP="${ARTIFACTS_DIR}/slice-42-self-test-bin/WinMuxApp"
    export WINMUX_E2E_SOURCE_CLI="${ARTIFACTS_DIR}/slice-42-self-test-bin/winmux"
    export WINMUX_E2E_SLICE42_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-42-zone-availability-profiles"
FINAL_ZONES_FORMAT='zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|availability=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
FINAL_WINDOWS_FORMAT='%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice42-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice42-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice42"
LAUNCH_PLIST="/tmp/winmux-e2e-slice42.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice42.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-42-setup.log"
CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-42-profile-config.toml"
WINDOW_READY_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-ready.log"
ZONES_READY_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-ready.log"
TOGGLE_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-42-toggle-comms.log"
WINDOW_TOGGLE_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-after-toggle-hidden.log"
ZONES_TOGGLE_HIDDEN_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-after-toggle-hidden.log"
PARKED_TOGGLE_LOG="${ARTIFACTS_DIR}/logs/slice-42-parked-after-toggle.tsv"
RESTORE_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-42-restore-comms.log"
WINDOW_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-after-toggle-restored.log"
ZONES_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-after-toggle-restored.log"
USE_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-42-use-focus-only.log"
WINDOW_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-after-profile-focus-only.log"
ZONES_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-after-profile-focus-only.log"
PARKED_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-42-parked-after-focus-only.tsv"
USE_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-42-use-communications.log"
WINDOW_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-after-profile-communications.log"
ZONES_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-after-profile-communications.log"
USE_DASHBOARD_LOG="${ARTIFACTS_DIR}/logs/slice-42-use-full-dashboard.log"
WINDOW_DASHBOARD_LOG="${ARTIFACTS_DIR}/logs/slice-42-windows-after-profile-full-dashboard.log"
ZONES_DASHBOARD_LOG="${ARTIFACTS_DIR}/logs/slice-42-zones-after-profile-full-dashboard.log"
FINAL_VISUAL_READY_LOG="${ARTIFACTS_DIR}/logs/slice-42-final-visual-ready.log"
FINAL_WINDOWS_LOG="${ARTIFACTS_DIR}/logs/slice-42-final-windows-all.log"
FINAL_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-42-final-zones.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-42-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-42-command-timing.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-42-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-42-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-42-zone-availability-profiles-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-availability-profile-docs"
REFERENCE_DOC="${DOC_DIR}/slice42-reference-profile-board.rtf"
WORK_DOC="${DOC_DIR}/slice42-work-main.rtf"
COMMS_DOC="${DOC_DIR}/slice42-comms-chat.rtf"
PARKED_DOC="${DOC_DIR}/slice42-parked-proof.rtf"
FINAL_DOC="${DOC_DIR}/slice-42-availability-final-audit.rtf"

REFERENCE_TITLE="slice42-reference-profile-board.rtf"
WORK_TITLE="slice42-work-main.rtf"
COMMS_TITLE="slice42-comms-chat.rtf"
PARKED_TITLE="slice42-parked-proof.rtf"
FINAL_TITLE="slice-42-availability-final-audit.rtf"

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
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs52\\b %s\\b0\\par\\f1\\fs25\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

write_profile_doc() {
    local visible_profile="${ARTIFACTS_DIR}/logs/slice-42-visible-profile-map.txt"
    {
        echo 'Slice 42 zone profiles'
        echo
        echo 'Profiles are aliases for [[zone-availability-sets]].'
        echo
        echo '[[zone-availability-sets]]'
        echo "id = 'focus-only'"
        echo "enabled-zones = ['main']"
        echo
        echo '[[zone-availability-sets]]'
        echo "id = 'communications'"
        echo "enabled-zones = ['main', 'right']"
        echo
        echo '[[zone-availability-sets]]'
        echo "id = 'full-dashboard'"
        echo "enabled-zones = ['left', 'main', 'right']"
        echo
        echo '[mode.main.binding]'
        echo "alt-c = 'toggle-zone Comms'"
        echo "alt-f = 'use-zone-profile focus-only'"
        echo "alt-m = 'use-zone-profile communications'"
        echo "alt-a = 'cycle-zone-profile focus-only communications full-dashboard'"
        echo "alt-d = 'use-zone-profile full-dashboard'"
        echo
        echo 'Commands shown in this recording:'
        echo 'winmux toggle-zone Comms'
        echo 'winmux toggle-zone Comms'
        echo 'winmux use-zone-profile focus-only'
        echo 'winmux use-zone-profile communications'
        echo 'winmux use-zone-profile full-dashboard'
        echo "winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|availability=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'"
        echo "winmux list-windows --all --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'"
    } >"${visible_profile}"
    write_text_doc "${visible_profile}" 'Profiles map to zone availability sets' "${REFERENCE_DOC}"
}

write_work_doc() {
    cat >"${WORK_DOC}" <<'RTF'
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b Work / Main\b0\par\f1\fs32 slice42-work-main.rtf\par This is the main work surface that expands when side zones are unavailable.\par}
RTF
}

write_comms_doc() {
    cat >"${COMMS_DOC}" <<'RTF'
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b Comms / Right\b0\par\f1\fs32 slice42-comms-chat.rtf\par This window must park when Comms hides and return with the same window id.\par}
RTF
}

write_parked_doc() {
    local visible_parked="${ARTIFACTS_DIR}/logs/slice-42-visible-parked-proof.txt"
    {
        echo 'Comms is hidden, not lost'
        echo
        echo '$ winmux toggle-zone Comms'
        cat "${TOGGLE_COMMS_LOG}"
        echo
        echo '$ winmux list-windows --workspace visible'
        cat "${WINDOW_TOGGLE_HIDDEN_LOG}"
        echo
        echo '$ winmux list-windows --all'
        cat "${PARKED_TOGGLE_LOG}"
        echo
        echo "parked-window=${COMMS_ID:-unknown}"
        echo "parked-title=${COMMS_TITLE}"
    } >"${visible_parked}"
    write_text_doc "${visible_parked}" 'Comms workspace is parked' "${PARKED_DOC}"
}

write_final_doc() {
    local visible_final="${ARTIFACTS_DIR}/logs/slice-42-visible-final.txt"
    {
        echo 'Slice 42 availability final audit'
        echo
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|availability=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'"
        cat "${FINAL_ZONES_LOG}"
        echo
        echo "$ winmux list-windows --all --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'"
        cat "${FINAL_WINDOWS_LOG}"
        echo
        echo 'PASS: zone toggle, restore, focus-only, communications, and full-dashboard profile beats all preserved parked workspaces.'
    } >"${visible_final}"
    write_text_doc "${visible_final}" 'Slice 42 availability final audit' "${FINAL_DOC}"
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
}

launch_winmux() {
    write_launch_plist
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-42-zone-count.txt" 2>"${WAIT_ERR}"; then
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

refresh_visible_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format "${FINAL_WINDOWS_FORMAT}" \
        >"${path}" 2>>"${WAIT_ERR}"
}

refresh_all_window_log() {
    local path="$1"
    "${CLI}" list-windows --all \
        --format "${FINAL_WINDOWS_FORMAT}" \
        >"${path}" 2>>"${WAIT_ERR}"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format "${FINAL_ZONES_FORMAT}" \
        >"${path}" 2>>"${WAIT_ERR}"
}

write_final_zones_log() {
    local path="$1"
    {
        printf '$ winmux list-zones --format '\''%s'\''\n' "${FINAL_ZONES_FORMAT}"
        "${CLI}" list-zones --format "${FINAL_ZONES_FORMAT}"
    } >"${path}" 2>>"${WAIT_ERR}"
}

refresh_final_all_window_log() {
    local path="$1"
    {
        printf '$ winmux list-windows --all --format '\''%s'\''\n' "${FINAL_WINDOWS_FORMAT}"
        "${CLI}" list-windows --all --format "${FINAL_WINDOWS_FORMAT}"
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

zone_field() {
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

assert_window_present() {
    local path="$1"
    local title="$2"
    [ -n "$(window_id_for_title "${path}" "${title}")" ] || {
        cat "${path}" >&2 || true
        semantic_fail "${title} missing from ${path}"
    }
}

assert_title_absent() {
    local path="$1"
    local title="$2"
    if /usr/bin/grep -F "|${title}|" "${path}" >/dev/null; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${title} to be hidden from visible window log ${path}"
    fi
}

assert_zone_field() {
    local path="$1"
    local zone_id="$2"
    local key="$3"
    local expected="$4"
    local actual
    actual="$(zone_field "${path}" "${zone_id}" "${key}")"
    if [ "${actual}" != "${expected}" ]; then
        cat "${path}" >&2 || true
        semantic_fail "Expected ${zone_id} ${key}=${expected}, got ${actual:-missing}"
    fi
}

wait_for_textedit_windows() {
    local expected="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        if refresh_visible_window_log "${path}"; then
            local count
            count="$(/usr/bin/grep -c '^' "${path}" || true)"
            if [ "${count}" -ge "${expected}" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

wait_for_window_present() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_visible_window_log "${path}"
        if [ -n "$(window_id_for_title "${path}" "${title}")" ]; then
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
    refresh_visible_window_log "${WINDOW_READY_LOG}"
    assert_window_zone "${WINDOW_READY_LOG}" "${title}" "${expected_zone}"
}

validate_recorded_evidence() {
    for path in \
        "${CONFIG_COPY}" "${SETUP_LOG}" "${WINDOW_READY_LOG}" "${ZONES_READY_LOG}" \
        "${TOGGLE_COMMS_LOG}" "${WINDOW_TOGGLE_HIDDEN_LOG}" "${ZONES_TOGGLE_HIDDEN_LOG}" "${PARKED_TOGGLE_LOG}" \
        "${RESTORE_COMMS_LOG}" "${WINDOW_RESTORED_LOG}" "${ZONES_RESTORED_LOG}" \
        "${USE_FOCUS_LOG}" "${WINDOW_FOCUS_LOG}" "${ZONES_FOCUS_LOG}" "${PARKED_FOCUS_LOG}" \
        "${USE_COMMUNICATIONS_LOG}" "${WINDOW_COMMUNICATIONS_LOG}" "${ZONES_COMMUNICATIONS_LOG}" \
        "${USE_DASHBOARD_LOG}" "${WINDOW_DASHBOARD_LOG}" "${ZONES_DASHBOARD_LOG}" \
        "${FINAL_VISUAL_READY_LOG}" "${FINAL_WINDOWS_LOG}" "${FINAL_ZONES_LOG}" "${TIMING_LOG}" "${PROOF}"; do
        [ -s "${path}" ] || semantic_fail "Missing Slice 42 evidence file: ${path}"
    done

    for expected in \
        "[[zone-availability-sets]]" \
        "alt-c = 'toggle-zone Comms'" \
        "alt-f = 'use-zone-profile focus-only'" \
        "alt-m = 'use-zone-profile communications'" \
        "alt-a = 'cycle-zone-profile focus-only communications full-dashboard'" \
        "alt-d = 'use-zone-profile full-dashboard'"; do
        /usr/bin/grep -F "${expected}" "${CONFIG_COPY}" >/dev/null \
            || semantic_fail "Slice 42 config evidence missing ${expected}"
    done

    /usr/bin/grep -F '$ winmux toggle-zone Comms' "${TOGGLE_COMMS_LOG}" >/dev/null \
        || semantic_fail 'Slice 42 missing toggle-zone hide command'
    /usr/bin/grep -F '$ winmux toggle-zone Comms' "${RESTORE_COMMS_LOG}" >/dev/null \
        || semantic_fail 'Slice 42 missing toggle-zone restore command'
    /usr/bin/grep -F '$ winmux use-zone-profile focus-only' "${USE_FOCUS_LOG}" >/dev/null \
        || semantic_fail 'Slice 42 missing use-zone-profile focus-only command'
    /usr/bin/grep -F '$ winmux use-zone-profile communications' "${USE_COMMUNICATIONS_LOG}" >/dev/null \
        || semantic_fail 'Slice 42 missing use-zone-profile communications command'
    /usr/bin/grep -F '$ winmux use-zone-profile full-dashboard' "${USE_DASHBOARD_LOG}" >/dev/null \
        || semantic_fail 'Slice 42 missing use-zone-profile full-dashboard command'

    assert_window_zone "${WINDOW_READY_LOG}" "${REFERENCE_TITLE}" left
    assert_window_zone "${WINDOW_READY_LOG}" "${WORK_TITLE}" main
    assert_window_zone "${WINDOW_READY_LOG}" "${COMMS_TITLE}" right
    assert_title_absent "${WINDOW_TOGGLE_HIDDEN_LOG}" "${COMMS_TITLE}"
    assert_window_present "${PARKED_TOGGLE_LOG}" "${COMMS_TITLE}"
    [ "$(window_id_for_title "${PARKED_TOGGLE_LOG}" "${COMMS_TITLE}")" = "${COMMS_ID:-}" ] \
        || semantic_fail 'Slice 42 parked Comms proof does not preserve the original Comms window id'
    assert_window_zone "${WINDOW_RESTORED_LOG}" "${COMMS_TITLE}" right
    [ "$(window_id_for_title "${WINDOW_RESTORED_LOG}" "${COMMS_TITLE}")" = "${COMMS_ID:-}" ] \
        || semantic_fail 'Slice 42 restored Comms proof does not preserve the original Comms window id'
    assert_title_absent "${WINDOW_FOCUS_LOG}" "${REFERENCE_TITLE}"
    assert_title_absent "${WINDOW_FOCUS_LOG}" "${COMMS_TITLE}"
    assert_window_present "${PARKED_FOCUS_LOG}" "${REFERENCE_TITLE}"
    assert_window_present "${PARKED_FOCUS_LOG}" "${COMMS_TITLE}"
    assert_window_zone "${WINDOW_COMMUNICATIONS_LOG}" "${COMMS_TITLE}" right
    assert_title_absent "${WINDOW_COMMUNICATIONS_LOG}" "${REFERENCE_TITLE}"
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${REFERENCE_TITLE}" left
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${WORK_TITLE}" main
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${COMMS_TITLE}" right

    assert_zone_field "${ZONES_READY_LOG}" left enabled true
    assert_zone_field "${ZONES_READY_LOG}" main enabled true
    assert_zone_field "${ZONES_READY_LOG}" right enabled true
    assert_zone_field "${ZONES_READY_LOG}" main availability ""
    assert_zone_field "${ZONES_TOGGLE_HIDDEN_LOG}" right enabled false
    assert_zone_field "${ZONES_RESTORED_LOG}" right enabled true
    assert_zone_field "${ZONES_FOCUS_LOG}" left enabled false
    assert_zone_field "${ZONES_FOCUS_LOG}" main enabled true
    assert_zone_field "${ZONES_FOCUS_LOG}" right enabled false
    assert_zone_field "${ZONES_FOCUS_LOG}" main availability focus-only
    assert_zone_field "${ZONES_COMMUNICATIONS_LOG}" left enabled false
    assert_zone_field "${ZONES_COMMUNICATIONS_LOG}" right enabled true
    assert_zone_field "${ZONES_COMMUNICATIONS_LOG}" main availability communications
    assert_zone_field "${ZONES_DASHBOARD_LOG}" left enabled true
    assert_zone_field "${ZONES_DASHBOARD_LOG}" main enabled true
    assert_zone_field "${ZONES_DASHBOARD_LOG}" right enabled true
    assert_zone_field "${ZONES_DASHBOARD_LOG}" main availability full-dashboard
    assert_window_present "${FINAL_VISUAL_READY_LOG}" "${FINAL_TITLE}"
    assert_window_present "${FINAL_WINDOWS_LOG}" "${REFERENCE_TITLE}"
    assert_window_present "${FINAL_WINDOWS_LOG}" "${WORK_TITLE}"
    assert_window_present "${FINAL_WINDOWS_LOG}" "${COMMS_TITLE}"
    /usr/bin/grep -F 'PASS: zone toggle, restore, focus-only, communications, and full-dashboard' "${PROOF}" >/dev/null \
        || semantic_fail 'Slice 42 proof missing PASS claim'
    /usr/bin/grep -F 'manual-move-node-to-zone-during-proof=no' "${PROOF}" >/dev/null \
        || semantic_fail 'Slice 42 proof must deny manual move-node-to-zone during proof'
    if /usr/bin/grep -F '$ winmux move-node-to-zone' "${TOGGLE_COMMS_LOG}" "${RESTORE_COMMS_LOG}" "${USE_FOCUS_LOG}" "${USE_COMMUNICATIONS_LOG}" "${USE_DASHBOARD_LOG}" >/dev/null; then
        semantic_fail 'Slice 42 proof-phase command logs must not include move-node-to-zone'
    fi
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_COPY}" "${WINDOW_READY_LOG}" "${ZONES_READY_LOG}" \
        "${TOGGLE_COMMS_LOG}" "${WINDOW_TOGGLE_HIDDEN_LOG}" "${ZONES_TOGGLE_HIDDEN_LOG}" "${PARKED_TOGGLE_LOG}" \
        "${RESTORE_COMMS_LOG}" "${WINDOW_RESTORED_LOG}" "${ZONES_RESTORED_LOG}" \
        "${USE_FOCUS_LOG}" "${WINDOW_FOCUS_LOG}" "${ZONES_FOCUS_LOG}" "${PARKED_FOCUS_LOG}" \
        "${USE_COMMUNICATIONS_LOG}" "${WINDOW_COMMUNICATIONS_LOG}" "${ZONES_COMMUNICATIONS_LOG}" \
        "${USE_DASHBOARD_LOG}" "${WINDOW_DASHBOARD_LOG}" "${ZONES_DASHBOARD_LOG}" \
        "${FINAL_VISUAL_READY_LOG}" "${FINAL_WINDOWS_LOG}" "${FINAL_ZONES_LOG}" \
        "${CLI_LOG}" "${TIMING_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${DONE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${BIN_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${CONFIG}" "${CONFIG_COPY}"

    write_profile_doc
    write_work_doc
    write_comms_doc

    {
        echo 'WinMux Slice 42: zone availability and profile workflows'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Profiles: focus-only, communications, full-dashboard as [[zone-availability-sets]]'
        echo 'Commands: toggle-zone Comms; use-zone-profile focus-only; use-zone-profile communications; use-zone-profile full-dashboard'
    } | tee "${SETUP_LOG}"

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 "${WINDOW_READY_LOG}" || {
        cat "${WINDOW_READY_LOG}" >&2 || true
        semantic_fail 'TextEdit windows did not appear'
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${REFERENCE_TITLE}")"
    work_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${WORK_TITLE}")"
    comms_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${COMMS_TITLE}")"
    [ -n "${reference_id}" ] || semantic_fail "Missing ${REFERENCE_TITLE} window id"
    [ -n "${work_id}" ] || semantic_fail "Missing ${WORK_TITLE} window id"
    [ -n "${comms_id}" ] || semantic_fail "Missing ${COMMS_TITLE} window id"

    move_window_to_zone "${reference_id}" "${REFERENCE_TITLE}" Reference left
    move_window_to_zone "${work_id}" "${WORK_TITLE}" Work main
    move_window_to_zone "${comms_id}" "${COMMS_TITLE}" Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_visible_window_log "${WINDOW_READY_LOG}"
    write_zones_log "${ZONES_READY_LOG}"
    assert_window_zone "${WINDOW_READY_LOG}" "${REFERENCE_TITLE}" left
    assert_window_zone "${WINDOW_READY_LOG}" "${WORK_TITLE}" main
    assert_window_zone "${WINDOW_READY_LOG}" "${COMMS_TITLE}" right

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

run_proof() {
    SECONDS=0
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"
    [ -f "${STATE_FILE}" ] || semantic_fail 'Missing Slice 42 state file'
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    [ -n "${COMMS_ID:-}" ] || semantic_fail 'Missing COMMS_ID in Slice 42 state file'

    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    "${CLI}" focus --window-id "${WORK_ID}" >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_visible_window_log "${WINDOW_READY_LOG}"
    write_zones_log "${ZONES_READY_LOG}"
    capture_guest_screenshot '02-profile-map-ready-slice-42'

    sleep_until_recording_offset 16 32 "Run: winmux toggle-zone Comms"
    echo "toggle-comms-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    {
        echo '$ winmux toggle-zone Comms'
        "${CLI}" toggle-zone Comms
    } | tee "${TOGGLE_COMMS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    refresh_visible_window_log "${WINDOW_TOGGLE_HIDDEN_LOG}"
    refresh_all_window_log "${PARKED_TOGGLE_LOG}"
    write_zones_log "${ZONES_TOGGLE_HIDDEN_LOG}"
    assert_title_absent "${WINDOW_TOGGLE_HIDDEN_LOG}" "${COMMS_TITLE}"
    assert_window_present "${PARKED_TOGGLE_LOG}" "${COMMS_TITLE}"
    write_parked_doc
    /usr/bin/open -a TextEdit "${PARKED_DOC}"
    wait_for_window_present "${PARKED_TITLE}" "${WINDOW_TOGGLE_HIDDEN_LOG}" || true
    capture_guest_screenshot '03-comms-hidden-parked-slice-42'

    sleep_until_recording_offset 32 48 "Run: winmux toggle-zone Comms"
    echo "restore-comms-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux toggle-zone Comms'
        "${CLI}" toggle-zone Comms
    } | tee "${RESTORE_COMMS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    refresh_visible_window_log "${WINDOW_RESTORED_LOG}"
    write_zones_log "${ZONES_RESTORED_LOG}"
    assert_window_zone "${WINDOW_RESTORED_LOG}" "${COMMS_TITLE}" right
    capture_guest_screenshot '04-comms-restored-slice-42'

    sleep_until_recording_offset 48 66 "Run: winmux use-zone-profile focus-only"
    echo "focus-only-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-profile focus-only'
        "${CLI}" use-zone-profile focus-only
    } | tee "${USE_FOCUS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    refresh_visible_window_log "${WINDOW_FOCUS_LOG}"
    refresh_all_window_log "${PARKED_FOCUS_LOG}"
    write_zones_log "${ZONES_FOCUS_LOG}"
    assert_title_absent "${WINDOW_FOCUS_LOG}" "${REFERENCE_TITLE}"
    assert_title_absent "${WINDOW_FOCUS_LOG}" "${COMMS_TITLE}"
    assert_window_present "${PARKED_FOCUS_LOG}" "${COMMS_TITLE}"
    capture_guest_screenshot '05-profile-focus-only-slice-42'

    sleep_until_recording_offset 66 84 "Run: winmux use-zone-profile communications"
    echo "communications-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-profile communications'
        "${CLI}" use-zone-profile communications
    } | tee "${USE_COMMUNICATIONS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    refresh_visible_window_log "${WINDOW_COMMUNICATIONS_LOG}"
    write_zones_log "${ZONES_COMMUNICATIONS_LOG}"
    assert_window_zone "${WINDOW_COMMUNICATIONS_LOG}" "${COMMS_TITLE}" right
    assert_title_absent "${WINDOW_COMMUNICATIONS_LOG}" "${REFERENCE_TITLE}"
    capture_guest_screenshot '06-profile-communications-slice-42'

    sleep_until_recording_offset 84 104 "Run: winmux use-zone-profile full-dashboard"
    echo "full-dashboard-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-profile full-dashboard'
        "${CLI}" use-zone-profile full-dashboard
    } | tee "${USE_DASHBOARD_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    refresh_visible_window_log "${WINDOW_DASHBOARD_LOG}"
    write_zones_log "${ZONES_DASHBOARD_LOG}"
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${REFERENCE_TITLE}" left
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${WORK_TITLE}" main
    assert_window_zone "${WINDOW_DASHBOARD_LOG}" "${COMMS_TITLE}" right

    sleep_until_recording_offset 104 116 "Run: winmux list-zones --format"
    echo "final-audit-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    echo "final-zones-audit-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_final_zones_log "${FINAL_ZONES_LOG}"
    sleep_until_recording_offset 116 128 "Run: winmux list-windows --all --format"
    echo "final-windows-audit-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    refresh_final_all_window_log "${FINAL_WINDOWS_LOG}"
    write_final_doc
    /usr/bin/open -a TextEdit "${FINAL_DOC}"
    wait_for_window_present "${FINAL_TITLE}" "${FINAL_VISUAL_READY_LOG}" \
        || semantic_fail "${FINAL_TITLE} did not become visible before final screenshot"
    sleep 2
    capture_guest_screenshot '06-final-availability-proof-slice-42'

    {
        echo 'WinMux Slice 42: zone availability and profile workflows'
        echo
        echo 'PASS: zone toggle, restore, focus-only, communications, and full-dashboard profile beats all preserved parked workspaces.'
        echo 'manual-move-node-to-zone-during-proof=no'
        echo "reference-window-id=${REFERENCE_ID:-}"
        echo "work-window-id=${WORK_ID:-}"
        echo "comms-window-id=${COMMS_ID:-}"
        echo "final-board=${FINAL_TITLE}"
        echo 'non-claim=no visual profile editor; no scene replacement'
    } >"${PROOF}"

    validate_recorded_evidence
    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

write_self_test_fixture() {
    mkdir -p "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots" "${ARTIFACTS_DIR}/config"
    cat >"${CONFIG_COPY}" <<'TOML'
[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']
[[zone-availability-sets]]
id = 'communications'
enabled-zones = ['main', 'right']
[[zone-availability-sets]]
id = 'full-dashboard'
enabled-zones = ['left', 'main', 'right']
[mode.main.binding]
alt-c = 'toggle-zone Comms'
alt-f = 'use-zone-profile focus-only'
alt-m = 'use-zone-profile communications'
alt-a = 'cycle-zone-profile focus-only communications full-dashboard'
alt-d = 'use-zone-profile full-dashboard'
TOML
    printf 'setup=result=success\n' >"${SETUP_LOG}"
    cat >"${WINDOW_READY_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    cat >"${ZONES_READY_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|availability=|workspace=reference|left=0|width=860|physical=1
zone=main|name=Work|enabled=true|availability=|workspace=work|left=860|width=1720|physical=1
zone=right|name=Comms|enabled=true|availability=|workspace=comms|left=2580|width=860|physical=1
EOF
    printf '$ winmux toggle-zone Comms\nDisabled zone Comms\n' >"${TOGGLE_COMMS_LOG}"
    cat >"${WINDOW_TOGGLE_HIDDEN_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
EOF
    cat >"${ZONES_TOGGLE_HIDDEN_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|availability=|workspace=reference|left=0|width=1147|physical=1
zone=main|name=Work|enabled=true|availability=|workspace=work|left=1147|width=2293|physical=1
zone=right|name=Comms|enabled=false|availability=|workspace=comms|left=0|width=0|physical=1
EOF
    cat >"${PARKED_TOGGLE_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    printf '$ winmux toggle-zone Comms\nEnabled zone Comms\n' >"${RESTORE_COMMS_LOG}"
    cat >"${WINDOW_RESTORED_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    cat >"${ZONES_RESTORED_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|availability=|workspace=reference|left=0|width=860|physical=1
zone=main|name=Work|enabled=true|availability=|workspace=work|left=860|width=1720|physical=1
zone=right|name=Comms|enabled=true|availability=|workspace=comms|left=2580|width=860|physical=1
EOF
    printf '$ winmux use-zone-profile focus-only\nUsing zone profile '\''focus-only'\'' on monitor 1\n' >"${USE_FOCUS_LOG}"
    cat >"${WINDOW_FOCUS_LOG}" <<EOF
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
EOF
    cat >"${ZONES_FOCUS_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|availability=focus-only|workspace=reference|left=0|width=0|physical=1
zone=main|name=Work|enabled=true|availability=focus-only|workspace=work|left=0|width=3440|physical=1
zone=right|name=Comms|enabled=false|availability=focus-only|workspace=comms|left=0|width=0|physical=1
EOF
    cat >"${PARKED_FOCUS_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    printf '$ winmux use-zone-profile communications\nUsing zone profile '\''communications'\'' on monitor 1\n' >"${USE_COMMUNICATIONS_LOG}"
    cat >"${WINDOW_COMMUNICATIONS_LOG}" <<EOF
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    cat >"${ZONES_COMMUNICATIONS_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|availability=communications|workspace=reference|left=0|width=0|physical=1
zone=main|name=Work|enabled=true|availability=communications|workspace=work|left=0|width=2293|physical=1
zone=right|name=Comms|enabled=true|availability=communications|workspace=comms|left=2293|width=1147|physical=1
EOF
    printf '$ winmux use-zone-profile full-dashboard\nUsing zone profile '\''full-dashboard'\'' on monitor 1\n' >"${USE_DASHBOARD_LOG}"
    cat >"${WINDOW_DASHBOARD_LOG}" <<EOF
1|${REFERENCE_TITLE}|zone=left|workspace=reference|monitor=Reference
2|${WORK_TITLE}|zone=main|workspace=work|monitor=Work
3|${COMMS_TITLE}|zone=right|workspace=comms|monitor=Comms
EOF
    cat >"${ZONES_DASHBOARD_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|availability=full-dashboard|workspace=reference|left=0|width=860|physical=1
zone=main|name=Work|enabled=true|availability=full-dashboard|workspace=work|left=860|width=1720|physical=1
zone=right|name=Comms|enabled=true|availability=full-dashboard|workspace=comms|left=2580|width=860|physical=1
EOF
    {
        cat "${WINDOW_DASHBOARD_LOG}"
        printf '4|%s|zone=main|workspace=work|monitor=Work\n' "${FINAL_TITLE}"
    } >"${FINAL_VISUAL_READY_LOG}"
    {
        printf '$ winmux list-windows --all --format '\''%s'\''\n' "${FINAL_WINDOWS_FORMAT}"
        cat "${WINDOW_DASHBOARD_LOG}"
    } >"${FINAL_WINDOWS_LOG}"
    {
        printf '$ winmux list-zones --format '\''%s'\''\n' "${FINAL_ZONES_FORMAT}"
        cat "${ZONES_DASHBOARD_LOG}"
    } >"${FINAL_ZONES_LOG}"
    printf 'toggle-comms-offset-seconds=16\nrestore-comms-offset-seconds=32\nfocus-only-offset-seconds=48\ncommunications-offset-seconds=66\nfull-dashboard-offset-seconds=84\nfinal-audit-offset-seconds=104\nfinal-zones-audit-offset-seconds=104\nfinal-windows-audit-offset-seconds=116\n' >"${TIMING_LOG}"
    cat >"${PROOF}" <<EOF
PASS: zone toggle, restore, focus-only, communications, and full-dashboard profile beats all preserved parked workspaces.
manual-move-node-to-zone-during-proof=no
reference-window-id=1
work-window-id=2
comms-window-id=3
final-board=${FINAL_TITLE}
non-claim=no visual profile editor; no scene replacement
EOF
}

self_test_slice() {
    export REFERENCE_ID=1
    export WORK_ID=2
    export COMMS_ID=3
    write_self_test_fixture
    validate_recorded_evidence

    local saved_parked="${PARKED_TOGGLE_LOG}.saved"
    /bin/mv "${PARKED_TOGGLE_LOG}" "${saved_parked}"
    if ( validate_recorded_evidence ) >/dev/null 2>&1; then
        /bin/mv "${saved_parked}" "${PARKED_TOGGLE_LOG}"
        semantic_fail 'self-test expected missing parked workspace proof to fail'
    fi
    /bin/mv "${saved_parked}" "${PARKED_TOGGLE_LOG}"
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
        echo "Unknown Slice 42 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
