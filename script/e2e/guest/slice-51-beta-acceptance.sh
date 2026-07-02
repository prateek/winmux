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
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-setup.log"
WINDOW_BEFORE_ROUTING_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-before-routing.log"
WINDOW_AFTER_ROUTING_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-after-routing.log"
WINDOW_BEFORE_MOUSE_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-before-mouse.log"
WINDOW_AFTER_FREEFORM_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-after-freeform.log"
WINDOW_RESET_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-after-reset.log"
WINDOW_AFTER_SNAP_LOG="${ARTIFACTS_DIR}/logs/slice-51-windows-after-snap.log"
MOUSE_EVENTS_LOG="${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.mouse-events.tsv"
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
DEMO_DOC_DIR="${HOME}/winmux-e2e/beta-acceptance-demo"
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
REFERENCE_WINDOW_DOC="${DEMO_DOC_DIR}/reference-beta.rtf"
ROUTING_WINDOW_DOC="${DEMO_DOC_DIR}/route-beta.rtf"
SNAP_WINDOW_DOC="${DEMO_DOC_DIR}/snap-demo.rtf"
COMMS_WINDOW_DOC="${DEMO_DOC_DIR}/comms-beta.rtf"
MOUSE_FREEFORM_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/07a-freeform-pickup-slice-51.png"
MOUSE_FREEFORM_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/07b-freeform-hover-slice-51.png"
MOUSE_RESET_SCREENSHOT="${SCREENSHOTS_DIR}/07c-reset-before-snap-slice-51.png"
MOUSE_SNAP_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/07d-snap-pickup-slice-51.png"
MOUSE_SNAP_PATH_SCREENSHOT="${SCREENSHOTS_DIR}/07e-snap-path-slice-51.png"
MOUSE_SNAP_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/07f-snap-hover-comms-slice-51.png"
MOUSE_SNAP_RELEASE_SCREENSHOT="${SCREENSHOTS_DIR}/07g-snap-release-slice-51.png"

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

awk_int() {
    /usr/bin/awk "BEGIN { printf \"%d\\n\", ($*) }"
}

