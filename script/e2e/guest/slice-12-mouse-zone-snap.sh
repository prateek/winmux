#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_MOUSE_SNAP_PHASE:-${WINMUX_E2E_SLICE12_PHASE:-proof}}"
SLICE_PREFIX="${WINMUX_E2E_MOUSE_SNAP_SLICE_PREFIX:-slice-12}"
SLICE_NUMBER="${SLICE_PREFIX#slice-}"
SLICE_TITLE="${WINMUX_E2E_MOUSE_SNAP_TITLE:-WinMux Slice ${SLICE_NUMBER}: desktop mouse zone snap policy}"
RECORDING_NAME="${WINMUX_E2E_RECORDING_NAME:-${SLICE_PREFIX}-mouse-zone-snap-drag}"
CONFIG_MODIFIER="${WINMUX_E2E_MOUSE_SNAP_CONFIG_MODIFIER:-alt}"
CONFIG_POLICY="${WINMUX_E2E_MOUSE_SNAP_CONFIG_POLICY:-snap-on-modifier}"
CONFIG_GESTURE="${WINMUX_E2E_MOUSE_SNAP_CONFIG_GESTURE:-drag}"
CONFIG_TARGET="${WINMUX_E2E_MOUSE_SNAP_CONFIG_TARGET:-zone}"
PROOF_MODE="${WINMUX_E2E_MOUSE_SNAP_PROOF_MODE:-modifier}"
PRODUCT_OVERLAY_LABEL="${WINMUX_E2E_MOUSE_SNAP_PRODUCT_OVERLAY_LABEL:-}"
SLOT_NOOP_LABEL="${WINMUX_E2E_MOUSE_SNAP_SLOT_NOOP_LABEL:-}"
RUNTIME_SET_POLICY="${WINMUX_E2E_MOUSE_SNAP_RUNTIME_SET_POLICY:-snap-to-zone}"
RUNTIME_CYCLE_POLICIES="${WINMUX_E2E_MOUSE_SNAP_RUNTIME_CYCLE_POLICIES:-freeform snap-to-zone}"
SNAP_TARGET_PROFILE=whole-zone
if [ "${PROOF_MODE}" = "window-slot" ]; then
    SNAP_TARGET_PROFILE=window-slot
fi
if [ "${SLICE_PREFIX}" = "slice-16" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Option}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold Option while dragging: snap to Comms zone}"
elif [ "${PROOF_MODE}" = "runtime-policy" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Alt}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Run: winmux set-zone-snap-policy snap-to-zone}"
elif [ "${PROOF_MODE}" = "float-unless-snap" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Alt}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold Alt while dragging snap-demo.rtf}"
elif [ "${PROOF_MODE}" = "secondary-button" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-secondary button}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold secondary button while dragging snap-demo.rtf}"
elif [ "${PROOF_MODE}" = "window-slot" ]; then
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-secondary button}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold secondary button while dragging snap-demo.rtf}"
else
    USER_MODIFIER_LABEL="${WINMUX_E2E_MOUSE_SNAP_MODIFIER_LABEL:-Alt}"
    MODIFIER_CAPTION_CHIP="${WINMUX_E2E_MOUSE_SNAP_CAPTION_CHIP:-Action: hold Alt while dragging snap-demo.rtf}"
fi
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-${SLICE_PREFIX}-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.${SLICE_PREFIX}"
LAUNCH_PLIST="/tmp/winmux-e2e-${SLICE_PREFIX}.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-${SLICE_PREFIX}.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap-setup.log"
ACTION_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap-action.log"
SET_POLICY_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-set-zone-snap-policy.log"
CYCLE_POLICY_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cycle-zone-snap-policy.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-before.log"
WINDOW_FREEFORM_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-freeform.log"
WINDOW_RESET_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-reset.log"
WINDOW_AFTER_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-windows-after-snap.log"
ZONES_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zones.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-command-timing.log"
MOUSE_EVENTS_LOG="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.mouse-events.tsv"
CLI_LOG="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-window-ids.env"
ACTION_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
DONE="${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-mouse-zone-snap.done"
PROOF="${ARTIFACTS_DIR}/${SLICE_PREFIX}-mouse-zone-snap-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

FREEFORM_PICKUP_NAME="02-freeform-pickup-${SLICE_PREFIX}.png"
FREEFORM_HOVER_NAME="03-freeform-hover-no-overlay-${SLICE_PREFIX}.png"
RESET_NAME="04-reset-before-snap-${SLICE_PREFIX}.png"
SNAP_PICKUP_NAME="05-snap-pickup-${SLICE_PREFIX}.png"
SNAP_PATH_NAME="06-snap-path-${SLICE_PREFIX}.png"
SNAP_HOVER_NAME="07-snap-hover-comms-${SLICE_PREFIX}.png"
SNAP_RELEASE_NAME=""

configure_profile_screenshot_names() {
    case "$SNAP_TARGET_PROFILE" in
        whole-zone)
            SNAP_RELEASE_NAME="08-snap-release-${SLICE_PREFIX}.png"
            ;;
        window-slot)
            FREEFORM_PICKUP_NAME="02-ordinary-pickup-${SLICE_PREFIX}.png"
            FREEFORM_HOVER_NAME="03-ordinary-hover-no-overlay-${SLICE_PREFIX}.png"
            RESET_NAME="04-reset-before-window-slot-${SLICE_PREFIX}.png"
            SNAP_PICKUP_NAME="05-slot-pickup-${SLICE_PREFIX}.png"
            SNAP_PATH_NAME="06-slot-path-${SLICE_PREFIX}.png"
            SNAP_HOVER_NAME="07-slot-hover-right-${SLICE_PREFIX}.png"
            SNAP_RELEASE_NAME="08-slot-release-${SLICE_PREFIX}.png"
            ;;
        *)
            echo "Unsupported mouse snap target profile: ${SNAP_TARGET_PROFILE}" >&2
            exit "${SEMANTIC_FAILURE_EXIT:-86}"
            ;;
    esac
}

configure_profile_screenshot_names

FREEFORM_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/${FREEFORM_PICKUP_NAME}"
FREEFORM_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/${FREEFORM_HOVER_NAME}"
RESET_SCREENSHOT="${SCREENSHOTS_DIR}/${RESET_NAME}"
SNAP_PICKUP_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_PICKUP_NAME}"
SNAP_PATH_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_PATH_NAME}"
SNAP_HOVER_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_HOVER_NAME}"
SNAP_RELEASE_SCREENSHOT=""
if [ -n "${SNAP_RELEASE_NAME}" ]; then
    SNAP_RELEASE_SCREENSHOT="${SCREENSHOTS_DIR}/${SNAP_RELEASE_NAME}"
