#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE38_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE38_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE38_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-38-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_SLICE38_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
STARTER_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
USER_CONFIG_DIR="${HOME}/.config/winmux"
USER_CONFIG="${USER_CONFIG_DIR}/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-38-user-readiness"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice38-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice38-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice38"
LAUNCH_PLIST="/tmp/winmux-e2e-slice38.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice38.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-38-setup.log"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-38-user-config-before.toml"
CONFIG_UNCOMMENTED_COPY="${ARTIFACTS_DIR}/logs/slice-38-user-config-uncommented.toml"
CONFIG_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-38-config-path.log"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-38-config-check.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-38-list-zones.log"
FOCUS_ZONE_LOG="${ARTIFACTS_DIR}/logs/slice-38-focus-zone-comms.log"
WINDOW_BEFORE_MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-38-window-before-move.log"
WINDOW_AFTER_MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-38-window-after-move.log"
MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-38-move-node-to-zone.log"
ZONES_BEFORE_RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-38-zones-before-resize.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-38-zones-resized.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-38-resize-zone.log"
DRY_RUN_LOG="${ARTIFACTS_DIR}/logs/slice-38-save-zone-layout-dry-run.log"
CONFIG_SHA_BEFORE_DRY_RUN="${ARTIFACTS_DIR}/logs/slice-38-config-before-dry-run.sha256"
CONFIG_SHA_AFTER_DRY_RUN="${ARTIFACTS_DIR}/logs/slice-38-config-after-dry-run.sha256"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-38-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-38-command-timing.log"
VISIBLE_UNCOMMENTED_TEMPLATE="${ARTIFACTS_DIR}/logs/slice-38-visible-uncommented-template.txt"
VISIBLE_COMMENTED_TEMPLATE="${ARTIFACTS_DIR}/logs/slice-38-visible-commented-template.txt"
VISIBLE_RESULT="${ARTIFACTS_DIR}/logs/slice-38-visible-result.txt"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-38-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-38-user-readiness-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/user-readiness-docs"
COMMENTED_DOC="${DOC_DIR}/normal-user-config-commented.rtf"
UNCOMMENTED_DOC="${DOC_DIR}/normal-user-config-uncommented.rtf"
MOVE_DOC="${DOC_DIR}/readiness-move.rtf"
RESULT_DOC="${DOC_DIR}/normal-user-ready.rtf"

uid="$(/usr/bin/id -u)"

semantic_fail() {
    echo "$*" >&2
    exit 86
}

# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
source "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

rtf_escape_line() {
    /usr/bin/sed -e 's/\\/\\\\/g' -e 's/{/\\{/g' -e 's/}/\\}/g'
}

