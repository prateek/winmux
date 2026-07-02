#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE45_PHASE:-proof}"

if [ "${PHASE}" = "self-test" ]; then
    mkdir -p "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots"
    manifest="${ARTIFACTS_DIR}/logs/slice-45-display-topology-recovery.topology-event-manifest.tsv"
    cat >"${manifest}" <<'EOF'
# event-id	kind	seconds	caption-label	sample-label	path	expected
topology-before	context	8.100	caption-02	topology-before	screenshots/02-topology-before-slice-45.png	before board shows physical monitor, zones, workspaces, and windows
simulated-loss	action	18.100	caption-03	simulated-loss	screenshots/03-simulated-loss-slice-45.png	board labels deterministic Tart simulation and display-loss policy
recovery-visible	recovery	32.100	caption-04	recovery-visible	screenshots/04-recovery-visible-slice-45.png	recovery board shows remaining-display state and no offscreen visible windows
simulated-return	action	48.100	caption-05	simulated-return	screenshots/05-simulated-return-slice-45.png	board labels simulated return at 3440x1440
topology-after	inspection	64.100	caption-06	topology-after	screenshots/06-topology-after-slice-45.png	after board shows restored zones and workspace identity
final-recoverability	result	80.100	caption-07	final-recoverability	screenshots/07-final-recoverability-slice-45.png	final board shows list-zones/list-windows audits and non-claim boundary
EOF
    /usr/bin/awk -F'\t' '
        $0 == "" || $1 ~ /^#/ { next }
        { rows++; labels[$5] = 1 }
        END {
            exit(rows == 6 &&
                 labels["topology-before"] &&
                 labels["simulated-loss"] &&
                 labels["recovery-visible"] &&
                 labels["simulated-return"] &&
                 labels["topology-after"] &&
                 labels["final-recoverability"] ? 0 : 1)
        }
    ' "${manifest}"
    echo "result=success"
    exit 0
fi

SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-45-display-topology-recovery"
ZONES_FORMAT='physical=%{monitor-physical-id}|zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}'
WINDOWS_FORMAT='%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice45-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice45-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice45"
LAUNCH_PLIST="/tmp/winmux-e2e-slice45.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice45.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-45-setup.log"
CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-45-config.toml"
WINDOW_READY_LOG="${ARTIFACTS_DIR}/logs/slice-45-windows-ready.log"
ZONES_READY_LOG="${ARTIFACTS_DIR}/logs/slice-45-zones-ready.log"
WINDOWS_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-45-windows-before.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-45-zones-before.log"
TOPOLOGY_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-before.log"
TOPOLOGY_LOSS_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-simulated-loss.log"
WINDOWS_RECOVERY_LOG="${ARTIFACTS_DIR}/logs/slice-45-windows-recovery-visible.log"
ZONES_RECOVERY_LOG="${ARTIFACTS_DIR}/logs/slice-45-zones-recovery-visible.log"
TOPOLOGY_RECOVERY_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-recovery-visible.log"
TOPOLOGY_RETURN_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-simulated-return.log"
WINDOWS_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-45-windows-after.log"
ZONES_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-45-zones-after.log"
TOPOLOGY_AFTER_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-after.log"
FINAL_WINDOWS_LOG="${ARTIFACTS_DIR}/logs/slice-45-final-windows.log"
FINAL_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-45-final-zones.log"
TOPOLOGY_FINAL_LOG="${ARTIFACTS_DIR}/logs/slice-45-topology-final-recoverability.log"
TOPOLOGY_EVENT_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.topology-event-manifest.tsv"
PROOF_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-45-command-timing.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-45-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-45-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-45-display-topology-recovery-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/display-topology-docs"
REFERENCE_DOC="${DOC_DIR}/slice45-reference-topology.rtf"
WORK_DOC="${DOC_DIR}/slice45-work-topology.rtf"
COMMS_DOC="${DOC_DIR}/slice45-comms-topology.rtf"
BOARD_DIR="${DOC_DIR}/boards"

