#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE50_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE50_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE50_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-50-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_APPLICATIONS_DIR="${ARTIFACTS_DIR}/slice-50-self-test-applications"
    export WINMUX_E2E_SLICE50_SELF_TEST_HOME_ACTIVE=1
    exec /bin/bash "$0"
fi

APPLICATIONS_DIR="${WINMUX_E2E_APPLICATIONS_DIR:-/Applications}"
APP_BUNDLE="${APPLICATIONS_DIR}/WinMux.app"
APP="${APP_BUNDLE}/Contents/MacOS/WinMuxApp"
APP_DEFAULT_CONFIG="${APP_BUNDLE}/Contents/Resources/default-config.toml"
CLI_DIR="${HOME}/winmux-e2e/bin"
CLI="${CLI_DIR}/winmux"
USER_CONFIG_DIR="${HOME}/.config/winmux"
USER_CONFIG="${USER_CONFIG_DIR}/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-50-package-release"

HOST_PROVENANCE="${ARTIFACTS_DIR}/logs/package-host-provenance.env"
PACKAGE_PROVENANCE="${ARTIFACTS_DIR}/logs/package-provenance.env"
PACKAGE_MANIFEST="${ARTIFACTS_DIR}/logs/package-slice-manifest.txt"
PRODUCT_EVIDENCE_INDEX="${ARTIFACTS_DIR}/logs/product-evidence-index.tsv"
INSTALL_PROOF="${ARTIFACTS_DIR}/logs/install-proof.log"
LAUNCH_PROOF="${ARTIFACTS_DIR}/logs/launch-proof.log"
RELEASE_NOTES="${ARTIFACTS_DIR}/docs/release-notes.md"
SUPPORT_BUNDLE="${ARTIFACTS_DIR}/logs/slice-50-zone-support-bundle"
SUPPORT_SCHEMA_LOG="${ARTIFACTS_DIR}/logs/support-bundle-schema.log"
SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-50-setup.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-50-command-timing.log"
DOCTOR_LOG="${ARTIFACTS_DIR}/logs/slice-50-doctor.log"
CONFIG_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-50-config-path.log"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-50-config-check.log"
SUPPORT_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-50-support-bundle-command.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-50-list-zones.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-50-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-50-cli-wait.err"
APP_LOG="${ARTIFACTS_DIR}/logs/winmux-slice-50-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice50-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-slice-50-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice50-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-slice-50-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice50"
LAUNCH_PLIST="/tmp/winmux-e2e-slice50.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice50.plist"
VISIBLE_STATUS="${ARTIFACTS_DIR}/logs/slice-50-visible-package-status.txt"
VISIBLE_DOCTOR="${ARTIFACTS_DIR}/logs/slice-50-visible-doctor-status.txt"
VISIBLE_SUPPORT="${ARTIFACTS_DIR}/logs/slice-50-visible-support-bundle.txt"
VISIBLE_RESULT="${ARTIFACTS_DIR}/logs/slice-50-visible-result.txt"
PROOF="${ARTIFACTS_DIR}/slice-50-package-release-proof.txt"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/package-release-docs"
STATUS_DOC="${DOC_DIR}/package-status.rtf"
DOCTOR_DOC="${DOC_DIR}/package-doctor.rtf"
SUPPORT_DOC="${DOC_DIR}/package-support-bundle.rtf"
RESULT_DOC="${DOC_DIR}/package-result.rtf"

uid="$(/usr/bin/id -u)"
mutation_marked=0

semantic_fail() {
    echo "$*" >&2
    exit 86
}

# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
# shellcheck disable=SC1091
source "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

env_value() {
    local key="$1"
    local file="$2"
    /usr/bin/awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$file"
}

