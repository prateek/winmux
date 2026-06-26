#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE11A_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice11a-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice11a-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice11a"
LAUNCH_PLIST="/tmp/winmux-e2e-slice11a.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice11a.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11a-width-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-11a-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11a-windows-before.log"
WINDOW_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-11a-windows-resized.log"
WINDOW_BALANCED_LOG="${ARTIFACTS_DIR}/logs/slice-11a-windows-balanced.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-11a-zones-before.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-11a-zones-resized.log"
ZONES_BALANCED_LOG="${ARTIFACTS_DIR}/logs/slice-11a-zones-balanced.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-11a-resize-zone.log"
BALANCE_LOG="${ARTIFACTS_DIR}/logs/slice-11a-balance-zones.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-11a-command-timing.log"
GEOMETRY_BOARD_LOG="${ARTIFACTS_DIR}/logs/slice-11a-visible-geometry-board.txt"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-11a-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-11a-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-11a-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/slice-11a-zone-width-controls.done"
PROOF="${ARTIFACTS_DIR}/slice-11a-zone-width-controls-proof.txt"

DOC_DIR="${HOME}/winmux-e2e/zone-width-docs"
REFERENCE_DOC="${DOC_DIR}/reference-width.rtf"
WORK_DOC="${DOC_DIR}/work-width.rtf"
COMMS_DOC="${DOC_DIR}/comms-width.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

write_zone_geometry_doc() {
    local path="$1"
    local title="$2"
    local zone_id="$3"
    local workspace="$4"
    local before_configured="$5"
    local before_effective="$6"
    local before_runtime="$7"
    local before_override_state="$8"
    local before_left="$9"
    local before_width="${10}"
    local resized_configured="${11}"
    local resized_effective="${12}"
    local resized_runtime="${13}"
    local resized_override_state="${14}"
    local resized_left="${15}"
    local resized_width="${16}"
    local balanced_configured="${17}"
    local balanced_effective="${18}"
    local balanced_runtime="${19}"
    local balanced_override_state="${20}"
    local balanced_left="${21}"
    local balanced_width="${22}"

    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs74\b ${title}\b0\par\f1\fs30 zone-id: ${zone_id}\par enabled: true\par active-workspace: ${workspace}\par\par BEFORE\par configured-width: ${before_configured}\par effective-width: ${before_effective}\par runtime-width: ${before_runtime}\par override-state: ${before_override_state}\par left-edge: ${before_left}px\par pixel-width: ${before_width}px\par\par AFTER RESIZE\par configured-width: ${resized_configured}\par effective-width: ${resized_effective}\par runtime-width: ${resized_runtime}\par override-state: ${resized_override_state}\par left-edge: ${resized_left}px\par pixel-width: ${resized_width}px\par\par AFTER BALANCE\par configured-width: ${balanced_configured}\par effective-width: ${balanced_effective}\par runtime-width: ${balanced_runtime}\par override-state: ${balanced_override_state}\par left-edge: ${balanced_left}px\par pixel-width: ${balanced_width}px\par}
RTF
}

