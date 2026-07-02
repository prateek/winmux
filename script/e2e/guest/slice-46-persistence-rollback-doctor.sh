#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE46_PHASE:-proof}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-46-persistence-rollback-doctor"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice46-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice46-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice46"
LAUNCH_PLIST="/tmp/winmux-e2e-slice46.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice46.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-46-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-setup.log"
WINDOWS_ORIGINAL_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-original.log"
WINDOWS_AFTER_SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-after-save.log"
WINDOWS_RELAUNCH_SAVED_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-relaunch-saved.log"
WINDOWS_BAD_CONFIG_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-bad-config.log"
WINDOWS_AFTER_RESTORE_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-after-restore.log"
WINDOWS_FINAL_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-46-windows-final-restored.log"
ZONES_ORIGINAL_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-original.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-resized.log"
ZONES_AFTER_SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-after-save.log"
ZONES_RELAUNCH_SAVED_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-relaunch-saved.log"
ZONES_AFTER_RESTORE_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-after-restore.log"
ZONES_FINAL_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-46-zones-final-restored.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-46-resize-zone.log"
SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-46-save-zone-layout.log"
RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-46-relaunch.log"
BAD_CONFIG_LOG="${ARTIFACTS_DIR}/logs/slice-46-write-bad-config.log"
CONFIG_CHECK_BAD_LOG="${ARTIFACTS_DIR}/logs/slice-46-config-check-bad.log"
DOCTOR_BAD_LOG="${ARTIFACTS_DIR}/logs/slice-46-doctor-bad-config.log"
BAD_CONFIG_BOARD_SOURCE="${ARTIFACTS_DIR}/logs/slice-46-bad-config-board-source.txt"
RESTORE_LOG="${ARTIFACTS_DIR}/logs/slice-46-restore-backup.log"
CONFIG_CHECK_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-46-config-check-restored.log"
DOCTOR_RESTORED_LOG="${ARTIFACTS_DIR}/logs/slice-46-doctor-restored-config.log"
RESTORE_BOARD_SOURCE="${ARTIFACTS_DIR}/logs/slice-46-restore-board-source.txt"
FINAL_BOARD_SOURCE="${ARTIFACTS_DIR}/logs/slice-46-final-board-source.txt"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-46-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-46-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-46-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-46-window-ids.env"
MEASUREMENTS="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.measurements.tsv"
EVENT_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.event-manifest.tsv"
PROOF_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/${RECORDING_NAME}-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

CONFIG_ORIGINAL_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-original.toml"
CONFIG_AFTER_SAVE_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-after-save.toml"
GOOD_SAVED_BACKUP="${ARTIFACTS_DIR}/logs/slice-46-good-saved-backup.toml"
BAD_CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-bad.toml"
CONFIG_AFTER_RESTORE_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-after-restore.toml"
CONFIG_FINAL_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-final-restored.toml"
CONFIG_SAVE_BACKUP_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-save-backup.toml"
ROLLBACK_BAD_CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-46-config-rollback-bad.toml"
SAVE_BACKUP_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-46-save-backup-path.txt"
ROLLBACK_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-46-rollback-path.txt"
CONFIG_SHA_ORIGINAL="${ARTIFACTS_DIR}/logs/slice-46-config-original.sha256"
CONFIG_SHA_AFTER_SAVE="${ARTIFACTS_DIR}/logs/slice-46-config-after-save.sha256"
CONFIG_SHA_SAVE_BACKUP="${ARTIFACTS_DIR}/logs/slice-46-config-save-backup.sha256"
CONFIG_SHA_GOOD_SAVED="${ARTIFACTS_DIR}/logs/slice-46-config-good-saved.sha256"
CONFIG_SHA_BAD="${ARTIFACTS_DIR}/logs/slice-46-config-bad.sha256"
CONFIG_SHA_ROLLBACK_BAD="${ARTIFACTS_DIR}/logs/slice-46-config-rollback-bad.sha256"
CONFIG_SHA_AFTER_RESTORE="${ARTIFACTS_DIR}/logs/slice-46-config-after-restore.sha256"
CONFIG_SHA_FINAL="${ARTIFACTS_DIR}/logs/slice-46-config-final-restored.sha256"

DOC_DIR="${HOME}/winmux-e2e/persistence-rollback-docs"
REFERENCE_DOC="${DOC_DIR}/slice46-reference.rtf"
WORK_DOC="${DOC_DIR}/slice46-work.rtf"
COMMS_DOC="${DOC_DIR}/slice46-comms.rtf"
REFERENCE_TITLE="slice46-reference.rtf"
WORK_TITLE="slice46-work.rtf"
COMMS_TITLE="slice46-comms.rtf"
BOARD_TITLE_PREFIX="slice46-proof-"

uid="$(/usr/bin/id -u)"
mutation_marked=0

# shellcheck source=script/e2e/guest/zone-window-helpers.sh
. "${REPO_DIR}/script/e2e/guest/zone-window-helpers.sh"
# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
. "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