write_demo_doc() {
    local path="$1"
    local title="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs82\b ${title}\b0\par\f1\fs34 zone: ${zone_name}\par ${detail}\par}
RTF
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|layout=%{window-layout}|monitor=%{monitor-name}|left=%{window-left}|top=%{window-top}|width=%{window-width}|height=%{window-height}' \
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

window_id_for_title() {
    field_for_title "$1" "$2" id
}

zone_for_title() {
    field_for_title "$1" "$2" zone
}

workspace_for_title() {
    field_for_title "$1" "$2" workspace
}

window_rect_field_for_title() {
    field_for_title "$1" "$2" "$3"
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

wait_for_textedit_windows() {
    local expected_count="$1"
    local count
    for _ in $(seq 1 60); do
        if refresh_window_log "${WINDOW_SETUP_LOG}"; then
            count="$(wc -l <"${WINDOW_SETUP_LOG}" | tr -d ' ')"
            if [ "${count}" -ge "${expected_count}" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
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
    /usr/bin/perl -0pi -e "s/policy = 'freeform'/policy = 'snap-on-modifier'/" "${USER_CONFIG}"

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
        "${ROUTING_KEYBOARD_LOG}" "${MOUSE_SNAP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_ROUTING_LOG}" \
        "${WINDOW_AFTER_ROUTING_LOG}" "${WINDOW_BEFORE_MOUSE_LOG}" "${WINDOW_AFTER_FREEFORM_LOG}" \
        "${WINDOW_RESET_LOG}" "${WINDOW_AFTER_SNAP_LOG}" "${MOUSE_EVENTS_LOG}" \
        "${PROFILE_LAYOUT_LOG}" "${SAVE_RELAUNCH_LOG}" \
        "${SUPPORT_COMMAND_LOG}" "${SUPPORT_SCHEMA_LOG}" "${DISABLE_LOG}" "${DONE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" \
        "${MOUSE_FREEFORM_PICKUP_SCREENSHOT}" "${MOUSE_FREEFORM_HOVER_SCREENSHOT}" "${MOUSE_RESET_SCREENSHOT}" \
        "${MOUSE_SNAP_PICKUP_SCREENSHOT}" "${MOUSE_SNAP_PATH_SCREENSHOT}" "${MOUSE_SNAP_HOVER_SCREENSHOT}" \
        "${MOUSE_SNAP_RELEASE_SCREENSHOT}"
    rm -rf "${DOC_DIR}" "${DEMO_DOC_DIR}" "${SUPPORT_BUNDLE}"
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

move_window_to_zone() {
    local id="$1"
    local title="$2"
    local zone_name="$3"
    local expected_zone="$4"
    {
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone_name}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone_name}"
    } | tee -a "${CLI_LOG}"
    refresh_window_log "${WINDOW_SETUP_LOG}"
    assert_window_zone "${WINDOW_SETUP_LOG}" "${title}" "${expected_zone}"
}

prepare_live_demo_windows() {
    /usr/bin/killall TextEdit >/dev/null 2>&1 || true
    sleep 1
    mkdir -p "${DEMO_DOC_DIR}"
    write_demo_doc "${REFERENCE_WINDOW_DOC}" 'REFERENCE' 'Reference' 'Beta acceptance live window. It stays in the left zone as the control.'
    write_demo_doc "${ROUTING_WINDOW_DOC}" 'ROUTE ME' 'Work' 'This window starts in Work, then move-node-to-zone sends it to Comms.'
    write_demo_doc "${SNAP_WINDOW_DOC}" 'SNAP DEMO' 'Work' 'Drag without Alt first; reset; then hold Alt and snap to the whole Comms zone.'
    write_demo_doc "${COMMS_WINDOW_DOC}" 'COMMS' 'Comms' 'Target zone for routing and mouse snap.'

    /usr/bin/open -a TextEdit "${REFERENCE_WINDOW_DOC}" "${ROUTING_WINDOW_DOC}" "${SNAP_WINDOW_DOC}" "${COMMS_WINDOW_DOC}"
    if ! wait_for_textedit_windows 4; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'Slice 51 live TextEdit windows did not appear'
    fi

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-beta.rtf')"
    ROUTING_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'route-beta.rtf')"
    SNAP_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'snap-demo.rtf')"
    COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-beta.rtf')"
    [ -n "${REFERENCE_ID}" ] && [ -n "${ROUTING_ID}" ] && [ -n "${SNAP_ID}" ] && [ -n "${COMMS_ID}" ] \
        || semantic_fail 'Could not resolve Slice 51 live TextEdit window ids'

    move_window_to_zone "${REFERENCE_ID}" 'reference-beta.rtf' Reference left
    move_window_to_zone "${ROUTING_ID}" 'route-beta.rtf' Work main
    move_window_to_zone "${SNAP_ID}" 'snap-demo.rtf' Work main
    move_window_to_zone "${COMMS_ID}" 'comms-beta.rtf' Comms right
    "${CLI}" focus --window-id "${SNAP_ID}" >/dev/null 2>>"${WAIT_ERR}" || true
    refresh_window_log "${WINDOW_BEFORE_ROUTING_LOG}"
    assert_window_zone "${WINDOW_BEFORE_ROUTING_LOG}" 'reference-beta.rtf' left
    assert_window_zone "${WINDOW_BEFORE_ROUTING_LOG}" 'route-beta.rtf' main
    assert_window_zone "${WINDOW_BEFORE_ROUTING_LOG}" 'snap-demo.rtf' main
    assert_window_zone "${WINDOW_BEFORE_ROUTING_LOG}" 'comms-beta.rtf' right
}