require_host_value() {
    local value
    value="$(env_value "$1" "$HOST_PROVENANCE")"
    [ -n "$value" ] || semantic_fail "missing package host provenance key: $1"
    printf '%s\n' "$value"
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

write_release_notes() {
    local package_path="$1"
    local codesign_status="$2"
    local demo_contact_sheet_path="$3"
    mkdir -p "$(dirname "${RELEASE_NOTES}")"
    {
        echo 'WinMux Slice 50 beta package notes'
        echo
        echo "Package: ${package_path}"
        if [ "${codesign_status}" = "unsigned" ]; then
            echo 'Status: unsigned internal beta candidate, not signed for public distribution.'
            echo 'When macOS attaches quarantine to a copied build, run:'
            echo 'xattr -dr com.apple.quarantine /Applications/WinMux.app'
        else
            echo 'Status: signed internal beta candidate; notarization is tracked separately in package provenance.'
        fi
        echo
        echo 'Supported workflows: install WinMux.app to /Applications, launch without a config-path override, run winmux doctor, use the normal ~/.config/winmux/winmux.toml path, inspect Reference/Work/Comms ultrawide zones, and generate diagnostics with winmux doctor zones --support-bundle.'
        echo
        echo 'Known limitations: this package is for internal package validation, has no automatic support upload, and reuses accepted product media for the wider feature tour.'
        echo
        echo "Demo evidence poster: ${demo_contact_sheet_path}"
        echo
        echo 'Slice 50 does not start external beta and does not imply App Store readiness.'
    } >"${RELEASE_NOTES}"
}

write_visible_status_doc() {
    local package_path="$1"
    local version="$2"
    {
        echo 'WinMux package install proof'
        echo
        echo "Version: ${version}"
        echo "Package: ${package_path}"
        echo 'Install command: copy WinMux.app to /Applications'
        echo 'CLI command: copy bin/winmux to ~/winmux-e2e/bin/winmux'
        echo 'Config: ~/.config/winmux/winmux.toml'
        echo
        echo 'Next proof: launch /Applications/WinMux.app, run winmux doctor, generate a support bundle, then list zones.'
    } >"${VISIBLE_STATUS}"
    write_text_doc "${VISIBLE_STATUS}" 'Package install path is ready' "${STATUS_DOC}"
}

write_doctor_doc() {
    {
        echo 'Slice 50 status: winmux doctor'
        echo
        echo '$ winmux doctor'
        /usr/bin/sed -n '1,30p' "${DOCTOR_LOG}"
    } >"${VISIBLE_DOCTOR}"
    write_text_doc "${VISIBLE_DOCTOR}" 'Packaged app identity and permissions' "${DOCTOR_DOC}"
}

write_support_doc() {
    {
        echo 'Slice 50 support bundle'
        echo
        echo "$ winmux doctor zones --support-bundle --output ${SUPPORT_BUNDLE}"
        /usr/bin/sed -n '1,20p' "${SUPPORT_COMMAND_LOG}"
        echo
        echo '$ find slice-50-zone-support-bundle -maxdepth 1 -type f | sort'
        find "${SUPPORT_BUNDLE}" -maxdepth 1 -type f -print | /usr/bin/sed "s#${SUPPORT_BUNDLE}/##" | /usr/bin/sort
    } >"${VISIBLE_SUPPORT}"
    write_text_doc "${VISIBLE_SUPPORT}" 'Support bundle is attachable' "${SUPPORT_DOC}"
}

write_result_doc() {
    {
        echo 'Slice 50 result: package install path works'
        echo
        echo "Installed app: ${APP_BUNDLE}"
        echo "Normal config: ${USER_CONFIG}"
        echo "Support bundle: ${SUPPORT_BUNDLE}"
        echo
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        cat "${LIST_ZONES_LOG}"
    } >"${VISIBLE_RESULT}"
    write_text_doc "${VISIBLE_RESULT}" 'Package is ready for beta acceptance testing' "${RESULT_DOC}"
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

assert_launch_plist_is_package_path() {
    if /usr/bin/grep -F -- '--config-path' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 50 LaunchAgent must not pass --config-path'
    fi
    if /usr/bin/grep -F 'WINMUX_DEFAULT_CONFIG_PATH' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 50 LaunchAgent must not set WINMUX_DEFAULT_CONFIG_PATH'
    fi
    /usr/bin/grep -F "${APP}" "${LAUNCH_PLIST}" >/dev/null \
        || semantic_fail 'Slice 50 LaunchAgent must launch the installed package app'
}

launch_winmux_installed() {
    write_launch_plist
    assert_launch_plist_is_package_path
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-50-zone-count.txt" 2>"${WAIT_ERR}"; then
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

install_from_package() {
    local package_rel app_rel cli_rel version codesign_status demo_contact_sheet_path
    local extract_dir extracted_app extracted_cli
    package_rel="$(require_host_value package_path)"
    app_rel="$(require_host_value app_path)"
    cli_rel="$(require_host_value cli_path)"
    version="$(require_host_value version)"
    codesign_status="$(require_host_value codesign_status)"
    demo_contact_sheet_path="$(require_host_value demo_contact_sheet_path)"

    test -s "${ARTIFACTS_DIR}/${package_rel}" || semantic_fail "missing package zip: ${package_rel}"
    test -d "${ARTIFACTS_DIR}/${app_rel}" || semantic_fail "missing packaged app copy: ${app_rel}"
    test -x "${ARTIFACTS_DIR}/${cli_rel}" || semantic_fail "missing packaged CLI copy: ${cli_rel}"

    extract_dir="/tmp/winmux-slice50-package"
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}" "${CLI_DIR}"
    /usr/bin/ditto -x -k "${ARTIFACTS_DIR}/${package_rel}" "${extract_dir}"
    extracted_app="$(find "${extract_dir}" -path '*/WinMux.app' -type d | head -1)"
    extracted_cli="$(find "${extract_dir}" -path '*/bin/winmux' -type f | head -1)"
    [ -n "${extracted_app}" ] || semantic_fail 'package zip did not contain WinMux.app'
    [ -n "${extracted_cli}" ] || semantic_fail 'package zip did not contain bin/winmux'

    if [ "${APPLICATIONS_DIR}" = "/Applications" ]; then
        /usr/bin/sudo -n /bin/rm -rf "${APP_BUNDLE}"
        /usr/bin/sudo -n /usr/bin/ditto "${extracted_app}" "${APP_BUNDLE}"
        /usr/bin/sudo -n /usr/sbin/chown -R "$(/usr/bin/id -un):staff" "${APP_BUNDLE}" >/dev/null 2>&1 || true
    else
        /bin/rm -rf "${APP_BUNDLE}"
        /usr/bin/ditto "${extracted_app}" "${APP_BUNDLE}"
    fi
    /bin/cp "${extracted_cli}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /usr/bin/xattr -dr com.apple.quarantine "${APP_BUNDLE}" >/dev/null 2>&1 || true

    test -x "${APP}"
    test -x "${CLI}"
    test -f "${APP_DEFAULT_CONFIG}"

    {
        echo 'install_result=success'
        echo "guest_user=$(/usr/bin/id -un)"
        echo 'clean_guest=1'
        echo "version=${version}"
        echo "package_path=${package_rel}"
        echo "packaged_app_path=${app_rel}"
        echo "packaged_cli_path=${cli_rel}"
        echo "package_extract_app_path=${extracted_app}"
        echo "installed_app_path=${APP_BUNDLE}"
        echo 'installed_app_exists=true'
        echo "installed_cli_path=${CLI}"
    } >"${INSTALL_PROOF}"

    write_release_notes "${package_rel}" "${codesign_status}" "${demo_contact_sheet_path}"
    write_visible_status_doc "${package_rel}" "${version}"
}

assert_doctor_output() {
    /usr/bin/grep -F 'Install:' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing Install section'
    /usr/bin/grep -F "app path: ${APP_BUNDLE}" "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing installed package app path'
    /usr/bin/grep -F "config path: ${USER_CONFIG}" "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing normal user config path'
    /usr/bin/grep -F 'accessibility: granted' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing granted accessibility'
    /usr/bin/grep -F 'screen recording: granted' "${DOCTOR_LOG}" >/dev/null \
        || semantic_fail 'doctor output missing granted screen recording'
}

write_final_provenance() {
    cat "${HOST_PROVENANCE}" >"${PACKAGE_PROVENANCE}"
    {
        echo "guest_user=$(/usr/bin/id -un)"
        echo "normal_config_path=${USER_CONFIG}"
        echo 'install_proof_path=logs/install-proof.log'
        echo 'launch_proof_path=logs/launch-proof.log'
    } >>"${PACKAGE_PROVENANCE}"
}

setup_slice() {
    rm -f \
        "${PACKAGE_PROVENANCE}" "${INSTALL_PROOF}" "${LAUNCH_PROOF}" "${SETUP_LOG}" "${TIMING_LOG}" \
        "${DOCTOR_LOG}" "${CONFIG_PATH_LOG}" "${CONFIG_CHECK_LOG}" "${SUPPORT_COMMAND_LOG}" \
        "${SUPPORT_SCHEMA_LOG}" "${LIST_ZONES_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${DONE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" "${VISIBLE_STATUS}" "${VISIBLE_DOCTOR}" \
        "${VISIBLE_SUPPORT}" "${VISIBLE_RESULT}"
    rm -rf "${DOC_DIR}" "${SUPPORT_BUNDLE}"
    mkdir -p "${DOC_DIR}" "${USER_CONFIG_DIR}" "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/docs"

    test -s "${HOST_PROVENANCE}"
    test -s "${PACKAGE_MANIFEST}"
    test -s "${PRODUCT_EVIDENCE_INDEX}"
    install_from_package
    /bin/cp "${APP_DEFAULT_CONFIG}" "${USER_CONFIG}"
    uncomment_template_in_place "${USER_CONFIG}"

    grep -E '^[[:space:]]*\[\[zones\]\]' "${USER_CONFIG}" >/dev/null \
        || semantic_fail 'normal config missing active zones after package setup'

    /usr/bin/open -a TextEdit "${STATUS_DOC}"
    sleep 3
    {
        echo 'WinMux Slice 50: beta package install and launch proof'
        echo "Installed app: ${APP_BUNDLE}"
        echo "Installed CLI: ${CLI}"
        echo "Normal config: ${USER_CONFIG}"
        echo "Package command: $(require_host_value package_command)"
        echo 'Commands: winmux doctor; config --config-path; config --check; doctor zones --support-bundle; list-zones'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

run_proof() {
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"

    sleep_until_recording_offset 14 26 "Run: WinMuxApp from /Applications/WinMux.app"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    launch_winmux_installed
    echo '$ WinMuxApp from /Applications/WinMux.app' | tee -a "${CLI_LOG}"
    capture_guest_screenshot '02-package-app-launched-slice-50'

    sleep_until_recording_offset 26 38 "Run: winmux doctor"
    echo "doctor-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_LOG}" 2>>"${WAIT_ERR}"
    cat "${DOCTOR_LOG}" | tee -a "${CLI_LOG}"
    assert_doctor_output
    write_doctor_doc
    /usr/bin/open -a TextEdit "${DOCTOR_DOC}"
    sleep 2
    capture_guest_screenshot '03-package-doctor-slice-50'

    sleep_until_recording_offset 38 48 "Run: winmux config --config-path"
    echo "config-path-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --config-path'
        "${CLI}" config --config-path
    } >"${CONFIG_PATH_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_PATH_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F "${USER_CONFIG}" "${CONFIG_PATH_LOG}" >/dev/null \
        || semantic_fail 'config --config-path did not report normal user config'

    sleep_until_recording_offset 48 58 "Run: winmux config --check ~/.config/winmux/winmux.toml"
    echo "config-check-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } >"${CONFIG_CHECK_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_CHECK_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config check did not pass'

    sleep_until_recording_offset 58 74 "Run: winmux doctor zones --support-bundle"
    echo "support-bundle-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "$ winmux doctor zones --support-bundle --output ${SUPPORT_BUNDLE}"
        "${CLI}" doctor zones --support-bundle --output "${SUPPORT_BUNDLE}"
    } >"${SUPPORT_COMMAND_LOG}" 2>>"${WAIT_ERR}"
    cat "${SUPPORT_COMMAND_LOG}" | tee -a "${CLI_LOG}"
    "${REPO_DIR}/script/e2e/check-support-bundle-schema" "${SUPPORT_BUNDLE}" >"${SUPPORT_SCHEMA_LOG}"
    write_support_doc
    /usr/bin/open -a TextEdit "${SUPPORT_DOC}"
    sleep 2
    capture_guest_screenshot '04-package-support-bundle-slice-50'

    sleep_until_recording_offset 74 88 "Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
    echo "list-zones-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${LIST_ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${LIST_ZONES_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'zone=left|name=Reference|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Reference zone missing after package launch'
    /usr/bin/grep -F 'zone=main|name=Work|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Work zone missing after package launch'
    /usr/bin/grep -F 'zone=right|name=Comms|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Comms zone missing after package launch'

    sleep_until_recording_offset 88 100 "Result: package install path is ready"
    echo "result-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_result_doc
    /usr/bin/open -a TextEdit "${RESULT_DOC}"
    sleep 2
    capture_guest_screenshot '05-package-ready-slice-50'

    {
        echo 'launch_result=success'
        echo "guest_user=$(/usr/bin/id -un)"
        echo 'clean_guest=1'
        echo "launched_app_path=${APP_BUNDLE}"
        echo "normal_config_path=${USER_CONFIG}"
        echo 'doctor_result=success'
        echo 'permission_status_result=success'
        echo 'accessibility=granted'
        echo 'screen-recording=granted'
        echo "support_bundle_path=logs/slice-50-zone-support-bundle"
        echo "support_bundle_schema_log_path=logs/support-bundle-schema.log"
    } >"${LAUNCH_PROOF}"

    write_final_provenance

    {
        echo "PASS: WinMux package $(require_host_value version) installed from $(require_host_value package_path), launched from ${APP_BUNDLE}, used ${USER_CONFIG}, generated a support bundle, and listed Reference, Work, and Comms zones."
        echo "package-provenance=logs/package-provenance.env"
        echo "install-proof=logs/install-proof.log"
        echo "launch-proof=logs/launch-proof.log"
        echo "support-bundle=${SUPPORT_BUNDLE}"
        echo 'non-claim=does not start external beta'
        echo 'non-claim=does not imply App Store readiness'
    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
}

self_test_slice() {
    local version package_dir package_zip package_app package_cli package_rel demo_contact_sheet
    version="0.50.0-self-test"
    package_dir="${ARTIFACTS_DIR}/package-src/WinMux-${version}"
    package_zip="${ARTIFACTS_DIR}/package/WinMux-${version}.zip"
    package_app="${ARTIFACTS_DIR}/package/WinMux.app"
    package_cli="${ARTIFACTS_DIR}/bin/winmux"
    package_rel="package/WinMux-${version}.zip"
    demo_contact_sheet="${ARTIFACTS_DIR}/demo-columnar-zones.contact-sheet.jpg"
    mkdir -p "${ARTIFACTS_DIR}/package" "${ARTIFACTS_DIR}/bin" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/docs" \
        "${package_dir}/WinMux.app/Contents/MacOS" "${package_dir}/WinMux.app/Contents/Resources" "${package_dir}/bin" \
        "${DOC_DIR}" "${USER_CONFIG_DIR}" "${SCREENSHOTS_DIR}"
    printf '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE\n# [[zones]]\n# name = "Reference"\n# END WINMUX ULTRAWIDE ZONES TEMPLATE\n' \
        >"${package_dir}/WinMux.app/Contents/Resources/default-config.toml"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${package_dir}/WinMux.app/Contents/MacOS/WinMuxApp"
    cat >"${package_dir}/bin/winmux" <<'CLI'
#!/usr/bin/env bash
case "$1 $2" in
    "list-zones --count") echo 3 ;;
    *) echo ok ;;
esac
CLI
    chmod +x "${package_dir}/WinMux.app/Contents/MacOS/WinMuxApp" "${package_dir}/bin/winmux"
    /usr/bin/ditto "${package_dir}/WinMux.app" "${package_app}"
    /bin/cp "${package_dir}/bin/winmux" "${package_cli}"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${package_dir}" "${package_zip}"
    printf 'contact sheet\n' >"${demo_contact_sheet}"
    printf 'kind=package\nslice=50\n' >"${PACKAGE_MANIFEST}"
    printf 'feature\tuser_claim\trecording_path\trecording_sha256\tduration_seconds\tresolution\taccepted_review_path\treview_verdict\tdecisive_proof_path\tnon_claims\n' >"${PRODUCT_EVIDENCE_INDEX}"
    cat >"${HOST_PROVENANCE}" <<EOF
source_commit=self-test
git_status_sha256=self-test
version=${version}
package_command=make beta-package VERSION=${version} PUBLISH=0
package_path=${package_rel}
package_sha256=$(/usr/bin/shasum -a 256 "${package_zip}" | /usr/bin/awk '{ print $1 }')
app_path=package/WinMux.app
app_sha256=self-test
cli_path=bin/winmux
cli_sha256=self-test
codesign_status=unsigned
notarization_status=not-notarized
release_notes_path=docs/release-notes.md
installed_app_path=/Applications/WinMux.app
demo_contact_sheet_path=demo-columnar-zones.contact-sheet.jpg
demo_contact_sheet_sha256=$(/usr/bin/shasum -a 256 "${demo_contact_sheet}" | /usr/bin/awk '{ print $1 }')
support_bundle_path=logs/slice-50-zone-support-bundle
support_bundle_schema_log_path=logs/support-bundle-schema.log
EOF
    install_from_package
    /bin/cp "${APP_DEFAULT_CONFIG}" "${USER_CONFIG}"
    uncomment_template_in_place "${USER_CONFIG}"
    write_launch_plist
    assert_launch_plist_is_package_path
    write_final_provenance
    grep -F 'install_result=success' "${INSTALL_PROOF}" >/dev/null \
        || semantic_fail 'self-test missing install proof success'
    grep -F 'package_command=make beta-package' "${PACKAGE_PROVENANCE}" >/dev/null \
        || semantic_fail 'self-test missing package command provenance'
    grep -F 'PUBLISH=0' "${PACKAGE_PROVENANCE}" >/dev/null \
        || semantic_fail 'self-test missing PUBLISH=0 provenance'
    grep -F 'xattr -dr com.apple.quarantine' "${RELEASE_NOTES}" >/dev/null \
        || semantic_fail 'self-test missing quarantine release-note wording'
    grep -E '^[[:space:]]*\[\[zones\]\]' "${USER_CONFIG}" >/dev/null \
        || semantic_fail 'self-test did not activate zones in normal config'
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
        echo "Unknown Slice 50 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