semantic_fail() {
    echo "$*" >&2
    exit "${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
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

config_sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

rtf_escape_line() {
    /usr/bin/sed -e 's/\\/\\\\/g' -e 's/{/\\{/g' -e 's/}/\\}/g'
}

write_text_doc() {
    local source_path="$1"
    local title="$2"
    local out_path="$3"
    {
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs58\\b %s\\b0\\par\\f1\\fs28\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

write_zone_doc() {
    local path="$1"
    local heading="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs78\b ${heading}\b0\par\f1\fs32 zone: ${zone_name}\par ${detail}\par}
RTF
}

close_existing_audit_board() {
    local old_board_id
    refresh_window_log "${WINDOW_SETUP_LOG}" || true
    /usr/bin/awk -F'|' -v prefix="${BOARD_TITLE_PREFIX}" 'index($2, prefix) == 1 { print $1 }' "${WINDOW_SETUP_LOG}" |
        while IFS= read -r old_board_id; do
            [ -n "${old_board_id}" ] || continue
            "${CLI}" close --window-id "${old_board_id}" >/dev/null 2>>"${WAIT_ERR}" || true
        done
    sleep 0.8
}

assert_visible_audit_board() {
    local board_title="$1"
    local expected_heading="$2"
    local source_path="$3"
    local board_id
    /usr/bin/grep -F "${expected_heading}" "${source_path}" >/dev/null \
        || semantic_fail "audit board source missing expected heading: ${expected_heading}"
    for _ in $(seq 1 24); do
        refresh_window_log "${WINDOW_SETUP_LOG}" || true
        board_id="$(field_for_title "${WINDOW_SETUP_LOG}" "${board_title}" id)"
        if [ -n "${board_id}" ]; then
            return 0
        fi
        sleep 0.5
    done
    cat "${WINDOW_SETUP_LOG}" >&2 || true
    semantic_fail "visible audit board did not load expected window: ${board_title}"
}

write_audit_board() {
    local title="$1"
    local result="$2"
    local command="$3"
    local details="$4"
    local copy_path="${5:-}"
    local board_title="$6"
    local board_doc="${DOC_DIR}/${board_title}"
    local source="${ARTIFACTS_DIR}/logs/slice-46-board-source.txt"
    {
        printf '%s\n' "$title"
        printf 'Command: %s\n' "$command"
        printf 'Result: %s\n' "$result"
        printf '%s\n' "$details"
    } >"${source}"
    if [ -n "${copy_path}" ]; then
        /bin/cp "${source}" "${copy_path}"
    fi
    close_existing_audit_board
    write_text_doc "${source}" "${title}" "${board_doc}"
    /usr/bin/open -a TextEdit "${board_doc}"
    sleep 1.5
    assert_visible_audit_board "${board_title}" "${title}" "${source}"
    refresh_window_log "${WINDOW_SETUP_LOG}" || true
    local board_id
    board_id="$(field_for_title "${WINDOW_SETUP_LOG}" "${board_title}" id)"
    if [ -n "${board_id}" ]; then
        move_window_to_zone "${board_id}" "${board_title}" Work main "${WINDOW_SETUP_LOG}" "${CLI_LOG}" || true
    fi
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    {
        printf '$ winmux list-zones --format '\''%s'\''\n' 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${path}" 2>>"${WAIT_ERR}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
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

display_percent() {
    local value="$1"
    /usr/bin/awk -v value="$value" 'BEGIN {
        pct = value * 100
        if (pct == int(pct)) {
            printf "%d%%", pct
        } else {
            printf "%.1f%%", pct
        }
    }'
}

measurement_chip_for_log() {
    local path="$1"
    printf 'Reference %s | Work %s | Comms %s\n' \
        "$(display_percent "$(zone_field "$path" left effective)")" \
        "$(display_percent "$(zone_field "$path" main effective)")" \
        "$(display_percent "$(zone_field "$path" right effective)")"
}

append_measurements() {
    local phase_name="$1"
    local zones_log="$2"
    local zone_id zone_name configured effective override_state chip
    chip="$(measurement_chip_for_log "$zones_log")"
    for zone_id in left main right; do
        case "$zone_id" in
            left) zone_name=Reference ;;
            main) zone_name=Work ;;
            right) zone_name=Comms ;;
        esac
        configured="$(zone_field "$zones_log" "$zone_id" configured)"
        effective="$(zone_field "$zones_log" "$zone_id" effective)"
        override_state="$(zone_field "$zones_log" "$zone_id" override-state)"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$phase_name" "$zone_id" "$zone_name" "$configured" "$effective" "$override_state" "$chip" >>"${MEASUREMENTS}"
    done
}

measurement_field() {
    local phase_name="$1"
    local zone_id="$2"
    local field="$3"
    /usr/bin/awk -F'\t' -v phase="$phase_name" -v zone="$zone_id" -v field="$field" '
        BEGIN {
            indexByName["configured"] = 4
            indexByName["effective"] = 5
            indexByName["override-state"] = 6
            indexByName["chip"] = 7
        }
        $1 == phase && $2 == zone {
            print $indexByName[field]
            exit
        }
    ' "${MEASUREMENTS}"
}

backup_path_from_save_log() {
    /usr/bin/awk -F': ' '$1 == "Backup" { print $2; exit }' "$1"
}

rollback_path_from_restore_log() {
    /usr/bin/awk -F': ' '$1 == "Previous config backup" { print $2; exit }' "$1"
}

assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [ "$actual" = "$expected" ] || semantic_fail "${message}: expected '${expected}', got '${actual}'"
}