write_visible_geometry_board() {
    write_zone_geometry_doc \
        "${REFERENCE_DOC}" "Reference" "left" "1" \
        "0.25" "0.25" "none" "configured" "64.0" "844.0" \
        "0.25" "0.20" "0.20" "runtime" "64.0" "675.2" \
        "0.25" "0.333" "0.333" "runtime" "64.0" "1125.3"
    write_zone_geometry_doc \
        "${WORK_DOC}" "Work" "main" "2" \
        "0.50" "0.50" "none" "configured" "908.0" "1688.0" \
        "0.50" "0.60" "0.60" "runtime" "739.2" "2025.6" \
        "0.50" "0.333" "0.333" "runtime" "1189.3" "1125.3"
    write_zone_geometry_doc \
        "${COMMS_DOC}" "Comms" "right" "3" \
        "0.25" "0.25" "none" "configured" "2596.0" "844.0" \
        "0.25" "0.20" "0.20" "runtime" "2764.8" "675.2" \
        "0.25" "0.333" "0.333" "runtime" "2314.7" "1125.3"

    cat >"${GEOMETRY_BOARD_LOG}" <<'EOF'
visible-geometry-board=TextEdit zone documents
required-fields=zone-id,enabled,configured-width,effective-width,runtime-width,override-state,left-edge,pixel-width,active-workspace
zone-id=left|enabled=true|active-workspace=1|before configured-width=0.25 effective-width=0.25 runtime-width=none override-state=configured left-edge=64.0px pixel-width=844.0px|resize configured-width=0.25 effective-width=0.20 runtime-width=0.20 override-state=runtime left-edge=64.0px pixel-width=675.2px|balance configured-width=0.25 effective-width=0.333 runtime-width=0.333 override-state=runtime left-edge=64.0px pixel-width=1125.3px
zone-id=main|enabled=true|active-workspace=2|before configured-width=0.50 effective-width=0.50 runtime-width=none override-state=configured left-edge=908.0px pixel-width=1688.0px|resize configured-width=0.50 effective-width=0.60 runtime-width=0.60 override-state=runtime left-edge=739.2px pixel-width=2025.6px|balance configured-width=0.50 effective-width=0.333 runtime-width=0.333 override-state=runtime left-edge=1189.3px pixel-width=1125.3px
zone-id=right|enabled=true|active-workspace=3|before configured-width=0.25 effective-width=0.25 runtime-width=none override-state=configured left-edge=2596.0px pixel-width=844.0px|resize configured-width=0.25 effective-width=0.20 runtime-width=0.20 override-state=runtime left-edge=2764.8px pixel-width=675.2px|balance configured-width=0.25 effective-width=0.333 runtime-width=0.333 override-state=runtime left-edge=2314.7px pixel-width=1125.3px
EOF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x "${ARTIFACTS_DIR}/screenshots/${name}.png"
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

zone_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title {
        sub(/^zone=/, "", $3)
        print $3
        exit
    }' "${path}"
}

workspace_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title {
        sub(/^workspace=/, "", $4)
        print $4
        exit
    }' "${path}"
}

window_id_for_title() {
    local path="$1"
    local title="$2"
    /usr/bin/awk -F'|' -v title="${title}" '$2 == title { print $1; exit }' "${path}"
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(zone_for_title "${path}" "${title}")"
    if [ "${actual_zone}" != "${expected_zone}" ]; then
        echo "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}" >&2
        cat "${path}" >&2 || true
        exit 1
    fi
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || {
            echo "${message}: expected ${left} > ${right}" >&2
            exit 1
        }
}

assert_float_lt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="${left}" -v right="${right}" 'BEGIN { exit(left < right ? 0 : 1) }' \
        || {
            echo "${message}: expected ${left} < ${right}" >&2
            exit 1
        }
}

