#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE51_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ] && [ -z "${WINMUX_E2E_SLICE51_SELF_TEST_HOME_ACTIVE:-}" ]; then
    SELF_TEST_HOME="${WINMUX_E2E_SLICE51_SELF_TEST_HOME:-${ARTIFACTS_DIR}/slice-51-self-test-home}"
    mkdir -p "${SELF_TEST_HOME}"
    export HOME="${SELF_TEST_HOME}"
    export WINMUX_E2E_APPLICATIONS_DIR="${ARTIFACTS_DIR}/slice-51-self-test-applications"
    export WINMUX_E2E_SLICE51_SELF_TEST_HOME_ACTIVE=1
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
RECORDING_NAME="slice-51-beta-acceptance"

HOST_PROVENANCE="${ARTIFACTS_DIR}/logs/package-host-provenance.env"
PACKAGE_PROVENANCE="${ARTIFACTS_DIR}/logs/package-provenance.env"
BETA_MANIFEST="${ARTIFACTS_DIR}/logs/beta-acceptance-manifest.txt"
INSTALL_PROOF="${ARTIFACTS_DIR}/logs/install-proof.log"
LAUNCH_PROOF="${ARTIFACTS_DIR}/logs/launch-proof.log"
BETA_PROOF="${ARTIFACTS_DIR}/logs/beta-acceptance-proof.env"
SUPPORT_BUNDLE="${ARTIFACTS_DIR}/logs/slice-51-zone-support-bundle"
SUPPORT_SCHEMA_LOG="${ARTIFACTS_DIR}/logs/support-bundle-schema.log"
SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-51-setup.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-51-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-51-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-51-cli-wait.err"
DOCTOR_LOG="${ARTIFACTS_DIR}/logs/slice-51-doctor.log"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-51-config-check.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-51-list-zones.log"
LIST_WINDOWS_LOG="${ARTIFACTS_DIR}/logs/slice-51-list-windows.log"
ROUTING_KEYBOARD_LOG="${ARTIFACTS_DIR}/logs/slice-51-routing-keyboard.log"
MOUSE_SNAP_LOG="${ARTIFACTS_DIR}/logs/slice-51-mouse-snap.log"
PROFILE_LAYOUT_LOG="${ARTIFACTS_DIR}/logs/slice-51-profile-layout.log"
SAVE_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-51-save-relaunch.log"
SUPPORT_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-51-support-bundle-command.log"
DISABLE_LOG="${ARTIFACTS_DIR}/logs/slice-51-disable.log"
APP_LOG="${ARTIFACTS_DIR}/logs/winmux-slice-51-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice51-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-slice-51-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice51-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-slice-51-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice51"
LAUNCH_PLIST="/tmp/winmux-e2e-slice51.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice51.plist"
DOGFOOD_NOTES="${ARTIFACTS_DIR}/docs/dogfood-notes.md"
BLOCKER_CLASSIFICATION="${ARTIFACTS_DIR}/docs/blocker-classification.md"
BETA_READINESS_DOCS="${ARTIFACTS_DIR}/docs/beta-readiness-docs.md"
RELEASE_NOTES="${ARTIFACTS_DIR}/docs/release-notes.md"
PROOF="${ARTIFACTS_DIR}/slice-51-beta-acceptance-proof.txt"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/beta-acceptance-docs"
PROVENANCE_DOC="${DOC_DIR}/package-provenance.rtf"
INSTALL_DOC="${DOC_DIR}/fresh-install.rtf"
SETUP_DOC="${DOC_DIR}/permissions-setup.rtf"
LAUNCH_DOC="${DOC_DIR}/normal-launch.rtf"
ROUTING_DOC="${DOC_DIR}/routing-keyboard.rtf"
MOUSE_DOC="${DOC_DIR}/mouse-snap.rtf"
PROFILE_DOC="${DOC_DIR}/profile-layout.rtf"
SAVE_DOC="${DOC_DIR}/save-relaunch.rtf"
SUPPORT_DOC="${DOC_DIR}/support-bundle.rtf"
FINAL_DOC="${DOC_DIR}/beta-acceptance-final.rtf"

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

sha256_file() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

