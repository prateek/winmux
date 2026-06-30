#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE28_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-28-export-zone-layout"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice28-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice28-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice28"
LAUNCH_PLIST="/tmp/winmux-e2e-slice28.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice28.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-28-export-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-28-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-28-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-28-windows-after.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-28-zones-before.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-28-zones-after-resize.log"
ZONES_AFTER_EXPORT_LOG="${ARTIFACTS_DIR}/logs/slice-28-zones-after-export.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-28-resize-zone.log"
EXPORT_LOG="${ARTIFACTS_DIR}/logs/slice-28-export-zone-layout.log"
EXPORT_TOML="${ARTIFACTS_DIR}/logs/slice-28-export-zone-layout.toml"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-28-config-check.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-28-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-28-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-28-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-28-window-ids.env"
CONFIG_SHA_BEFORE="${ARTIFACTS_DIR}/logs/slice-28-config-before.sha256"
CONFIG_SHA_AFTER="${ARTIFACTS_DIR}/logs/slice-28-config-after.sha256"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-28-export-zone-layout-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-export-docs"
REFERENCE_DOC="${DOC_DIR}/reference-export.rtf"
WORK_DOC="${DOC_DIR}/work-export.rtf"
COMMS_DOC="${DOC_DIR}/comms-export.rtf"
EXPORT_DOC="${DOC_DIR}/export-zone-layout-output.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit 86
}

config_sha256() {
    /usr/bin/shasum -a 256 "$CONFIG" | /usr/bin/awk '{ print $1 }'
}

write_zone_doc() {
    local path="$1"
    local title="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs82\b ${title}\b0\par\f1\fs34 zone: ${zone_name}\par ${detail}\par}
RTF
}

rtf_escape_line() {
    /usr/bin/sed -e 's/\\/\\\\/g' -e 's/{/\\{/g' -e 's/}/\\}/g'
}

write_export_doc() {
    {
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs64\\b export-zone-layout\\b0\\par\\f1\\fs28\n'
        printf 'command: winmux export-zone-layout saved-ultrawide --monitor 1\\par\n'
        printf 'result: emitted parseable [[zone-layouts]] TOML\\par\\par\n'
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${EXPORT_TOML}"
        printf '\\par config check:\\par\n'
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${CONFIG_CHECK_LOG}"
        printf '}'
    } >"${EXPORT_DOC}"
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${path}" 2>>"${WAIT_ERR}"
    cat "${path}"
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

toml_width_for_zone() {
    local path="$1"
    local zone_id="$2"
    /usr/bin/awk -v zone_id="${zone_id}" '
        index($0, "id = \"" zone_id "\"") > 0 {
            for (i = 1; i <= NF; i++) {
                if ($i == "width" && (i + 2) <= NF) {
                    value = $(i + 2)
                    gsub(/[^0-9.]/, "", value)
                    print value
                    exit
                }
            }
        }
    ' "${path}"
}

zone_for_title() {
    field_for_title "$1" "$2" zone
}

window_id_for_title() {
    field_for_title "$1" "$2" id
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

assert_float_approximately_equal() {
    local left="$1"
    local right="$2"
    local tolerance="$3"
    local message="$4"
    /usr/bin/awk -v left="${left}" -v right="${right}" -v tolerance="${tolerance}" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - right) <= tolerance ? 0 : 1) }
    ' || semantic_fail "${message}: expected ${left} ~= ${right} within ${tolerance}"
}

assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [ "${actual}" = "${expected}" ] \
        || semantic_fail "${message}: expected '${expected}', got '${actual}'"
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