assert_widths_approximately_equal() {
    local left_width="$1"
    local main_width="$2"
    local right_width="$3"
    /usr/bin/awk -v left="${left_width}" -v main="${main_width}" -v right="${right_width}" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - main) <= 2 && abs(main - right) <= 2 ? 0 : 1) }
    ' || {
        echo "Expected balanced widths, got left=${left_width} main=${main_width} right=${right_width}" >&2
        exit 1
    }
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-11a-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${WINDOW_RESIZED_LOG}" "${WINDOW_BALANCED_LOG}" "${ZONES_BEFORE_LOG}" \
        "${ZONES_RESIZED_LOG}" "${ZONES_BALANCED_LOG}" "${RESIZE_LOG}" \
        "${BALANCE_LOG}" "${TIMING_LOG}" "${GEOMETRY_BOARD_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 11A: runtime zone width controls'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: resize-zone Work width +10%, balance-zones, cycle-zone-layout balanced focus'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_visible_geometry_board

    launch_winmux
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 || {
        echo 'TextEdit windows did not appear' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        exit 1
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-width.rtf')"
    work_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'work-width.rtf')"
    comms_id="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-width.rtf')"
    test -n "${reference_id}"
    test -n "${work_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'reference-width.rtf' Reference left
    move_window_to_zone "${work_id}" 'work-width.rtf' Work main
    move_window_to_zone "${comms_id}" 'comms-width.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-width.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'work-width.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-width.rtf' right

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
    capture_guest_screenshot '02-before-resize-slice-11a'
    sleep 14

    echo "resize-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_RESIZED_LOG}"
    write_zones_log "${ZONES_RESIZED_LOG}" >/dev/null
    capture_guest_screenshot '03-after-resize-slice-11a'
    sleep 8
    capture_guest_screenshot '04-before-balance-slice-11a'
    sleep 7

    echo "balance-command-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux balance-zones'
        "${CLI}" balance-zones
    } | tee "${BALANCE_LOG}"
    sleep 3
    refresh_window_log "${WINDOW_BALANCED_LOG}"
    write_zones_log "${ZONES_BALANCED_LOG}" >/dev/null
    capture_guest_screenshot '05-after-balance-slice-11a'
    sleep 8

    local before_left before_main before_right
    local resized_left resized_main resized_right
    local balanced_left balanced_main balanced_right
    before_left="$(zone_field "${ZONES_BEFORE_LOG}" left width)"
    before_main="$(zone_field "${ZONES_BEFORE_LOG}" main width)"
    before_right="$(zone_field "${ZONES_BEFORE_LOG}" right width)"
    resized_left="$(zone_field "${ZONES_RESIZED_LOG}" left width)"
    resized_main="$(zone_field "${ZONES_RESIZED_LOG}" main width)"
    resized_right="$(zone_field "${ZONES_RESIZED_LOG}" right width)"
    balanced_left="$(zone_field "${ZONES_BALANCED_LOG}" left width)"
    balanced_main="$(zone_field "${ZONES_BALANCED_LOG}" main width)"
    balanced_right="$(zone_field "${ZONES_BALANCED_LOG}" right width)"

    assert_float_gt "${resized_main}" "${before_main}" 'Work/main width did not grow after resize-zone'
    assert_float_lt "${resized_left}" "${before_left}" 'Reference/left width did not shrink after resize-zone'
    assert_float_lt "${resized_right}" "${before_right}" 'Comms/right width did not shrink after resize-zone'
    assert_widths_approximately_equal "${balanced_left}" "${balanced_main}" "${balanced_right}"

    assert_window_zone "${WINDOW_RESIZED_LOG}" 'reference-width.rtf' left
    assert_window_zone "${WINDOW_RESIZED_LOG}" 'work-width.rtf' main
    assert_window_zone "${WINDOW_RESIZED_LOG}" 'comms-width.rtf' right
    assert_window_zone "${WINDOW_BALANCED_LOG}" 'reference-width.rtf' left
    assert_window_zone "${WINDOW_BALANCED_LOG}" 'work-width.rtf' main
    assert_window_zone "${WINDOW_BALANCED_LOG}" 'comms-width.rtf' right

    cat \
        "${WINDOW_BEFORE_LOG}" "${RESIZE_LOG}" "${WINDOW_RESIZED_LOG}" \
        "${BALANCE_LOG}" "${WINDOW_BALANCED_LOG}" "${ZONES_BALANCED_LOG}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 11A: runtime zone width controls'
        echo
        echo 'Commands:'
        cat "${RESIZE_LOG}"
        cat "${BALANCE_LOG}"
        echo
        echo 'Before geometry:'
        cat "${ZONES_BEFORE_LOG}"
        echo
        echo 'After resize geometry:'
        cat "${ZONES_RESIZED_LOG}"
        echo
        echo 'After balance geometry:'
        cat "${ZONES_BALANCED_LOG}"
        echo
        echo 'Visible geometry board:'
        cat "${GEOMETRY_BOARD_LOG}"
        echo
        echo "widths-before=left:${before_left},main:${before_main},right:${before_right}"
        echo "widths-resized=left:${resized_left},main:${resized_main},right:${resized_right}"
        echo "widths-balanced=left:${balanced_left},main:${balanced_main},right:${balanced_right}"
        cat "${TIMING_LOG}"
        echo "work-window-id=${WORK_ID}"
        echo "work-workspace=$(workspace_for_title "${WINDOW_BALANCED_LOG}" 'work-width.rtf')"
        echo
        echo 'PASS: resize-zone Work width +10% changes runtime zone widths; balance-zones returns enabled zones to equal widths while preserving windows and workspaces.'
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
    copy_runtime_logs
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    *)
        echo "Unknown Slice 11A phase: ${PHASE}" >&2
        exit 2
        ;;
esac