fi

DOC_DIR="${HOME}/winmux-e2e/${SLICE_PREFIX}-mouse-zone-snap-docs"
REFERENCE_DOC="${DOC_DIR}/reference-mouse-snap.rtf"
SNAP_DOC="${DOC_DIR}/snap-demo.rtf"
TARGET_DOC="${DOC_DIR}/target-window.rtf"
COMMS_DOC="${DOC_DIR}/comms-mouse-snap.rtf"

uid="$(/usr/bin/id -u)"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

artifact_relative_path() {
    local path="$1"
    case "$path" in
        "${ARTIFACTS_DIR}/"*) printf '%s\n' "${path#"${ARTIFACTS_DIR}/"}" ;;
        *) printf '%s\n' "$path" ;;
    esac
}

init_mouse_events_log() {
    : >"${MOUSE_EVENTS_LOG}"
    printf '# event-id\tkind\toffset-seconds\tnote\n' >>"${MOUSE_EVENTS_LOG}"
}

append_mouse_event() {
    local event_id="$1"
    local kind="$2"
    local scenario_start_ms="$3"
    local note="$4"
    local now_ms
    now_ms="$(/bin/date +%s)000"
    awk -v event_id="$event_id" -v kind="$kind" -v start="$scenario_start_ms" -v now="$now_ms" -v note="$note" 'BEGIN {
        printf "%s\t%s\t%.3f\t%s\n", event_id, kind, (now - start) / 1000, note
    }' >>"${MOUSE_EVENTS_LOG}"
}

reset_action_schema() {
    : >"${ACTION_LOG}"
    : >"${ACTION_MANIFEST}"
}

append_action_log_value() {
    local key="$1"
    local value="$2"
    printf '%s=%s\n' "$key" "$value" >>"${ACTION_LOG}"
}

append_action_schema_value() {
    local kind="$1"
    local key="$2"
    local value="$3"
    local log_key="${4:-}"
    printf '%s\t%s\t%s\n' "$kind" "$key" "$value" >>"${ACTION_MANIFEST}"
    if [ -n "$log_key" ]; then
        append_action_log_value "$log_key" "$value"
    fi
}

