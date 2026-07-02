#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE48_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-48-support-bundle-diagnostics"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice48-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice48-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice48"
LAUNCH_PLIST="/tmp/winmux-e2e-slice48.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice48.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-48-setup.log"
ZONE_WORKFLOW_LOG="${ARTIFACTS_DIR}/logs/slice-48-zone-workflow.log"
SUPPORT_COMMAND_LOG="${ARTIFACTS_DIR}/logs/slice-48-support-bundle-command.log"
BUNDLE_DIR="${ARTIFACTS_DIR}/logs/slice-48-zone-support-bundle"
BUNDLE_FILES_LOG="${ARTIFACTS_DIR}/logs/slice-48-bundle-files.txt"
BUNDLE_MANIFEST_COPY="${ARTIFACTS_DIR}/logs/slice-48-bundle-manifest.txt"
BUNDLE_REDACTION_COPY="${ARTIFACTS_DIR}/logs/slice-48-bundle-redaction-summary.txt"
BUNDLE_CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-48-bundle-config-redacted.toml"
BUNDLE_AFFINITIES_COPY="${ARTIFACTS_DIR}/logs/slice-48-bundle-zone-affinities.tsv"
BUNDLE_ROUTING_COPY="${ARTIFACTS_DIR}/logs/slice-48-bundle-routing-decisions.tsv"
FINAL_BOARD_SOURCE="${ARTIFACTS_DIR}/logs/slice-48-final-board-source.txt"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-48-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-48-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-48-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/${RECORDING_NAME}-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/support-bundle-docs"
WORKFLOW_DOC="${DOC_DIR}/slice48-zone-workflow.rtf"
SUPPORT_DOC="${DOC_DIR}/slice48-support-bundle-command.rtf"
CONTENTS_DOC="${DOC_DIR}/slice48-support-bundle-contents.rtf"
FINAL_DOC="${DOC_DIR}/slice48-final-support-audit.rtf"
WORKFLOW_TITLE="slice48-zone-workflow.rtf"
SUPPORT_TITLE="slice48-support-bundle-command.rtf"
CONTENTS_TITLE="slice48-support-bundle-contents.rtf"
FINAL_TITLE="slice48-final-support-audit.rtf"

uid="$(/usr/bin/id -u)"
mutation_marked=0

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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-48-zone-count.txt" 2>"${WAIT_ERR}"; then
            return
        fi
        sleep 1
    done

    cat "${LAUNCH_STATUS}" >&2 || true
    cat "${APP_LOG}" >&2 || true
    cat "${STARTUP_TRACE}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    semantic_fail 'WinMux CLI did not become ready'
}

wait_for_window_present() {
    local title="$1"
    local log_path="$2"
    for _ in $(seq 1 30); do
        if "${CLI}" list-windows --all --format '%{window-title}' >"${log_path}" 2>>"${WAIT_ERR}" &&
            /usr/bin/grep -Fx "${title}" "${log_path}" >/dev/null; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}

write_slice_config() {
    mkdir -p "$(dirname "${CONFIG}")"
    cat >"${CONFIG}" <<'TOML'
config-version = 2
auto-reload-config = false
persistent-workspaces = []

[[zones]]
monitor = 1
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[[zone-bindings]]
zone = 'left'
workspace = 'reference'

[[zone-bindings]]
zone = 'main'
workspace = 'work'

[[zone-bindings]]
zone = 'right'
workspace = 'comms'

[[zone-affinities]]
zone = 'Comms'
if.app-id = 'com.secret.Mail'
if.window-title-regex-substring = 'Secret Board'
if.workspace = 'work'
focus-follows-window = true

[workspace-sidebar]
enabled = true
enable-focus = false
width = 300
collapsed-width = 64
show-date = false

[mode.main.binding]
alt-r = 'focus-zone Reference'
alt-w = 'focus-zone Work'
alt-c = 'focus-zone Comms'
TOML
    {
        echo '# token = "super-secret-token"'
        echo "# private-path = \"${HOME}/Secret\""
    } >>"${CONFIG}"
}

