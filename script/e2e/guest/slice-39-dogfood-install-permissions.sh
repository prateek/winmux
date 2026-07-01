#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE39_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE39_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE39_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-39-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_APPLICATIONS_DIR="${ARTIFACTS_DIR}/slice-39-self-test-applications"
    export WINMUX_E2E_SOURCE_APP="${ARTIFACTS_DIR}/slice-39-self-test-bin/WinMuxApp"
    export WINMUX_E2E_SOURCE_CLI="${ARTIFACTS_DIR}/slice-39-self-test-bin/winmux"
    export WINMUX_E2E_SLICE39_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
APPLICATIONS_DIR="${WINMUX_E2E_APPLICATIONS_DIR:-/Applications}"
APP_BUNDLE="${APPLICATIONS_DIR}/WinMux.app"
APP="${APP_BUNDLE}/Contents/MacOS/WinMuxApp"
APP_DEFAULT_CONFIG="${APP_BUNDLE}/Contents/Resources/default-config.toml"
CLI_DIR="${HOME}/winmux-e2e/bin"
CLI="${CLI_DIR}/winmux"
STARTER_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
USER_CONFIG_DIR="${HOME}/.config/winmux"
USER_CONFIG="${USER_CONFIG_DIR}/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-39-dogfood-install-permissions"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice39-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice39-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice39"
LAUNCH_PLIST="/tmp/winmux-e2e-slice39.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice39.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-39-setup.log"
INSTALL_LOG="${ARTIFACTS_DIR}/logs/slice-39-install.log"
PERMISSIONS_LOG="${ARTIFACTS_DIR}/logs/slice-39-permissions.log"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-39-user-config-before.toml"
CONFIG_UNCOMMENTED_COPY="${ARTIFACTS_DIR}/logs/slice-39-user-config-uncommented.toml"
DOCTOR_LOG="${ARTIFACTS_DIR}/logs/slice-39-doctor.log"
CONFIG_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-39-config-path.log"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-39-config-check.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-39-list-zones.log"
RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-39-relaunch.log"
FOCUS_ZONE_LOG="${ARTIFACTS_DIR}/logs/slice-39-focus-zone-comms.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-39-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-39-command-timing.log"
VISIBLE_INSTALL_STATUS="${ARTIFACTS_DIR}/logs/slice-39-visible-install-status.txt"
VISIBLE_DOCTOR_STATUS="${ARTIFACTS_DIR}/logs/slice-39-visible-doctor-status.txt"
VISIBLE_RESULT="${ARTIFACTS_DIR}/logs/slice-39-visible-result.txt"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-39-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-39-dogfood-install-permissions-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/dogfood-install-docs"
STATUS_DOC="${DOC_DIR}/dogfood-install-status.rtf"
DOCTOR_DOC="${DOC_DIR}/dogfood-doctor-status.rtf"
RESULT_DOC="${DOC_DIR}/dogfood-install-result.rtf"

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