wait_for_textedit_title() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_window_log "$path"
        if [ -n "$(window_id_for_title "$path" "$title")" ]; then
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-28-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" "${WINDOW_AFTER_LOG}" \
        "${ZONES_BEFORE_LOG}" "${ZONES_RESIZED_LOG}" "${ZONES_AFTER_EXPORT_LOG}" "${RESIZE_LOG}" \
        "${EXPORT_LOG}" "${EXPORT_TOML}" "${CONFIG_CHECK_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${CONFIG_SHA_BEFORE}" "${CONFIG_SHA_AFTER}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 28: export runtime zone layout'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Commands: resize-zone Work width +10%; export-zone-layout saved-ultrawide --monitor 1; config --check'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${REFERENCE_DOC}" "Reference" "Reference" "runtime export source layout"
    write_zone_doc "${WORK_DOC}" "Work" "Work" "will resize before export"
    write_zone_doc "${COMMS_DOC}" "Comms" "Comms" "side zone narrows after resize"

    config_sha256 >"${CONFIG_SHA_BEFORE}"
    launch_winmux
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 || {
        echo 'TextEdit windows did not appear' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        exit 1
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-export.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-export.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-export.rtf')"
    test -n "${reference_id}"
    test -n "${work_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'reference-export.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-export.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-export.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-export.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-export.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-export.rtf' right

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=reference-work-comms-visible'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${WORK_ID:-}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    capture_guest_screenshot '02-before-export-resize-slice-28'
    sleep 9

    echo "resize-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    sleep 4
    write_zones_log "${ZONES_RESIZED_LOG}" >/dev/null
    refresh_window_log "${WINDOW_AFTER_LOG}"
    capture_guest_screenshot '03-after-runtime-resize-slice-28'
    sleep 14

    echo "export-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux export-zone-layout saved-ultrawide --monitor 1'
        "${CLI}" export-zone-layout saved-ultrawide --monitor 1 | tee "${EXPORT_TOML}"
    } | tee "${EXPORT_LOG}"
    sleep 3

    echo "check-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "\$ winmux config --check ${EXPORT_TOML}"
        "${CLI}" config --check "${EXPORT_TOML}"
    } | tee "${CONFIG_CHECK_LOG}"
    write_export_doc
    /usr/bin/open -a TextEdit "${EXPORT_DOC}"
    wait_for_textedit_title 'export-zone-layout-output.rtf' "${WINDOW_AFTER_LOG}" || {
        echo 'Export output TextEdit window did not appear' >&2
        cat "${WINDOW_AFTER_LOG}" >&2 || true
        exit 1
    }
    local export_doc_id
    export_doc_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'export-zone-layout-output.rtf')"
    test -n "${export_doc_id}"
    move_window_to_zone "${export_doc_id}" 'export-zone-layout-output.rtf' Work main
    sleep 6
    capture_guest_screenshot '04-export-output-slice-28'
    sleep 8
    capture_guest_screenshot '05-config-check-slice-28'

    config_sha256 >"${CONFIG_SHA_AFTER}"
    write_zones_log "${ZONES_AFTER_EXPORT_LOG}" >/dev/null
    refresh_window_log "${WINDOW_AFTER_LOG}"
    capture_guest_screenshot '06-final-state-slice-28'

    local before_left before_main before_right resized_left resized_main resized_right
    local resized_left_effective resized_main_effective resized_right_effective
    before_left="$(zone_field "${ZONES_BEFORE_LOG}" left width)"
    before_main="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    before_right="$(zone_field "${ZONES_BEFORE_LOG}" right width)"
    resized_left="$(zone_field "${ZONES_RESIZED_LOG}" left width)"
    resized_main="$(zone_field "${ZONES_RESIZED_LOG}" main width)"
    resized_right="$(zone_field "${ZONES_RESIZED_LOG}" right width)"
    resized_left_effective="$(zone_field "${ZONES_RESIZED_LOG}" left effective)"
    resized_main_effective="$(zone_field "${ZONES_RESIZED_LOG}" main effective)"
    resized_right_effective="$(zone_field "${ZONES_RESIZED_LOG}" right effective)"

    assert_float_gt "${resized_main}" "${before_main}" 'Work/main width did not grow before export'
    assert_float_lt "${resized_left}" "${before_left}" 'Reference/left width did not shrink before export'
    assert_float_lt "${resized_right}" "${before_right}" 'Comms/right width did not shrink before export'
    assert_window_zone "${WINDOW_AFTER_LOG}" 'reference-export.rtf' left
    assert_window_zone "${WINDOW_AFTER_LOG}" 'work-export.rtf' main
    assert_window_zone "${WINDOW_AFTER_LOG}" 'comms-export.rtf' right
    assert_window_zone "${WINDOW_AFTER_LOG}" 'export-zone-layout-output.rtf' main

    grep -F '[[zone-layouts]]' "${EXPORT_TOML}" >/dev/null \
        || semantic_fail 'Exported TOML missing [[zone-layouts]]'
    grep -F 'id = "saved-ultrawide"' "${EXPORT_TOML}" >/dev/null \
        || semantic_fail 'Exported TOML missing saved-ultrawide id'
    grep -F 'default-zone = "main"' "${EXPORT_TOML}" >/dev/null \
        || semantic_fail 'Exported TOML missing default-zone main'
    assert_float_approximately_equal "$(toml_width_for_zone "${EXPORT_TOML}" left)" "${resized_left_effective}" 0.000001 \
        'Exported TOML Reference width does not match runtime effective width'
    assert_float_approximately_equal "$(toml_width_for_zone "${EXPORT_TOML}" main)" "${resized_main_effective}" 0.000001 \
        'Exported TOML Work width does not match runtime effective width'
    assert_float_approximately_equal "$(toml_width_for_zone "${EXPORT_TOML}" right)" "${resized_right_effective}" 0.000001 \
        'Exported TOML Comms width does not match runtime effective width'
    grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'Config check did not report success'

    local before_sha after_sha
    before_sha="$(cat "${CONFIG_SHA_BEFORE}")"
    after_sha="$(cat "${CONFIG_SHA_AFTER}")"
    [ -n "${before_sha}" ] && [ "${before_sha}" = "${after_sha}" ] \
        || semantic_fail "Copied config hash changed: ${before_sha:-missing} -> ${after_sha:-missing}"

    cat \
        "${WINDOW_BEFORE_LOG}" "${RESIZE_LOG}" "${ZONES_RESIZED_LOG}" \
        "${EXPORT_LOG}" "${EXPORT_TOML}" "${CONFIG_CHECK_LOG}" "${ZONES_AFTER_EXPORT_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 28: export runtime zone layout'
        echo
        echo 'Commands:'
        cat "${RESIZE_LOG}"
        cat "${EXPORT_LOG}"
        cat "${CONFIG_CHECK_LOG}"
        echo
        echo 'Before geometry:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'After runtime resize geometry:'
        cat "${ZONES_RESIZED_LOG}"
        echo
        echo 'Exported TOML:'
        cat "${EXPORT_TOML}"
        echo
        echo 'Config check:'
        cat "${CONFIG_CHECK_LOG}"
        echo
        echo "config-sha-before=${before_sha}"
        echo "config-sha-after=${after_sha}"
        echo "widths-before=left:${before_left},main:${before_main},right:${before_right}"
        echo "widths-resized=left:${resized_left},main:${resized_main},right:${resized_right}"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: export-zone-layout emits parseable [[zone-layouts]] TOML from current runtime widths after resize-zone, preserves zone ids/names/default-zone, and leaves copied config unchanged.'
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
    copy_runtime_logs
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/config" "${ARTIFACTS_DIR}/logs"

    local windows_fixture="${ARTIFACTS_DIR}/logs/slice-28-self-test-windows.log"
    local zones_fixture="${ARTIFACTS_DIR}/logs/slice-28-self-test-zones.log"
    printf '%s\n' \
        '53|reference-export.rtf|zone=left|workspace=1|monitor=Main' \
        '54|work-export.rtf|zone=main|workspace=2|monitor=Main' \
        '55|comms-export.rtf|zone=right|workspace=3|monitor=Main' \
        >"${windows_fixture}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=1|left=64.0|width=675.2|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.6|override=0.6|override-state=runtime|workspace=2|left=739.2|width=2025.6|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=3|left=2764.8|width=675.2|physical=1' \
        >"${zones_fixture}"

    assert_equal "$(field_for_title "${windows_fixture}" 'work-export.rtf' zone)" main \
        'field_for_title did not parse Work zone'
    assert_equal "$(field_for_title "${windows_fixture}" 'comms-export.rtf' workspace)" 3 \
        'field_for_title did not parse Comms workspace'
    assert_equal "$(field_for_title "${windows_fixture}" 'reference-export.rtf' id)" 53 \
        'field_for_title did not parse Reference id'
    assert_equal "$(zone_field "${zones_fixture}" main width)" 2025.6 \
        'zone_field did not parse main width'
    assert_equal "$(zone_field "${zones_fixture}" left override-state)" runtime \
        'zone_field did not parse left override state'

    local toml_fixture="${ARTIFACTS_DIR}/logs/slice-28-self-test-export.toml"
    printf '%s\n' \
        '[[zone-layouts]]' \
        'id = "saved-ultrawide"' \
        'columns = [' \
        '    { id = "left", name = "Reference", width = 0.2 },' \
        '    { id = "main", name = "Work", width = 0.6 },' \
        '    { id = "right", name = "Comms", width = 0.2 },' \
        ']' \
        >"${toml_fixture}"
    assert_equal "$(toml_width_for_zone "${toml_fixture}" main)" 0.6 \
        'toml_width_for_zone did not parse main width'

    local escaped
    escaped="$(printf '%s\n' 'path\with {braces}' | rtf_escape_line)"
    assert_equal "${escaped}" 'path\\with \{braces\}' \
        'rtf_escape_line did not escape backslashes and braces'

    printf '%s\n' '[[zone-layouts]]' 'id = "balanced"' >"${CONFIG}"
    local before_hash after_hash
    before_hash="$(config_sha256)"
    after_hash="$(config_sha256)"
    assert_equal "${after_hash}" "${before_hash}" \
        'config_sha256 changed for unchanged fixture config'

    printf '%s\n' 'result=success'
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    self-test)
        self_test_slice
        ;;
    *)
        echo "Unknown Slice 28 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