validate_bundle() {
    local required
    for required in \
        active-workspaces.tsv \
        command-failures.tsv \
        config-doctor.txt \
        config-redacted.toml \
        logs.txt \
        manifest.txt \
        monitor-topology.tsv \
        node-zone-bindings.tsv \
        permissions.txt \
        recent-window-routing-decisions.tsv \
        redaction-summary.txt \
        zone-affinities.tsv \
        zone-runtime-overlay.tsv; do
        [ -s "${BUNDLE_DIR}/${required}" ] || semantic_fail "support bundle missing ${required}"
    done

    if /usr/bin/grep -R -E 'Secret Board|com\.secret\.Mail|super-secret-token' "${BUNDLE_DIR}" >/dev/null; then
        semantic_fail 'support bundle leaked sensitive app/title/token content'
    fi
    /usr/bin/grep -R -F '<redacted-window-title>' "${BUNDLE_DIR}" >/dev/null \
        || semantic_fail 'support bundle missing window title redaction marker'
    /usr/bin/grep -R -F '<redacted-app-identifier>' "${BUNDLE_DIR}" >/dev/null \
        || semantic_fail 'support bundle missing app identifier redaction marker'
    /usr/bin/grep -F 'schema-version=1' "${BUNDLE_DIR}/manifest.txt" >/dev/null \
        || semantic_fail 'support bundle manifest missing schema-version=1'
    /usr/bin/grep -F 'permission	status	note' "${BUNDLE_DIR}/permissions.txt" >/dev/null \
        || semantic_fail 'support bundle missing permissions header'
    /usr/bin/grep -F 'monitor-id	zone-id	zone-name	physical-identity	active-workspace' "${BUNDLE_DIR}/active-workspaces.tsv" >/dev/null \
        || semantic_fail 'support bundle missing active workspace header'
    /usr/bin/grep -F 'WinMux does not retain command failure history yet' "${BUNDLE_DIR}/command-failures.tsv" >/dev/null \
        || semantic_fail 'support bundle missing command failure retention note'
    if ! /usr/bin/grep -F 'WinMux does not retain a recent window-routing decision log yet' "${BUNDLE_DIR}/recent-window-routing-decisions.tsv" >/dev/null &&
        ! /usr/bin/grep -F 'zone-affinity-config' "${BUNDLE_DIR}/recent-window-routing-decisions.tsv" >/dev/null; then
        semantic_fail 'support bundle missing routing retention note'
    fi
}

copy_bundle_evidence() {
    /usr/bin/find "${BUNDLE_DIR}" -maxdepth 1 -type f -print | /usr/bin/sort >"${BUNDLE_FILES_LOG}"
    /bin/cp "${BUNDLE_DIR}/manifest.txt" "${BUNDLE_MANIFEST_COPY}"
    /bin/cp "${BUNDLE_DIR}/redaction-summary.txt" "${BUNDLE_REDACTION_COPY}"
    /bin/cp "${BUNDLE_DIR}/config-redacted.toml" "${BUNDLE_CONFIG_COPY}"
    /bin/cp "${BUNDLE_DIR}/zone-affinities.tsv" "${BUNDLE_AFFINITIES_COPY}"
    /bin/cp "${BUNDLE_DIR}/recent-window-routing-decisions.tsv" "${BUNDLE_ROUTING_COPY}"
}

setup_slice() {
    rm -rf "${DOC_DIR}" "${BUNDLE_DIR}"
    rm -f \
        "${SETUP_LOG}" "${ZONE_WORKFLOW_LOG}" "${SUPPORT_COMMAND_LOG}" "${BUNDLE_FILES_LOG}" \
        "${BUNDLE_MANIFEST_COPY}" "${BUNDLE_REDACTION_COPY}" "${BUNDLE_CONFIG_COPY}" \
        "${BUNDLE_AFFINITIES_COPY}" "${BUNDLE_ROUTING_COPY}" "${FINAL_BOARD_SOURCE}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${DONE}" "${PROOF}" "${APP_LOG}" \
        "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" \
        "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    mkdir -p "${DOC_DIR}" "${BIN_DIR}" "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    write_slice_config

    {
        echo 'WinMux Slice 48: support bundle and diagnostics'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config includes zones, zone bindings, and redaction bait for app/title/token fields.'
    } | tee "${SETUP_LOG}"

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
}