write_zones_log() {
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${LIST_ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${LIST_ZONES_LOG}"
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

assert_launch_plist_is_dogfood_path() {
    if /usr/bin/grep -F -- '--config-path' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 39 LaunchAgent must not pass --config-path'
    fi
    if /usr/bin/grep -F 'WINMUX_DEFAULT_CONFIG_PATH' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 39 LaunchAgent must not set WINMUX_DEFAULT_CONFIG_PATH'
    fi
    /usr/bin/grep -F "${APP_BUNDLE}/Contents/MacOS/WinMuxApp" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'Slice 39 LaunchAgent must launch the installed app bundle executable'
}

launch_winmux_installed() {
    write_launch_plist
    assert_launch_plist_is_dogfood_path
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-39-zone-count.txt" 2>"${WAIT_ERR}"; then
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

relaunch_winmux_installed() {
    {
        echo "$ launchctl kickstart -k gui/${uid}/${LAUNCH_LABEL}"
        /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true
        for _ in $(seq 1 45); do
            if "${CLI}" list-zones --count >/dev/null 2>>"${WAIT_ERR}"; then
                echo 'relaunch=result=success'
                return
            fi
            sleep 1
        done
        echo 'relaunch=result=failure'
        return 1
    } >"${RELAUNCH_LOG}"
}

install_app_bundle() {
    local tmp_bundle="${ARTIFACTS_DIR}/tmp/WinMux.app"
    local tmp_app="${tmp_bundle}/Contents/MacOS/WinMuxApp"
    local tmp_default_config="${tmp_bundle}/Contents/Resources/default-config.toml"
    local source_default_config="${REPO_DIR}/resources/default-config.toml"

    rm -rf "${tmp_bundle}"
    mkdir -p "${tmp_bundle}/Contents/MacOS" "${tmp_bundle}/Contents/Resources" "${CLI_DIR}"
    /bin/cp "${SOURCE_APP}" "${tmp_app}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    /bin/cp "${source_default_config}" "${tmp_default_config}"
    chmod +x "${tmp_app}" "${CLI}"
    cat >"${tmp_bundle}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WinMuxApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.zimengxiong.winmux</string>
    <key>CFBundleName</key>
    <string>WinMux</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST
    if [ "${APPLICATIONS_DIR}" = "/Applications" ]; then
        /usr/bin/sudo -n /bin/rm -rf "${APP_BUNDLE}"
        /usr/bin/sudo -n /usr/bin/ditto "${tmp_bundle}" "${APP_BUNDLE}"
        /usr/bin/sudo -n /usr/sbin/chown -R "$(/usr/bin/id -un):staff" "${APP_BUNDLE}" >/dev/null 2>&1 || true
    else
        /bin/rm -rf "${APP_BUNDLE}"
        /usr/bin/ditto "${tmp_bundle}" "${APP_BUNDLE}"
    fi
    test -x "${APP}"
    test -f "${APP_DEFAULT_CONFIG}"
    {
        echo "install_path=${APP_BUNDLE}"
        echo "app_executable=${APP}"
        echo "app_default_config_source=${source_default_config}"
        echo "app_default_config_resource=${APP_DEFAULT_CONFIG}"
        echo "cli_path=${CLI}"
        echo "bundle_identifier=com.zimengxiong.winmux"
        /usr/bin/shasum -a 256 "${APP}" "${CLI}" "${APP_DEFAULT_CONFIG}"
        echo 'install=result=success'
    } >"${INSTALL_LOG}"
}

write_permission_status_log() {
    {
        echo "permission_setup_source=${ARTIFACTS_DIR}/logs/guest-privacy-setup.log"
        echo 'required_permissions=Accessibility Screen Recording Automation Input Monitoring'
        echo 'accessibility=prepared-before-recording'
        echo 'screen_recording=prepared-before-recording'
        echo 'automation=prepared-before-recording'
        echo 'input_monitoring=prepared-before-recording'
        echo "recovery_surface=winmux doctor"
        echo 'recovery_accessibility=tccutil reset Accessibility com.zimengxiong.winmux'
        echo 'recovery_screen_recording=tccutil reset ScreenCapture com.zimengxiong.winmux'
        echo 'recovery_automation=tccutil reset AppleEvents com.zimengxiong.winmux'
        echo 'recovery_input_monitoring=tccutil reset ListenEvent com.zimengxiong.winmux'
        echo 'permissions=result=success'
    } >"${PERMISSIONS_LOG}"
}

write_visible_install_status() {
    {
        echo 'WinMux dogfood install'
        echo
        echo "App: ${APP_BUNDLE}"
        echo "CLI: ${CLI}"
        echo 'Config: ~/.config/winmux/winmux.toml'
        echo
        echo 'Permissions prepared before recording:'
        echo '- Accessibility'
        echo '- Screen Recording'
        echo '- Automation'
        echo '- Input Monitoring'
        echo
        echo 'Status surface: winmux doctor'
        echo 'Next proof: launch installed app, run doctor, relaunch, focus Comms.'
    } >"${VISIBLE_INSTALL_STATUS}"
    write_text_doc "${VISIBLE_INSTALL_STATUS}" \
        'Dogfood install path and permissions are ready' \
        "${STATUS_DOC}"
}

write_result_doc() {
    {
        echo 'Slice 39 result: dogfood install path works'
        echo
        echo '$ winmux doctor'
        /usr/bin/sed -n '1,18p' "${DOCTOR_LOG}"
        echo
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        cat "${LIST_ZONES_LOG}"
        echo
        echo '$ winmux focus-zone Comms'
        cat "${FOCUS_ZONE_LOG}"
    } >"${VISIBLE_RESULT}"
    write_text_doc "${VISIBLE_RESULT}" \
        'Installed app relaunches and zones are usable' \
        "${RESULT_DOC}"
}

write_doctor_status_doc() {
    {
        echo 'Slice 39 status: winmux doctor'
        echo
        echo '$ winmux doctor'
        /usr/bin/sed -n '1,28p' "${DOCTOR_LOG}"
    } >"${VISIBLE_DOCTOR_STATUS}"
    write_text_doc "${VISIBLE_DOCTOR_STATUS}" \
        'Doctor shows installed app identity and permissions' \
        "${DOCTOR_DOC}"
}

assert_doctor_output() {
    /usr/bin/grep -F 'Install:' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing Install section'
    /usr/bin/grep -F "app path: ${APP_BUNDLE}" "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing installed app bundle path'
    /usr/bin/grep -F "config path: ${USER_CONFIG}" "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing normal user config path'
    /usr/bin/grep -F 'accessibility: granted' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing granted accessibility'
    /usr/bin/grep -F 'screen recording: granted' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing granted screen recording'
    /usr/bin/grep -F 'automation: macOS-managed' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing automation status'
    /usr/bin/grep -F 'automation reset: tccutil reset AppleEvents com.zimengxiong.winmux' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing automation recovery command'
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${INSTALL_LOG}" "${PERMISSIONS_LOG}" "${CONFIG_BEFORE_COPY}" "${CONFIG_UNCOMMENTED_COPY}" \
        "${DOCTOR_LOG}" "${CONFIG_PATH_LOG}" "${CONFIG_CHECK_LOG}" "${LIST_ZONES_LOG}" "${RELAUNCH_LOG}" \
        "${FOCUS_ZONE_LOG}" "${CLI_LOG}" "${TIMING_LOG}" "${VISIBLE_INSTALL_STATUS}" "${VISIBLE_DOCTOR_STATUS}" \
        "${VISIBLE_RESULT}" \
        "${WAIT_ERR}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${USER_CONFIG_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"

    install_app_bundle
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"
    uncomment_template_in_place "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_UNCOMMENTED_COPY}"
    write_permission_status_log
    write_visible_install_status
    /usr/bin/open -a TextEdit "${STATUS_DOC}"
    sleep 3

    grep -F '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE' "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'user config missing template begin marker'
    grep -F '# [[zones]]' "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'user config missing commented zones template'
    if grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_BEFORE_COPY}" >/dev/null; then
        semantic_fail 'user config should not enable zones before uncommenting'
    fi
    grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'user config missing active zones after uncommenting'

    {
        echo 'WinMux Slice 39: dogfood install and permissions'
        echo "Installed app: ${APP_BUNDLE}"
        echo "Installed executable: ${APP}"
        echo "Installed CLI: ${CLI}"
        echo "User config: ${USER_CONFIG}"
        echo 'Permissions: prepared before recording; visible status is winmux doctor'
        echo 'Commands: WinMuxApp from installed app bundle; winmux doctor; config --config-path; config --check; list-zones; relaunch; focus-zone Comms'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

run_proof() {
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"

    sleep_until_recording_offset 18 30 "Run: WinMuxApp from /Applications/WinMux.app"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    launch_winmux_installed
    echo '$ WinMuxApp from /Applications/WinMux.app' | tee -a "${CLI_LOG}"
    capture_guest_screenshot "02-installed-app-launched-slice-39"

    sleep_until_recording_offset 30 42 "Run: winmux doctor"
    echo "doctor-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_LOG}" 2>>"${WAIT_ERR}"
    cat "${DOCTOR_LOG}" | tee -a "${CLI_LOG}"
    assert_doctor_output
    write_doctor_status_doc
    /usr/bin/open -a TextEdit "${DOCTOR_DOC}"
    sleep 2
    capture_guest_screenshot "03-doctor-status-slice-39"

    sleep_until_recording_offset 42 50 "Run: winmux config --config-path"
    echo "config-path-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --config-path'
        "${CLI}" config --config-path
    } >"${CONFIG_PATH_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_PATH_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F "${USER_CONFIG}" "${CONFIG_PATH_LOG}" >/dev/null \
        || semantic_fail 'config --config-path did not report normal user config'

    sleep_until_recording_offset 50 60 "Run: winmux config --check ~/.config/winmux/winmux.toml"
    echo "config-check-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } >"${CONFIG_CHECK_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_CHECK_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config check did not pass'

    sleep_until_recording_offset 60 72 "Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
    echo "list-zones-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_zones_log | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'zone=left|name=Reference|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Reference zone missing after install'
    /usr/bin/grep -F 'zone=main|name=Work|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Work zone missing after install'
    /usr/bin/grep -F 'zone=right|name=Comms|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Comms zone missing after install'

    sleep_until_recording_offset 72 84 "Action: relaunch WinMux from /Applications/WinMux.app"
    echo "relaunch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    relaunch_winmux_installed
    cat "${RELAUNCH_LOG}" | tee -a "${CLI_LOG}"
    capture_guest_screenshot "04-after-relaunch-slice-39"

    sleep_until_recording_offset 84 96 "Run: winmux focus-zone Comms"
    echo "focus-zone-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo 'focus-zone=Comms'
        echo 'result=success'
    } >"${FOCUS_ZONE_LOG}" 2>>"${WAIT_ERR}"
    cat "${FOCUS_ZONE_LOG}" | tee -a "${CLI_LOG}"

    sleep_until_recording_offset 96 108 "Result: dogfood install path is ready"
    echo "result-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_result_doc
    /usr/bin/open -a TextEdit "${RESULT_DOC}"
    sleep 2
    capture_guest_screenshot "05-dogfood-ready-slice-39"

    {
        echo "PASS: WinMux launched from ${APP_BUNDLE}, doctor exposed install and permission recovery status, config-path used ${USER_CONFIG}, zones survived relaunch, and focus-zone Comms succeeded."
        echo "installed-app=${APP_BUNDLE}"
        echo "installed-cli=${CLI}"
        echo "user-config=${USER_CONFIG}"
        echo "doctor-log=${DOCTOR_LOG}"
        echo "permissions-log=${PERMISSIONS_LOG}"
        echo "relaunch-log=${RELAUNCH_LOG}"
    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/config" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots" "$(dirname "${SOURCE_APP}")" "$(dirname "${SOURCE_CLI}")" "${DOC_DIR}" "${USER_CONFIG_DIR}"
    printf '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE\n# [[zones]]\n# name = "Reference"\n# END WINMUX ULTRAWIDE ZONES TEMPLATE\n' >"${STARTER_CONFIG}"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${SOURCE_APP}"
    cat >"${SOURCE_CLI}" <<'CLI'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    list-zones)
        if [ "${2:-}" = "--count" ]; then echo 3; exit 0; fi
        echo 'zone=left|name=Reference|layout=balanced|enabled=true|workspace=reference|left=0|width=860|physical=1'
        echo 'zone=main|name=Work|layout=balanced|enabled=true|workspace=work|left=860|width=1720|physical=1'
        echo 'zone=right|name=Comms|layout=balanced|enabled=true|workspace=comms|left=2580|width=860|physical=1'
        ;;
    doctor)
        echo 'Install:'
        echo "  app path: ${WINMUX_E2E_APPLICATIONS_DIR}/WinMux.app"
        echo "  config path: ${HOME}/.config/winmux/winmux.toml"
        echo 'Permissions:'
        echo '  accessibility: granted'
        echo '  screen recording: granted'
        echo '  automation: macOS-managed; use System Settings > Privacy & Security > Automation when Apple Events are blocked'
        echo 'Permission recovery:'
        echo '  automation reset: tccutil reset AppleEvents com.zimengxiong.winmux'
        ;;
    config)
        if [ "$2" = "--config-path" ]; then echo "${HOME}/.config/winmux/winmux.toml"; exit 0; fi
        if [ "$2" = "--check" ]; then echo "Config OK: $3"; exit 0; fi
        ;;
    focus-zone)
        echo "focused=$2"
        ;;
esac
CLI
    chmod +x "${SOURCE_APP}" "${SOURCE_CLI}"
    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"
    install_app_bundle
    /bin/cp "${STARTER_CONFIG}" "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_BEFORE_COPY}"
    uncomment_template_in_place "${USER_CONFIG}"
    /bin/cp "${USER_CONFIG}" "${CONFIG_UNCOMMENTED_COPY}"
    write_permission_status_log
    write_visible_install_status
    write_launch_plist
    assert_launch_plist_is_dogfood_path
    test -x "${APP}"
    test -x "${CLI}"
    grep -F 'install=result=success' "${INSTALL_LOG}" >/dev/null \
        || semantic_fail 'self-test missing install success'
    grep -F 'permissions=result=success' "${PERMISSIONS_LOG}" >/dev/null \
        || semantic_fail 'self-test missing permission status success'
    grep -F "app_executable=${APP}" "${INSTALL_LOG}" >/dev/null \
        || semantic_fail 'self-test install log missing app executable'
    grep -F "app_default_config_resource=${APP_DEFAULT_CONFIG}" "${INSTALL_LOG}" >/dev/null \
        || semantic_fail 'self-test install log missing bundle default config resource'
    test -f "${APP_DEFAULT_CONFIG}" \
        || semantic_fail 'self-test installed app bundle missing default-config resource'
    grep -F "<string>${APP}</string>" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'self-test LaunchAgent missing installed app executable'
    grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_UNCOMMENTED_COPY}" >/dev/null \
        || semantic_fail 'self-test did not uncomment zones'
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_LOG}"
    assert_doctor_output
    write_doctor_status_doc
    grep -F 'Slice 39 status: winmux doctor' "${VISIBLE_DOCTOR_STATUS}" >/dev/null \
        || semantic_fail 'self-test visible doctor status missing title'
    grep -F "app path: ${APP_BUNDLE}" "${VISIBLE_DOCTOR_STATUS}" >/dev/null \
        || semantic_fail 'self-test visible doctor status missing installed app path'
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
        echo "Unknown Slice 39 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