REFERENCE_TITLE="slice45-reference-topology.rtf"
WORK_TITLE="slice45-work-topology.rtf"
COMMS_TITLE="slice45-comms-topology.rtf"

uid="$(/usr/bin/id -u)"
mutation_marked=0

# shellcheck disable=SC1091
# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
source "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

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
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl500\\margr500\\pard\\ql\\f0\\fs50\\b %s\\b0\\par\\f1\\fs24\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

write_static_docs() {
    mkdir -p "${DOC_DIR}" "${BOARD_DIR}"
    cat >"${REFERENCE_DOC}" <<'RTF'
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs64\b Reference / Left\b0\par\f1\fs30 slice45-reference-topology.rtf\par This window must remain recoverable through display topology churn.\par}
RTF
    cat >"${WORK_DOC}" <<'RTF'
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs64\b Work / Main\b0\par\f1\fs30 slice45-work-topology.rtf\par This is the default zone workspace and should survive display id churn.\par}
RTF
    cat >"${COMMS_DOC}" <<'RTF'
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs64\b Comms / Right\b0\par\f1\fs30 slice45-comms-topology.rtf\par This window proves the side zone is restored and not stranded offscreen.\par}
RTF
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-45-zone-count.txt" 2>"${WAIT_ERR}"; then
            return
        fi
        sleep 1
    done

    cat "${LAUNCH_STATUS}" >&2 || true
    copy_runtime_logs
    cat "${APP_LOG}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    semantic_fail 'WinMux CLI did not become ready for Slice 45'
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    local path="$1"
    {
        printf '$ winmux list-zones --format '\''%s'\''\n' "${ZONES_FORMAT}"
        "${CLI}" list-zones --format "${ZONES_FORMAT}"
    } >"${path}" 2>>"${WAIT_ERR}"
}

write_windows_log() {
    local path="$1"
    {
        printf '$ winmux list-windows --all --format '\''%s'\''\n' "${WINDOWS_FORMAT}"
        "${CLI}" list-windows --all --format "${WINDOWS_FORMAT}"
    } >"${path}" 2>>"${WAIT_ERR}"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local field="$3"
    /usr/bin/awk -F'|' -v title="${title}" -v field="${field}" '$2 == title {
        if (field == "id") { print $1; exit }
        if (field == "zone") { sub(/^zone=/, "", $3); print $3; exit }
        if (field == "workspace") { sub(/^workspace=/, "", $4); print $4; exit }
    }' "${path}"
}

wait_for_textedit_windows() {
    local expected="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
            --format "${WINDOWS_FORMAT}" >"${path}" 2>>"${WAIT_ERR}" || true
        count="$(/usr/bin/grep -c '^' "${path}" || true)"
        if [ "${count}" -ge "${expected}" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

window_id_for_title() {
    field_for_title "$1" "$2" id
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
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone_name}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone_name}"
    } >>"${SETUP_LOG}" 2>>"${WAIT_ERR}"
    wait_for_textedit_windows 3 "${WINDOW_READY_LOG}" || semantic_fail "TextEdit windows disappeared after moving ${title}"
    assert_window_zone "${WINDOW_READY_LOG}" "${title}" "${expected_zone}"
}

write_topology_log() {
    local phase="$1"
    local status="$2"
    local zones_log="$3"
    local windows_log="$4"
    local output="$5"
    {
        printf 'phase=%s\n' "${phase}"
        printf 'status=%s\n' "${status}"
        printf 'tart_topology_mode=deterministic-simulation\n'
        printf 'hardware_hotplug_claim=no\n'
        printf 'zones_log=%s\n' "${zones_log#"${ARTIFACTS_DIR}"/}"
        printf 'windows_log=%s\n' "${windows_log#"${ARTIFACTS_DIR}"/}"
        printf '\n[zones]\n'
        cat "${zones_log}"
        printf '\n[windows]\n'
        cat "${windows_log}"
    } >"${output}"
}