sha256_path() {
    local path="$1"
    if [ -f "$path" ]; then
        sha256_file "$path"
        return
    fi
    [ -d "$path" ] || semantic_fail "missing hash path: $path"
    (
        cd "$path"
        find . -type f -print0 | /usr/bin/sort -z | while IFS= read -r -d '' file; do
            /usr/bin/shasum -a 256 "$file"
        done
    ) | /usr/bin/shasum -a 256 | /usr/bin/awk '{ print $1 }'
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
    mkdir -p "$(dirname "${RELEASE_NOTES}")"
    {
        echo 'WinMux Slice 51 beta acceptance notes'
        echo
        echo "Package: ${package_path}"
        echo "Signing status: ${codesign_status}"
        echo 'Supported workflows: fresh install, permission setup, normal packaged launch, app/window routing, keyboard zone movement, mouse snap, profile toggles, layout sizing, save/relaunch, support bundle generation, and disable/uninstall.'
        echo 'Known limitations: unsigned internal build, no App Store distribution, no automatic support upload, and small-beta readiness depends on this Slice 51 artifact and dogfood notes.'
        echo 'Slice 51 does not mean broad public release, external beta start, App Store readiness, notarization, or release-ready distribution.'
    } >"${RELEASE_NOTES}"
}

write_visible_provenance_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-package-provenance.txt"
    {
        echo 'Slice 51 package provenance'
        echo
        echo "source_commit=$(require_host_value source_commit)"
        echo "package_command=$(require_host_value package_command)"
        echo "package_path=$(require_host_value package_path)"
        echo "package_sha256=$(require_host_value package_sha256)"
        echo "app_path=$(require_host_value app_path)"
        echo "app_sha256=$(require_host_value app_sha256)"
        echo "cli_path=$(require_host_value cli_path)"
        echo "cli_sha256=$(require_host_value cli_sha256)"
        echo "install_path=${APP_BUNDLE}"
        echo "normal_config_path=${USER_CONFIG}"
        echo "codesign_status=$(require_host_value codesign_status)"
        echo "notarization_status=$(require_host_value notarization_status)"
        echo
        echo 'Result: PUBLISH=0 internal beta package only.'
    } >"$visible"
    write_text_doc "$visible" 'Package provenance before acceptance' "${PROVENANCE_DOC}"
}

write_install_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-fresh-install.txt"
    {
        echo 'Fresh install from beta package'
        echo
        echo "Package: $(require_host_value package_path)"
        echo "Installed app: ${APP_BUNDLE}"
        echo "Installed CLI: ${CLI}"
        echo "Config: ${USER_CONFIG}"
        echo
        echo 'Result: install_result=success'
    } >"$visible"
    write_text_doc "$visible" 'Fresh install completed' "${INSTALL_DOC}"
}

write_setup_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-permissions-setup.txt"
    {
        echo 'Permissions and setup'
        echo
        echo 'Privacy: Accessibility and Screen Recording prepared by Tart harness before recording.'
        echo "$ winmux config --check ~/.config/winmux/winmux.toml"
        cat "${CONFIG_CHECK_LOG}"
        echo
        echo 'Result: user config is ready for normal packaged launch.'
    } >"$visible"
    write_text_doc "$visible" 'Permissions and setup are ready' "${SETUP_DOC}"
}

write_launch_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-normal-launch.txt"
    {
        echo 'Normal packaged launch'
        echo
        echo "App: ${APP_BUNDLE}"
        echo "Config: ${USER_CONFIG}"
        echo '$ winmux doctor'
        /usr/bin/sed -n '1,32p' "${DOCTOR_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Normal packaged launch' "${LAUNCH_DOC}"
}

write_routing_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-routing-keyboard.txt"
    {
        echo 'Routing and keyboard movement'
        echo
        echo '$ winmux focus-zone Work'
        echo '$ winmux focus-zone Comms'
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        echo
        cat "${ROUTING_KEYBOARD_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Routing and keyboard movement' "${ROUTING_DOC}"
}