assert_float_approximately_equal() {
    local left="$1"
    local right="$2"
    local tolerance="$3"
    local message="$4"
    /usr/bin/awk -v left="$left" -v right="$right" -v tolerance="$tolerance" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - right) <= tolerance ? 0 : 1) }
    ' || semantic_fail "${message}: expected ${left} ~= ${right} within ${tolerance}"
}

assert_task_documents_present() {
    local path="$1"
    local context="$2"
    for title in "${REFERENCE_TITLE}" "${WORK_TITLE}" "${COMMS_TITLE}"; do
        [ -n "$(field_for_title "$path" "$title" id)" ] || {
            cat "$path" >&2 || true
            semantic_fail "${context}: missing ${title}"
        }
    done
}

assert_anchor_windows_in_expected_zones() {
    local path="$1"
    local context="$2"
    assert_task_documents_present "$path" "$context"
    assert_window_zone "$path" "${REFERENCE_TITLE}" left
    assert_window_zone "$path" "${WORK_TITLE}" main
    assert_window_zone "$path" "${COMMS_TITLE}" right
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(field_for_title "$path" "$title" zone)"
    [ "$actual_zone" = "$expected_zone" ] || {
        cat "$path" >&2 || true
        semantic_fail "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}"
    }
}

wait_for_task_documents() {
    for _ in $(seq 1 60); do
        refresh_window_log "${WINDOW_SETUP_LOG}" || true
        if [ -n "$(field_for_title "${WINDOW_SETUP_LOG}" "${REFERENCE_TITLE}" id)" ] &&
           [ -n "$(field_for_title "${WINDOW_SETUP_LOG}" "${WORK_TITLE}" id)" ] &&
           [ -n "$(field_for_title "${WINDOW_SETUP_LOG}" "${COMMS_TITLE}" id)" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

move_window_to_zone() {
    ensure_window_in_zone "$@"
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
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
}

launch_winmux() {
    local phase_name="$1"
    {
        printf '%s-launch-offset-seconds=%s\n' "$phase_name" "${SECONDS}"
        echo '$ launchctl bootstrap WinMux slice service'
    } >>"${RELAUNCH_LOG}"
    write_launch_plist
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-46-zone-count-${phase_name}.txt" 2>"${WAIT_ERR}"; then
            printf '%s-launched=yes\n' "$phase_name" >>"${RELAUNCH_LOG}"
            return
        fi
        sleep 1
    done

    cat "${LAUNCH_STATUS}" >&2 || true
    copy_runtime_logs
    cat "${APP_LOG}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    semantic_fail "WinMux CLI did not become ready during ${phase_name}"
}

stop_winmux() {
    local phase_name="$1"
    {
        printf '%s-stop-offset-seconds=%s\n' "$phase_name" "${SECONDS}"
        echo '$ launchctl bootout WinMux slice service'
    } >>"${RELAUNCH_LOG}"
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
        if ! "${CLI}" list-zones --count >/dev/null 2>&1; then
            printf '%s-stopped=yes\n' "$phase_name" >>"${RELAUNCH_LOG}"
            copy_runtime_logs
            return
        fi
        sleep 1
    done
    printf '%s-stopped=unknown-cli-still-responded\n' "$phase_name" >>"${RELAUNCH_LOG}"
    copy_runtime_logs
    cat "${RELAUNCH_LOG}" >&2 || true
    semantic_fail "WinMux did not stop during ${phase_name}; CLI still responded after bootout"
}

write_bad_config() {
    cat >"${CONFIG}" <<'TOML'
config-version = 2
auto-reload-config = false

[[zone-layouts]]
id = 'balanced'
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.10 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.10 },
]

[[zones]]
monitor = 1
layout-preset = 'balanced'
TOML
}