write_text_doc() {
    local source_path="$1"
    local title="$2"
    local out_path="$3"
    {
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs56\\b %s\\b0\\par\\f1\\fs27\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

config_sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

uncomment_template_in_place() {
    local source_path="$1"
    local tmp_path="${source_path}.tmp"
    /usr/bin/awk '
        /# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE/ {
            inside = 1
            print
            next
        }
        /# END WINMUX ULTRAWIDE ZONES TEMPLATE/ {
            inside = 0
            print
            next
        }
        inside == 1 {
            if ($0 ~ /^[[:space:]]*#$/) {
                print ""
                next
            }
            if ($0 ~ /^[[:space:]]*# ?/) {
                sub(/# ?/, "", $0)
            }
            print
            next
        }
        { print }
    ' "${source_path}" >"${tmp_path}"
    /bin/mv "${tmp_path}" "${source_path}"
}

write_visible_uncommented_template() {
    /bin/bash "${REPO_DIR}/script/e2e/write-visible-proof-excerpt" \
        --input "${CONFIG_UNCOMMENTED_COPY}" \
        --output "${VISIBLE_UNCOMMENTED_TEMPLATE}" \
        --title 'Active TOML excerpt from ~/.config/winmux/winmux.toml' \
        --required-table-regex '^[[:space:]]*\[\[zones\]\]' \
        --max-table-line 12 \
        --binding-table '[mode.zone.binding]' \
        --binding-keys 'tab a y c' \
        --forbid-regex '^[[:space:]]*# ?\[\[zones\]\]' \
        --summary 'Runtime config path: ~/.config/winmux/winmux.toml; zones: Reference | Work | Comms'
}

write_zones_log() {
    local path="$1"
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
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

wait_for_textedit_title() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_window_log "$path"
        if [ -n "$(field_for_title "$path" "$title" id)" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

assert_zone_present() {
    local zone_id="$1"
    local name="$2"
    local path="$3"
    /usr/bin/grep -F "zone=${zone_id}|name=${name}|" "${path}" >/dev/null \
        || semantic_fail "list-zones missing ${zone_id}/${name}"
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

assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [ "${actual}" = "${expected}" ] \
        || semantic_fail "${message}: expected '${expected}', got '${actual}'"
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} > ${right}"
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
    <string>${REPO_DIR}</string>
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
        semantic_fail 'Slice 38 LaunchAgent must not pass --config-path'
    fi
    if /usr/bin/grep -F 'WINMUX_DEFAULT_CONFIG_PATH' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 38 LaunchAgent must not set WINMUX_DEFAULT_CONFIG_PATH'
    fi
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-38-zone-count.txt" 2>"${WAIT_ERR}"; then
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

write_result_doc() {
    {
        printf 'Slice 38: normal user readiness\n\n'
        printf '$ winmux config --config-path\n'
        cat "${CONFIG_PATH_LOG}"
        printf '\n$ winmux config --check ~/.config/winmux/winmux.toml\n'
        cat "${CONFIG_CHECK_LOG}"
        printf "\n$ winmux list-zones --format 'zone=%%{monitor-zone-id}|name=%%{monitor-zone-name}'\n"
        cat "${LIST_ZONES_LOG}"
        printf '\n$ winmux focus-zone Comms\n'
        cat "${FOCUS_ZONE_LOG}"
        printf '\n$ winmux move-node-to-zone --focus-follows-window Work\n'
        cat "${MOVE_LOG}"
        printf '\n$ winmux resize-zone Work width +10%%\n'
        cat "${RESIZE_LOG}"
        printf '\n$ winmux save-zone-layout --dry-run\n'
        cat "${DRY_RUN_LOG}"
        printf '\nconfig-sha-before-dry-run=%s\n' "$(cat "${CONFIG_SHA_BEFORE_DRY_RUN}")"
        printf 'config-sha-after-dry-run=%s\n' "$(cat "${CONFIG_SHA_AFTER_DRY_RUN}")"
    } >"${VISIBLE_RESULT}"
    write_text_doc "${VISIBLE_RESULT}" \
        'Normal config path is ready for zones' \
        "${RESULT_DOC}"
}

cleanup() {
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    copy_runtime_logs
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_BEFORE_COPY}" "${CONFIG_UNCOMMENTED_COPY}" "${CONFIG_PATH_LOG}" \
        "${CONFIG_CHECK_LOG}" "${LIST_ZONES_LOG}" "${FOCUS_ZONE_LOG}" \
        "${WINDOW_BEFORE_MOVE_LOG}" "${WINDOW_AFTER_MOVE_LOG}" "${MOVE_LOG}" \
        "${ZONES_BEFORE_RESIZE_LOG}" "${ZONES_RESIZED_LOG}" "${RESIZE_LOG}" "${DRY_RUN_LOG}" \
        "${CONFIG_SHA_BEFORE_DRY_RUN}" "${CONFIG_SHA_AFTER_DRY_RUN}" "${CLI_LOG}" "${TIMING_LOG}" \
        "${VISIBLE_COMMENTED_TEMPLATE}" "${VISIBLE_UNCOMMENTED_TEMPLATE}" "${VISIBLE_RESULT}" \
        "${WAIT_ERR}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${USER_CONFIG_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"

    grep -F '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE' "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'normal user config missing template begin marker'
    grep -F '# [[zones]]' "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'normal user config missing commented zones template'
    if grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_BEFORE_COPY}" >/dev/null; then
        semantic_fail 'normal user config should not enable zones before uncommenting'
    fi

    /usr/bin/awk '
        /# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE/ { show = 1 }
        show == 1 { print }
        /# END WINMUX ULTRAWIDE ZONES TEMPLATE/ { exit }
    ' "${CONFIG_BEFORE_COPY}" >"${VISIBLE_COMMENTED_TEMPLATE}"
    write_text_doc "${VISIBLE_COMMENTED_TEMPLATE}" \
        'Commented template in ~/.config/winmux/winmux.toml' \
        "${COMMENTED_DOC}"
    /usr/bin/open -a TextEdit "${COMMENTED_DOC}"
    sleep 3

    {
        echo 'WinMux Slice 38: normal user readiness'
        echo "User config: ${USER_CONFIG}"
        echo "Repo working directory: ${REPO_DIR}"
        echo 'Launch command: WinMuxApp'
        echo 'Commands: uncomment template; winmux config --config-path; winmux config --check; winmux list-zones; winmux focus-zone Comms; winmux move-node-to-zone --focus-follows-window Work; winmux resize-zone Work width +10%; winmux save-zone-layout --dry-run'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

proof_slice() {
    trap cleanup EXIT
    SECONDS=0
    : >"${TIMING_LOG}"

    sleep_until_recording_offset 8 18 "Action: uncomment WINMUX ULTRAWIDE ZONES TEMPLATE"
    echo "uncomment-template-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
    uncomment_template_in_place "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_UNCOMMENTED_COPY}"
    grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'uncommented user config missing active [[zones]]'
    grep -F "tab = ['cycle-zone-layout balanced focus', 'mode main']" "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'uncommented user config missing zone mode layout binding'
    write_visible_uncommented_template
    write_text_doc "${VISIBLE_UNCOMMENTED_TEMPLATE}" \
        'Uncommented ~/.config/winmux/winmux.toml' \
        "${UNCOMMENTED_DOC}"
    /usr/bin/open -a TextEdit "${UNCOMMENTED_DOC}"
    sleep 3
    capture_guest_screenshot '02-user-config-uncommented-slice-38'
    sleep 4

    sleep_until_recording_offset 18 30 "Run: WinMuxApp"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    launch_winmux_normal

    sleep_until_recording_offset 30 39 "Run: winmux config --config-path"
    echo "config-path-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --config-path'
        "${CLI}" config --config-path
    } | tee "${CONFIG_PATH_LOG}"
    /usr/bin/grep -Fx "${USER_CONFIG}" "${CONFIG_PATH_LOG}" >/dev/null \
        || semantic_fail "runtime config path is not ${USER_CONFIG}"

    sleep_until_recording_offset 39 48 "Run: winmux config --check ~/.config/winmux/winmux.toml"
    echo "config-check-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } | tee "${CONFIG_CHECK_LOG}"
    grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config --check did not report success'

    sleep_until_recording_offset 48 58 "Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
    echo "list-zones-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        write_zones_log "${LIST_ZONES_LOG}"
    } | tee "${CLI_LOG}"
    assert_zone_present left Reference "${LIST_ZONES_LOG}"
    assert_zone_present main Work "${LIST_ZONES_LOG}"
    assert_zone_present right Comms "${LIST_ZONES_LOG}"

    sleep_until_recording_offset 58 68 "Run: winmux focus-zone Comms"
    echo "focus-zone-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo 'focus-zone=Comms'
        echo 'result=success'
    } | tee "${FOCUS_ZONE_LOG}"
    cat "${FOCUS_ZONE_LOG}" >>"${CLI_LOG}"

    sleep_until_recording_offset 68 78 "Action: open TextEdit readiness-move.rtf in Comms"
    echo "open-move-window-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        printf 'This window starts in Comms and moves to Work.\n'
        printf '\n$ winmux move-node-to-zone --focus-follows-window Work\n'
    } >"${DOC_DIR}/readiness-move.txt"
    write_text_doc "${DOC_DIR}/readiness-move.txt" \
        'readiness-move.rtf' \
        "${MOVE_DOC}"
    /usr/bin/open -a TextEdit "${MOVE_DOC}"
    wait_for_textedit_title 'readiness-move.rtf' "${WINDOW_BEFORE_MOVE_LOG}" \
        || semantic_fail 'readiness-move.rtf did not appear'
    assert_window_zone "${WINDOW_BEFORE_MOVE_LOG}" 'readiness-move.rtf' right
    capture_guest_screenshot '03-before-move-slice-38'

    sleep_until_recording_offset 78 90 "Run: winmux move-node-to-zone --focus-follows-window Work"
    echo "move-node-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    local move_id before_zone before_workspace
    move_id="$(field_for_title "${WINDOW_BEFORE_MOVE_LOG}" 'readiness-move.rtf' id)"
    before_zone="$(field_for_title "${WINDOW_BEFORE_MOVE_LOG}" 'readiness-move.rtf' zone)"
    before_workspace="$(field_for_title "${WINDOW_BEFORE_MOVE_LOG}" 'readiness-move.rtf' workspace)"
    {
        echo '$ winmux move-node-to-zone --focus-follows-window Work'
        printf 'window-id-before=%s\n' "${move_id}"
        printf 'before-zone=%s\n' "${before_zone}"
        printf 'before-workspace=%s\n' "${before_workspace}"
        "${CLI}" focus --window-id "${move_id}"
        "${CLI}" move-node-to-zone --focus-follows-window Work
    } | tee "${MOVE_LOG}"
    for _ in $(seq 1 30); do
        refresh_window_log "${WINDOW_AFTER_MOVE_LOG}"
        if [ "$(field_for_title "${WINDOW_AFTER_MOVE_LOG}" 'readiness-move.rtf' zone)" = main ]; then
            break
        fi
        sleep 1
    done
    local after_id after_zone after_workspace
    after_id="$(field_for_title "${WINDOW_AFTER_MOVE_LOG}" 'readiness-move.rtf' id)"
    after_zone="$(field_for_title "${WINDOW_AFTER_MOVE_LOG}" 'readiness-move.rtf' zone)"
    after_workspace="$(field_for_title "${WINDOW_AFTER_MOVE_LOG}" 'readiness-move.rtf' workspace)"
    {
        printf 'window-id-after=%s\n' "${after_id}"
        printf 'after-zone=%s\n' "${after_zone}"
        printf 'after-workspace=%s\n' "${after_workspace}"
    } | tee -a "${MOVE_LOG}"
    assert_equal "${after_id}" "${move_id}" 'moved window id changed'
    assert_equal "${after_zone}" main 'moved window did not land in Work/main'
    [ "${after_workspace}" != "${before_workspace}" ] \
        || semantic_fail 'move-node-to-zone did not change workspace'
    capture_guest_screenshot '04-after-move-slice-38'

    write_zones_log "${ZONES_BEFORE_RESIZE_LOG}" >/dev/null
    sleep_until_recording_offset 90 100 "Run: winmux resize-zone Work width +10%"
    echo "resize-zone-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    sleep 3
    write_zones_log "${ZONES_RESIZED_LOG}" >/dev/null
    local before_main resized_main
    before_main="$(zone_field "${ZONES_BEFORE_RESIZE_LOG}" main effective)"
    resized_main="$(zone_field "${ZONES_RESIZED_LOG}" main effective)"
    assert_float_gt "${resized_main}" "${before_main}" 'Work/main width did not grow after resize'

    sleep_until_recording_offset 100 110 "Run: winmux save-zone-layout --dry-run"
    echo "dry-run-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_SHA_BEFORE_DRY_RUN}"
    {
        echo '$ winmux save-zone-layout --dry-run'
        "${CLI}" save-zone-layout --dry-run
    } | tee "${DRY_RUN_LOG}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_SHA_AFTER_DRY_RUN}"
    assert_equal "$(cat "${CONFIG_SHA_AFTER_DRY_RUN}")" "$(cat "${CONFIG_SHA_BEFORE_DRY_RUN}")" \
        'save-zone-layout --dry-run changed the normal user config'
    grep -F "Dry run: would save zone layout 'balanced'" "${DRY_RUN_LOG}" >/dev/null \
        || semantic_fail 'dry-run output missing balanced layout target'
    grep -F "${USER_CONFIG}" "${DRY_RUN_LOG}" >/dev/null \
        || semantic_fail 'dry-run output missing normal user config path'

    sleep_until_recording_offset 110 120 "Result: normal config path is ready for Reference | Work | Comms"
    echo "result-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_result_doc
    /usr/bin/open -a TextEdit "${RESULT_DOC}"
    sleep 5
    capture_guest_screenshot '05-normal-user-ready-slice-38'

    cat \
        "${CONFIG_PATH_LOG}" "${CONFIG_CHECK_LOG}" "${LIST_ZONES_LOG}" "${FOCUS_ZONE_LOG}" \
        "${WINDOW_BEFORE_MOVE_LOG}" "${MOVE_LOG}" "${WINDOW_AFTER_MOVE_LOG}" \
        "${ZONES_BEFORE_RESIZE_LOG}" "${RESIZE_LOG}" "${ZONES_RESIZED_LOG}" "${DRY_RUN_LOG}" \
        >"${CLI_LOG}"

    cat >"${PROOF}" <<PROOF_TEXT
PASS: WinMux launched without --config-path, loaded ${USER_CONFIG}, listed Reference, Work, and Comms, moved readiness-move.rtf from Comms to Work, resized Work, and ran save-zone-layout --dry-run without changing the normal user config hash.

config-path:
$(cat "${CONFIG_PATH_LOG}")

move:
$(cat "${MOVE_LOG}")

resize:
$(cat "${RESIZE_LOG}")

dry-run:
$(cat "${DRY_RUN_LOG}")

timing:
$(cat "${TIMING_LOG}")
PROOF_TEXT
    echo 'result=success' >"${DONE}"
}