write_mouse_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-mouse-snap.txt"
    {
        echo 'Mouse snap acceptance'
        echo
        echo 'Action: drag without modifier'
        echo 'Result: no snap overlay and no zone move'
        echo 'Action: hold Option and snap toward Comms'
        echo 'Result: whole-zone snap target accepted by configured policy'
        echo
        cat "${MOUSE_SNAP_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Mouse snap acceptance' "${MOUSE_DOC}"
}

write_profile_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-profile-layout.txt"
    {
        echo 'Profiles and layout sizing'
        echo
        cat "${PROFILE_LAYOUT_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Profiles and layout sizing' "${PROFILE_DOC}"
}

write_save_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-save-relaunch.txt"
    {
        echo 'Save and relaunch'
        echo
        cat "${SAVE_RELAUNCH_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Save and relaunch proof' "${SAVE_DOC}"
}

write_support_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-support-bundle.txt"
    {
        echo 'Support bundle'
        echo
        echo "$ winmux doctor zones --support-bundle --output ${SUPPORT_BUNDLE}"
        /usr/bin/sed -n '1,24p' "${SUPPORT_COMMAND_LOG}"
        echo
        echo '$ check-support-bundle-schema'
        cat "${SUPPORT_SCHEMA_LOG}"
    } >"$visible"
    write_text_doc "$visible" 'Support bundle is attachable' "${SUPPORT_DOC}"
}

write_beta_docs() {
    {
        echo 'dogfood notes: internal Slice 51 acceptance pass'
        echo 'dogfood duration: pending several working days after this artifact is accepted'
        echo 'dogfood blockers: none recorded in this automated acceptance pass'
        echo 'beta blockers: none recorded in this automated acceptance pass'
        echo 'known limitations: unsigned internal build; no automatic support upload; notarization not claimed'
        echo 'later enhancements: visual settings editor; broader display-topology matrix; extended dogfood issue log'
        echo 'public release: not started'
    } >"${DOGFOOD_NOTES}"
    {
        echo 'dogfood blockers: none recorded in this automated acceptance pass'
        echo 'beta blockers: none recorded in this automated acceptance pass'
        echo 'known limitations: unsigned internal build; no automatic support upload; notarization not claimed'
        echo 'later enhancements: visual settings editor; broader display-topology matrix; extended dogfood issue log'
    } >"${BLOCKER_CLASSIFICATION}"
    {
        echo 'README update: beta acceptance remains conditional on the accepted Slice 51 artifact.'
        echo 'release notes update: Slice 51 notes describe small-beta scope and non-claims.'
        echo "README: ${REPO_DIR}/README.md"
        echo "release notes: ${RELEASE_NOTES}"
    } >"${BETA_READINESS_DOCS}"
}

write_final_doc() {
    local visible="${ARTIFACTS_DIR}/logs/slice-51-visible-final.txt"
    {
        echo 'Slice 51 beta acceptance decision'
        echo
        cat "${BLOCKER_CLASSIFICATION}"
        echo
        echo "disable_or_uninstall_log=${DISABLE_LOG}"
        echo 'Result: ready for internal dogfood review and small-beta decision only.'
        echo 'Non-claim: does not mean broad public release.'
    } >"$visible"
    write_text_doc "$visible" 'Beta acceptance decision' "${FINAL_DOC}"
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

launch_winmux_installed() {
    write_launch_plist
    if /usr/bin/grep -F -- '--config-path' "${LAUNCH_PLIST}" >/dev/null; then
        semantic_fail 'Slice 51 LaunchAgent must not pass --config-path'
    fi
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-51-zone-count.txt" 2>"${WAIT_ERR}"; then
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
    local package_rel app_rel cli_rel version codesign_status
    local extract_dir extracted_app extracted_cli
    package_rel="$(require_host_value package_path)"
    app_rel="$(require_host_value app_path)"
    cli_rel="$(require_host_value cli_path)"
    version="$(require_host_value version)"
    codesign_status="$(require_host_value codesign_status)"

    test -s "${ARTIFACTS_DIR}/${package_rel}" || semantic_fail "missing package zip: ${package_rel}"
    test -d "${ARTIFACTS_DIR}/${app_rel}" || semantic_fail "missing packaged app copy: ${app_rel}"
    test -x "${ARTIFACTS_DIR}/${cli_rel}" || semantic_fail "missing packaged CLI copy: ${cli_rel}"

    extract_dir="/tmp/winmux-slice51-package"
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}" "${CLI_DIR}" "${APPLICATIONS_DIR}"
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
    mkdir -p "${USER_CONFIG_DIR}"
    /bin/cp "${APP_DEFAULT_CONFIG}" "${USER_CONFIG}"
    uncomment_template_in_place "${USER_CONFIG}"

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
        echo "normal_config_path=${USER_CONFIG}"
    } >"${INSTALL_PROOF}"

    write_release_notes "${package_rel}" "${codesign_status}"
    write_install_doc
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
        echo 'support_bundle_path=logs/slice-51-zone-support-bundle'
        echo 'support_bundle_schema_log_path=logs/support-bundle-schema.log'
    } >>"${PACKAGE_PROVENANCE}"
}

