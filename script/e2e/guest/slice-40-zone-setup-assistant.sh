#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE40_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE40_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE40_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-40-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_SOURCE_APP="${ARTIFACTS_DIR}/slice-40-self-test-bin/WinMuxApp"
    export WINMUX_E2E_SOURCE_CLI="${ARTIFACTS_DIR}/slice-40-self-test-bin/winmux"
    export WINMUX_E2E_SLICE40_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
APP_DEFAULT_CONFIG="${BIN_DIR}/default-config.toml"
STARTER_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
USER_CONFIG_DIR="${HOME}/.config/winmux"
USER_CONFIG="${USER_CONFIG_DIR}/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-40-zone-setup-assistant"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice40-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice40-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice40"
LAUNCH_PLIST="/tmp/winmux-e2e-slice40.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice40.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-40-setup.log"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-40-user-config-before.toml"
CONFIG_AFTER_COPY="${ARTIFACTS_DIR}/logs/slice-40-user-config-after.toml"
DRY_RUN_LOG="${ARTIFACTS_DIR}/logs/slice-40-zone-init-dry-run.log"
WRITE_LOG="${ARTIFACTS_DIR}/logs/slice-40-zone-init-write.log"
CONFIG_BEFORE_DRY_RUN_HASH="${ARTIFACTS_DIR}/logs/slice-40-config-before-dry-run.sha256"
CONFIG_AFTER_DRY_RUN_HASH="${ARTIFACTS_DIR}/logs/slice-40-config-after-dry-run.sha256"
BACKUP_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-40-backup-path.txt"
CONFIG_BACKUP_COPY="${ARTIFACTS_DIR}/logs/slice-40-config-backup.toml"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-40-config-check.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-40-list-zones.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-40-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-40-command-timing.log"
VISIBLE_READY="${ARTIFACTS_DIR}/logs/slice-40-visible-ready.txt"
VISIBLE_DRY_RUN="${ARTIFACTS_DIR}/logs/slice-40-visible-dry-run.txt"
VISIBLE_WRITE="${ARTIFACTS_DIR}/logs/slice-40-visible-write.txt"
VISIBLE_RESULT="${ARTIFACTS_DIR}/logs/slice-40-visible-result.txt"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-40-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-40-zone-setup-assistant-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/zone-setup-docs"
READY_DOC="${DOC_DIR}/zone-setup-ready.rtf"
DRY_RUN_DOC="${DOC_DIR}/zone-setup-dry-run.rtf"
WRITE_DOC="${DOC_DIR}/zone-setup-write.rtf"
RESULT_DOC="${DOC_DIR}/zone-setup-result.rtf"

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
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs54\\b %s\\b0\\par\\f1\\fs27\n' \
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