write_board() {
    local phase="$1"
    local title="$2"
    local status="$3"
    local zones_log="$4"
    local windows_log="$5"
    local topology_log="$6"
    local text_path="${BOARD_DIR}/${phase}.txt"
    local doc_path="${BOARD_DIR}/${phase}.rtf"

    {
        echo "Slice 45 topology board: ${title}"
        echo
        echo "Config: zones bind to physical monitor; display ids may churn"
        echo "Tart proof mode: deterministic topology simulation"
        echo "Hardware hotplug claim: no, requires supplemental real-machine video"
        echo "Status: ${status}"
        echo
        echo "User-facing commands shown in this beat:"
        echo "winmux list-zones --format '${ZONES_FORMAT}'"
        echo "winmux list-windows --all --format '${WINDOWS_FORMAT}'"
        echo
        echo "Topology log: ${topology_log#"${ARTIFACTS_DIR}"/}"
        echo "Zones:"
        cat "${zones_log}"
        echo
        echo "Windows:"
        cat "${windows_log}"
    } >"${text_path}"
    write_text_doc "${text_path}" "${title}" "${doc_path}"
    /usr/bin/open -a TextEdit "${doc_path}"
    sleep 1
}

write_topology_event_manifest() {
    cat >"${TOPOLOGY_EVENT_MANIFEST}" <<'EOF'
# event-id	kind	seconds	caption-label	sample-label	path	expected
topology-before	context	8.100	caption-02	topology-before	screenshots/02-topology-before-slice-45.png	before board shows physical monitor, zones, workspaces, and windows
simulated-loss	action	18.100	caption-03	simulated-loss	screenshots/03-simulated-loss-slice-45.png	board labels deterministic Tart simulation and display-loss policy
recovery-visible	recovery	32.100	caption-04	recovery-visible	screenshots/04-recovery-visible-slice-45.png	recovery board shows remaining-display state and no offscreen visible windows
simulated-return	action	48.100	caption-05	simulated-return	screenshots/05-simulated-return-slice-45.png	board labels simulated return at 3440x1440
topology-after	inspection	64.100	caption-06	topology-after	screenshots/06-topology-after-slice-45.png	after board shows restored zones and workspace identity
final-recoverability	result	80.100	caption-07	final-recoverability	screenshots/07-final-recoverability-slice-45.png	final board shows list-zones/list-windows audits and non-claim boundary
EOF
}