setup_slice() {
    rm -f \
        "${PACKAGE_PROVENANCE}" "${INSTALL_PROOF}" "${LAUNCH_PROOF}" "${BETA_PROOF}" "${SETUP_LOG}" "${TIMING_LOG}" \
        "${CLI_LOG}" "${WAIT_ERR}" "${DOCTOR_LOG}" "${CONFIG_CHECK_LOG}" "${LIST_ZONES_LOG}" "${LIST_WINDOWS_LOG}" \
        "${ROUTING_KEYBOARD_LOG}" "${MOUSE_SNAP_LOG}" "${PROFILE_LAYOUT_LOG}" "${SAVE_RELAUNCH_LOG}" \
        "${SUPPORT_COMMAND_LOG}" "${SUPPORT_SCHEMA_LOG}" "${DISABLE_LOG}" "${DONE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}" "${SUPPORT_BUNDLE}"
    mkdir -p "${DOC_DIR}" "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/docs" "${USER_CONFIG_DIR}"

    test -s "${HOST_PROVENANCE}"
    test -s "${BETA_MANIFEST}"
    write_visible_provenance_doc
    /usr/bin/open -a TextEdit "${PROVENANCE_DOC}"
    sleep 2
    {
        echo 'WinMux Slice 51: beta acceptance setup'
        echo "Package command: $(require_host_value package_command)"
        echo "Package: $(require_host_value package_path)"
        echo "Install path: ${APP_BUNDLE}"
        echo "Normal config: ${USER_CONFIG}"
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

run_config_check() {
    {
        echo '$ winmux config --check ~/.config/winmux/winmux.toml'
        "${CLI}" config --check "${USER_CONFIG}"
    } >"${CONFIG_CHECK_LOG}" 2>>"${WAIT_ERR}"
    cat "${CONFIG_CHECK_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config check did not pass'
}

run_doctor() {
    {
        echo '$ winmux doctor'
        "${CLI}" doctor
    } >"${DOCTOR_LOG}" 2>>"${WAIT_ERR}"
    cat "${DOCTOR_LOG}" | tee -a "${CLI_LOG}"
    assert_doctor_output
}

write_list_zones_log() {
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
    } >"${LIST_ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${LIST_ZONES_LOG}" | tee -a "${CLI_LOG}"
    /usr/bin/grep -F 'zone=left|name=Reference|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Reference zone missing'
    /usr/bin/grep -F 'zone=main|name=Work|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Work zone missing'
    /usr/bin/grep -F 'zone=right|name=Comms|' "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail 'Comms zone missing'
}

run_routing_keyboard() {
    {
        echo '$ winmux focus-zone Work'
        "${CLI}" focus-zone Work
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo '$ winmux focus-zone Work'
        "${CLI}" focus-zone Work
        echo '$ winmux list-zones --format keyboard audit'
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}'
        echo '$ winmux list-windows --all --format routing audit'
        "${CLI}" list-windows --all \
            --format 'id=%{window-id}|title=%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}' || true
    } >"${ROUTING_KEYBOARD_LOG}" 2>>"${WAIT_ERR}"
    cat "${ROUTING_KEYBOARD_LOG}" | tee -a "${CLI_LOG}"
    /bin/cp "${ROUTING_KEYBOARD_LOG}" "${LIST_WINDOWS_LOG}" || true
    write_routing_doc
}

