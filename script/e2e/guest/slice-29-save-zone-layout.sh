#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE29_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-29-save-zone-layout"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice29-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice29-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice29"
LAUNCH_PLIST="/tmp/winmux-e2e-slice29.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice29.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-29-save-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-29-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-29-windows-before.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-29-windows-after.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-29-zones-before.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-29-zones-after-resize.log"
ZONES_AFTER_DRY_RUN_LOG="${ARTIFACTS_DIR}/logs/slice-29-zones-after-dry-run.log"
ZONES_AFTER_SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-29-zones-after-save.log"
ZONES_AFTER_RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-29-zones-after-reload.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-29-resize-zone.log"
DRY_RUN_LOG="${ARTIFACTS_DIR}/logs/slice-29-save-zone-layout-dry-run.log"
SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-29-save-zone-layout.log"
RELOAD_LOG="${ARTIFACTS_DIR}/logs/slice-29-reload-config.log"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-29-config-check.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-29-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-29-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-29-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-29-window-ids.env"
CONFIG_SHA_BEFORE="${ARTIFACTS_DIR}/logs/slice-29-config-before.sha256"
CONFIG_SHA_AFTER_DRY_RUN="${ARTIFACTS_DIR}/logs/slice-29-config-after-dry-run.sha256"
CONFIG_SHA_AFTER_SAVE="${ARTIFACTS_DIR}/logs/slice-29-config-after-save.sha256"
BACKUP_SHA="${ARTIFACTS_DIR}/logs/slice-29-config-backup.sha256"
BACKUP_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-29-backup-path.txt"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-29-config-before.toml"
CONFIG_AFTER_COPY="${ARTIFACTS_DIR}/logs/slice-29-config-after.toml"
CONFIG_BACKUP_COPY="${ARTIFACTS_DIR}/logs/slice-29-config-backup.toml"
CONFIG_AFTER_EXCERPT="${ARTIFACTS_DIR}/logs/slice-29-config-after-excerpt.toml"
PROOF_MANIFEST="${ARTIFACTS_DIR}/logs/slice-29-save-zone-layout.proof-manifest.tsv"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-29-save-zone-layout-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-save-docs"
REFERENCE_DOC="${DOC_DIR}/reference-save.rtf"
WORK_DOC="${DOC_DIR}/work-save.rtf"
COMMS_DOC="${DOC_DIR}/comms-save.rtf"
DRY_RUN_DOC="${DOC_DIR}/save-zone-layout-dry-run.rtf"
SAVE_DOC="${DOC_DIR}/save-zone-layout-result.rtf"
CONFIG_DOC="${DOC_DIR}/saved-zone-layout-config.rtf"
RELOAD_DOC="${DOC_DIR}/save-zone-layout-reload.rtf"

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
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
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
        index($0, "id = \"" zone_id "\"") > 0 || index($0, "id = '\''" zone_id "'\''") > 0 {
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

backup_path_from_save_log() {
    /usr/bin/awk -F': ' '$1 == "Backup" { print $2; exit }' "$1"
}

extract_balanced_layout() {
    local source_path="$1"
    local out_path="$2"
    /usr/bin/awk '
        /^\[\[zone-layouts\]\]/ {
            if (capture) {
                printf "%s", block
                printed = 1
                exit
            }
            block = $0 "\n"
            in_layout = 1
            capture = 0
            next
        }
        in_layout {
            block = block $0 "\n"
            if ($0 ~ /^id = '\''balanced'\''$/ || $0 ~ /^id = "balanced"$/) {
                capture = 1
            }
        }
        END {
            if (capture && !printed) {
                printf "%s", block
            }
        }
    ' "$source_path" >"$out_path"
    if [ ! -s "$out_path" ]; then
        /bin/cp "$source_path" "$out_path"
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
        if [ -n "$(field_for_title "$path" "$title" id)" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
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

open_doc_in_work() {
    local doc_path="$1"
    local title="$2"
    /usr/bin/open -a TextEdit "${doc_path}"
    wait_for_textedit_title "${title}" "${WINDOW_AFTER_LOG}" || {
        echo "TextEdit window did not appear: ${title}" >&2
        cat "${WINDOW_AFTER_LOG}" >&2 || true
        exit 1
    }
    local doc_id
    doc_id="$(field_for_title "${WINDOW_AFTER_LOG}" "${title}" id)"
    test -n "${doc_id}"
    move_window_to_zone "${doc_id}" "${title}" Work main
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-29-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${ZONES_BEFORE_LOG}" "${ZONES_RESIZED_LOG}" "${ZONES_AFTER_DRY_RUN_LOG}" \
        "${ZONES_AFTER_SAVE_LOG}" "${ZONES_AFTER_RELOAD_LOG}" "${RESIZE_LOG}" "${DRY_RUN_LOG}" \
        "${SAVE_LOG}" "${RELOAD_LOG}" "${CONFIG_CHECK_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${CONFIG_SHA_BEFORE}" "${CONFIG_SHA_AFTER_DRY_RUN}" "${CONFIG_SHA_AFTER_SAVE}" \
        "${BACKUP_SHA}" "${BACKUP_PATH_LOG}" "${CONFIG_BEFORE_COPY}" "${CONFIG_AFTER_COPY}" \
        "${CONFIG_BACKUP_COPY}" "${CONFIG_AFTER_EXCERPT}" "${PROOF_MANIFEST}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 29: save runtime zone layout'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Commands: resize-zone Work width +10%; save-zone-layout --dry-run; save-zone-layout; reload-config'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${REFERENCE_DOC}" "Reference" "Reference" "save layout source"
    write_zone_doc "${WORK_DOC}" "Work" "Work" "runtime width grows before save"
    write_zone_doc "${COMMS_DOC}" "Comms" "Comms" "side zone narrows before save"

    /bin/cp "${CONFIG}" "${CONFIG_BEFORE_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_BEFORE}"
    launch_winmux
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 || {
        echo 'TextEdit windows did not appear' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        exit 1
    }

    local reference_id work_id comms_id
    reference_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'reference-save.rtf' id)"
    work_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'work-save.rtf' id)"
    comms_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'comms-save.rtf' id)"
    test -n "${reference_id}"
    test -n "${work_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'reference-save.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-save.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-save.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-save.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-save.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-save.rtf' right

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
    capture_guest_screenshot '02-before-save-resize-slice-29'
    sleep 8

    echo "resize-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    sleep 4
    write_zones_log "${ZONES_RESIZED_LOG}" >/dev/null
    refresh_window_log "${WINDOW_AFTER_LOG}"
    capture_guest_screenshot '03-after-runtime-resize-slice-29'
    sleep 8

    echo "dry-run-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux save-zone-layout --dry-run'
        "${CLI}" save-zone-layout --dry-run
    } | tee "${DRY_RUN_LOG}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_AFTER_DRY_RUN}"
    write_zones_log "${ZONES_AFTER_DRY_RUN_LOG}" >/dev/null
    write_text_doc "${DRY_RUN_LOG}" "save-zone-layout --dry-run" "${DRY_RUN_DOC}"
    open_doc_in_work "${DRY_RUN_DOC}" 'save-zone-layout-dry-run.rtf'
    sleep 6
    capture_guest_screenshot '04-dry-run-output-slice-29'
    sleep 6

    echo "save-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
        echo '$ winmux save-zone-layout'
        "${CLI}" save-zone-layout
    } | tee "${SAVE_LOG}"
    local backup_path
    backup_path="$(backup_path_from_save_log "${SAVE_LOG}")"
    test -n "${backup_path}"
    test -f "${backup_path}"
    printf '%s\n' "${backup_path}" >"${BACKUP_PATH_LOG}"
    /bin/cp "${backup_path}" "${CONFIG_BACKUP_COPY}"
    /bin/cp "${CONFIG}" "${CONFIG_AFTER_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_AFTER_SAVE}"
    config_sha256 "${CONFIG_BACKUP_COPY}" >"${BACKUP_SHA}"
    write_zones_log "${ZONES_AFTER_SAVE_LOG}" >/dev/null
    write_text_doc "${SAVE_LOG}" "save-zone-layout result" "${SAVE_DOC}"
    open_doc_in_work "${SAVE_DOC}" 'save-zone-layout-result.rtf'
    sleep 6
    capture_guest_screenshot '05-save-output-slice-29'

    extract_balanced_layout "${CONFIG}" "${CONFIG_AFTER_EXCERPT}"
    write_text_doc "${CONFIG_AFTER_EXCERPT}" "saved balanced layout" "${CONFIG_DOC}"
    open_doc_in_work "${CONFIG_DOC}" 'saved-zone-layout-config.rtf'
    sleep 6
    capture_guest_screenshot '06-config-after-save-slice-29'

    echo "reload-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux reload-config'
        "${CLI}" reload-config
    } | tee "${RELOAD_LOG}"
    {
        echo "\$ winmux config --check ${CONFIG}"
        "${CLI}" config --check "${CONFIG}"
    } | tee "${CONFIG_CHECK_LOG}"
    write_zones_log "${ZONES_AFTER_RELOAD_LOG}" >/dev/null
    {
        cat "${RELOAD_LOG}"
        cat "${CONFIG_CHECK_LOG}"
        cat "${ZONES_AFTER_RELOAD_LOG}"
    } >"${ARTIFACTS_DIR}/logs/slice-29-reload-inspect.txt"
    write_text_doc "${ARTIFACTS_DIR}/logs/slice-29-reload-inspect.txt" "reload + configured widths" "${RELOAD_DOC}"
    open_doc_in_work "${RELOAD_DOC}" 'save-zone-layout-reload.rtf'
    sleep 6
    capture_guest_screenshot '07-after-reload-inspect-slice-29'
    refresh_window_log "${WINDOW_AFTER_LOG}"

    local before_left before_main before_right resized_left resized_main resized_right
    local runtime_left runtime_main runtime_right saved_left saved_main saved_right
    local configured_left configured_main configured_right before_sha dry_sha save_sha backup_sha
    before_left="$(zone_field "${ZONES_BEFORE_LOG}" left width)"
    before_main="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    before_right="$(zone_field "${ZONES_BEFORE_LOG}" right width)"
    resized_left="$(zone_field "${ZONES_RESIZED_LOG}" left width)"
    resized_main="$(zone_field "${ZONES_RESIZED_LOG}" main width)"
    resized_right="$(zone_field "${ZONES_RESIZED_LOG}" right width)"
    runtime_left="$(zone_field "${ZONES_RESIZED_LOG}" left effective)"
    runtime_main="$(zone_field "${ZONES_RESIZED_LOG}" main effective)"
    runtime_right="$(zone_field "${ZONES_RESIZED_LOG}" right effective)"
    saved_left="$(toml_width_for_zone "${CONFIG}" left)"
    saved_main="$(toml_width_for_zone "${CONFIG}" main)"
    saved_right="$(toml_width_for_zone "${CONFIG}" right)"
    configured_left="$(zone_field "${ZONES_AFTER_RELOAD_LOG}" left configured)"
    configured_main="$(zone_field "${ZONES_AFTER_RELOAD_LOG}" main configured)"
    configured_right="$(zone_field "${ZONES_AFTER_RELOAD_LOG}" right configured)"
    before_sha="$(cat "${CONFIG_SHA_BEFORE}")"
    dry_sha="$(cat "${CONFIG_SHA_AFTER_DRY_RUN}")"
    save_sha="$(cat "${CONFIG_SHA_AFTER_SAVE}")"
    backup_sha="$(cat "${BACKUP_SHA}")"

    assert_float_gt "${resized_main}" "${before_main}" 'Work/main width did not grow before save'
    assert_float_lt "${resized_left}" "${before_left}" 'Reference/left width did not shrink before save'
    assert_float_lt "${resized_right}" "${before_right}" 'Comms/right width did not shrink before save'
    assert_equal "${dry_sha}" "${before_sha}" 'dry-run changed config hash'
    [ "${save_sha}" != "${before_sha}" ] \
        || semantic_fail 'save-zone-layout did not change config hash'
    assert_equal "${backup_sha}" "${before_sha}" 'backup file does not match original config'
    assert_float_approximately_equal "${saved_left}" "${runtime_left}" 0.000001 \
        'Saved Reference width does not match runtime effective width'
    assert_float_approximately_equal "${saved_main}" "${runtime_main}" 0.000001 \
        'Saved Work width does not match runtime effective width'
    assert_float_approximately_equal "${saved_right}" "${runtime_right}" 0.000001 \
        'Saved Comms width does not match runtime effective width'
    assert_float_approximately_equal "${configured_left}" "${runtime_left}" 0.000001 \
        'Reloaded Reference configured width does not match saved runtime width'
    assert_float_approximately_equal "${configured_main}" "${runtime_main}" 0.000001 \
        'Reloaded Work configured width does not match saved runtime width'
    assert_float_approximately_equal "${configured_right}" "${runtime_right}" 0.000001 \
        'Reloaded Comms configured width does not match saved runtime width'

    grep -F 'Dry run: would save zone layout' "${DRY_RUN_LOG}" >/dev/null \
        || semantic_fail 'dry-run output missing dry-run line'
    grep -F 'Saved zone layout' "${SAVE_LOG}" >/dev/null \
        || semantic_fail 'save output missing saved line'
    grep -F 'Backup:' "${SAVE_LOG}" >/dev/null \
        || semantic_fail 'save output missing backup path'
    grep -F "id = 'focus'" "${CONFIG}" >/dev/null \
        || semantic_fail 'unrelated focus layout disappeared after save'
    grep -F "[[zone-availability-sets]]" "${CONFIG}" >/dev/null \
        || semantic_fail 'zone availability sets disappeared after save'
    grep -F "[[zone-bindings]]" "${CONFIG}" >/dev/null \
        || semantic_fail 'zone bindings disappeared after save'
    grep -F "[[zone-affinities]]" "${CONFIG}" >/dev/null \
        || semantic_fail 'zone affinities disappeared after save'
    grep -F "[mouse.zone-snap]" "${CONFIG}" >/dev/null \
        || semantic_fail 'mouse config disappeared after save'
    grep -F '# preserve this comment' "${CONFIG}" >/dev/null \
        || semantic_fail 'column comment was not preserved after save'
    grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config --check did not report success after save'

    for title in reference-save.rtf work-save.rtf comms-save.rtf; do
        local expected_zone before_id after_id before_zone after_zone before_workspace after_workspace
        case "$title" in
            reference-save.rtf) expected_zone=left ;;
            work-save.rtf) expected_zone=main ;;
            comms-save.rtf) expected_zone=right ;;
            *) expected_zone= ;;
        esac
        before_id="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" id)"
        after_id="$(field_for_title "$WINDOW_AFTER_LOG" "$title" id)"
        before_zone="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" zone)"
        after_zone="$(field_for_title "$WINDOW_AFTER_LOG" "$title" zone)"
        before_workspace="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" workspace)"
        after_workspace="$(field_for_title "$WINDOW_AFTER_LOG" "$title" workspace)"
        [ -n "$before_id" ] && [ -n "$after_id" ] \
            || semantic_fail "Missing window title across logs: $title"
        assert_equal "$after_id" "$before_id" "window id changed for $title"
        assert_equal "$before_zone" "$expected_zone" "before zone mismatch for $title"
        assert_equal "$after_zone" "$expected_zone" "after zone mismatch for $title"
        assert_equal "$after_workspace" "$before_workspace" "workspace changed for $title"
    done

    cat >"${PROOF_MANIFEST}" <<MANIFEST