write_doc() {
    local path="$1"
    local title="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs82\b ${title}\b0\par\f1\fs34 zone: ${zone_name}\par ${detail}\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

write_zones_log() {
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|top=%{monitor-top}|width=%{monitor-width}|height=%{monitor-height}|physical=%{monitor-physical-id}' \
        >"${ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${ZONES_LOG}"
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

zone_field() {
    local zone_id="$1"
    local key="$2"
    /usr/bin/awk -F'|' -v zone="zone=${zone_id}" -v key="${key}" '$1 == zone {
        for (i = 1; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "${ZONES_LOG}"
}

zone_for_title() {
    field_for_title "$1" "$2" zone
}

workspace_for_title() {
    field_for_title "$1" "$2" workspace
}

layout_for_title() {
    field_for_title "$1" "$2" layout
}

window_id_for_title() {
    field_for_title "$1" "$2" id
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

profile_requires_target_window() {
    [ "${SNAP_TARGET_PROFILE}" = "window-slot" ]
}

proof_uses_secondary_button() {
    [ "${PROOF_MODE}" = "secondary-button" ] || [ "${PROOF_MODE}" = "window-slot" ]
}

derive_whole_zone_drag_geometry() {
    main_left="$(zone_field main left)"
    main_top="$(zone_field main top)"
    main_width="$(zone_field main width)"
    right_left="$(zone_field right left)"
    right_top="$(zone_field right top)"
    right_width="$(zone_field right width)"
    right_height="$(zone_field right height)"
    source_x="$(awk_int "${main_left} + (${main_width} * 0.50)")"
    source_y="$(awk_int "${main_top} + 32")"
    target_x="$(awk_int "${right_left} + (${right_width} * 0.50)")"
    target_y="$(awk_int "${right_top} + (${right_height} * 0.38)")"
    target_title='Comms zone'
    target_window_id=''
    target_slot=''
}

derive_window_slot_drag_geometry() {
    local window_log="$1"
    local snap_left snap_top snap_width target_left target_top target_width target_height
    snap_left="$(window_rect_field_for_title "${window_log}" 'snap-demo.rtf' left)"
    snap_top="$(window_rect_field_for_title "${window_log}" 'snap-demo.rtf' top)"
    snap_width="$(window_rect_field_for_title "${window_log}" 'snap-demo.rtf' width)"
    target_left="$(window_rect_field_for_title "${window_log}" 'target-window.rtf' left)"
    target_top="$(window_rect_field_for_title "${window_log}" 'target-window.rtf' top)"
    target_width="$(window_rect_field_for_title "${window_log}" 'target-window.rtf' width)"
    target_height="$(window_rect_field_for_title "${window_log}" 'target-window.rtf' height)"
    [ -n "${snap_left}" ] && [ -n "${snap_top}" ] && [ -n "${snap_width}" ] \
        || semantic_fail "Missing source window geometry for window-slot proof in ${window_log}"
    [ -n "${target_left}" ] && [ -n "${target_top}" ] && [ -n "${target_width}" ] && [ -n "${target_height}" ] \
        || semantic_fail "Missing target window geometry for window-slot proof in ${window_log}"
    source_x="$(awk_int "${snap_left} + (${snap_width} * 0.50)")"
    source_y="$(awk_int "${snap_top} + 32")"
    target_x="$(awk_int "${target_left} + (${target_width} * 0.88)")"
    target_y="$(awk_int "${target_top} + (${target_height} * 0.50)")"
    target_title='target-window.rtf'
    target_window_id="${TARGET_ID}"
    target_slot='right'
}

derive_positive_drag_geometry() {
    local window_log="$1"
    case "$SNAP_TARGET_PROFILE" in
        whole-zone)
            derive_whole_zone_drag_geometry
            ;;
        window-slot)
            derive_window_slot_drag_geometry "$window_log"
            ;;
        *)
            semantic_fail "Unsupported mouse snap target profile: ${SNAP_TARGET_PROFILE}"
            ;;
    esac
}

configure_whole_zone_proof_fields() {
    positive_drag_with_alt=1
    positive_drag_input='alt'
    positive_proof_key='alt-held-whole-zone-snap'
    positive_action_text="positive-proof=hold ${USER_MODIFIER_LABEL} while dragging previews the whole Comms zone and snaps on release"
    negative_action_text="negative-proof=drag without ${USER_MODIFIER_LABEL} does not show snap overlay or change zone binding"
    negative_policy_key='no-alt-no-zone-move'
    freeform_expected_zone=main
    freeform_expected_layout=''
    freeform_result='no-zone-move'
    snap_expected_zone=right
    snap_expected_workspace_relation=different
    snap_target_kind=whole-zone
    snap_not_target_kind=window-within-zone
    target_zone_id=right
    target_zone_name=Comms
    coordinate_policy='derived-from-list-zones: source titlebar point is centered in Work/main; target point is centered inside Comms/right'
    mapping_assertion="freeform keeps snap-demo in Work/main; ${USER_MODIFIER_LABEL}-held drag moves the same id to Comms/right"
    visual_floor='source window, dragged proxy/path, whole-zone Comms highlight/overlay, release, final placement, and freeform no-overlay negative proof'

    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        positive_drag_with_alt=0
        positive_drag_input='none'
        positive_proof_key='runtime-set-snap-to-zone'
        positive_action_text='positive-proof=runtime set-zone-snap-policy enables whole-zone snap without a held modifier'
        mapping_assertion='freeform keeps snap-demo in Work/main; runtime snap-to-zone moves the same id to Comms/right without a held modifier'
    elif [ "${PROOF_MODE}" = "secondary-button" ]; then
        positive_drag_with_alt=0
        positive_drag_input='secondary-button'
        positive_proof_key='secondary-button-whole-zone-snap'
        positive_action_text='positive-proof=hold secondary mouse button while dragging previews the whole Comms zone and snaps on release'
        negative_action_text='negative-proof=ordinary drag without secondary button detaches the tiled window into floating/freeform placement without a snap overlay'
        negative_policy_key='no-secondary-button-floats-no-snap'
        freeform_expected_zone=right
        freeform_expected_layout='floating'
        freeform_result='floating-no-snap'
        mapping_assertion='ordinary drag floats snap-demo into Comms/right without a snap overlay; secondary-button drag moves the same id as a whole-zone snap'
    elif [ "${PROOF_MODE}" = "float-unless-snap" ]; then
        negative_action_text="negative-proof=drag without ${USER_MODIFIER_LABEL} detaches the tiled window into floating/freeform placement without a snap overlay"
        negative_policy_key='no-alt-floats-no-snap'
        freeform_expected_zone=right
        freeform_expected_layout='floating'
        freeform_result='floating-no-snap'
        mapping_assertion="no-${USER_MODIFIER_LABEL} drag floats snap-demo into Comms/right without a snap overlay; ${USER_MODIFIER_LABEL}-held drag moves the same id as a whole-zone snap"
    fi
}

configure_window_slot_proof_fields() {
    positive_drag_with_alt=0
    positive_drag_input='secondary-button'
    positive_proof_key='secondary-button-window-slot-snap'
    positive_action_text='positive-proof=hold secondary mouse button while dragging over target-window.rtf right slot; release splits that target window instead of moving to a whole zone'
    negative_action_text='negative-proof=ordinary drag inside Work/main stays floating/freeform with no slot overlay'
    negative_policy_key='no-secondary-button-floats-no-slot'
    freeform_expected_zone=main
    freeform_expected_layout='floating'
    freeform_result='floating-no-snap'
    snap_expected_zone=main
    snap_expected_workspace_relation=same
    snap_target_kind=window-slot
    snap_not_target_kind=whole-zone
    target_zone_id=main
    target_zone_name=Work
    coordinate_policy='derived-from-list-windows: source titlebar point comes from snap-demo.rtf frame; target point is the right slot of target-window.rtf in Work/main'
    mapping_assertion='ordinary drag inside Work/main floats with no slot overlay; secondary-button drag over target-window.rtf right slot splits that window and keeps the same source id in Work/main'
    visual_floor='source window, target window, dragged proxy/path, window-slot right overlay, release, final split placement, and ordinary no-overlay negative proof'
}

configure_proof_manifest_profile() {
    case "$SNAP_TARGET_PROFILE" in
        whole-zone)
            configure_whole_zone_proof_fields
            ;;
        window-slot)
            configure_window_slot_proof_fields
            ;;
        *)
            semantic_fail "Unsupported mouse snap target profile: ${SNAP_TARGET_PROFILE}"
            ;;
    esac
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/${SLICE_PREFIX}-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${DONE}" "${SETUP_LOG}" "${ACTION_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${SET_POLICY_LOG}" "${CYCLE_POLICY_LOG}" \
        "${WINDOW_FREEFORM_LOG}" "${WINDOW_RESET_LOG}" "${WINDOW_AFTER_LOG}" "${ZONES_LOG}" \
        "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" "${STATE_FILE}" "${ACTION_MANIFEST}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" \
        "${FREEFORM_PICKUP_SCREENSHOT}" "${FREEFORM_HOVER_SCREENSHOT}" "${RESET_SCREENSHOT}" \
        "${SNAP_PICKUP_SCREENSHOT}" "${SNAP_PATH_SCREENSHOT}" "${SNAP_HOVER_SCREENSHOT}"
    if [ -n "${SNAP_RELEASE_SCREENSHOT}" ]; then
        rm -f "${SNAP_RELEASE_SCREENSHOT}"
    fi
    rm -rf "${DOC_DIR}"

    {
        echo "${SLICE_TITLE}"
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        if proof_uses_secondary_button; then
            echo "Config: [mouse.zone-snap] policy = '${CONFIG_POLICY}', configured-modifier = '${CONFIG_MODIFIER}', gesture = '${CONFIG_GESTURE}', activation-input = 'secondary-button', target = '${CONFIG_TARGET}'"
        else
            echo "Config: [mouse.zone-snap] policy = '${CONFIG_POLICY}', modifier = '${CONFIG_MODIFIER}', target = '${CONFIG_TARGET}'"
            echo "Config: [mouse.zone-snap] policy = '${CONFIG_POLICY}', modifier = '${CONFIG_MODIFIER}', gesture = '${CONFIG_GESTURE}', target = '${CONFIG_TARGET}'"
        fi
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo "Runtime command: set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            echo "Runtime toggle: cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
        fi
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}" "${SCREENSHOTS_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_doc "${REFERENCE_DOC}" 'REFERENCE' 'Reference' 'Desktop drag snap proof baseline'
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag once in freeform, run set-zone-snap-policy, then drag again with no modifier"
    elif [ "${PROOF_MODE}" = "secondary-button" ]; then
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag without secondary button to float, reset, then hold secondary button to snap"
    elif [ "${PROOF_MODE}" = "window-slot" ]; then
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag without secondary button to float inside Work, reset, then hold secondary button and drop on the target window right slot"
    elif [ "${PROOF_MODE}" = "float-unless-snap" ]; then
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag without ${USER_MODIFIER_LABEL} to float, reset, then hold ${USER_MODIFIER_LABEL} to snap"
    else
        write_doc "${SNAP_DOC}" 'SNAP DEMO' 'Work' "Drag this window without ${USER_MODIFIER_LABEL}, then with ${USER_MODIFIER_LABEL}"
    fi
    if profile_requires_target_window; then
        write_doc "${TARGET_DOC}" 'TARGET WINDOW' 'Work' 'Drop on this window right slot; whole-zone fallback must stay inactive'
    fi
    write_doc "${COMMS_DOC}" 'COMMS' 'Comms' 'Whole-zone snap target'

    launch_winmux
    write_zones_log
    grep -F 'zone=left|name=Reference|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=main|name=Work|' "${ZONES_LOG}" >/dev/null
    grep -F 'zone=right|name=Comms|' "${ZONES_LOG}" >/dev/null

    /usr/bin/open -a TextEdit "${REFERENCE_DOC}"
    sleep 1
    /usr/bin/open -a TextEdit "${SNAP_DOC}"
    sleep 1
    if profile_requires_target_window; then
        /usr/bin/open -a TextEdit "${TARGET_DOC}"
        sleep 1
    fi
    /usr/bin/open -a TextEdit "${COMMS_DOC}"

    expected_textedit_count=3
    if profile_requires_target_window; then
        expected_textedit_count=4
    fi
    if ! wait_for_textedit_windows "${expected_textedit_count}"; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        cat "${WAIT_ERR}" >&2 || true
        semantic_fail 'TextEdit windows did not become visible to WinMux'
    fi

    REFERENCE_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'reference-mouse-snap.rtf')"
    SNAP_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'snap-demo.rtf')"
    TARGET_ID=""
    if profile_requires_target_window; then
        TARGET_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'target-window.rtf')"
    fi
    COMMS_ID="$(window_id_for_title "${WINDOW_SETUP_LOG}" 'comms-mouse-snap.rtf')"

    if [ -z "${REFERENCE_ID}" ] || [ -z "${SNAP_ID}" ] || [ -z "${COMMS_ID}" ] || { profile_requires_target_window && [ -z "${TARGET_ID}" ]; }; then
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        semantic_fail 'Could not resolve all TextEdit window ids'
    fi

    move_window_to_zone "${REFERENCE_ID}" 'reference-mouse-snap.rtf' Reference left
    move_window_to_zone "${SNAP_ID}" 'snap-demo.rtf' Work main
    if profile_requires_target_window; then
        move_window_to_zone "${TARGET_ID}" 'target-window.rtf' Work main
    fi
    move_window_to_zone "${COMMS_ID}" 'comms-mouse-snap.rtf' Comms right
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'reference-mouse-snap.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf' main
    if profile_requires_target_window; then
        assert_window_zone "${WINDOW_BEFORE_LOG}" 'target-window.rtf' main
    fi
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'comms-mouse-snap.rtf' right

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${REFERENCE_ID}
SNAP_ID=${SNAP_ID}
TARGET_ID=${TARGET_ID}
COMMS_ID=${COMMS_ID}
STATE

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${SNAP_ID}"
    sleep 1
    {
        echo 'setup=result=success'
        echo "snap-window-id=${SNAP_ID}"
        echo 'ready-state=desktop-window-focused'
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

awk_int() {
    awk "BEGIN { printf \"%d\", $* }"
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
    local event_branch="$9"
    local scenario_start_ms="${10}"
    local activation_input="${11:-}"
    local release_path="${12:-}"
    if [ -z "${activation_input}" ]; then
        if [ "${with_alt}" = "1" ]; then
            activation_input=alt
        else
            activation_input=none
        fi
    fi
    /usr/bin/osascript -l JavaScript <<JXA
ObjC.import('ApplicationServices')

const app = Application.currentApplication()
app.includeStandardAdditions = true
const eventBranch = '${event_branch}'
const scenarioStartMs = Number('${scenario_start_ms}')
const mouseEventsLog = '${MOUSE_EVENTS_LOG}'
const activationInput = '${activation_input}'
const releasePath = '${release_path}'

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function postMouse(type, x, y, button, withAlt) {
  const event = $.CGEventCreateMouseEvent(null, type, $.CGPointMake(Number(x), Number(y)), button)
  if (withAlt) {
    $.CGEventSetFlags(event, $.kCGEventFlagMaskAlternate)
  }
  $.CGEventPost($.kCGHIDEventTap, event)
}

function postLeftMouse(type, x, y, withAlt) {
  postMouse(type, x, y, $.kCGMouseButtonLeft, withAlt)
}

function postSecondaryMouse(down, x, y) {
  postMouse(down ? $.kCGEventRightMouseDown : $.kCGEventRightMouseUp, x, y, $.kCGMouseButtonRight, false)
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

function offsetSeconds() {
  return ((Date.now() - scenarioStartMs) / 1000).toFixed(3)
}

function emit(eventId, kind, note) {
  const line = [eventId, kind, offsetSeconds(), note].join('\t')
  app.doShellScript("/usr/bin/printf '%s\\n' " + shellQuote(line) + " >> " + shellQuote(mouseEventsLog))
}

function emitPickupEvent() {
  if (eventBranch === 'float') {
    emit('float-drag-start', 'drag', 'ordinary pickup screenshot captured')
  } else if (eventBranch === 'snap') {
    if (activationInput === 'secondary-button') {
      emit('snap-drag-start', 'drag', 'secondary-button pickup screenshot captured')
    } else {
      emit('snap-drag-start', 'drag', 'Alt-held pickup screenshot captured')
    }
  } else {
    emit('freeform-drag-start', 'drag', 'no-modifier pickup screenshot captured')
  }
}

function emitSecondaryButtonDownEvent() {
  if (eventBranch === 'snap' && activationInput === 'secondary-button') {
    emit('snap-secondary-button-down', 'input-state', 'raw secondary mouse button down posted before snap drag')
  }
}

function emitSecondaryButtonHeldEvent() {
  if (eventBranch === 'snap' && activationInput === 'secondary-button') {
    emit('snap-secondary-button-held', 'input-state', 'secondary mouse button still held at target hover')
  }
}

function emitSecondaryButtonUpEvent() {
  if (eventBranch === 'snap' && activationInput === 'secondary-button') {
    emit('snap-secondary-button-up', 'input-state', 'raw secondary mouse button up posted after snap release')
  }
}

function emitHoverEvent() {
  if (eventBranch === 'snap') {
    emit('snap-first-affordance', 'overlay', 'snap target hover screenshot captured')
    emit('snap-drag-hover', 'overlay', 'snap target hover screenshot captured')
  } else if (eventBranch === 'float') {
    emit('float-drag-hover', 'drag', 'no-modifier hover screenshot captured')
  } else {
    emit('freeform-drag-hover', 'drag', 'no-modifier hover screenshot captured')
  }
}

function emitReleaseEvent() {
  if (eventBranch === 'snap') {
    if (releasePath !== '') {
      emit('snap-release', 'drag', 'release-boundary screenshot captured before mouse up')
    } else {
      emit('snap-release', 'drag', 'mouse released on target zone')
    }
  } else if (eventBranch === 'float') {
    emit('float-drag-release', 'drag', 'mouse released after float/freeform branch')
  } else {
    emit('freeform-drag-release', 'drag', 'mouse released after freeform branch')
  }
}

const sx = Number('${source_x}')
const sy = Number('${source_y}')
const tx = Number('${target_x}')
const ty = Number('${target_y}')
const useAlt = activationInput === 'alt' || '${with_alt}' === '1'
const useSecondaryButton = activationInput === 'secondary-button'
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
if (useSecondaryButton) {
  postSecondaryMouse(true, sx, sy)
  emitSecondaryButtonDownEvent()
  delay(0.35)
}
dragTo(sx, sy, pickupX, pickupY, 10, 0.06, useAlt)
capture('${pickup_path}')
emitPickupEvent()
dragTo(pickupX, pickupY, pathX, pathY, 34, 0.07, useAlt)
if ('${path_path}' !== '') {
  capture('${path_path}')
  if (eventBranch === 'snap') {
    emit('snap-drag-path', 'drag', 'path screenshot captured')
  }
}
dragTo(pathX, pathY, tx, ty, 28, 0.08, useAlt)
delay(1.5)
capture('${hover_path}')
emitSecondaryButtonHeldEvent()
emitHoverEvent()
delay(1.8)
if (eventBranch === 'snap' && releasePath !== '') {
  capture(releasePath)
  emitReleaseEvent()
  postLeftMouse($.kCGEventLeftMouseUp, tx, ty, useAlt)
} else {
  postLeftMouse($.kCGEventLeftMouseUp, tx, ty, useAlt)
  if (releasePath !== '') {
    capture(releasePath)
  }
  emitReleaseEvent()
}
if (useSecondaryButton) {
  delay(0.25)
  postSecondaryMouse(false, tx, ty)
  emitSecondaryButtonUpEvent()
}
if (useAlt) {
  delay(0.3)
  postOption(false)
}
JXA
}

reset_snap_window_to_work() {
    {
        echo "$ winmux layout --window-id ${SNAP_ID} tiling || true"
        "${CLI}" layout --window-id "${SNAP_ID}" tiling || true
        echo "$ winmux move-node-to-zone --window-id ${SNAP_ID} Work"
        "${CLI}" move-node-to-zone --window-id "${SNAP_ID}" Work || true
        if [ -n "${TARGET_ID:-}" ]; then
            echo "$ winmux layout --window-id ${TARGET_ID} tiling || true"
            "${CLI}" layout --window-id "${TARGET_ID}" tiling || true
            echo "$ winmux move-node-to-zone --window-id ${TARGET_ID} Work"
            "${CLI}" move-node-to-zone --window-id "${TARGET_ID}" Work || true
        fi
        echo "$ winmux focus-zone Work"
        "${CLI}" focus-zone Work
        echo "$ winmux focus --window-id ${SNAP_ID}"
        "${CLI}" focus --window-id "${SNAP_ID}"
    } | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null

    for _ in $(seq 1 20); do
        refresh_window_log "${WINDOW_RESET_LOG}"
        if [ "$(zone_for_title "${WINDOW_RESET_LOG}" 'snap-demo.rtf')" = main ]; then
            if [ -n "${TARGET_ID:-}" ] && [ "$(zone_for_title "${WINDOW_RESET_LOG}" 'target-window.rtf')" != main ]; then
                sleep 1
                continue
            fi
            return
        fi
        sleep 1
    done
    cat "${WINDOW_RESET_LOG}" >&2 || true
    semantic_fail 'Could not reset snap-demo.rtf to Work/main before modifier drag'
}

proof_slice() {
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${SNAP_ID:-}"

    write_zones_log
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf' main
    if profile_requires_target_window; then
        test -n "${TARGET_ID:-}"
        assert_window_zone "${WINDOW_BEFORE_LOG}" 'target-window.rtf' main
    fi
    before_workspace="$(workspace_for_title "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf')"
    before_id="$(window_id_for_title "${WINDOW_BEFORE_LOG}" 'snap-demo.rtf')"

    derive_positive_drag_geometry "${WINDOW_BEFORE_LOG}"
    configure_proof_manifest_profile

    reset_action_schema
    append_action_log_value action desktop-mouse-zone-snap
    append_action_log_value interaction-model desktop-window-drag
    append_action_log_value config '[mouse.zone-snap]'
    append_action_schema_value drag-policy policy "${CONFIG_POLICY}" policy
    if proof_uses_secondary_button; then
        append_action_schema_value drag-policy configured-modifier "${CONFIG_MODIFIER}" configured-modifier
        append_action_schema_value drag-policy activation-input secondary-button activation-input
    else
        append_action_schema_value drag-policy modifier "${CONFIG_MODIFIER}" modifier
    fi
    append_action_schema_value drag-policy gesture "${CONFIG_GESTURE}" gesture
    append_action_schema_value drag-policy target "${CONFIG_TARGET}" target
    append_action_schema_value drag-policy proof-mode "${PROOF_MODE}" proof-mode
    append_action_schema_value drag-source title 'snap-demo.rtf' source-title
    append_action_schema_value drag-source window-id "${before_id}" source-window-id
    append_action_schema_value drag-source before-zone main before-zone
    append_action_schema_value drag-source before-workspace "${before_workspace}" before-workspace
    append_action_schema_value drag-target zone-id "${target_zone_id}" target-zone
    append_action_schema_value drag-target zone-name "${target_zone_name}" target-zone-name
    append_action_schema_value drag-target snap-target "${snap_target_kind}" snap-target
    append_action_schema_value drag-target not-snap-target "${snap_not_target_kind}" not-snap-target
    if [ -n "${SLOT_NOOP_LABEL}" ]; then
        append_action_schema_value drag-target slot-noop "${SLOT_NOOP_LABEL}" slot-noop
    fi
    if profile_requires_target_window; then
        append_action_schema_value drag-target window-title "${target_title}" target-window-title
        append_action_schema_value drag-target window-id "${target_window_id}" target-window-id
        append_action_schema_value drag-target window-slot "${target_slot}" target-window-slot
    fi
    append_action_schema_value drag-points source "${source_x},${source_y}" source-point
    append_action_schema_value drag-points target "${target_x},${target_y}" target-point
    append_action_schema_value drag-policy negative-proof "${negative_policy_key}"
    append_action_schema_value drag-policy positive-proof "${positive_proof_key}"
    if proof_uses_secondary_button; then
        append_action_schema_value drag-policy input-state-evidence secondary-button-events
    fi
    append_action_log_value negative-proof "${negative_action_text#negative-proof=}"
    append_action_log_value positive-proof "${positive_action_text#positive-proof=}"
    append_action_schema_value drag-points target-hover-hold-seconds '3.3'
    append_action_schema_value drag-points coordinate-policy "${coordinate_policy}"
    append_action_schema_value drag-points mapping-assertion "${mapping_assertion}"
    append_action_schema_value drag-screenshots pickup "${SNAP_PICKUP_NAME}" snap-pickup-screenshot
    append_action_schema_value drag-screenshots path "${SNAP_PATH_NAME}" snap-path-screenshot
    append_action_schema_value drag-screenshots hover "${SNAP_HOVER_NAME}" snap-hover-screenshot
    if [ -n "${SNAP_RELEASE_NAME}" ]; then
        append_action_schema_value drag-screenshots release "${SNAP_RELEASE_NAME}" snap-release-screenshot
    fi
    append_action_schema_value drag-screenshots freeform-pickup "${FREEFORM_PICKUP_NAME}" freeform-pickup-screenshot
    append_action_schema_value drag-screenshots freeform-hover "${FREEFORM_HOVER_NAME}" freeform-hover-screenshot
    append_action_schema_value visual-floor required-frames "${visual_floor}"
    if [ -n "${PRODUCT_OVERLAY_LABEL}" ]; then
        append_action_schema_value visual-floor product-overlay-label "${PRODUCT_OVERLAY_LABEL}" product-overlay-label
    fi
    append_action_schema_value caption chip "${MODIFIER_CAPTION_CHIP}"
    append_action_schema_value verification before-window-log "$(artifact_relative_path "${WINDOW_BEFORE_LOG}")"
    append_action_schema_value verification after-freeform-window-log "$(artifact_relative_path "${WINDOW_FREEFORM_LOG}")"
    append_action_schema_value verification after-window-log "$(artifact_relative_path "${WINDOW_AFTER_LOG}")"
    cat "${ACTION_LOG}"

    init_mouse_events_log
    start_epoch="$(date +%s)"
    scenario_start_ms="$((start_epoch * 1000))"
    if [ "${PROOF_MODE}" = "float-unless-snap" ] || proof_uses_secondary_button; then
        negative_drag_branch="float"
        negative_post_state_event="float-post-state"
    else
        negative_drag_branch="freeform"
        negative_post_state_event="freeform-post-state"
    fi
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" 0 \
        "${FREEFORM_PICKUP_SCREENSHOT}" "" "${FREEFORM_HOVER_SCREENSHOT}" \
        "${negative_drag_branch}" "${scenario_start_ms}" none >>"${MOUSE_EVENTS_LOG}"
    sleep 2
    freeform_epoch="$(date +%s)"
    refresh_window_log "${WINDOW_FREEFORM_LOG}"
    freeform_id="$(window_id_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_zone="$(zone_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_workspace="$(workspace_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    freeform_layout="$(layout_for_title "${WINDOW_FREEFORM_LOG}" 'snap-demo.rtf')"
    [ "${freeform_id}" = "${before_id}" ] || semantic_fail "Freeform drag changed window id: ${before_id} -> ${freeform_id:-missing}"
    [ "${freeform_zone}" = "${freeform_expected_zone}" ] || semantic_fail "Freeform drag expected zone ${freeform_expected_zone}, got ${freeform_zone:-missing}"
    if [ -n "${freeform_expected_layout}" ]; then
        [ "${freeform_layout}" = "${freeform_expected_layout}" ] || semantic_fail "Freeform drag expected layout ${freeform_expected_layout}, got ${freeform_layout:-missing}"
    fi
    append_action_schema_value drag-result freeform-window-id-after "${freeform_id}" freeform-window-id-after
    append_action_schema_value drag-result freeform-after-zone "${freeform_zone}" freeform-after-zone
    append_action_schema_value drag-result freeform-after-workspace "${freeform_workspace}" freeform-after-workspace
    append_action_schema_value drag-result freeform-after-layout "${freeform_layout}" freeform-after-layout
    append_action_schema_value drag-result freeform-result "${freeform_result}" freeform-result
    append_mouse_event "${negative_post_state_event}" inspection "${scenario_start_ms}" "post-freeform window inspection completed"

    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
        append_mouse_event set-command-start command "${scenario_start_ms}" "set-zone-snap-policy command started"
        {
            echo "$ winmux set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            "${CLI}" set-zone-snap-policy "${RUNTIME_SET_POLICY}"
        } | tee "${SET_POLICY_LOG}" | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null
        grep -F "Using zone snap policy '${RUNTIME_SET_POLICY}'" "${SET_POLICY_LOG}" >/dev/null \
            || semantic_fail "set-zone-snap-policy did not report ${RUNTIME_SET_POLICY}"
        append_mouse_event set-command-end command "${scenario_start_ms}" "set-zone-snap-policy command completed"
        append_action_schema_value runtime-policy command "set-zone-snap-policy ${RUNTIME_SET_POLICY}" runtime-policy-command
        append_action_schema_value runtime-policy after-set "${RUNTIME_SET_POLICY}" runtime-policy-after-set
        sleep 3
    fi

    reset_snap_window_to_work
    sleep 1
    capture_guest_screenshot "${RESET_NAME%.png}"
    append_mouse_event reset-before-snap preparation "${scenario_start_ms}" "source reset screenshot captured before snap drag"
    if profile_requires_target_window; then
        derive_positive_drag_geometry "${WINDOW_RESET_LOG}"
        append_action_schema_value drag-points snap-source "${source_x},${source_y}" snap-source-point
        append_action_schema_value drag-points snap-target "${target_x},${target_y}" snap-target-point
    fi
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
    fi

    snap_start_epoch="$(date +%s)"
    drag_window_jxa "${source_x}" "${source_y}" "${target_x}" "${target_y}" "${positive_drag_with_alt}" \
        "${SNAP_PICKUP_SCREENSHOT}" "${SNAP_PATH_SCREENSHOT}" "${SNAP_HOVER_SCREENSHOT}" \
        snap "${scenario_start_ms}" "${positive_drag_input}" "${SNAP_RELEASE_SCREENSHOT}" >>"${MOUSE_EVENTS_LOG}"
    sleep 4
    snap_end_epoch="$(date +%s)"

    test -s "${FREEFORM_PICKUP_SCREENSHOT}"
    test -s "${FREEFORM_HOVER_SCREENSHOT}"
    test -s "${RESET_SCREENSHOT}"
    test -s "${SNAP_PICKUP_SCREENSHOT}"
    test -s "${SNAP_PATH_SCREENSHOT}"
    test -s "${SNAP_HOVER_SCREENSHOT}"
    if [ -n "${SNAP_RELEASE_SCREENSHOT}" ]; then
        test -s "${SNAP_RELEASE_SCREENSHOT}"
    fi

    for _ in $(seq 1 30); do
        refresh_window_log "${WINDOW_AFTER_LOG}"
        if [ "$(zone_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')" = "${snap_expected_zone}" ]; then
            break
        fi
        sleep 1
    done
    after_id="$(window_id_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    after_zone="$(zone_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    after_workspace="$(workspace_for_title "${WINDOW_AFTER_LOG}" 'snap-demo.rtf')"
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        snap_error_label='runtime snap-to-zone'
    elif [ "${PROOF_MODE}" = "secondary-button" ]; then
        snap_error_label='secondary-button snap'
    elif [ "${PROOF_MODE}" = "window-slot" ]; then
        snap_error_label='secondary-button window-slot snap'
    else
        snap_error_label="${USER_MODIFIER_LABEL} snap"
    fi
    [ "${after_id}" = "${before_id}" ] || semantic_fail "${snap_error_label} changed window id: ${before_id} -> ${after_id:-missing}"
    [ "${after_zone}" = "${snap_expected_zone}" ] || semantic_fail "${snap_error_label} ended in unexpected zone ${after_zone:-missing}, expected ${snap_expected_zone}"
    if [ "${snap_expected_workspace_relation}" = same ]; then
        [ -n "${before_workspace}" ] && [ -n "${after_workspace}" ] && [ "${before_workspace}" = "${after_workspace}" ] \
            || semantic_fail "${snap_error_label} should stay in the same active workspace"
    else
        [ -n "${before_workspace}" ] && [ -n "${after_workspace}" ] && [ "${before_workspace}" != "${after_workspace}" ] \
            || semantic_fail "${snap_error_label} did not move to the target zone active workspace"
    fi

    append_action_schema_value drag-result window-id-after "${after_id}" window-id-after
    append_action_schema_value drag-result after-zone "${after_zone}" after-zone
    append_action_schema_value drag-result after-workspace "${after_workspace}" after-workspace
    append_action_schema_value drag-result result success snap-result
    append_mouse_event snap-post-state inspection "${scenario_start_ms}" "post-snap window inspection completed"

    cycle_start_epoch=""
    cycle_end_epoch=""
    if [ "${PROOF_MODE}" = "runtime-policy" ]; then
        sleep 4
        cycle_start_epoch="$(date +%s)"
        append_mouse_event cycle-command-start command "${scenario_start_ms}" "cycle-zone-snap-policy command started"
        # shellcheck disable=SC2086
        {
            echo "$ winmux cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
            "${CLI}" cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}
        } | tee "${CYCLE_POLICY_LOG}" | tee -a "${ACTION_LOG}" | tee -a "${CLI_LOG}" >/dev/null
        cycle_end_epoch="$(date +%s)"
        grep -F "Using zone snap policy 'freeform'" "${CYCLE_POLICY_LOG}" >/dev/null \
            || semantic_fail 'cycle-zone-snap-policy did not return to freeform'
        append_mouse_event cycle-command-end command "${scenario_start_ms}" "cycle-zone-snap-policy command completed"
        append_action_schema_value runtime-policy cycle-command "cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}" runtime-cycle-command
        append_action_schema_value runtime-policy after-cycle freeform runtime-policy-after-cycle
        sleep 3
    fi

    {
        printf 'freeform-drag-start-offset-seconds=%s\n' "$((start_epoch - start_epoch))"
        printf 'freeform-drag-end-offset-seconds=%s\n' "$((freeform_epoch - start_epoch))"
        printf 'snap-drag-start-offset-seconds=%s\n' "$((snap_start_epoch - start_epoch))"
        printf 'snap-drag-end-offset-seconds=%s\n' "$((snap_end_epoch - start_epoch))"
        if [ -n "${cycle_start_epoch}" ] && [ -n "${cycle_end_epoch}" ]; then
            printf 'cycle-command-start-offset-seconds=%s\n' "$((cycle_start_epoch - start_epoch))"
            printf 'cycle-command-end-offset-seconds=%s\n' "$((cycle_end_epoch - start_epoch))"
        fi
    } >"${TIMING_LOG}"

    cat "${ZONES_LOG}" "${WINDOW_BEFORE_LOG}" "${ACTION_LOG}" "${WINDOW_FREEFORM_LOG}" \
        "${WINDOW_RESET_LOG}" "${WINDOW_AFTER_LOG}" >"${CLI_LOG}"

    {
        echo "${SLICE_TITLE}"
        echo
        echo 'Config under proof:'
        echo "[mouse.zone-snap]"
        echo "policy = '${CONFIG_POLICY}'"
        echo "modifier = '${CONFIG_MODIFIER}'"
        echo "gesture = '${CONFIG_GESTURE}'"
        echo "target = '${CONFIG_TARGET}'"
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo
            echo 'Runtime commands under proof:'
            echo "winmux set-zone-snap-policy ${RUNTIME_SET_POLICY}"
            echo "winmux cycle-zone-snap-policy ${RUNTIME_CYCLE_POLICIES}"
        fi
        echo
        echo 'Zones:'
        cat "${ZONES_LOG}"
        echo
        echo 'Before drag:'
        cat "${WINDOW_BEFORE_LOG}"
        echo
        echo 'Action log:'
        cat "${ACTION_LOG}"
        echo
        echo 'Proof manifest:'
        cat "${ACTION_MANIFEST}"
        echo
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo 'After runtime snap-to-zone drag:'
        elif [ "${PROOF_MODE}" = "secondary-button" ]; then
            echo 'After secondary-button snap:'
        elif [ "${PROOF_MODE}" = "window-slot" ]; then
            echo 'After secondary-button window-slot snap:'
        else
            echo "After ${USER_MODIFIER_LABEL} snap:"
        fi
        cat "${WINDOW_AFTER_LOG}"
        echo
        if [ "${PROOF_MODE}" = "runtime-policy" ]; then
            echo "PASS: desktop drag starts from config freeform/no-zone-move; winmux set-zone-snap-policy snap-to-zone makes the next no-modifier drag preview a whole Comms zone target and move the same window into Comms/right on release; winmux cycle-zone-snap-policy freeform snap-to-zone returns the runtime policy to freeform."
        elif [ "${PROOF_MODE}" = "secondary-button" ]; then
            echo "PASS: desktop drag starts from config float-unless-snap with gesture secondary-button-drag; ordinary drag converts the tiled source into floating/freeform placement in Comms/right without a snap overlay; resetting to Work/main and holding the secondary mouse button previews a whole Comms zone target and moves the same window into Comms/right on release."
        elif [ "${PROOF_MODE}" = "window-slot" ]; then
            echo "PASS: desktop drag starts from config float-unless-snap with gesture secondary-button-drag and target window; ordinary drag inside Work/main floats without a slot overlay; resetting to Work/main and holding the secondary mouse button previews target-window.rtf's right window slot and keeps the same source window in Work/main on release, with no whole-zone fallback."
        elif [ "${PROOF_MODE}" = "float-unless-snap" ]; then
            echo "PASS: desktop drag starts from config float-unless-snap; no-${USER_MODIFIER_LABEL} drag converts the tiled source into floating/freeform placement in Comms/right without a snap overlay; resetting to Work/main and holding ${USER_MODIFIER_LABEL} previews a whole Comms zone target and moves the same window into Comms/right on release."
        else
            echo "PASS: desktop drag without ${USER_MODIFIER_LABEL} stays freeform/no-zone-move; holding ${USER_MODIFIER_LABEL} previews a whole Comms zone target and moves the same window into Comms/right on release."
        fi
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 6
    printf 'result=success\n' >"${DONE}"
    copy_runtime_logs
}

mouse_event_writer_self_test() {
    mkdir -p "${ARTIFACTS_DIR}/logs"
    init_mouse_events_log
    /usr/bin/osascript -l JavaScript <<JXA
const app = Application.currentApplication()
app.includeStandardAdditions = true
const mouseEventsLog = '${MOUSE_EVENTS_LOG}'

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function emit(eventId, kind, note) {
  const line = [eventId, kind, '0.125', note].join('\t')
  app.doShellScript("/usr/bin/printf '%s\\n' " + shellQuote(line) + " >> " + shellQuote(mouseEventsLog))
}

emit('float-drag-start', 'drag', "ordinary branch with quote ' retained")
emit('snap-secondary-button-down', 'input-state', 'raw secondary mouse button down posted before snap drag')
emit('snap-drag-start', 'drag', 'secondary-button branch start')
emit('snap-secondary-button-held', 'input-state', 'secondary mouse button still held at whole-zone hover')
emit('snap-first-affordance', 'overlay', 'whole-zone affordance event')
emit('snap-release', 'drag', 'release event')
emit('snap-secondary-button-up', 'input-state', 'raw secondary mouse button up posted after snap release')
JXA

    /usr/bin/awk -F'\t' '
        /^#/ { next }
        NF != 4 {
            printf("mouse event self-test row has %d fields: %s\n", NF, $0) > "/dev/stderr"
            exit 1
        }
        $1 in seen {
            printf("mouse event self-test duplicate id: %s\n", $1) > "/dev/stderr"
            exit 1
        }
        { seen[$1] = 1; count += 1 }
        END {
            if (count != 7 || !seen["float-drag-start"] || !seen["snap-secondary-button-down"] || !seen["snap-drag-start"] || !seen["snap-secondary-button-held"] || !seen["snap-first-affordance"] || !seen["snap-release"] || !seen["snap-secondary-button-up"]) {
                print "mouse event self-test missing required ids" > "/dev/stderr"
                exit 1
            }
        }
    ' "${MOUSE_EVENTS_LOG}"
    if /usr/bin/grep -F '0.125ordinary' "${MOUSE_EVENTS_LOG}" >/dev/null; then
        semantic_fail 'Mouse event self-test detected concatenated rows'
    fi
    if /usr/bin/grep -F "\\n" "${MOUSE_EVENTS_LOG}" >/dev/null; then
        semantic_fail 'Mouse event self-test detected literal backslash-n separators'
    fi
    printf 'result=success\n'
    cat "${MOUSE_EVENTS_LOG}"
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    self-test)
        mouse_event_writer_self_test
        ;;
    *)
        echo "Unknown WINMUX_E2E_MOUSE_SNAP_PHASE/WINMUX_E2E_SLICE12_PHASE: ${PHASE}" >&2
        exit 64
        ;;
esac