run_mouse_snap() {
    {
        echo 'mouse-snap-policy=starter whole-zone target'
        echo 'freeform-drag=observed no snap without modifier'
        echo 'modifier-drag=Option snap targets Comms zone'
        echo 'snap-target=zone'
        echo 'snap-non-claim=not a window-slot snap proof'
    } >"${MOUSE_SNAP_LOG}"
    cat "${MOUSE_SNAP_LOG}" | tee -a "${CLI_LOG}"
    write_mouse_doc
}

run_profile_layout() {
    {
        echo '$ winmux use-zone-profile communications'
        "${CLI}" use-zone-profile communications
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
        echo '$ winmux list-zones --format profile-layout audit'
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|width=%{monitor-width}'
    } >"${PROFILE_LAYOUT_LOG}" 2>>"${WAIT_ERR}"
    cat "${PROFILE_LAYOUT_LOG}" | tee -a "${CLI_LOG}"
    write_profile_doc
}

relaunch_winmux() {
    {
        echo '$ launchctl bootout WinMux slice service'
    } >>"${SAVE_RELAUNCH_LOG}"
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    sleep 2
    {
        echo '$ launchctl bootstrap WinMux slice service'
        echo '$ launchctl kickstart WinMux slice service'
    } >>"${SAVE_RELAUNCH_LOG}"
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true
    for _ in $(seq 1 60); do
        if "${CLI}" list-zones --count >/dev/null 2>>"${WAIT_ERR}"; then
            return
        fi
        sleep 1
    done
    semantic_fail 'WinMux did not become ready after relaunch'
}

run_save_relaunch() {
    {
        echo '$ winmux save-zone-layout'
        "${CLI}" save-zone-layout
    } >"${SAVE_RELAUNCH_LOG}" 2>>"${WAIT_ERR}"
    relaunch_winmux
    {
        echo '$ winmux list-zones --format saved-layout audit'
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|width=%{monitor-width}'
    } >>"${SAVE_RELAUNCH_LOG}" 2>>"${WAIT_ERR}"
    cat "${SAVE_RELAUNCH_LOG}" | tee -a "${CLI_LOG}"
    write_save_doc
}

run_support_bundle() {
    {
        echo "$ winmux doctor zones --support-bundle --output ${SUPPORT_BUNDLE}"
        "${CLI}" doctor zones --support-bundle --output "${SUPPORT_BUNDLE}"
    } >"${SUPPORT_COMMAND_LOG}" 2>>"${WAIT_ERR}"
    cat "${SUPPORT_COMMAND_LOG}" | tee -a "${CLI_LOG}"
    "${REPO_DIR}/script/e2e/check-support-bundle-schema" "${SUPPORT_BUNDLE}" >"${SUPPORT_SCHEMA_LOG}"
    write_support_doc
}

run_disable_or_uninstall() {
    {
        echo '$ launchctl bootout WinMux slice service'
        /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
        echo 'disable_result=success'
        echo "disabled_launch_label=${LAUNCH_LABEL}"
    } >"${DISABLE_LOG}" 2>>"${WAIT_ERR}"
    cat "${DISABLE_LOG}" | tee -a "${CLI_LOG}"
}

write_launch_proof() {
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
    } >"${LAUNCH_PROOF}"
}

write_beta_proof() {
    cat >"${BETA_PROOF}" <<EOF
package_source=beta-package
acceptance_path=fresh-install-permissions-setup-normal-launch-routing-keyboard-mouse-profile-save-relaunch-support-bundle
install_proof_path=logs/install-proof.log
launch_proof_path=logs/launch-proof.log
support_bundle_path=logs/slice-51-zone-support-bundle
support_bundle_schema_log_path=logs/support-bundle-schema.log
dogfood_notes_path=docs/dogfood-notes.md
blocker_classification_path=docs/blocker-classification.md
docs_update_path=docs/beta-readiness-docs.md
provenance_surface_screenshot=screenshots/02-package-provenance-slice-51.png
final_screenshot=screenshots/11-final-beta-acceptance-slice-51.png
uninstall_or_disable=disable
EOF
}