kind	key	value
target	monitor	1
target	layout-id	balanced
command	dry-run	winmux save-zone-layout --dry-run
command	save	winmux save-zone-layout
command	reload	winmux reload-config
safety	dry-run-mutated-config	no
safety	backup-path	${backup_path}
safety	backup-matches-original	yes
widths	before	${before_left},${before_main},${before_right}
widths	runtime-effective	${runtime_left},${runtime_main},${runtime_right}
widths	saved-config	${saved_left},${saved_main},${saved_right}
hash	config-before	${before_sha}
hash	config-after-dry-run	${dry_sha}
hash	config-after-save	${save_sha}
hash	config-backup	${backup_sha}
preserved	focus-layout	yes
preserved	availability-sets	yes
preserved	zone-bindings	yes
preserved	zone-affinities	yes
preserved	mouse-zone-snap	yes
preserved	column-comment	yes
MANIFEST

    cat \
        "${WINDOW_BEFORE_LOG}" "${RESIZE_LOG}" "${ZONES_RESIZED_LOG}" \
        "${DRY_RUN_LOG}" "${SAVE_LOG}" "${CONFIG_AFTER_EXCERPT}" \
        "${RELOAD_LOG}" "${CONFIG_CHECK_LOG}" "${ZONES_AFTER_RELOAD_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 29: save runtime zone layout'
        echo
        echo 'Commands:'
        cat "${RESIZE_LOG}"
        cat "${DRY_RUN_LOG}"
        cat "${SAVE_LOG}"
        cat "${RELOAD_LOG}"
        cat "${CONFIG_CHECK_LOG}"
        echo
        echo "backup-path=${backup_path}"
        echo "config-sha-before=${before_sha}"
        echo "config-sha-after-dry-run=${dry_sha}"
        echo "config-sha-after-save=${save_sha}"
        echo "config-backup-sha=${backup_sha}"
        echo "widths-before=left:${before_left},main:${before_main},right:${before_right}"
        echo "widths-runtime=left:${runtime_left},main:${runtime_main},right:${runtime_right}"
        echo "widths-saved=left:${saved_left},main:${saved_main},right:${saved_right}"
        echo "widths-reloaded-configured=left:${configured_left},main:${configured_main},right:${configured_right}"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: save-zone-layout writes current runtime widths back to the active named layout only after an explicit command, dry-run is read-only, a backup is created before replacement, and reload/config inspection sees the saved widths as configured baseline.'
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

    local zones_fixture="${ARTIFACTS_DIR}/logs/slice-29-self-test-zones.log"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=1|left=64.0|width=675.2|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.6|override=0.6|override-state=runtime|workspace=2|left=739.2|width=2025.6|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=3|left=2764.8|width=675.2|physical=1' \
        >"${zones_fixture}"
    assert_equal "$(zone_field "${zones_fixture}" main width)" 2025.6 \
        'zone_field did not parse main width'
    assert_equal "$(zone_field "${zones_fixture}" right override-state)" runtime \
        'zone_field did not parse right override state'

    local toml_fixture="${ARTIFACTS_DIR}/logs/slice-29-self-test-config.toml"
    printf '%s\n' \
        '[[zone-layouts]]' \
        "id = 'balanced'" \
        'columns = [' \
        "    { id = 'left', name = 'Reference', width = 0.2 }," \
        "    { id = 'main', name = 'Work', width = 0.6 }," \
        "    { id = 'right', name = 'Comms', width = 0.2 }," \
        ']' \
        >"${toml_fixture}"
    assert_equal "$(toml_width_for_zone "${toml_fixture}" main)" 0.6 \
        'toml_width_for_zone did not parse single-quoted main width'

    local save_log="${ARTIFACTS_DIR}/logs/slice-29-self-test-save.log"
    printf '%s\n' 'Saved zone layout' 'Backup: /tmp/winmux.toml.backup-20260630T000000Z' >"${save_log}"
    assert_equal "$(backup_path_from_save_log "${save_log}")" /tmp/winmux.toml.backup-20260630T000000Z \
        'backup_path_from_save_log did not parse backup path'

    local escaped
    escaped="$(printf '%s\n' 'path\with {braces}' | rtf_escape_line)"
    assert_equal "${escaped}" 'path\\with \{braces\}' \
        'rtf_escape_line did not escape backslashes and braces'

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
        echo "Unknown Slice 29 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