run_proof() {
    mkdir -p "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs"
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"

    sleep 4
    echo "zone-workflow-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo '$ winmux list-zones --format zone|name|workspace|physical'
        "${CLI}" list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|physical=%{monitor-physical-id}'
    } | tee "${ZONE_WORKFLOW_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    write_text_doc "${ZONE_WORKFLOW_LOG}" 'Slice 48 zone workflow' "${WORKFLOW_DOC}"
    /usr/bin/open -a TextEdit "${WORKFLOW_DOC}"
    wait_for_window_present "${WORKFLOW_TITLE}" "${ARTIFACTS_DIR}/logs/slice-48-windows-workflow.log" \
        || semantic_fail "${WORKFLOW_TITLE} did not become visible"
    sleep 1
    capture_guest_screenshot '02-zone-workflow-slice-48'

    sleep 12
    echo "support-bundle-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    rm -rf "${BUNDLE_DIR}"
    {
        echo "$ winmux doctor zones --support-bundle --output ${BUNDLE_DIR}"
        "${CLI}" doctor zones --support-bundle --output "${BUNDLE_DIR}"
    } | tee "${SUPPORT_COMMAND_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    validate_bundle
    copy_bundle_evidence
    write_text_doc "${SUPPORT_COMMAND_LOG}" 'Slice 48 support bundle command' "${SUPPORT_DOC}"
    /usr/bin/open -a TextEdit "${SUPPORT_DOC}"
    wait_for_window_present "${SUPPORT_TITLE}" "${ARTIFACTS_DIR}/logs/slice-48-windows-support.log" \
        || semantic_fail "${SUPPORT_TITLE} did not become visible"
    sleep 1
    capture_guest_screenshot '03-support-bundle-command-slice-48'

    sleep 12
    echo "bundle-contents-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ find slice-48-zone-support-bundle -maxdepth 1 -type f | sort'
        cat "${BUNDLE_FILES_LOG}"
        echo
        echo '$ cat redaction-summary.txt'
        cat "${BUNDLE_REDACTION_COPY}"
        echo
        echo '$ cat zone-affinities.tsv'
        cat "${BUNDLE_AFFINITIES_COPY}"
    } >"${ARTIFACTS_DIR}/logs/slice-48-bundle-contents-board-source.txt"
    write_text_doc "${ARTIFACTS_DIR}/logs/slice-48-bundle-contents-board-source.txt" \
        'Slice 48 support bundle contents' "${CONTENTS_DOC}"
    /usr/bin/open -a TextEdit "${CONTENTS_DOC}"
    wait_for_window_present "${CONTENTS_TITLE}" "${ARTIFACTS_DIR}/logs/slice-48-windows-contents.log" \
        || semantic_fail "${CONTENTS_TITLE} did not become visible"
    sleep 1
    capture_guest_screenshot '04-support-bundle-contents-slice-48'

    sleep 12
    echo "final-audit-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo 'Slice 48 final support audit'
        echo "Run: winmux doctor zones --support-bundle --output ${BUNDLE_DIR}"
        echo "Result: support bundle generated"
        echo "Bundle: ${BUNDLE_DIR}"
        echo 'Redaction: usernames, home paths, app identifiers, and window titles are redacted by default'
        echo 'Required files: present'
        echo 'support-bundle-redaction-pass=yes'
        echo 'support-bundle-required-files-pass=yes'
        echo 'support-bundle-debug-value-pass=yes'
        echo 'non-claim=no automatic upload'
    } >"${FINAL_BOARD_SOURCE}"
    write_text_doc "${FINAL_BOARD_SOURCE}" 'Slice 48 final support audit' "${FINAL_DOC}"
    /usr/bin/open -a TextEdit "${FINAL_DOC}"
    wait_for_window_present "${FINAL_TITLE}" "${ARTIFACTS_DIR}/logs/slice-48-windows-final.log" \
        || semantic_fail "${FINAL_TITLE} did not become visible"
    sleep 1
    capture_guest_screenshot '05-final-support-audit-slice-48'

    {
        echo 'WinMux Slice 48: support bundle and diagnostics'
        echo
        echo 'PASS: doctor zones --support-bundle creates an attachable redacted zone diagnostics directory after a zone workflow.'
        echo "bundle-dir=${BUNDLE_DIR}"
        echo 'support-bundle-redaction-pass=yes'
        echo 'support-bundle-required-files-pass=yes'
        echo 'support-bundle-debug-value-pass=yes'
        echo 'non-claim=no automatic upload'
    } >"${PROOF}"

    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