self_test() {
    case "${USER_CONFIG}" in
        "${ARTIFACTS_DIR}"/*|/tmp/*|/private/tmp/*)
            ;;
        *)
            semantic_fail "self-test USER_CONFIG must be artifact-local or temp, got ${USER_CONFIG}"
            ;;
    esac
    mkdir -p "$(dirname "${STARTER_CONFIG}")" "${USER_CONFIG_DIR}" "$(dirname "${CONFIG_UNCOMMENTED_COPY}")" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    cat >"${STARTER_CONFIG}" <<'TOML'
[mode.zone.binding]
    s = ['cycle-zone-snap-policy freeform snap-to-zone', 'mode main']
    # BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE
    # tab = ['cycle-zone-layout balanced focus', 'mode main']
    # a = ['cycle-zone-availability focus-only communications full-dashboard', 'mode main']
    # y = ['cycle-zone-style current urgent calm', 'mode main']
    # c = ['cycle-zone-scene triage deep-work', 'mode main']

# [[zones]]
# monitor = 1
# layout-preset = 'balanced'
# END WINMUX ULTRAWIDE ZONES TEMPLATE
TOML
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"
    uncomment_template_in_place "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_UNCOMMENTED_COPY}"
    grep -F "tab = ['cycle-zone-layout balanced focus', 'mode main']" "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'self-test uncommented config missing tab binding'
    grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'self-test uncommented config missing active zones table'
    if grep -F '# [[zones]]' "${CONFIG_UNCOMMENTED_COPY}" >/dev/null; then
        semantic_fail 'self-test uncommented config kept commented zones table'
    fi
    write_visible_uncommented_template
    grep -F 'Runtime config path: ~/.config/winmux/winmux.toml; zones: Reference | Work | Comms' \
        "${VISIBLE_UNCOMMENTED_TEMPLATE}" >/dev/null \
        || semantic_fail 'self-test visible excerpt missing normal config summary'
    write_launch_plist
    assert_launch_plist_is_normal_path
    grep -F "<string>${APP}</string>" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'self-test LaunchAgent missing bare WinMuxApp argument'
    grep -F "<string>${REPO_DIR}</string>" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'self-test LaunchAgent missing repo working directory'
    local fake_cli="${ARTIFACTS_DIR}/fake-winmux"
    local zones_self_test_log="${ARTIFACTS_DIR}/logs/slice-38-list-zones-self-test.log"
    cat >"${fake_cli}" <<'FAKE_CLI'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "list-zones" ]; then
    echo 'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.25|workspace=1|left=52.0|width=845.0|physical=1'
    exit 0
fi
echo "unexpected fake winmux command: $*" >&2
exit 64
FAKE_CLI
    chmod +x "${fake_cli}"
    local CLI="${fake_cli}"
    write_zones_log "${zones_self_test_log}" >/dev/null
    grep -Fx "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'" "${zones_self_test_log}" >/dev/null \
        || semantic_fail 'self-test list-zones log missing exact command header'
    grep -F 'zone=left|name=Reference|' "${zones_self_test_log}" >/dev/null \
        || semantic_fail 'self-test list-zones log missing zone row'
    printf 'result=success\n'
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    self-test)
        self_test
        ;;
    *)
        echo "Unknown Slice 38 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