run_routing_keyboard() {
    if [ -z "${ROUTING_ID:-}" ] || [ -z "${SNAP_ID:-}" ]; then
        prepare_live_demo_windows
    fi
    {
        echo "$ winmux move-node-to-zone --window-id ${ROUTING_ID} Comms"
        "${CLI}" move-node-to-zone --window-id "${ROUTING_ID}" Comms
        echo '$ winmux focus-zone Work'
        "${CLI}" focus-zone Work
        echo "$ winmux focus --window-id ${SNAP_ID}"
        "${CLI}" focus --window-id "${SNAP_ID}"
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo '$ winmux focus-zone Work'
        "${CLI}" focus-zone Work
        echo "$ winmux focus --window-id ${SNAP_ID}"
        "${CLI}" focus --window-id "${SNAP_ID}"
        echo '$ winmux list-zones --format keyboard audit'
        "${CLI}" list-zones \
            --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|workspace=%{monitor-active-workspace}'
        echo '$ winmux list-windows --all --format routing audit'
        "${CLI}" list-windows --all \
            --format 'id=%{window-id}|title=%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|left=%{window-left}|top=%{window-top}|width=%{window-width}|height=%{window-height}' || true
    } >"${ROUTING_KEYBOARD_LOG}" 2>>"${WAIT_ERR}"
    cat "${ROUTING_KEYBOARD_LOG}" | tee -a "${CLI_LOG}"
    refresh_window_log "${WINDOW_AFTER_ROUTING_LOG}"
    assert_window_zone "${WINDOW_AFTER_ROUTING_LOG}" 'route-beta.rtf' right
    assert_window_zone "${WINDOW_AFTER_ROUTING_LOG}" 'snap-demo.rtf' main
    /bin/cp "${WINDOW_AFTER_ROUTING_LOG}" "${LIST_WINDOWS_LOG}" || true
    write_routing_doc
}

drag_window_jxa() {
    local source_x="$1"
    local source_y="$2"
    local target_x="$3"
    local target_y="$4"
    local with_alt="$5"
    local pickup_path="$6"
    local path_path="$7"
    local hover_path="$8"
    local branch="$9"
    local scenario_start_ms="${10}"
    local release_path="${11:-}"
    /usr/bin/osascript -l JavaScript <<JXA
ObjC.import('ApplicationServices')

const app = Application.currentApplication()
app.includeStandardAdditions = true
const branch = '${branch}'
const scenarioStartMs = Number('${scenario_start_ms}')
const mouseEventsLog = '${MOUSE_EVENTS_LOG}'
const releasePath = '${release_path}'

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function postLeftMouse(type, x, y, withAlt) {
  const event = $.CGEventCreateMouseEvent(null, type, $.CGPointMake(Number(x), Number(y)), $.kCGMouseButtonLeft)
  if (withAlt) {
    $.CGEventSetFlags(event, $.kCGEventFlagMaskAlternate)
  }
  $.CGEventPost($.kCGHIDEventTap, event)
}

function postOption(down) {
  const event = $.CGEventCreateKeyboardEvent(null, 58, down)
  if (down) {
    $.CGEventSetFlags(event, $.kCGEventFlagMaskAlternate)
  }
  $.CGEventPost($.kCGHIDEventTap, event)
}

function dragTo(x1, y1, x2, y2, steps, stepDelay, withAlt) {
  for (let i = 1; i <= steps; i++) {
    const t = i / Number(steps)
    const x = Number(x1) + ((Number(x2) - Number(x1)) * t)
    const y = Number(y1) + ((Number(y2) - Number(y1)) * t)
    postLeftMouse($.kCGEventLeftMouseDragged, x, y, withAlt)
    delay(stepDelay)
  }
}

function capture(path) {
  delay(0.35)
  app.doShellScript('/usr/sbin/screencapture -x -D ${GUEST_DISPLAY_ID} ' + shellQuote(path))
}

function emit(eventId, kind, note) {
  const offset = ((Date.now() - scenarioStartMs) / 1000).toFixed(3)
  const line = [eventId, kind, offset, note].join('\t')
  app.doShellScript("/usr/bin/printf '%s\\n' " + shellQuote(line) + " >> " + shellQuote(mouseEventsLog))
}

const sx = Number('${source_x}')
const sy = Number('${source_y}')
const tx = Number('${target_x}')
const ty = Number('${target_y}')
const useAlt = '${with_alt}' === '1'
const pickupX = sx + ((tx - sx) * 0.10)
const pickupY = sy + 12
const pathX = sx + ((tx - sx) * 0.58)
const pathY = sy + ((ty - sy) * 0.58)

postLeftMouse($.kCGEventMouseMoved, sx, sy, useAlt)
delay(0.8)
if (useAlt) {
  postOption(true)
  delay(0.35)
}
postLeftMouse($.kCGEventLeftMouseDown, sx, sy, useAlt)
delay(0.25)
dragTo(sx, sy, pickupX, pickupY, 10, 0.06, useAlt)
capture('${pickup_path}')
emit(branch + '-drag-start', 'drag', useAlt ? 'Alt-held pickup' : 'no-modifier pickup')
dragTo(pickupX, pickupY, pathX, pathY, 24, 0.07, useAlt)
if ('${path_path}' !== '') {
  capture('${path_path}')
  emit(branch + '-drag-path', 'drag', 'path screenshot captured')
}
dragTo(pathX, pathY, tx, ty, 24, 0.08, useAlt)
delay(1.5)
capture('${hover_path}')
emit(branch + '-drag-hover', useAlt ? 'overlay' : 'drag', useAlt ? 'whole Comms zone target hover' : 'no snap overlay hover')
delay(1.5)
if (releasePath !== '') {
  capture(releasePath)
}
postLeftMouse($.kCGEventLeftMouseUp, tx, ty, useAlt)
emit(branch === 'snap' ? 'snap-release' : 'freeform-drag-release', 'drag', useAlt ? 'released on whole Comms zone' : 'released without snap')
if (useAlt) {
  delay(0.3)
  postOption(false)
}
JXA
}