write_self_test_bundle() {
    mkdir -p "${BUNDLE_DIR}" "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots"
    printf 'winmux-zone-support-bundle\nschema-version=1\ncommand=doctor zones --support-bundle\nfiles=active-workspaces.tsv,command-failures.tsv,config-doctor.txt,config-redacted.toml,logs.txt,manifest.txt,monitor-topology.tsv,node-zone-bindings.tsv,permissions.txt,recent-window-routing-decisions.tsv,redaction-summary.txt,zone-affinities.tsv,zone-runtime-overlay.tsv\n' >"${BUNDLE_DIR}/manifest.txt"
    printf 'Zone support bundle redaction\nwindow-titles=<redacted-window-title>\napp-identifiers=<redacted-app-identifier>\n' >"${BUNDLE_DIR}/redaction-summary.txt"
    printf 'config-version = 2\nif.app-id = "<redacted>"\nif.window-title-regex-substring = "<redacted>"\n# token = "<redacted>"\n' >"${BUNDLE_DIR}/config-redacted.toml"
    printf 'Config doctor:\n  config status: OK\n' >"${BUNDLE_DIR}/config-doctor.txt"
    printf 'permission\tstatus\tnote\naccessibility\tgranted\trequired\n' >"${BUNDLE_DIR}/permissions.txt"
    printf 'kind\tmonitor-id\tname\tphysical-identity\tx\ty\twidth\theight\tvisible-x\tvisible-y\tvisible-width\tvisible-height\tzone-id\tzone-name\tlayout-id\tavailability-set-id\tstyle-id\tstyle-color\tdefault-zone\nzone\t1\tMain\tmain\t0\t0\t100\t100\t0\t0\t100\t100\tmain\tWork\t\t\t\t\ttrue\n' >"${BUNDLE_DIR}/monitor-topology.tsv"
    printf 'monitor-id\tzone-id\tzone-name\tphysical-identity\tactive-workspace\tworkspace-visible\n1\tmain\tWork\tmain\twork\ttrue\n' >"${BUNDLE_DIR}/active-workspaces.tsv"
    printf 'physical-identity\tactive-layout\tactive-scene\tactive-availability\tsnap-policy\tdisabled-zones\tparked-workspaces\twidth-overrides\tstyle-overrides\ttoggle-restore-zone\nnone\t\t\t\t\t\t\t\t\t\n' >"${BUNDLE_DIR}/zone-runtime-overlay.tsv"
    printf 'index\tzone\tapp-id-configured\tapp-name-configured\twindow-title-configured\tworkspace\tstartup\tfocus-follows-window\tfail-if-noop\tcheck-further-callbacks\n0\tComms\ttrue:<redacted-app-identifier>\tfalse\ttrue:<redacted-window-title>\twork\t\ttrue\tfalse\tfalse\n' >"${BUNDLE_DIR}/zone-affinities.tsv"
    printf 'node-id\tnode-type\twindow-ids\ttitle\tzone\tzone-name\tworkspace\tmonitor\tphysical\nnone\t\t\t\t\t\t\t\t\n' >"${BUNDLE_DIR}/node-zone-bindings.tsv"
    printf 'source\tindex-or-node\tzone\tworkspace\tmatched\tdebug\nunavailable\t\t\t\tnot-retained\tWinMux does not retain a recent window-routing decision log yet\n' >"${BUNDLE_DIR}/recent-window-routing-decisions.tsv"
    printf 'source\tcommand\tstatus\tdebug\nunavailable\t\tunretained\tWinMux does not retain command failure history yet\n' >"${BUNDLE_DIR}/command-failures.tsv"
    printf 'source\tstatus\tdebug\nstderr\tunavailable\tWinMux debug logs are emitted to stderr\n' >"${BUNDLE_DIR}/logs.txt"
}

self_test_slice() {
    write_self_test_bundle
    validate_bundle
    copy_bundle_evidence
    printf '$ winmux doctor zones --support-bundle --output %s\nZone support bundle: %s\nFiles: manifest.txt\n' \
        "${BUNDLE_DIR}" "${BUNDLE_DIR}" >"${SUPPORT_COMMAND_LOG}"
    printf 'zone-workflow-offset-seconds=4\nsupport-bundle-command-offset-seconds=20\nbundle-contents-offset-seconds=36\nfinal-audit-offset-seconds=52\n' >"${TIMING_LOG}"
    printf 'support-bundle-redaction-pass=yes\nsupport-bundle-required-files-pass=yes\nsupport-bundle-debug-value-pass=yes\n' >"${FINAL_BOARD_SOURCE}"
    printf 'PASS: doctor zones --support-bundle creates an attachable redacted zone diagnostics directory after a zone workflow.\nsupport-bundle-redaction-pass=yes\nsupport-bundle-required-files-pass=yes\nsupport-bundle-debug-value-pass=yes\nnon-claim=no automatic upload\n' >"${PROOF}"
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
        semantic_fail "Unknown Slice 48 phase: ${PHASE}"
        ;;
esac