setup_slice() {
    rm -f \
        "${DONE}" "${PROOF}" "${PROOF_MANIFEST}" "${EVENT_MANIFEST}" "${SETUP_LOG}" \
        "${WINDOW_SETUP_LOG}" "${WINDOWS_ORIGINAL_LOG}" "${WINDOWS_AFTER_SAVE_LOG}" "${WINDOWS_RELAUNCH_SAVED_LOG}" \
        "${WINDOWS_BAD_CONFIG_LOG}" "${WINDOWS_AFTER_RESTORE_LOG}" "${WINDOWS_FINAL_RESTORED_LOG}" \
        "${ZONES_ORIGINAL_LOG}" "${ZONES_RESIZED_LOG}" "${ZONES_AFTER_SAVE_LOG}" "${ZONES_RELAUNCH_SAVED_LOG}" \
        "${ZONES_AFTER_RESTORE_LOG}" "${ZONES_FINAL_RESTORED_LOG}" "${RESIZE_LOG}" "${SAVE_LOG}" "${RELAUNCH_LOG}" \
        "${BAD_CONFIG_LOG}" "${CONFIG_CHECK_BAD_LOG}" "${DOCTOR_BAD_LOG}" "${BAD_CONFIG_BOARD_SOURCE}" "${RESTORE_LOG}" \
        "${CONFIG_CHECK_RESTORED_LOG}" "${DOCTOR_RESTORED_LOG}" "${RESTORE_BOARD_SOURCE}" "${FINAL_BOARD_SOURCE}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${MEASUREMENTS}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" \
        "${CONFIG_ORIGINAL_COPY}" "${CONFIG_AFTER_SAVE_COPY}" "${GOOD_SAVED_BACKUP}" "${BAD_CONFIG_COPY}" \
        "${CONFIG_AFTER_RESTORE_COPY}" "${CONFIG_FINAL_COPY}" "${CONFIG_SAVE_BACKUP_COPY}" "${ROLLBACK_BAD_CONFIG_COPY}" \
        "${SAVE_BACKUP_PATH_LOG}" "${ROLLBACK_PATH_LOG}" "${CONFIG_SHA_ORIGINAL}" "${CONFIG_SHA_AFTER_SAVE}" \
        "${CONFIG_SHA_SAVE_BACKUP}" "${CONFIG_SHA_GOOD_SAVED}" "${CONFIG_SHA_BAD}" "${CONFIG_SHA_ROLLBACK_BAD}" \
        "${CONFIG_SHA_AFTER_RESTORE}" "${CONFIG_SHA_FINAL}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${REFERENCE_DOC}" 'Reference Queue' 'Reference' 'Original and restored layout must keep this in the left zone.'
    write_zone_doc "${WORK_DOC}" 'Primary Work' 'Work' 'This center column grows to 60%, then survives relaunch and restore.'
    write_zone_doc "${COMMS_DOC}" 'Comms Panel' 'Comms' 'This right column shrinks to 20% and verifies rollback recovery.'

    /bin/cp "${CONFIG}" "${CONFIG_ORIGINAL_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_ORIGINAL}"
    launch_winmux initial
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_task_documents || semantic_fail 'Slice 46 task documents did not appear'

    local reference_id work_id comms_id
    reference_id="$(field_for_title "${WINDOW_SETUP_LOG}" "${REFERENCE_TITLE}" id)"
    work_id="$(field_for_title "${WINDOW_SETUP_LOG}" "${WORK_TITLE}" id)"
    comms_id="$(field_for_title "${WINDOW_SETUP_LOG}" "${COMMS_TITLE}" id)"
    [ -n "${reference_id}" ] || semantic_fail "Missing ${REFERENCE_TITLE} window id"
    [ -n "${work_id}" ] || semantic_fail "Missing ${WORK_TITLE} window id"
    [ -n "${comms_id}" ] || semantic_fail "Missing ${COMMS_TITLE} window id"

    move_window_to_zone "${reference_id}" "${REFERENCE_TITLE}" Reference left "${WINDOW_SETUP_LOG}" "${CLI_LOG}"
    move_window_to_zone "${work_id}" "${WORK_TITLE}" Work main "${WINDOW_SETUP_LOG}" "${CLI_LOG}"
    move_window_to_zone "${comms_id}" "${COMMS_TITLE}" Comms right "${WINDOW_SETUP_LOG}" "${CLI_LOG}"
    "${CLI}" focus-zone Work >/dev/null 2>>"${WAIT_ERR}" || true
    "${CLI}" focus --window-id "${work_id}" >/dev/null 2>>"${WAIT_ERR}" || true
    write_zones_log "${ZONES_ORIGINAL_LOG}"
    refresh_window_log "${WINDOWS_ORIGINAL_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_ORIGINAL_LOG}" 'Setup'
    capture_guest_screenshot '01-ready-slice-46'

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'WinMux Slice 46: persistence, doctor, rollback'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Commands: save-zone-layout; relaunch; write bad config; doctor; config --restore-backup; relaunch'
        echo 'setup=result=success'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee "${SETUP_LOG}"
    copy_runtime_logs
}