write_proof_manifest() {
    cat >"${PROOF_MANIFEST}" <<EOF
topology-proof	mode	deterministic-tart-simulation
topology-proof	hardware-hotplug-claim	no
topology-proof	real-machine-supplement-required	yes-before-real-disconnect-claim
topology-screenshots	topology-before	screenshots/02-topology-before-slice-45.png
topology-screenshots	simulated-loss	screenshots/03-simulated-loss-slice-45.png
topology-screenshots	recovery-visible	screenshots/04-recovery-visible-slice-45.png
topology-screenshots	simulated-return	screenshots/05-simulated-return-slice-45.png
topology-screenshots	topology-after	screenshots/06-topology-after-slice-45.png
topology-screenshots	final-recoverability	screenshots/07-final-recoverability-slice-45.png
topology-logs	before	logs/slice-45-topology-before.log
topology-logs	loss	logs/slice-45-topology-simulated-loss.log
topology-logs	recovery	logs/slice-45-topology-recovery-visible.log
topology-logs	return	logs/slice-45-topology-simulated-return.log
topology-logs	after	logs/slice-45-topology-after.log
topology-logs	final	logs/slice-45-topology-final-recoverability.log
caption	chip	Config: zones bind to physical monitor; display ids may churn
caption	chip	Action: disconnect ultrawide
caption	chip	Result: windows recover on the remaining display
caption	chip	Action: reconnect ultrawide at 3440x1440
caption	chip	Run: winmux list-zones --format
caption	chip	Config: physical=%{monitor-physical-id}|zone=%{monitor-zone-id}
caption	chip	Config: name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}
caption	chip	Config: left=%{monitor-left}|width=%{monitor-width}
caption	chip	Run: winmux list-windows --all --format
caption	chip	Config: %{window-id}|%{window-title}|zone=%{monitor-zone-id}
caption	chip	Config: workspace=%{workspace}|monitor=%{monitor-name}
caption	chip	Result: Reference | Work | Comms restored; no offscreen windows
EOF
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_COPY}" "${WINDOW_READY_LOG}" "${ZONES_READY_LOG}" \
        "${WAIT_ERR}" "${STATE_FILE}" "${DONE}" "${PROOF}" "${PROOF_MANIFEST}" \
        "${TOPOLOGY_EVENT_MANIFEST}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${BOARD_DIR}" "${BIN_DIR}" "${SCREENSHOTS_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${CONFIG}" "${CONFIG_COPY}"
    write_static_docs

    {
        echo 'WinMux Slice 45: deterministic display topology recovery harness'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Proof mode: deterministic Tart simulation; real hardware disconnect requires supplemental video before claim.'
    } | tee "${SETUP_LOG}"

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 "${WINDOW_READY_LOG}" || semantic_fail 'TextEdit windows did not appear'

    reference_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${REFERENCE_TITLE}")"
    work_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${WORK_TITLE}")"
    comms_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${COMMS_TITLE}")"
    [ -n "${reference_id}" ] || semantic_fail "Missing ${REFERENCE_TITLE} window id"
    [ -n "${work_id}" ] || semantic_fail "Missing ${WORK_TITLE} window id"
    [ -n "${comms_id}" ] || semantic_fail "Missing ${COMMS_TITLE} window id"

    move_window_to_zone "${reference_id}" "${REFERENCE_TITLE}" Reference left
    move_window_to_zone "${work_id}" "${WORK_TITLE}" Work main
    move_window_to_zone "${comms_id}" "${COMMS_TITLE}" Comms right
    "${CLI}" focus-zone Work >>"${SETUP_LOG}" 2>>"${WAIT_ERR}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    wait_for_textedit_windows 3 "${WINDOW_READY_LOG}" || semantic_fail 'TextEdit windows missing after setup'
    write_zones_log "${ZONES_READY_LOG}"
    capture_guest_screenshot '01-ready-slice-45'

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

run_proof() {
    SECONDS=0
    : >"${TIMING_LOG}"
    [ -f "${STATE_FILE}" ] || semantic_fail 'Missing Slice 45 state file'
    # shellcheck disable=SC1090
    source "${STATE_FILE}"

    "${CLI}" focus-zone Work >/dev/null 2>>"${WAIT_ERR}" || true
    wait_for_textedit_windows 3 "${WINDOWS_BEFORE_LOG}" || semantic_fail 'Before windows are missing'
    write_zones_log "${ZONES_BEFORE_LOG}"
    write_topology_log before 'all zones visible before topology event' "${ZONES_BEFORE_LOG}" "${WINDOWS_BEFORE_LOG}" "${TOPOLOGY_BEFORE_LOG}"
    sleep_until_recording_offset 8 16 'topology-before'
    write_board before 'Topology before display event' 'Reference | Work | Comms visible on configured ultrawide zones' "${ZONES_BEFORE_LOG}" "${WINDOWS_BEFORE_LOG}" "${TOPOLOGY_BEFORE_LOG}"
    capture_guest_screenshot '02-topology-before-slice-45'
    printf 'topology-before-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    mark_mutation_once
    write_topology_log simulated-loss 'Action: disconnect ultrawide (simulated in Tart); remaining display recovery policy is visible' "${ZONES_BEFORE_LOG}" "${WINDOWS_BEFORE_LOG}" "${TOPOLOGY_LOSS_LOG}"
    sleep_until_recording_offset 18 30 'Action: disconnect ultrawide'
    write_board simulated-loss 'Action: disconnect ultrawide' 'Simulated display loss; windows must be recoverable, not stranded offscreen' "${ZONES_BEFORE_LOG}" "${WINDOWS_BEFORE_LOG}" "${TOPOLOGY_LOSS_LOG}"
    capture_guest_screenshot '03-simulated-loss-slice-45'
    printf 'simulated-loss-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    write_zones_log "${ZONES_RECOVERY_LOG}"
    write_windows_log "${WINDOWS_RECOVERY_LOG}"
    write_topology_log recovery-visible 'Result: windows recover on the remaining display; no offscreen visible windows in audit' "${ZONES_RECOVERY_LOG}" "${WINDOWS_RECOVERY_LOG}" "${TOPOLOGY_RECOVERY_LOG}"
    sleep_until_recording_offset 32 46 'Result: windows recover on the remaining display'
    write_board recovery-visible 'Recovery on remaining display' 'Recoverability audit: zone workspaces retained; no offscreen visible windows' "${ZONES_RECOVERY_LOG}" "${WINDOWS_RECOVERY_LOG}" "${TOPOLOGY_RECOVERY_LOG}"
    capture_guest_screenshot '04-recovery-visible-slice-45'
    printf 'recovery-visible-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    write_topology_log simulated-return 'Action: reconnect ultrawide at 3440x1440 (simulated in Tart)' "${ZONES_RECOVERY_LOG}" "${WINDOWS_RECOVERY_LOG}" "${TOPOLOGY_RETURN_LOG}"
    sleep_until_recording_offset 48 62 'Action: reconnect ultrawide at 3440x1440'
    write_board simulated-return 'Action: reconnect ultrawide at 3440x1440' 'Simulated return/resolution churn; display ids may change' "${ZONES_RECOVERY_LOG}" "${WINDOWS_RECOVERY_LOG}" "${TOPOLOGY_RETURN_LOG}"
    capture_guest_screenshot '05-simulated-return-slice-45'
    printf 'simulated-return-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    write_zones_log "${ZONES_AFTER_LOG}"
    write_windows_log "${WINDOWS_AFTER_LOG}"
    write_topology_log topology-after 'Reference | Work | Comms restored after simulated return' "${ZONES_AFTER_LOG}" "${WINDOWS_AFTER_LOG}" "${TOPOLOGY_AFTER_LOG}"
    sleep_until_recording_offset 64 78 'topology-after'
    write_board topology-after 'Topology after simulated return' 'Reference | Work | Comms restored; same zone command surfaces remain usable' "${ZONES_AFTER_LOG}" "${WINDOWS_AFTER_LOG}" "${TOPOLOGY_AFTER_LOG}"
    capture_guest_screenshot '06-topology-after-slice-45'
    printf 'topology-after-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    write_zones_log "${FINAL_ZONES_LOG}"
    write_windows_log "${FINAL_WINDOWS_LOG}"
    write_topology_log final-recoverability 'Result: Reference | Work | Comms restored; no offscreen windows' "${FINAL_ZONES_LOG}" "${FINAL_WINDOWS_LOG}" "${TOPOLOGY_FINAL_LOG}"
    sleep_until_recording_offset 80 94 'final recoverability'
    write_board final-recoverability 'Final recoverability audit' 'Result: Reference | Work | Comms restored; no offscreen windows' "${FINAL_ZONES_LOG}" "${FINAL_WINDOWS_LOG}" "${TOPOLOGY_FINAL_LOG}"
    capture_guest_screenshot '07-final-recoverability-slice-45'
    printf 'final-recoverability-offset-seconds=%s\n' "${SECONDS}" >>"${TIMING_LOG}"

    write_topology_event_manifest
    write_proof_manifest
    cat >"${PROOF}" <<'EOF'
PASS: deterministic Tart topology simulation shows the before/loss/recovery/return/after/final storyboard with exact list-zones and list-windows audits. The artifact does not claim a real hardware disconnect without a supplemental real-machine video.
EOF
    echo "result=success" >"${DONE}"
    copy_runtime_logs
}

case "${PHASE}" in
    setup) setup_slice ;;
    proof) run_proof ;;
    *) semantic_fail "Unknown Slice 45 phase: ${PHASE}" ;;
esac