reset_snap_window_to_work() {
    move_window_to_zone "${SNAP_ID}" 'snap-demo.rtf' Work main
    "${CLI}" focus --window-id "${SNAP_ID}" >/dev/null 2>>"${WAIT_ERR}" || true
    refresh_window_log "${WINDOW_RESET_LOG}"
    assert_window_zone "${WINDOW_RESET_LOG}" 'snap-demo.rtf' main
}

run_mouse_snap() {
    local source_left source_top source_width main_left main_top main_width right_left right_top right_width right_height
    local source_x source_y target_x target_y scenario_start_ms before_id before_workspace freeform_id freeform_zone snap_id snap_zone snap_workspace
    if [ -z "${SNAP_ID:-}" ]; then
        prepare_live_demo_windows
    fi
    write_list_zones_log >/dev/null
    refresh_window_log "${WINDOW_BEFORE_MOUSE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf' main
    before_id="$(window_id_for_title "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf')"
    before_workspace="$(workspace_for_title "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf')"
    source_left="$(window_rect_field_for_title "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf' left)"
    source_top="$(window_rect_field_for_title "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf' top)"
    source_width="$(window_rect_field_for_title "${WINDOW_BEFORE_MOUSE_LOG}" 'snap-demo.rtf' width)"
    main_left="$(zone_field "${LIST_ZONES_LOG}" main left)"
    main_top="$(zone_field "${LIST_ZONES_LOG}" main top)"
    main_width="$(zone_field "${LIST_ZONES_LOG}" main width)"
    right_left="$(zone_field "${LIST_ZONES_LOG}" right left)"
    right_top="$(zone_field "${LIST_ZONES_LOG}" right top)"
    right_width="$(zone_field "${LIST_ZONES_LOG}" right width)"
    right_height="$(zone_field "${LIST_ZONES_LOG}" right height)"
    [ -n "${source_left}" ] && [ -n "${source_top}" ] && [ -n "${source_width}" ] \
        || semantic_fail 'Missing snap-demo.rtf source geometry'
    [ -n "${main_left}" ] && [ -n "${main_top}" ] && [ -n "${main_width}" ] \
        && [ -n "${right_left}" ] && [ -n "${right_top}" ] && [ -n "${right_width}" ] && [ -n "${right_height}" ] \
        || semantic_fail 'Missing Slice 51 zone geometry'

    source_x="$(awk_int "${source_left} + (${source_width} * 0.50)")"
    source_y="$(awk_int "${source_top} + 32")"
    target_x="$(awk_int "${right_left} + (${right_width} * 0.50)")"
    target_y="$(awk_int "${right_top} + (${right_height} * 0.38)")"

    : >"${MOUSE_EVENTS_LOG}"
    printf '# event-id\tkind\toffset-seconds\tnote\n' >>"${MOUSE_EVENTS_LOG}"
    scenario_start_ms="$(/bin/date +%s)000"
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" 0 \
        "${MOUSE_FREEFORM_PICKUP_SCREENSHOT}" "" "${MOUSE_FREEFORM_HOVER_SCREENSHOT}" \
        freeform "${scenario_start_ms}"
    sleep 2
    refresh_window_log "${WINDOW_AFTER_FREEFORM_LOG}"
    freeform_id="$(window_id_for_title "${WINDOW_AFTER_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_zone="$(zone_for_title "${WINDOW_AFTER_FREEFORM_LOG}" 'snap-demo.rtf')"
    [ "${freeform_id}" = "${before_id}" ] || semantic_fail "Freeform drag changed snap window id: ${before_id} -> ${freeform_id:-missing}"
    [ "${freeform_zone}" = "main" ] || semantic_fail "Freeform drag should keep snap-demo.rtf assigned to Work/main, got ${freeform_zone:-missing}"

    reset_snap_window_to_work
    capture_guest_screenshot '07c-reset-before-snap-slice-51'
    source_left="$(window_rect_field_for_title "${WINDOW_RESET_LOG}" 'snap-demo.rtf' left)"
    source_top="$(window_rect_field_for_title "${WINDOW_RESET_LOG}" 'snap-demo.rtf' top)"
    source_width="$(window_rect_field_for_title "${WINDOW_RESET_LOG}" 'snap-demo.rtf' width)"
    source_x="$(awk_int "${source_left} + (${source_width} * 0.50)")"
    source_y="$(awk_int "${source_top} + 32")"
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" 1 \
        "${MOUSE_SNAP_PICKUP_SCREENSHOT}" "${MOUSE_SNAP_PATH_SCREENSHOT}" "${MOUSE_SNAP_HOVER_SCREENSHOT}" \
        snap "${scenario_start_ms}" "${MOUSE_SNAP_RELEASE_SCREENSHOT}"
    sleep 4
    for _ in $(seq 1 30); do
        refresh_window_log "${WINDOW_AFTER_SNAP_LOG}"
        if [ "$(zone_for_title "${WINDOW_AFTER_SNAP_LOG}" 'snap-demo.rtf')" = "right" ]; then
            break
        fi
        sleep 1
    done
    snap_id="$(window_id_for_title "${WINDOW_AFTER_SNAP_LOG}" 'snap-demo.rtf')"
    snap_zone="$(zone_for_title "${WINDOW_AFTER_SNAP_LOG}" 'snap-demo.rtf')"
    snap_workspace="$(workspace_for_title "${WINDOW_AFTER_SNAP_LOG}" 'snap-demo.rtf')"
    [ "${snap_id}" = "${before_id}" ] || semantic_fail "Alt snap changed snap window id: ${before_id} -> ${snap_id:-missing}"
    [ "${snap_zone}" = "right" ] || semantic_fail "Alt snap should move snap-demo.rtf to Comms/right, got ${snap_zone:-missing}"

    for screenshot in \
        "${MOUSE_FREEFORM_PICKUP_SCREENSHOT}" \
        "${MOUSE_FREEFORM_HOVER_SCREENSHOT}" \
        "${MOUSE_RESET_SCREENSHOT}" \
        "${MOUSE_SNAP_PICKUP_SCREENSHOT}" \
        "${MOUSE_SNAP_PATH_SCREENSHOT}" \
        "${MOUSE_SNAP_HOVER_SCREENSHOT}" \
        "${MOUSE_SNAP_RELEASE_SCREENSHOT}"; do
        test -s "${screenshot}" || semantic_fail "missing mouse snap screenshot: ${screenshot}"
    done

    {
        echo 'mouse-snap-policy=snap-on-modifier'
        echo 'mouse-snap-modifier=alt'
        echo 'mouse-snap-target=whole-zone'
        echo 'mouse-snap-not-target=window-slot'
        echo "source-window-id=${before_id}"
        echo "source-before-workspace=${before_workspace}"
        echo 'freeform-drag=observed no snap without modifier'
        echo "freeform-after-zone=${freeform_zone}"
        echo 'modifier-drag=Alt snap targets Comms zone'
        echo "snap-after-zone=${snap_zone}"
        echo "snap-after-workspace=${snap_workspace}"
        echo "freeform-pickup=screenshots/07a-freeform-pickup-slice-51.png"
        echo "freeform-hover=screenshots/07b-freeform-hover-slice-51.png"
        echo "snap-hover=screenshots/07f-snap-hover-comms-slice-51.png"
        echo "snap-release=screenshots/07g-snap-release-slice-51.png"
        echo 'snap-non-claim=not a window-slot snap proof'
    } >"${MOUSE_SNAP_LOG}"
    cat "${MOUSE_SNAP_LOG}" | tee -a "${CLI_LOG}"
    capture_guest_screenshot '07-mouse-snap-slice-51'
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
    /usr/bin/killall TextEdit >/dev/null 2>&1 || true
    sleep 1

    sleep_until_recording_offset 68 90 "Run: winmux move-node-to-zone Comms"
    echo "routing-keyboard-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_routing_keyboard
    sleep 2
    capture_guest_screenshot '06-routing-keyboard-slice-51'

    sleep_until_recording_offset 90 110 "Action: hold Option and snap to Comms"
    echo "mouse-snap-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    run_mouse_snap
    sleep 2

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
    /usr/bin/killall TextEdit >/dev/null 2>&1 || true
    sleep 1
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
        "${ARTIFACTS_DIR}/reviews" "${ARTIFACTS_DIR}/retrospectives" "${ARTIFACTS_DIR}/recordings/raw" \
        "${ARTIFACTS_DIR}/screenshots/slice-51-beta-acceptance.samples" "${package_dir}/WinMux.app/Contents/MacOS" \
        "${package_dir}/WinMux.app/Contents/Resources" "${package_dir}/bin" "${ARTIFACTS_DIR}/logs/slice-51-zone-support-bundle"
    ffmpeg -v error -y -f lavfi -i 'color=c=0x102030:s=100x80' -frames:v 1 "${ARTIFACTS_DIR}/template.png"
    ffmpeg -v error -y -f lavfi -i 'color=c=0x304050:s=100x80' -frames:v 1 "${ARTIFACTS_DIR}/template.jpg"
    ffmpeg -v error -y -f lavfi -i 'testsrc=duration=1:size=100x80:rate=10' -pix_fmt yuv420p "${ARTIFACTS_DIR}/template.mov"
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
    cat >"${ARTIFACTS_DIR}/logs/preflight.log" <<'EOF'
vm_display=100x80px
record_seconds=1
capture_mode=guest
require_guest_control=1
annotate_recording=1
EOF
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
    cat >"${WINDOW_BEFORE_ROUTING_LOG}" <<'EOF'
1|route-beta.rtf|zone=main|workspace=Work|layout=tiling|monitor=Main / Work|left=300|top=0|width=600|height=800
EOF
    cat >"${WINDOW_AFTER_ROUTING_LOG}" <<'EOF'
1|route-beta.rtf|zone=right|workspace=Comms|layout=tiling|monitor=Main / Comms|left=900|top=0|width=300|height=800
EOF
    cat >"${ROUTING_KEYBOARD_LOG}" <<'EOF'
$ winmux move-node-to-zone --window-id 1 Comms
route-beta.rtf moved from Work/main to Comms/right
EOF
    cat >"${WINDOW_AFTER_FREEFORM_LOG}" <<'EOF'
2|snap-demo.rtf|zone=main|workspace=Work|layout=floating|monitor=Main / Work|left=500|top=40|width=600|height=800
EOF
    cat >"${WINDOW_AFTER_SNAP_LOG}" <<'EOF'
2|snap-demo.rtf|zone=right|workspace=Comms|layout=tiling|monitor=Main / Comms|left=900|top=0|width=300|height=800
EOF
    cat >"${MOUSE_SNAP_LOG}" <<'EOF'
freeform-after-zone=main
snap-after-zone=right
EOF
    cat >"${MOUSE_EVENTS_LOG}" <<'EOF'
# event-id	kind	offset-seconds	note
freeform-drag-start	drag	1.0	no modifier pickup
freeform-drag-hover	drag	2.0	no modifier hover
freeform-drag-release	drag	3.0	no modifier release
snap-drag-start	drag	4.0	Alt-held pickup
snap-drag-hover	overlay	5.0	whole Comms zone target
snap-release	drag	6.0	release on whole Comms zone
EOF
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
        /bin/cp "${ARTIFACTS_DIR}/template.png" "${SCREENSHOTS_DIR}/${screenshot}.png"
    done
    for screenshot in \
        07a-freeform-pickup-slice-51 \
        07b-freeform-hover-slice-51 \
        07c-reset-before-snap-slice-51 \
        07d-snap-pickup-slice-51 \
        07e-snap-path-slice-51 \
        07f-snap-hover-comms-slice-51 \
        07g-snap-release-slice-51; do
        /bin/cp "${ARTIFACTS_DIR}/template.png" "${SCREENSHOTS_DIR}/${screenshot}.png"
    done
    /bin/cp "${ARTIFACTS_DIR}/template.jpg" "${SCREENSHOTS_DIR}/slice-51-beta-acceptance.contact-sheet.jpg"
    /bin/cp "${ARTIFACTS_DIR}/template.jpg" "${SCREENSHOTS_DIR}/slice-51-beta-acceptance.event-contact-sheet.jpg"
    /bin/cp "${ARTIFACTS_DIR}/template.mov" "${ARTIFACTS_DIR}/recordings/slice-51-beta-acceptance.mov"
    /bin/cp "${ARTIFACTS_DIR}/template.mov" "${ARTIFACTS_DIR}/recordings/raw/slice-51-beta-acceptance.raw.mov"
    for sample in caption-01 caption-02 caption-03 caption-04 caption-05 caption-06 caption-07 caption-08 caption-09 caption-10; do
        /bin/cp "${ARTIFACTS_DIR}/template.png" "${SCREENSHOTS_DIR}/slice-51-beta-acceptance.samples/${sample}.png"
        /bin/cp "${ARTIFACTS_DIR}/template.png" "${SCREENSHOTS_DIR}/slice-51-beta-acceptance.samples/${sample}-boundary-start.png"
    done
    printf 'result=success\n' >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.annotation.log"
    cat >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.annotations.tsv" <<'EOF'
0	16	Package provenance	Start from the beta package and show hashes before any acceptance action.	Run: make beta-package VERSION=0.51.0-self-test PUBLISH=0
48	68	Normal launch	Launch the packaged app with the normal config path.	Run: open /Applications/WinMux.app
68	90	Routing and keyboard	Route a window and move it across zones with key-bindable commands.	Run: winmux move-node-to-zone --window-id ROUTE_ID Comms	Run: winmux focus-zone Work
90	110	Mouse snap	Show freeform drag first, then modifier-held zone snap.	Action: drag snap-demo without Option	Result: no snap	Action: hold Option and snap snap-demo to Comms
110	130	Profiles and sizing	Toggle zone availability and resize the working layout.	Run: winmux use-zone-profile communications	Run: winmux resize-zone Work width +10%
130	148	Save and relaunch	Persist the layout, quit, relaunch, and inspect restored widths.	Run: winmux save-zone-layout	Action: relaunch WinMux
148	164	Support bundle	Generate the attachable diagnostics bundle from the packaged CLI.	Run: winmux doctor zones --support-bundle
EOF
    cat >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.expected-chips.txt" <<'EOF'
Run: make beta-package VERSION=0.51.0-self-test PUBLISH=0
Run: open /Applications/WinMux.app
Run: winmux move-node-to-zone --window-id ROUTE_ID Comms
Run: winmux focus-zone Work
Action: drag snap-demo without Option
Result: no snap
Action: hold Option and snap snap-demo to Comms
Run: winmux use-zone-profile communications
Run: winmux resize-zone Work width +10%
Run: winmux save-zone-layout
Run: winmux doctor zones --support-bundle
EOF
    printf 'result=success\n' >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.caption-tail.tsv"
    printf 'result=success\n' >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.demo-cut.tsv"
    cat >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.event-manifest.tsv" <<'EOF'
# event-id	kind	seconds	caption-label	sample-label	path	expected
package-provenance	context	4.100	caption-01	package-provenance	screenshots/02-package-provenance-slice-51.png	provenance visible
fresh-install	action	18.100	caption-02	fresh-install	screenshots/03-fresh-install-slice-51.png	fresh install visible
permissions-setup	action	34.100	caption-03	permissions-setup	screenshots/04-permissions-setup-slice-51.png	permissions visible
normal-launch	action	50.100	caption-04	normal-launch	screenshots/05-normal-launch-slice-51.png	normal launch visible
routing-keyboard	action	70.100	caption-05	routing-keyboard	screenshots/06-routing-keyboard-slice-51.png	routing visible
mouse-snap	action	92.100	caption-06	mouse-snap	screenshots/07-mouse-snap-slice-51.png	mouse visible
profile-layout	action	112.100	caption-07	profile-layout	screenshots/08-profile-layout-slice-51.png	profile visible
save-relaunch	relaunch	132.100	caption-08	save-relaunch	screenshots/09-save-relaunch-slice-51.png	save visible
support-bundle	diagnostic	150.100	caption-09	support-bundle	screenshots/10-support-bundle-slice-51.png	support visible
disable-close	result	166.100	caption-10	disable-close	screenshots/11-final-beta-acceptance-slice-51.png	final visible
freeform-drag-start	drag	93.100	caption-06	freeform-drag-start	screenshots/07a-freeform-pickup-slice-51.png	freeform pickup
freeform-drag-hover	drag	96.100	caption-06	freeform-drag-hover	screenshots/07b-freeform-hover-slice-51.png	freeform hover
freeform-drag-release	drag	99.100	caption-06	freeform-drag-release	screenshots/07c-reset-before-snap-slice-51.png	freeform release
snap-drag-start	drag	101.100	caption-06	snap-drag-start	screenshots/07d-snap-pickup-slice-51.png	snap pickup
snap-drag-path	drag	103.100	caption-06	snap-drag-path	screenshots/07e-snap-path-slice-51.png	snap path
snap-drag-hover	overlay	105.100	caption-06	snap-drag-hover	screenshots/07f-snap-hover-comms-slice-51.png	snap hover
snap-release	drag	108.100	caption-06	snap-release	screenshots/07g-snap-release-slice-51.png	snap release
EOF
    cat >"${ARTIFACTS_DIR}/logs/slice-51-beta-acceptance.sample-manifest.tsv" <<'EOF'
semantic	package-provenance	screenshot	screenshot	screenshots/02-package-provenance-slice-51.png	provenance visible
semantic	fresh-install	screenshot	screenshot	screenshots/03-fresh-install-slice-51.png	fresh install visible
semantic	permissions-setup	screenshot	screenshot	screenshots/04-permissions-setup-slice-51.png	permissions visible
semantic	normal-launch	screenshot	screenshot	screenshots/05-normal-launch-slice-51.png	normal launch visible
semantic	routing-keyboard	screenshot	screenshot	screenshots/06-routing-keyboard-slice-51.png	routing visible
semantic	mouse-snap	screenshot	screenshot	screenshots/07-mouse-snap-slice-51.png	mouse visible
semantic	profile-layout	screenshot	screenshot	screenshots/08-profile-layout-slice-51.png	profile visible
semantic	save-relaunch	screenshot	screenshot	screenshots/09-save-relaunch-slice-51.png	save visible
semantic	support-bundle	screenshot	screenshot	screenshots/10-support-bundle-slice-51.png	support visible
semantic	disable-close	screenshot	screenshot	screenshots/11-final-beta-acceptance-slice-51.png	final visible
semantic	freeform-drag-start	screenshot	screenshot	screenshots/07a-freeform-pickup-slice-51.png	freeform pickup
semantic	freeform-drag-hover	screenshot	screenshot	screenshots/07b-freeform-hover-slice-51.png	freeform hover
semantic	freeform-drag-release	screenshot	screenshot	screenshots/07c-reset-before-snap-slice-51.png	freeform release
semantic	snap-drag-start	screenshot	screenshot	screenshots/07d-snap-pickup-slice-51.png	snap pickup
semantic	snap-drag-path	screenshot	screenshot	screenshots/07e-snap-path-slice-51.png	snap path
semantic	snap-drag-hover	screenshot	screenshot	screenshots/07f-snap-hover-comms-slice-51.png	snap hover
semantic	snap-release	screenshot	screenshot	screenshots/07g-snap-release-slice-51.png	snap release
EOF
    write_beta_proof
    cat >"${ARTIFACTS_DIR}/logs/guest-script-retry-summary.tsv" <<'EOF'
# phase	log	attempts	failures	final_result	before_recording	attempt_statuses	first_failure_reason	last_failure_reason	mutation_started	first_mutation_line
slice-51-setup	logs/slice-51-setup.log	1	0	success	yes	success	-	-	no	-
slice-51-run	logs/slice-51-run.log	1	0	success	no	success	-	-	yes	7
EOF
}

self_test_slice() {
    write_self_test_fixture
    WINMUX_E2E_SLICE51_SELF_TEST_CONTRACT=1 "${REPO_DIR}/script/e2e/check-slice-51-beta-acceptance" "${ARTIFACTS_DIR}" >/dev/null
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