assert_no_active_zones() {
    local path="$1"
    if /usr/bin/grep -E '^[[:space:]]*\[\[zones\]\]' "$path" >/dev/null; then
        semantic_fail "expected no active [[zones]] in ${path}"
    fi
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
    <string>${HOME}</string>
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
        semantic_fail 'Slice 40 LaunchAgent must not pass --config-path'
    fi
    if /usr/bin/grep -F 'WINMUX_DEFAULT_CONFIG_PATH' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 40 LaunchAgent must not set WINMUX_DEFAULT_CONFIG_PATH'
    fi
    /usr/bin/grep -F "<string>${APP}</string>" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'Slice 40 LaunchAgent must launch the staged WinMuxApp executable'
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-40-zone-count.txt" 2>"${WAIT_ERR}"; then
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

write_zones_log() {
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${LIST_ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${LIST_ZONES_LOG}"
}

write_ready_doc() {
    {
        echo 'Slice 40 setup: normal config before zone init'
        echo
        echo "Config: ${USER_CONFIG}"
        echo 'State: no active [[zones]]'
        echo
        echo 'Next commands:'
        echo '$ winmux zone init --dry-run --preset balanced'
        echo '$ winmux zone init --preset balanced --write'
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
    } >"${VISIBLE_READY}"
    write_text_doc "${VISIBLE_READY}" \
        'Zone setup starts from a clean normal config' \
        "${READY_DOC}"
}

write_dry_run_doc() {
    {
        echo 'Slice 40 dry-run: preview only'
        echo
        echo '$ winmux zone init --dry-run --preset balanced'
        /usr/bin/sed -n '1,32p' "${DRY_RUN_LOG}"
        echo
        echo "before-hash=$(cat "${CONFIG_BEFORE_DRY_RUN_HASH}")"
        echo "after-hash=$(cat "${CONFIG_AFTER_DRY_RUN_HASH}")"
    } >"${VISIBLE_DRY_RUN}"
    write_text_doc "${VISIBLE_DRY_RUN}" \
        'Dry-run previews Reference, Work, and Comms' \
        "${DRY_RUN_DOC}"
}

write_write_doc() {
    {
        echo 'Slice 40 write: backup plus managed TOML'
        echo
        echo '$ winmux zone init --preset balanced --write'
        /usr/bin/sed -n '1,38p' "${WRITE_LOG}"
    } >"${VISIBLE_WRITE}"
    write_text_doc "${VISIBLE_WRITE}" \
        'Write creates a backup and managed block' \
        "${WRITE_DOC}"
}

write_result_doc() {
    {
        echo 'Slice 40 result: winmux zone init created Reference | Work | Comms'
        echo
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        cat "${CONFIG_CHECK_LOG}"
        echo
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'"
        cat "${LIST_ZONES_LOG}"
        echo
        echo 'Setup command for users:'
        echo 'winmux zone init --preset balanced --write'
    } >"${VISIBLE_RESULT}"
    write_text_doc "${VISIBLE_RESULT}" \
        'Zone setup assistant result' \
        "${RESULT_DOC}"
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_BEFORE_COPY}" "${CONFIG_AFTER_COPY}" "${DRY_RUN_LOG}" "${WRITE_LOG}" \
        "${CONFIG_BEFORE_DRY_RUN_HASH}" "${CONFIG_AFTER_DRY_RUN_HASH}" "${BACKUP_PATH_LOG}" \
        "${CONFIG_BACKUP_COPY}" "${CONFIG_CHECK_LOG}" "${LIST_ZONES_LOG}" "${CLI_LOG}" "${TIMING_LOG}" \
        "${VISIBLE_READY}" "${VISIBLE_DRY_RUN}" "${VISIBLE_WRITE}" "${VISIBLE_RESULT}" \
        "${WAIT_ERR}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" \
        "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${USER_CONFIG_DIR}" "${BIN_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${APP_DEFAULT_CONFIG}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"
    assert_no_active_zones "${CONFIG_BEFORE_COPY}"
    write_ready_doc
    /usr/bin/open -a TextEdit "${READY_DOC}"
    sleep 3

    {
        echo 'WinMux Slice 40: zone setup assistant'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Staged default config: ${APP_DEFAULT_CONFIG}"
        echo "User config: ${USER_CONFIG}"
        echo 'Initial config: no active [[zones]]'
        echo 'Commands: zone init dry-run; zone init write; config check; WinMuxApp; list-zones'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

run_proof() {
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"

    sleep_until_recording_offset 10 24 "Run: winmux zone init --dry-run --preset balanced"
    echo "dry-run-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_BEFORE_DRY_RUN_HASH}"
    {
        echo '$ winmux zone init --dry-run --preset balanced'
        "${CLI}" zone init --dry-run --preset balanced
    } >"${DRY_RUN_LOG}" 2>>"${WAIT_ERR}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_AFTER_DRY_RUN_HASH}"
    cat "${DRY_RUN_LOG}" | tee -a "${CLI_LOG}"
    cmp -s "${CONFIG_BEFORE_DRY_RUN_HASH}" "${CONFIG_AFTER_DRY_RUN_HASH}" \
        || semantic_fail 'zone init dry-run changed the config hash'
    for expected in 'Dry run: would append balanced zones' 'Reference' 'Work' 'Comms' 'Run with --write'; do
        /usr/bin/grep -F "$expected" "${DRY_RUN_LOG}" >/dev/null \
            || semantic_fail "dry-run log missing ${expected}"
    done
    write_dry_run_doc
    /usr/bin/open -a TextEdit "${DRY_RUN_DOC}"
    sleep 2
    capture_guest_screenshot "02-zone-init-dry-run-slice-40"

    sleep_until_recording_offset 24 40 "Run: winmux zone init --preset balanced --write"
    echo "write-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
    {
        echo '$ winmux zone init --preset balanced --write'
        "${CLI}" zone init --preset balanced --write
    } >"${WRITE_LOG}" 2>>"${WAIT_ERR}"
    cat "${WRITE_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/awk -F': ' '/^Backup:/ { print $2; exit }' "${WRITE_LOG}" >"${BACKUP_PATH_LOG}"
    backup_path="$(cat "${BACKUP_PATH_LOG}")"
    [ -n "${backup_path}" ] || semantic_fail 'write log did not include a Backup path'
    test -f "${backup_path}" || semantic_fail "backup path does not exist: ${backup_path}"
    /bin/cp "${backup_path}" "${CONFIG_BACKUP_COPY}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_AFTER_COPY}"
    for expected in 'Wrote balanced zones' 'Backup:' 'BEGIN WINMUX ZONE INIT MANAGED BLOCK' 'END WINMUX ZONE INIT MANAGED BLOCK' 'Reference' 'Work' 'Comms'; do
        /usr/bin/grep -F "$expected" "${WRITE_LOG}" >/dev/null \
            || semantic_fail "write log missing ${expected}"
    done
    /usr/bin/grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_AFTER_COPY}" >/dev/null \
        || semantic_fail 'generated config missing active [[zones]]'
    write_write_doc
    /usr/bin/open -a TextEdit "${WRITE_DOC}"
    sleep 2
    capture_guest_screenshot "03-zone-init-write-slice-40"

    sleep_until_recording_offset 40 52 "Run: winmux config --check ~/.config/winmux/winmux.toml"
    echo "config-check-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } >"${CONFIG_CHECK_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_CHECK_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config check did not pass'

    sleep_until_recording_offset 52 66 "Run: WinMuxApp"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    launch_winmux_normal
    echo '$ WinMuxApp' | tee -a "${CLI_LOG}"
    capture_guest_screenshot "04-zone-init-launched-slice-40"

    sleep_until_recording_offset 66 82 "Run: winmux list-zones --format zone|name|workspace"
    echo "list-zones-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_zones_log | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'zone=left|name=Reference|workspace=' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Reference zone missing after zone init'
    /usr/bin/grep -F 'zone=main|name=Work|workspace=' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Work zone missing after zone init'
    /usr/bin/grep -F 'zone=right|name=Comms|workspace=' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Comms zone missing after zone init'

    sleep_until_recording_offset 82 108 "Result: winmux zone init created Reference | Work | Comms"
    echo "result-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_result_doc
    /usr/bin/open -a TextEdit "${RESULT_DOC}"
    sleep 2
    capture_guest_screenshot "05-zone-setup-ready-slice-40"

    {
        echo "PASS: zone init writes normal user config before WinMux launches, preserves a backup, validates the generated config, and starts Reference, Work, and Comms from the normal path."
        echo "user-config=${USER_CONFIG}"
        echo "backup-path=${backup_path}"
        echo "launch-plist=${LAUNCH_PLIST_COPY}"
        echo "list-zones-log=${LIST_ZONES_LOG}"
    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
}

write_fake_cli() {
    cat >"${SOURCE_CLI}" <<'CLI'
#!/usr/bin/env bash
set -euo pipefail
config_path="${HOME}/.config/winmux/winmux.toml"
managed_block() {
    cat <<'BLOCK'
# BEGIN WINMUX ZONE INIT MANAGED BLOCK
# Generated by: winmux zone init --preset balanced --write
[[zones]]
monitor = 1
layout = 'columns'
default-zone = "main"
columns = [
    { id = "left", name = "Reference", width = 0.25 },
    { id = "main", name = "Work", width = 0.5 },
    { id = "right", name = "Comms", width = 0.25 },
]
# END WINMUX ZONE INIT MANAGED BLOCK
BLOCK
}
case "${1:-}" in
    zone)
        shift
        if [ "${1:-}" = "init" ] && [ "$*" = "init --dry-run --preset balanced" ]; then
            echo "Dry run: would append balanced zones to ${config_path}"
            echo 'Mode: dry-run'
            echo 'Preset: balanced'
            echo 'Selected monitor: monitor 1 Display 1 3440x1440 aspect 2.388889'
            echo 'TOML:'
            managed_block
            echo 'Run with --write to update the config.'
            exit 0
        fi
        if [ "${1:-}" = "init" ] && [ "$*" = "init --preset balanced --write" ]; then
            backup="${config_path}.backup-20260701T000000Z"
            cp "${config_path}" "${backup}"
            {
                cat "${config_path}"
                echo
                managed_block
            } >"${config_path}.tmp"
            mv "${config_path}.tmp" "${config_path}"
            echo "Wrote balanced zones to ${config_path}"
            echo 'Mode: write'
            echo 'Preset: balanced'
            echo 'Selected monitor: monitor 1 Display 1 3440x1440 aspect 2.388889'
            echo "Backup: ${backup}"
            echo 'TOML:'
            managed_block
            exit 0
        fi
        ;;
    config)
        if [ "${2:-}" = "--check" ]; then echo "Config OK: ${3:-${config_path}}"; exit 0; fi
        ;;
    list-zones)
        if [ "${2:-}" = "--count" ]; then echo 3; exit 0; fi
        echo 'zone=left|name=Reference|workspace=reference|layout=balanced|enabled=true|left=0|width=860|physical=1'
        echo 'zone=main|name=Work|workspace=work|layout=balanced|enabled=true|left=860|width=1720|physical=1'
        echo 'zone=right|name=Comms|workspace=comms|layout=balanced|enabled=true|left=2580|width=860|physical=1'
        exit 0
        ;;
esac
exit 64
CLI
    chmod +x "${SOURCE_CLI}"
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/config" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots" "$(dirname "${SOURCE_APP}")" "$(dirname "${SOURCE_CLI}")" "${DOC_DIR}" "${USER_CONFIG_DIR}" "${BIN_DIR}"
    printf '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE\n# [[zones]]\n# name = "Reference"\n# END WINMUX ULTRAWIDE ZONES TEMPLATE\n' >"${STARTER_CONFIG}"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${SOURCE_APP}"
    chmod +x "${SOURCE_APP}"
    write_fake_cli
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${APP_DEFAULT_CONFIG}"
    chmod +x "${APP}" "${CLI}"
    test -f "${APP_DEFAULT_CONFIG}"
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"
    assert_no_active_zones "${CONFIG_BEFORE_COPY}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_BEFORE_DRY_RUN_HASH}"
    {
        echo '$ winmux zone init --dry-run --preset balanced'
        "${CLI}" zone init --dry-run --preset balanced
    } >"${DRY_RUN_LOG}"
    config_sha256 "${USER_CONFIG}" >"${CONFIG_AFTER_DRY_RUN_HASH}"
    cmp -s "${CONFIG_BEFORE_DRY_RUN_HASH}" "${CONFIG_AFTER_DRY_RUN_HASH}" \
        || semantic_fail 'self-test dry-run changed config'
    echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}" >"${ARTIFACTS_DIR}/logs/slice-40-self-test-mutation-marker.log"
    {
        echo '$ winmux zone init --preset balanced --write'
        "${CLI}" zone init --preset balanced --write
    } >"${WRITE_LOG}"
    /usr/bin/awk -F': ' '/^Backup:/ { print $2; exit }' "${WRITE_LOG}" >"${BACKUP_PATH_LOG}"
    test -f "$(cat "${BACKUP_PATH_LOG}")"
    /bin/cp "${USER_CONFIG}" "${CONFIG_AFTER_COPY}"
    /bin/cp "$(cat "${BACKUP_PATH_LOG}")" "${CONFIG_BACKUP_COPY}"
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } >"${CONFIG_CHECK_LOG}"
    write_launch_plist
    assert_launch_plist_is_normal_path
    write_zones_log >"${CLI_LOG}"
    write_ready_doc
    write_dry_run_doc
    write_write_doc
    write_result_doc
    grep -F 'BEGIN WINMUX ZONE INIT MANAGED BLOCK' "${CONFIG_AFTER_COPY}" >/dev/null \
        || semantic_fail 'self-test managed block missing from generated config'
    grep -F 'zone=right|name=Comms|workspace=' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'self-test list-zones missing Comms'
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
        echo "Unknown Slice 40 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