write_event_manifest() {
    cat >"${EVENT_MANIFEST}" <<MANIFEST
# event-id	kind	seconds	caption-label	sample-label	path	expected
original-layout	context	${original_offset}	caption-02	original-layout	screenshots/02-original-layout-slice-46.png	original layout shows Reference 25%, Work 50%, Comms 25%
saved-layout	action	${save_offset}	caption-03	saved-layout	screenshots/03-saved-layout-slice-46.png	save-zone-layout writes 20/60/20 runtime widths and records backup
relaunch-saved-layout	relaunch	${relaunch_saved_offset}	caption-04	relaunch-saved-layout	screenshots/04-relaunch-saved-layout-slice-46.png	fresh relaunch reads saved 20/60/20 layout without another resize
bad-config-doctor	diagnostic	${doctor_bad_offset}	caption-05	bad-config-doctor	screenshots/05-bad-config-doctor-slice-46.png	bad config is visible and doctor reports Config doctor ERROR
restore-backup	recovery	${restore_offset}	caption-06	restore-backup	screenshots/06-restore-backup-slice-46.png	config --restore-backup restores saved-good backup and rolls bad config aside
final-restored-layout	result	${final_offset}	caption-07	final-restored-layout	screenshots/07-final-restored-layout-slice-46.png	final relaunch reads restored saved layout and no config was deleted
MANIFEST
}

write_proof_manifest() {
    cat >"${PROOF_MANIFEST}" <<MANIFEST
kind	key	value
target	monitor	1
target	layout-id	balanced
command	resize	winmux resize-zone Work width +10%
command	save	winmux save-zone-layout
command	doctor	winmux doctor
command	restore	winmux config --restore-backup ${GOOD_SAVED_BACKUP}
safety	save-backup-path	${save_backup_path}
safety	save-backup-matches-original	yes
safety	good-saved-backup-path	${GOOD_SAVED_BACKUP}
safety	bad-config-not-deleted	yes
safety	rollback-bad-config-path	${rollback_path}
relaunch	saved-layout-loaded	yes
relaunch	saved-stopped	yes
relaunch	saved-launched	yes
restore	restored-layout-loaded	yes
restore	restored-stopped	yes
restore	restored-launched	yes
doctor	bad-config-status	ERROR
doctor	restored-config-status	OK
doctor	zone-references-checked	yes
retry	no-post-recording-retry	required-by-verifier
measurement	original	$(measurement_field original left chip)
measurement	saved	$(measurement_field saved left chip)
measurement	relaunch-saved	$(measurement_field relaunch-saved left chip)
measurement	final-restored	$(measurement_field final-restored left chip)
width-original	left	${original_left}
width-original	main	${original_main}
width-original	right	${original_right}
width-saved	left	${saved_left}
width-saved	main	${saved_main}
width-saved	right	${saved_right}
width-final-restored	left	${final_left}
width-final-restored	main	${final_main}
width-final-restored	right	${final_right}
hash	config-original	${original_sha}
hash	config-after-save	${after_save_sha}
hash	config-save-backup	${save_backup_sha}
hash	config-good-saved	${good_saved_sha}
hash	config-bad	${bad_sha}
hash	config-rollback-bad	${rollback_bad_sha}
hash	config-after-restore	${after_restore_sha}
hash	config-final	${final_sha}
MANIFEST
}