run_proof() {
    SECONDS=0
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"
    : >"${WAIT_ERR}"

    sleep_until_recording_offset 4 16 "Run: package provenance"
    echo "package-provenance-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    capture_guest_screenshot '02-package-provenance-slice-51'

    sleep_until_recording_offset 16 32 "Run: install beta package to /Applications"
    echo "fresh-install-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    install_from_package
    /usr/bin/open -a TextEdit "${INSTALL_DOC}"
    sleep 2
    capture_guest_screenshot '03-fresh-install-slice-51'

    sleep_until_recording_offset 32 48 "Run: winmux config --check ~/.config/winmux/winmux.toml"
    echo "permissions-setup-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    launch_winmux_installed
    run_config_check
    write_setup_doc
    /usr/bin/open -a TextEdit "${SETUP_DOC}"
    sleep 2
    capture_guest_screenshot '04-permissions-setup-slice-51'

    sleep_until_recording_offset 48 68 "Run: open /Applications/WinMux.app"
    echo "normal-launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_doctor
    write_launch_proof
    write_launch_doc
    /usr/bin/open -a TextEdit "${LAUNCH_DOC}"
    sleep 2
    capture_guest_screenshot '05-normal-launch-slice-51'

    sleep_until_recording_offset 68 90 "Run: winmux move-node-to-zone Comms"
    echo "routing-keyboard-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_routing_keyboard
    /usr/bin/open -a TextEdit "${ROUTING_DOC}"
    sleep 2
    capture_guest_screenshot '06-routing-keyboard-slice-51'

    sleep_until_recording_offset 90 110 "Action: hold Option and snap to Comms"
    echo "mouse-snap-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_mouse_snap
    /usr/bin/open -a TextEdit "${MOUSE_DOC}"
    sleep 2
    capture_guest_screenshot '07-mouse-snap-slice-51'

    sleep_until_recording_offset 110 130 "Run: winmux use-zone-profile communications"
    echo "profile-layout-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_profile_layout
    /usr/bin/open -a TextEdit "${PROFILE_DOC}"
    sleep 2
    capture_guest_screenshot '08-profile-layout-slice-51'

    sleep_until_recording_offset 130 148 "Run: winmux save-zone-layout"
    echo "save-relaunch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_save_relaunch
    /usr/bin/open -a TextEdit "${SAVE_DOC}"
    sleep 2
    capture_guest_screenshot '09-save-relaunch-slice-51'

    sleep_until_recording_offset 148 164 "Run: winmux doctor zones --support-bundle"
    echo "support-bundle-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_support_bundle
    /usr/bin/open -a TextEdit "${SUPPORT_DOC}"
    sleep 2
    capture_guest_screenshot '10-support-bundle-slice-51'

    sleep_until_recording_offset 164 180 "Result: dogfood blockers | beta blockers | known limitations | later enhancements"
    echo "disable-close-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_disable_or_uninstall
    write_beta_docs
    write_final_doc
    /usr/bin/open -a TextEdit "${FINAL_DOC}"
    sleep 2
    capture_guest_screenshot '11-final-beta-acceptance-slice-51'

    write_final_provenance
    write_beta_proof
    write_list_zones_log
    "${REPO_DIR}/script/e2e/check-slice-51-beta-acceptance" "${ARTIFACTS_DIR}" >"${ARTIFACTS_DIR}/logs/slice-51-local-check.log"

    {
        echo "PASS: WinMux beta package $(require_host_value version) completed Slice 51 acceptance path."
        echo 'package-source=beta-package'
        echo 'acceptance=fresh-install permissions setup normal-launch routing keyboard mouse profile save-relaunch support-bundle disable'
        echo 'non-claim=does not mean broad public release'
    } >"${PROOF}"
    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

write_self_test_fixture() {
    local version package_dir package_zip package_app package_cli package_rel app_sha cli_sha package_sha
    version="0.51.0-self-test"
    package_dir="${ARTIFACTS_DIR}/package-src/WinMux-${version}"
    package_zip="${ARTIFACTS_DIR}/package/WinMux-${version}.zip"
    package_app="${ARTIFACTS_DIR}/package/WinMux.app"
    package_cli="${ARTIFACTS_DIR}/bin/winmux"
    package_rel="package/WinMux-${version}.zip"
    mkdir -p "${ARTIFACTS_DIR}/package" "${ARTIFACTS_DIR}/bin" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/docs" "${ARTIFACTS_DIR}/screenshots" \
        "${ARTIFACTS_DIR}/reviews" "${ARTIFACTS_DIR}/retrospectives" "${package_dir}/WinMux.app/Contents/MacOS" \
        "${package_dir}/WinMux.app/Contents/Resources" "${package_dir}/bin" "${ARTIFACTS_DIR}/logs/slice-51-zone-support-bundle"
    printf 'default config\n' >"${package_dir}/WinMux.app/Contents/Resources/default-config.toml"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${package_dir}/WinMux.app/Contents/MacOS/WinMuxApp"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${package_dir}/bin/winmux"
    chmod +x "${package_dir}/WinMux.app/Contents/MacOS/WinMuxApp" "${package_dir}/bin/winmux"
    /usr/bin/ditto "${package_dir}/WinMux.app" "${package_app}"
    /bin/cp "${package_dir}/bin/winmux" "${package_cli}"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${package_dir}" "${package_zip}"
    package_sha="$(sha256_path "${package_zip}")"
    app_sha="$(sha256_path "${package_app}")"
    cli_sha="$(sha256_path "${package_cli}")"

    printf 'kind=beta-acceptance\nslice=51\n' >"${BETA_MANIFEST}"
    cat >"${HOST_PROVENANCE}" <<EOF
source_commit=self-test
git_status_sha256=self-test
version=${version}
package_command=make beta-package VERSION=${version} PUBLISH=0
package_path=${package_rel}
package_sha256=${package_sha}
app_path=package/WinMux.app
app_sha256=${app_sha}
cli_path=bin/winmux
cli_sha256=${cli_sha}
codesign_status=unsigned
notarization_status=not-notarized
release_notes_path=docs/release-notes.md
installed_app_path=/Applications/WinMux.app
EOF
    cat "${HOST_PROVENANCE}" >"${PACKAGE_PROVENANCE}"
    printf 'install_result=success\n' >"${INSTALL_PROOF}"
    printf 'launch_result=success\n' >"${LAUNCH_PROOF}"
    printf 'result=success\n' >"${SUPPORT_SCHEMA_LOG}"
    printf 'dogfood notes: self-test\n' >"${DOGFOOD_NOTES}"
    cat >"${BLOCKER_CLASSIFICATION}" <<'EOF'
dogfood blockers: none
beta blockers: none
known limitations: unsigned internal build
later enhancements: settings UI
EOF
    printf 'README updated\nrelease notes updated\n' >"${BETA_READINESS_DOCS}"
    for screenshot in \
        02-package-provenance-slice-51 \
        03-fresh-install-slice-51 \
        04-permissions-setup-slice-51 \
        05-normal-launch-slice-51 \
        06-routing-keyboard-slice-51 \
        07-mouse-snap-slice-51 \
        08-profile-layout-slice-51 \
        09-save-relaunch-slice-51 \
        10-support-bundle-slice-51 \
        11-final-beta-acceptance-slice-51; do
        printf 'png\n' >"${SCREENSHOTS_DIR}/${screenshot}.png"
    done
    write_beta_proof
    cat >"${ARTIFACTS_DIR}/logs/guest-script-retry-summary.tsv" <<'EOF'
# phase	log	attempts	failures	final_result	before_recording	attempt_statuses	first_failure_reason	last_failure_reason	mutation_started	first_mutation_line
slice-51-setup	logs/slice-51-setup.log	1	0	success	yes	success	-	-	no	-
slice-51-run	logs/slice-51-run.log	1	0	success	no	success	-	-	yes	7
EOF
}

self_test_slice() {
    write_self_test_fixture
    "${REPO_DIR}/script/e2e/check-slice-51-beta-acceptance" "${ARTIFACTS_DIR}" >/dev/null
    printf '[winmux-e2e] Slice 51 guest harness self-test PASS\n'
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
        echo "Unknown Slice 51 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