run_proof() {
    SECONDS=0
    : >"${TIMING_LOG}"
    : >"${RELAUNCH_LOG}"
    printf 'phase\tzone-id\tzone-name\tconfigured\teffective\toverride-state\tchip\n' >"${MEASUREMENTS}"
    [ -f "${STATE_FILE}" ] || semantic_fail 'Missing Slice 46 state file'
    # shellcheck disable=SC1090
    source "${STATE_FILE}"

    "${CLI}" focus-zone Work >/dev/null 2>>"${WAIT_ERR}" || true
    refresh_window_log "${WINDOWS_ORIGINAL_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_ORIGINAL_LOG}" 'Original'
    write_zones_log "${ZONES_ORIGINAL_LOG}"
    append_measurements original "${ZONES_ORIGINAL_LOG}"
    sleep_until_recording_offset 8 18 'original layout'
    original_offset="${SECONDS}"
    printf 'original-layout-offset-seconds=%s\n' "${original_offset}" >>"${TIMING_LOG}"
    capture_guest_screenshot '02-original-layout-slice-46'

    sleep_until_recording_offset 20 30 'save current runtime layout'
    resize_offset="${SECONDS}"
    printf 'resize-command-offset-seconds=%s\n' "${resize_offset}" >>"${TIMING_LOG}"
    {
        mark_mutation_once
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    write_zones_log "${ZONES_RESIZED_LOG}"
    append_measurements resized "${ZONES_RESIZED_LOG}"

    save_offset="${SECONDS}"
    printf 'save-command-offset-seconds=%s\n' "${save_offset}" >>"${TIMING_LOG}"
    {
        echo '$ winmux save-zone-layout'
        "${CLI}" save-zone-layout
    } | tee "${SAVE_LOG}"
    save_backup_path="$(backup_path_from_save_log "${SAVE_LOG}")"
    [ -n "${save_backup_path}" ] || semantic_fail 'save-zone-layout did not print backup path'
    [ -f "${save_backup_path}" ] || semantic_fail "save backup missing: ${save_backup_path}"
    printf '%s\n' "${save_backup_path}" >"${SAVE_BACKUP_PATH_LOG}"
    /bin/cp "${save_backup_path}" "${CONFIG_SAVE_BACKUP_COPY}"
    /bin/cp "${CONFIG}" "${CONFIG_AFTER_SAVE_COPY}"
    /bin/cp "${CONFIG}" "${GOOD_SAVED_BACKUP}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_AFTER_SAVE}"
    config_sha256 "${CONFIG_SAVE_BACKUP_COPY}" >"${CONFIG_SHA_SAVE_BACKUP}"
    config_sha256 "${GOOD_SAVED_BACKUP}" >"${CONFIG_SHA_GOOD_SAVED}"
    write_zones_log "${ZONES_AFTER_SAVE_LOG}"
    append_measurements saved "${ZONES_AFTER_SAVE_LOG}"
    refresh_window_log "${WINDOWS_AFTER_SAVE_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_AFTER_SAVE_LOG}" 'After save'
    capture_guest_screenshot '03-saved-layout-slice-46'

    sleep_until_recording_offset 38 48 'relaunch saved layout'
    relaunch_saved_offset="${SECONDS}"
    printf 'relaunch-saved-offset-seconds=%s\n' "${relaunch_saved_offset}" >>"${TIMING_LOG}"
    stop_winmux saved
    launch_winmux saved
    write_zones_log "${ZONES_RELAUNCH_SAVED_LOG}"
    append_measurements relaunch-saved "${ZONES_RELAUNCH_SAVED_LOG}"
    refresh_window_log "${WINDOWS_RELAUNCH_SAVED_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_RELAUNCH_SAVED_LOG}" 'Relaunch saved'
    capture_guest_screenshot '04-relaunch-saved-layout-slice-46'

    sleep_until_recording_offset 54 68 'bad config doctor'
    doctor_bad_offset="${SECONDS}"
    printf 'bad-config-doctor-offset-seconds=%s\n' "${doctor_bad_offset}" >>"${TIMING_LOG}"
    {
        echo '$ write invalid generated config'
        write_bad_config
    } | tee "${BAD_CONFIG_LOG}"
    /bin/cp "${CONFIG}" "${BAD_CONFIG_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_BAD}"
    {
        echo "$ winmux config --check ${CONFIG}"
        if "${CLI}" config --check "${CONFIG}"; then
            semantic_fail 'bad config unexpectedly passed config --check'
        else
            echo 'expected-failure=yes'
        fi
    } >"${CONFIG_CHECK_BAD_LOG}" 2>&1
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_BAD_LOG}" 2>&1
    grep -F '  config status: ERROR' "${DOCTOR_BAD_LOG}" >/dev/null \
        || semantic_fail 'doctor did not report config status ERROR for bad config'
    grep -F 'Column widths must sum to 1.0' "${DOCTOR_BAD_LOG}" >/dev/null \
        || semantic_fail 'doctor did not report bad zone width sum'
    bad_config_details="$(
        {
            echo 'Visible proof: invalid generated config excerpt'
            /usr/bin/awk '/width =/ { print; count++ } count == 3 { exit }' "${BAD_CONFIG_COPY}"
            echo 'Visible proof: doctor output'
            /usr/bin/grep -F 'Config doctor:' "${DOCTOR_BAD_LOG}" || true
            /usr/bin/grep -F '  config status: ERROR' "${DOCTOR_BAD_LOG}" || true
            /usr/bin/grep -F 'Column widths must sum to 1.0' "${DOCTOR_BAD_LOG}" || true
        }
    )"
    write_audit_board \
        'Slice 46 bad config doctor' \
        'Config doctor reports ERROR from the real command output.' \
        'winmux doctor' \
        "${bad_config_details}" \
        "${BAD_CONFIG_BOARD_SOURCE}" \
        "${BOARD_TITLE_PREFIX}bad-config-doctor.rtf"
    refresh_window_log "${WINDOWS_BAD_CONFIG_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_BAD_CONFIG_LOG}" 'Bad config doctor'
    capture_guest_screenshot '05-bad-config-doctor-slice-46'

    sleep_until_recording_offset 74 86 'restore saved backup'
    restore_offset="${SECONDS}"
    printf 'restore-backup-offset-seconds=%s\n' "${restore_offset}" >>"${TIMING_LOG}"
    {
        echo "$ winmux config --restore-backup ${GOOD_SAVED_BACKUP}"
        "${CLI}" config --restore-backup "${GOOD_SAVED_BACKUP}"
    } | tee "${RESTORE_LOG}"
    rollback_path="$(rollback_path_from_restore_log "${RESTORE_LOG}")"
    [ -n "${rollback_path}" ] || semantic_fail 'restore output did not include rollback backup path'
    [ -f "${rollback_path}" ] || semantic_fail "rollback backup missing: ${rollback_path}"
    printf '%s\n' "${rollback_path}" >"${ROLLBACK_PATH_LOG}"
    /bin/cp "${rollback_path}" "${ROLLBACK_BAD_CONFIG_COPY}"
    /bin/cp "${CONFIG}" "${CONFIG_AFTER_RESTORE_COPY}"
    config_sha256 "${ROLLBACK_BAD_CONFIG_COPY}" >"${CONFIG_SHA_ROLLBACK_BAD}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_AFTER_RESTORE}"
    {
        echo "$ winmux config --check ${CONFIG}"
        "${CLI}" config --check "${CONFIG}"
    } >"${CONFIG_CHECK_RESTORED_LOG}" 2>&1
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_RESTORED_LOG}" 2>&1
    grep -F 'Restored config OK' "${RESTORE_LOG}" >/dev/null \
        || semantic_fail 'restore output missing success line'
    grep -F '  config status: OK' "${DOCTOR_RESTORED_LOG}" >/dev/null \
        || semantic_fail 'doctor did not report config status OK after restore'
    write_zones_log "${ZONES_AFTER_RESTORE_LOG}"
    append_measurements restored "${ZONES_AFTER_RESTORE_LOG}"
    restore_details="$(
        {
            echo 'Visible proof: restore output'
            /usr/bin/grep -F 'Previous config backup:' "${RESTORE_LOG}" || true
            /usr/bin/grep -F 'Restored config OK' "${RESTORE_LOG}" || true
            echo 'Visible proof: restored doctor output'
            /usr/bin/grep -F '  config status: OK' "${DOCTOR_RESTORED_LOG}" || true
            /usr/bin/grep -F '  zone references: OK' "${DOCTOR_RESTORED_LOG}" || true
        }
    )"
    write_audit_board \
        'Slice 46 restore backup' \
        'Saved-good backup restored; bad config copied to rollback backup.' \
        "winmux config --restore-backup ${GOOD_SAVED_BACKUP}" \
        "${restore_details}" \
        "${RESTORE_BOARD_SOURCE}" \
        "${BOARD_TITLE_PREFIX}restore-backup.rtf"
    refresh_window_log "${WINDOWS_AFTER_RESTORE_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_AFTER_RESTORE_LOG}" 'After restore'
    capture_guest_screenshot '06-restore-backup-slice-46'

    sleep_until_recording_offset 92 108 'final restored layout'
    final_offset="${SECONDS}"
    printf 'final-restored-offset-seconds=%s\n' "${final_offset}" >>"${TIMING_LOG}"
    stop_winmux restored
    launch_winmux restored
    write_zones_log "${ZONES_FINAL_RESTORED_LOG}"
    append_measurements final-restored "${ZONES_FINAL_RESTORED_LOG}"
    /bin/cp "${CONFIG}" "${CONFIG_FINAL_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_FINAL}"
    write_audit_board \
        'Slice 46 final restored layout' \
        'Final relaunch loads saved 20/60/20 layout from restored config.' \
        'winmux list-zones --format ...' \
        'No config deletion: rollback copy of the bad file is present and hashed.' \
        "${FINAL_BOARD_SOURCE}" \
        "${BOARD_TITLE_PREFIX}final-restored-layout.rtf"
    refresh_window_log "${WINDOWS_FINAL_RESTORED_LOG}"
    assert_anchor_windows_in_expected_zones "${WINDOWS_FINAL_RESTORED_LOG}" 'Final restored'
    capture_guest_screenshot '07-final-restored-layout-slice-46'

    local original_left original_main original_right saved_left saved_main saved_right final_left final_main final_right
    original_left="$(measurement_field original left effective)"
    original_main="$(measurement_field original main effective)"
    original_right="$(measurement_field original right effective)"
    saved_left="$(measurement_field saved left effective)"
    saved_main="$(measurement_field saved main effective)"
    saved_right="$(measurement_field saved right effective)"
    final_left="$(measurement_field final-restored left effective)"
    final_main="$(measurement_field final-restored main effective)"
    final_right="$(measurement_field final-restored right effective)"

    assert_float_approximately_equal "${original_left}" 0.25 0.000001 'Original Reference width is not 25%'
    assert_float_approximately_equal "${original_main}" 0.5 0.000001 'Original Work width is not 50%'
    assert_float_approximately_equal "${original_right}" 0.25 0.000001 'Original Comms width is not 25%'
    assert_float_approximately_equal "${saved_left}" 0.2 0.000001 'Saved Reference width is not 20%'
    assert_float_approximately_equal "${saved_main}" 0.6 0.000001 'Saved Work width is not 60%'
    assert_float_approximately_equal "${saved_right}" 0.2 0.000001 'Saved Comms width is not 20%'
    assert_float_approximately_equal "${final_left}" 0.2 0.000001 'Final restored Reference width is not 20%'
    assert_float_approximately_equal "${final_main}" 0.6 0.000001 'Final restored Work width is not 60%'
    assert_float_approximately_equal "${final_right}" 0.2 0.000001 'Final restored Comms width is not 20%'
    assert_equal "$(measurement_field final-restored main override-state)" configured \
        'Final restored Work should use configured width, not runtime override'

    local original_sha after_save_sha save_backup_sha good_saved_sha bad_sha rollback_bad_sha after_restore_sha final_sha
    original_sha="$(cat "${CONFIG_SHA_ORIGINAL}")"
    after_save_sha="$(cat "${CONFIG_SHA_AFTER_SAVE}")"
    save_backup_sha="$(cat "${CONFIG_SHA_SAVE_BACKUP}")"
    good_saved_sha="$(cat "${CONFIG_SHA_GOOD_SAVED}")"
    bad_sha="$(cat "${CONFIG_SHA_BAD}")"
    rollback_bad_sha="$(cat "${CONFIG_SHA_ROLLBACK_BAD}")"
    after_restore_sha="$(cat "${CONFIG_SHA_AFTER_RESTORE}")"
    final_sha="$(cat "${CONFIG_SHA_FINAL}")"

    [ "${after_save_sha}" != "${original_sha}" ] || semantic_fail 'save-zone-layout did not mutate config'
    assert_equal "${save_backup_sha}" "${original_sha}" 'save backup does not match original config'
    assert_equal "${rollback_bad_sha}" "${bad_sha}" 'rollback backup does not match bad config'
    assert_equal "${after_restore_sha}" "${good_saved_sha}" 'restored config does not match saved-good backup'
    assert_equal "${final_sha}" "${good_saved_sha}" 'final relaunched config does not match saved-good backup'

    write_event_manifest
    write_proof_manifest
    cat \
        "${RESIZE_LOG}" "${SAVE_LOG}" "${RELAUNCH_LOG}" "${BAD_CONFIG_LOG}" \
        "${CONFIG_CHECK_BAD_LOG}" "${DOCTOR_BAD_LOG}" "${RESTORE_LOG}" \
        "${CONFIG_CHECK_RESTORED_LOG}" "${DOCTOR_RESTORED_LOG}" \
        "${ZONES_FINAL_RESTORED_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 46: persistence, doctor, rollback'
        echo
        echo 'PASS: save-zone-layout writes a saved 20/60/20 layout, a fresh relaunch loads it, doctor rejects a bad generated config, config --restore-backup restores the saved-good config while preserving the bad file as a rollback backup, and the final relaunch loads the restored layout without deleting evidence.'
        echo "save-backup-path=${save_backup_path}"
        echo "rollback-bad-config-path=${rollback_path}"
        echo "widths-original=$(measurement_field original left chip)"
        echo "widths-saved=$(measurement_field saved left chip)"
        echo "widths-final-restored=$(measurement_field final-restored left chip)"
        echo "config-original-sha=${original_sha}"
        echo "config-after-save-sha=${after_save_sha}"
        echo "config-save-backup-sha=${save_backup_sha}"
        echo "config-bad-sha=${bad_sha}"
        echo "config-rollback-bad-sha=${rollback_bad_sha}"
        echo "config-final-sha=${final_sha}"
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
    copy_runtime_logs
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/logs"
    zone_window_helpers_self_test "${ARTIFACTS_DIR}/logs/zone-window-helper-self-test"
    recording_timing_helpers_self_test "${ARTIFACTS_DIR}/logs/recording-timing-helper-self-test"

    local save_log="${ARTIFACTS_DIR}/logs/slice-46-self-test-save.log"
    printf '%s\n' 'Saved zone layout' 'Backup: /tmp/winmux.toml.backup-20260702T000000Z' >"${save_log}"
    assert_equal "$(backup_path_from_save_log "${save_log}")" /tmp/winmux.toml.backup-20260702T000000Z \
        'backup_path_from_save_log did not parse backup path'

    local restore_log="${ARTIFACTS_DIR}/logs/slice-46-self-test-restore.log"
    printf '%s\n' \
        'Restored config from backup: /tmp/good.toml' \
        'Config path: /tmp/winmux.toml' \
        'Previous config backup: /tmp/winmux.toml.rollback-20260702T000000Z' \
        'Restored config OK' >"${restore_log}"
    assert_equal "$(rollback_path_from_restore_log "${restore_log}")" /tmp/winmux.toml.rollback-20260702T000000Z \
        'rollback_path_from_restore_log did not parse rollback path'

    local zones_fixture="${ARTIFACTS_DIR}/logs/slice-46-self-test-zones.log"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.2|effective=0.2|override=none|override-state=configured|workspace=ReferenceDesk|left=64|width=675|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.6|effective=0.6|override=none|override-state=configured|workspace=WorkDesk|left=739|width=2025|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.2|effective=0.2|override=none|override-state=configured|workspace=CommsDesk|left=2764|width=675|physical=1' \
        >"${zones_fixture}"
    assert_equal "$(measurement_chip_for_log "${zones_fixture}")" 'Reference 20% | Work 60% | Comms 20%' \
        'measurement_chip_for_log did not render saved layout chip'

    printf '%s\n' 'result=success'
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
        semantic_fail "Unknown Slice 46 phase: ${PHASE}"
        ;;
esac
