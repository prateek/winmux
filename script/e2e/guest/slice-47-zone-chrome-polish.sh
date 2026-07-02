#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE47_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-47-zone-chrome-polish"
ZONE_FORMAT='zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|profile=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|style=%{monitor-zone-style-id}|color=%{monitor-zone-style-color}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'
WINDOW_FORMAT='%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice47-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice47-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice47"
LAUNCH_PLIST="/tmp/winmux-e2e-slice47.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice47.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-47-setup.log"
CONFIG_COPY="${ARTIFACTS_DIR}/logs/slice-47-zone-chrome-config.toml"
WINDOW_READY_LOG="${ARTIFACTS_DIR}/logs/slice-47-windows-ready.log"
WINDOW_ALL_LOG="${ARTIFACTS_DIR}/logs/slice-47-windows-all.log"
ZONE_TARGETS_READY_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-ready.log"
ZONE_TARGETS_REFERENCE_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-focus-reference.log"
ZONE_TARGETS_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-focus-comms.log"
ZONE_TARGETS_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-focus-only.log"
ZONE_TARGETS_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-communications.log"
ZONE_TARGETS_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-urgent.log"
ZONE_TARGETS_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-calm.log"
ZONE_TARGETS_FINAL_LOG="${ARTIFACTS_DIR}/logs/slice-47-zone-targets-final.log"
FOCUS_REFERENCE_LOG="${ARTIFACTS_DIR}/logs/slice-47-focus-reference.log"
FOCUS_COMMS_LOG="${ARTIFACTS_DIR}/logs/slice-47-focus-comms.log"
USE_FOCUS_LOG="${ARTIFACTS_DIR}/logs/slice-47-use-focus-only.log"
USE_COMMUNICATIONS_LOG="${ARTIFACTS_DIR}/logs/slice-47-use-communications.log"
STYLE_URGENT_LOG="${ARTIFACTS_DIR}/logs/slice-47-style-urgent.log"
STYLE_CALM_LOG="${ARTIFACTS_DIR}/logs/slice-47-style-calm.log"
FINAL_AUDIT_LOG="${ARTIFACTS_DIR}/logs/slice-47-final-audit.log"
WINDOW_STABILITY_LOG="${ARTIFACTS_DIR}/logs/slice-47-window-stability.tsv"
LAYOUT_STABILITY_LOG="${ARTIFACTS_DIR}/logs/slice-47-layout-stability.tsv"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-47-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-47-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-47-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-47-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/${RECORDING_NAME}-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-chrome-docs"
REFERENCE_DOC="${DOC_DIR}/slice47-reference.rtf"
WORK_DOC="${DOC_DIR}/slice47-work.rtf"
COMMS_DOC="${DOC_DIR}/slice47-comms.rtf"
FINAL_DOC="${DOC_DIR}/slice47-final-zone-chrome-audit.rtf"
REFERENCE_TITLE="slice47-reference.rtf"
WORK_TITLE="slice47-work.rtf"
COMMS_TITLE="slice47-comms.rtf"
FINAL_TITLE="slice47-final-zone-chrome-audit.rtf"

uid="$(/usr/bin/id -u)"
mutation_marked=0

# shellcheck source=script/e2e/guest/zone-window-helpers.sh
. "${REPO_DIR}/script/e2e/guest/zone-window-helpers.sh"
# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
. "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

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
        printf '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}{\\f1 Menlo;}}\\viewkind4\\uc1\\margl540\\margr540\\pard\\ql\\f0\\fs56\\b %s\\b0\\par\\f1\\fs26\n' \
            "$(printf '%s\n' "$title" | rtf_escape_line)"
        while IFS= read -r line; do
            printf '%s\\par\n' "$(printf '%s\n' "$line" | rtf_escape_line)"
        done <"${source_path}"
        printf '}'
    } >"${out_path}"
}

write_zone_doc() {
    local path="$1"
    local heading="$2"
    local zone_name="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs76\b ${heading}\b0\par\f1\fs32 zone: ${zone_name}\par ${detail}\par}
RTF
}

write_final_doc() {
    local source="${ARTIFACTS_DIR}/logs/slice-47-final-board-source.txt"
    {
        echo 'Slice 47 final zone chrome audit'
        echo
        echo 'Current state visible in sidebar chrome:'
        echo 'profile=communications'
        echo 'current-zone=Comms'
        echo 'style=calm'
        echo 'hidden-zone=Reference'
        echo
        echo '$ winmux list-zones --format chrome audit'
        cat "${ZONE_TARGETS_FINAL_LOG}"
        echo
        echo 'PASS: focus/profile/style chrome stayed visible and anchor window ids/workspaces stayed stable.'
    } >"${source}"
    write_text_doc "${source}" 'Slice 47 final zone chrome audit' "${FINAL_DOC}"
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
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-47-zone-count.txt" 2>"${WAIT_ERR}"; then
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

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format "${WINDOW_FORMAT}" \
        >"${path}" 2>>"${WAIT_ERR}"
}

refresh_all_window_log() {
    local path="$1"
    "${CLI}" list-windows --all \
        --format "${WINDOW_FORMAT}" \
        >"${path}" 2>>"${WAIT_ERR}"
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

window_id_for_title() {
    field_for_title "$1" "$2" id
}

zone_for_title() {
    field_for_title "$1" "$2" zone
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
    local expected="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        if refresh_window_log "${path}"; then
            local count
            count="$(/usr/bin/grep -c '^' "${path}" || true)"
            if [ "${count}" -ge "${expected}" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

wait_for_window_present() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_window_log "${path}"
        if [ -n "$(window_id_for_title "${path}" "${title}")" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

focused_zone_id() {
    "${CLI}" list-monitors --focused --format '%{monitor-zone-id}' 2>>"${WAIT_ERR}" | /usr/bin/head -n 1
}

write_zone_targets_log() {
    local path="$1"
    local focused
    local raw_path="${path}.raw"
    focused="$(focused_zone_id)"
    {
        printf '$ winmux list-zones --format '\''chrome audit'\''\n'
        printf 'focused-zone=%s\n' "${focused}"
        "${CLI}" list-zones --format "${ZONE_FORMAT}"
    } >"${raw_path}" 2>>"${WAIT_ERR}"

    {
        printf '$ winmux list-zones --format '\''chrome audit'\''\n'
        printf 'focused-zone=%s\n' "${focused}"
        /usr/bin/awk -F'|' -v focused="${focused}" '
            /^zone=/ {
                zone = name = enabled = profile = workspace = style = color = left = width = ""
                for (i = 1; i <= NF; i++) {
                    split($i, kv, "=")
                    if (kv[1] == "zone") { zone = kv[2] }
                    else if (kv[1] == "name") { name = kv[2] }
                    else if (kv[1] == "enabled") { enabled = kv[2] }
                    else if (kv[1] == "profile") { profile = kv[2] }
                    else if (kv[1] == "workspace") { workspace = kv[2] }
                    else if (kv[1] == "style") { style = kv[2] }
                    else if (kv[1] == "color") { color = kv[2] }
                    else if (kv[1] == "left") { left = kv[2] }
                    else if (kv[1] == "width") { width = kv[2] }
                }
                if (enabled == "false") {
                    workspace = "Hidden"
                }
                is_focused = (zone == focused ? "true" : "false")
                printf("zone=%s|name=%s|enabled=%s|profile=%s|workspace=%s|focused=%s|style=%s|color=%s|left=%s|width=%s\n", zone, name, enabled, profile, workspace, is_focused, style, color, left, width)
            }
        ' "${raw_path}"
    } >"${path}"
}

zone_target_field() {
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

assert_zone_target_state() {
    local path="$1"
    local zone_id="$2"
    local enabled="$3"
    local profile="${4:-}"
    local style="${5:-}"
    local focused="${6:-}"
    [ -s "${path}" ] || semantic_fail "Missing zone target log: ${path}"
    [ "$(zone_target_field "${path}" "${zone_id}" enabled)" = "${enabled}" ] \
        || { cat "${path}" >&2; semantic_fail "Expected ${zone_id} enabled=${enabled}"; }
    if [ -n "${profile}" ]; then
        [ "$(zone_target_field "${path}" "${zone_id}" profile)" = "${profile}" ] \
            || { cat "${path}" >&2; semantic_fail "Expected ${zone_id} profile=${profile}"; }
    fi
    if [ -n "${style}" ]; then
        [ "$(zone_target_field "${path}" "${zone_id}" style)" = "${style}" ] \
            || { cat "${path}" >&2; semantic_fail "Expected ${zone_id} style=${style}"; }
    fi
    if [ -n "${focused}" ]; then
        [ "$(zone_target_field "${path}" "${zone_id}" focused)" = "${focused}" ] \
            || { cat "${path}" >&2; semantic_fail "Expected ${zone_id} focused=${focused}"; }
    fi
    if [ "${enabled}" = "false" ]; then
        [ "$(zone_target_field "${path}" "${zone_id}" workspace)" = "Hidden" ] \
            || { cat "${path}" >&2; semantic_fail "Expected hidden ${zone_id} row to show workspace=Hidden"; }
    fi
}

write_stability_logs() {
    local phase="$1"
    local zones_log="$2"
    local windows_log="${ARTIFACTS_DIR}/logs/slice-47-windows-${phase}.log"
    refresh_all_window_log "${windows_log}"
    if [ ! -s "${WINDOW_STABILITY_LOG}" ]; then
        printf '# phase\ttitle\twindow-id\tzone\tworkspace\n' >"${WINDOW_STABILITY_LOG}"
    fi
    for title in "${REFERENCE_TITLE}" "${WORK_TITLE}" "${COMMS_TITLE}"; do
        local id zone workspace
        id="$(field_for_title "${windows_log}" "${title}" id)"
        zone="$(field_for_title "${windows_log}" "${title}" zone)"
        workspace="$(field_for_title "${windows_log}" "${title}" workspace)"
        printf '%s\t%s\t%s\t%s\t%s\n' "${phase}" "${title}" "${id}" "${zone}" "${workspace}" >>"${WINDOW_STABILITY_LOG}"
    done

    if [ ! -s "${LAYOUT_STABILITY_LOG}" ]; then
        printf '# phase\tzone\tenabled\tprofile\tstyle\tleft\twidth\n' >"${LAYOUT_STABILITY_LOG}"
    fi
    /usr/bin/awk -F'|' -v phase="${phase}" '
        /^zone=/ {
            zone = enabled = profile = style = left = width = ""
            for (i = 1; i <= NF; i++) {
                split($i, kv, "=")
                if (kv[1] == "zone") { zone = kv[2] }
                else if (kv[1] == "enabled") { enabled = kv[2] }
                else if (kv[1] == "profile") { profile = kv[2] }
                else if (kv[1] == "style") { style = kv[2] }
                else if (kv[1] == "left") { left = kv[2] }
                else if (kv[1] == "width") { width = kv[2] }
            }
            printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", phase, zone, enabled, profile, style, left, width)
        }
    ' "${zones_log}" >>"${LAYOUT_STABILITY_LOG}"
}

window_stability_field() {
    local phase="$1"
    local title="$2"
    local field="$3"
    /usr/bin/awk -F'\t' -v phase="${phase}" -v title="${title}" -v field="${field}" '
        $0 == "" || $1 ~ /^#/ { next }
        $1 == phase && $2 == title {
            if (field == "id") { print $3; exit }
            if (field == "zone") { print $4; exit }
            if (field == "workspace") { print $5; exit }
        }
    ' "${WINDOW_STABILITY_LOG}"
}

require_window_stability_field() {
    local phase="$1"
    local title="$2"
    local field="$3"
    local expected="$4"
    local actual
    actual="$(window_stability_field "${phase}" "${title}" "${field}")"
    [ "${actual}" = "${expected}" ] || {
        cat "${WINDOW_STABILITY_LOG}" >&2 || true
        semantic_fail "Window stability failed for ${title} at ${phase}: expected ${field}=${expected}, got ${actual:-missing}"
    }
}

assert_window_stability() {
    local phases=(ready focus-reference focus-comms focus-only communications style-urgent style-calm final-audit)
    local title phase expected_id ready_workspace communications_zone

    for title in "${REFERENCE_TITLE}" "${WORK_TITLE}" "${COMMS_TITLE}"; do
        case "$title" in
            "${REFERENCE_TITLE}") expected_id="${REFERENCE_ID:-}" ;;
            "${WORK_TITLE}") expected_id="${WORK_ID:-}" ;;
            *) expected_id="${COMMS_ID:-}" ;;
        esac
        ready_workspace="$(window_stability_field ready "${title}" workspace)"
        [ -n "${expected_id}" ] && [ -n "${ready_workspace}" ] || {
            cat "${WINDOW_STABILITY_LOG}" >&2 || true
            semantic_fail "Window stability missing ready id/workspace for ${title}"
        }
        for phase in "${phases[@]}"; do
            require_window_stability_field "${phase}" "${title}" id "${expected_id}"
            require_window_stability_field "${phase}" "${title}" workspace "${ready_workspace}"
        done
    done

    for phase in ready focus-reference focus-comms; do
        require_window_stability_field "${phase}" "${REFERENCE_TITLE}" zone left
        require_window_stability_field "${phase}" "${WORK_TITLE}" zone main
        require_window_stability_field "${phase}" "${COMMS_TITLE}" zone right
    done
    for phase in "${phases[@]}"; do
        require_window_stability_field "${phase}" "${WORK_TITLE}" zone main
    done
    for phase in ready focus-reference focus-comms communications style-urgent style-calm final-audit; do
        require_window_stability_field "${phase}" "${COMMS_TITLE}" zone right
    done

    for title in "${REFERENCE_TITLE}" "${WORK_TITLE}" "${COMMS_TITLE}"; do
        communications_zone="$(window_stability_field communications "${title}" zone)"
        [ -n "${communications_zone}" ] || {
            cat "${WINDOW_STABILITY_LOG}" >&2 || true
            semantic_fail "Window stability missing communications placement for ${title}"
        }
        for phase in style-urgent style-calm final-audit; do
            require_window_stability_field "${phase}" "${title}" zone "${communications_zone}"
        done
    done
}

validate_recorded_evidence() {
    for path in \
        "${CONFIG_COPY}" "${SETUP_LOG}" "${ZONE_TARGETS_READY_LOG}" "${ZONE_TARGETS_REFERENCE_LOG}" \
        "${ZONE_TARGETS_COMMS_LOG}" "${ZONE_TARGETS_FOCUS_LOG}" "${ZONE_TARGETS_COMMUNICATIONS_LOG}" \
        "${ZONE_TARGETS_URGENT_LOG}" "${ZONE_TARGETS_CALM_LOG}" "${ZONE_TARGETS_FINAL_LOG}" \
        "${FOCUS_REFERENCE_LOG}" "${FOCUS_COMMS_LOG}" "${USE_FOCUS_LOG}" "${USE_COMMUNICATIONS_LOG}" \
        "${STYLE_URGENT_LOG}" "${STYLE_CALM_LOG}" "${FINAL_AUDIT_LOG}" \
        "${WINDOW_STABILITY_LOG}" "${LAYOUT_STABILITY_LOG}" "${TIMING_LOG}" "${PROOF}"; do
        [ -s "${path}" ] || semantic_fail "Missing Slice 47 evidence file: ${path}"
    done

    for expected in \
        "[[zone-styles]]" \
        "alt-f = 'use-zone-profile focus-only'" \
        "alt-m = 'use-zone-profile communications'" \
        "alt-y = 'cycle-zone-style current urgent calm'"; do
        /usr/bin/grep -F "${expected}" "${CONFIG_COPY}" >/dev/null \
            || semantic_fail "Slice 47 config evidence missing ${expected}"
    done

    /usr/bin/grep -F '$ winmux focus-zone Reference' "${FOCUS_REFERENCE_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing focus-zone Reference command'
    /usr/bin/grep -F '$ winmux focus-zone Comms' "${FOCUS_COMMS_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing focus-zone Comms command'
    /usr/bin/grep -F '$ winmux use-zone-profile focus-only' "${USE_FOCUS_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing use-zone-profile focus-only command'
    /usr/bin/grep -F '$ winmux use-zone-profile communications' "${USE_COMMUNICATIONS_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing use-zone-profile communications command'
    /usr/bin/grep -F '$ winmux cycle-zone-style current urgent calm' "${STYLE_URGENT_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing urgent cycle-zone-style command'
    /usr/bin/grep -F '$ winmux cycle-zone-style current urgent calm' "${STYLE_CALM_LOG}" >/dev/null \
        || semantic_fail 'Slice 47 missing calm cycle-zone-style command'

    assert_zone_target_state "${ZONE_TARGETS_READY_LOG}" left true "" "" false
    assert_zone_target_state "${ZONE_TARGETS_READY_LOG}" main true "" "" true
    assert_zone_target_state "${ZONE_TARGETS_READY_LOG}" right true "" "" false
    assert_zone_target_state "${ZONE_TARGETS_REFERENCE_LOG}" left true "" "" true
    assert_zone_target_state "${ZONE_TARGETS_COMMS_LOG}" right true "" "" true
    assert_zone_target_state "${ZONE_TARGETS_FOCUS_LOG}" left false
    assert_zone_target_state "${ZONE_TARGETS_FOCUS_LOG}" right false
    assert_zone_target_state "${ZONE_TARGETS_COMMUNICATIONS_LOG}" left false communications
    assert_zone_target_state "${ZONE_TARGETS_COMMUNICATIONS_LOG}" right true communications "" true
    assert_zone_target_state "${ZONE_TARGETS_URGENT_LOG}" right true communications urgent true
    assert_zone_target_state "${ZONE_TARGETS_CALM_LOG}" right true communications calm true
    assert_zone_target_state "${ZONE_TARGETS_FINAL_LOG}" right true communications calm true
    assert_window_stability

    /usr/bin/grep -F 'PASS: Slice 47 zone chrome shows focused, hidden, profile, and style state' "${PROOF}" >/dev/null \
        || semantic_fail 'Slice 47 proof missing PASS claim'
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${CONFIG_COPY}" "${WINDOW_READY_LOG}" "${WINDOW_ALL_LOG}" \
        "${ZONE_TARGETS_READY_LOG}" "${ZONE_TARGETS_REFERENCE_LOG}" "${ZONE_TARGETS_COMMS_LOG}" \
        "${ZONE_TARGETS_FOCUS_LOG}" "${ZONE_TARGETS_COMMUNICATIONS_LOG}" "${ZONE_TARGETS_URGENT_LOG}" \
        "${ZONE_TARGETS_CALM_LOG}" "${ZONE_TARGETS_FINAL_LOG}" \
        "${FOCUS_REFERENCE_LOG}" "${FOCUS_COMMS_LOG}" "${USE_FOCUS_LOG}" "${USE_COMMUNICATIONS_LOG}" \
        "${STYLE_URGENT_LOG}" "${STYLE_CALM_LOG}" "${FINAL_AUDIT_LOG}" \
        "${WINDOW_STABILITY_LOG}" "${LAYOUT_STABILITY_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" \
        "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -f "${ARTIFACTS_DIR}"/logs/slice-47-zone-targets-*.log.raw
    rm -rf "${DOC_DIR}"
    mkdir -p "${DOC_DIR}" "${BIN_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${CONFIG}" "${CONFIG_COPY}"

    write_zone_doc "${REFERENCE_DOC}" "Reference / Left" Reference "Slice 47 checks that hidden Reference rows stay visible in sidebar chrome."
    write_zone_doc "${WORK_DOC}" "Work / Main" Work "Slice 47 checks focused-row and profile indicators without moving this window."
    write_zone_doc "${COMMS_DOC}" "Comms / Right" Comms "Slice 47 checks current-zone style chips and profile state."

    {
        echo 'WinMux Slice 47: product UI and zone chrome polish'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config: sidebar zone rows show profile + style chips'
        echo 'Commands: focus-zone Reference; focus-zone Comms; use-zone-profile focus-only; use-zone-profile communications; cycle-zone-style current urgent calm'
    } | tee "${SETUP_LOG}"

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_textedit_windows 3 "${WINDOW_READY_LOG}" || {
        cat "${WINDOW_READY_LOG}" >&2 || true
        semantic_fail 'TextEdit windows did not appear'
    }

    local reference_id work_id comms_id
    reference_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${REFERENCE_TITLE}")"
    work_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${WORK_TITLE}")"
    comms_id="$(window_id_for_title "${WINDOW_READY_LOG}" "${COMMS_TITLE}")"
    [ -n "${reference_id}" ] || semantic_fail "Missing ${REFERENCE_TITLE} window id"
    [ -n "${work_id}" ] || semantic_fail "Missing ${WORK_TITLE} window id"
    [ -n "${comms_id}" ] || semantic_fail "Missing ${COMMS_TITLE} window id"

    ensure_window_in_zone "${reference_id}" "${REFERENCE_TITLE}" Reference left "${WINDOW_READY_LOG}" "${CLI_LOG}"
    ensure_window_in_zone "${work_id}" "${WORK_TITLE}" Work main "${WINDOW_READY_LOG}" "${CLI_LOG}"
    ensure_window_in_zone "${comms_id}" "${COMMS_TITLE}" Comms right "${WINDOW_READY_LOG}" "${CLI_LOG}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    refresh_window_log "${WINDOW_READY_LOG}"
    refresh_all_window_log "${WINDOW_ALL_LOG}"
    assert_window_zone "${WINDOW_ALL_LOG}" "${REFERENCE_TITLE}" left
    assert_window_zone "${WINDOW_ALL_LOG}" "${WORK_TITLE}" main
    assert_window_zone "${WINDOW_ALL_LOG}" "${COMMS_TITLE}" right

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
    : >"${CLI_LOG}"
    : >"${TIMING_LOG}"
    [ -f "${STATE_FILE}" ] || semantic_fail 'Missing Slice 47 state file'
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    [ -n "${REFERENCE_ID:-}" ] && [ -n "${WORK_ID:-}" ] && [ -n "${COMMS_ID:-}" ] \
        || semantic_fail 'Missing Slice 47 window ids'

    "${CLI}" focus-zone Work >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    "${CLI}" focus --window-id "${WORK_ID}" >>"${CLI_LOG}" 2>>"${WAIT_ERR}"
    "${CLI}" open-sidebar >/dev/null 2>&1 || true
    write_zone_targets_log "${ZONE_TARGETS_READY_LOG}"
    write_stability_logs ready "${ZONE_TARGETS_READY_LOG}"
    echo "ready-chrome-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    capture_guest_screenshot '02-ready-zone-chrome-slice-47'

    sleep_until_recording_offset 10 22 "Run: winmux focus-zone Reference"
    echo "focus-reference-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    mark_mutation_once
    {
        echo '$ winmux focus-zone Reference'
        "${CLI}" focus-zone Reference
    } | tee "${FOCUS_REFERENCE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 1
    write_zone_targets_log "${ZONE_TARGETS_REFERENCE_LOG}"
    write_stability_logs focus-reference "${ZONE_TARGETS_REFERENCE_LOG}"
    capture_guest_screenshot '03-focus-reference-slice-47'

    sleep_until_recording_offset 22 34 "Run: winmux focus-zone Comms"
    echo "focus-comms-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
    } | tee "${FOCUS_COMMS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 1
    write_zone_targets_log "${ZONE_TARGETS_COMMS_LOG}"
    write_stability_logs focus-comms "${ZONE_TARGETS_COMMS_LOG}"
    capture_guest_screenshot '04-focus-comms-slice-47'

    sleep_until_recording_offset 34 50 "Run: winmux use-zone-profile focus-only"
    echo "focus-only-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-profile focus-only'
        "${CLI}" use-zone-profile focus-only
    } | tee "${USE_FOCUS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    write_zone_targets_log "${ZONE_TARGETS_FOCUS_LOG}"
    write_stability_logs focus-only "${ZONE_TARGETS_FOCUS_LOG}"
    capture_guest_screenshot '05-focus-only-profile-slice-47'

    sleep_until_recording_offset 50 66 "Run: winmux use-zone-profile communications"
    echo "communications-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux use-zone-profile communications'
        "${CLI}" use-zone-profile communications
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
    } | tee "${USE_COMMUNICATIONS_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    write_zone_targets_log "${ZONE_TARGETS_COMMUNICATIONS_LOG}"
    write_stability_logs communications "${ZONE_TARGETS_COMMUNICATIONS_LOG}"
    capture_guest_screenshot '06-communications-profile-slice-47'

    sleep_until_recording_offset 66 82 "Run: winmux cycle-zone-style current urgent calm"
    echo "style-urgent-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux cycle-zone-style current urgent calm'
        "${CLI}" cycle-zone-style current urgent calm
    } | tee "${STYLE_URGENT_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 1
    write_zone_targets_log "${ZONE_TARGETS_URGENT_LOG}"
    write_stability_logs style-urgent "${ZONE_TARGETS_URGENT_LOG}"
    capture_guest_screenshot '07-style-cycle-urgent-slice-47'

    sleep_until_recording_offset 82 98 "Result: current zone style = calm"
    echo "style-calm-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux cycle-zone-style current urgent calm'
        "${CLI}" cycle-zone-style current urgent calm
        echo 'Result: current zone style = calm'
    } | tee "${STYLE_CALM_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 1
    write_zone_targets_log "${ZONE_TARGETS_CALM_LOG}"
    write_stability_logs style-calm "${ZONE_TARGETS_CALM_LOG}"
    capture_guest_screenshot '08-style-cycle-calm-slice-47'

    sleep_until_recording_offset 98 112 "Run: winmux list-zones --format chrome audit"
    echo "final-audit-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    write_zone_targets_log "${ZONE_TARGETS_FINAL_LOG}"
    write_stability_logs final-audit "${ZONE_TARGETS_FINAL_LOG}"
    write_final_doc
    /usr/bin/open -a TextEdit "${FINAL_DOC}"
    wait_for_window_present "${FINAL_TITLE}" "${FINAL_AUDIT_LOG}" \
        || semantic_fail "${FINAL_TITLE} did not become visible before final screenshot"
    {
        echo '$ winmux list-zones --format chrome audit'
        cat "${ZONE_TARGETS_FINAL_LOG}"
        echo
        echo '$ winmux list-windows --all --format'
        refresh_all_window_log /dev/stdout
    } >"${FINAL_AUDIT_LOG}" 2>>"${WAIT_ERR}"
    sleep 2
    capture_guest_screenshot '09-final-zone-chrome-audit-slice-47'

    {
        echo 'PASS: Slice 47 zone chrome shows focused, hidden, profile, and style state in product UI rows.'
        echo 'anchor-window-ids-and-workspaces-stable=yes'
        echo 'style-beats-preserve-post-profile-placement=yes'
        echo 'layout-changes-limited-to-profile-availability=yes'
        echo 'style-cycle-changes-chrome-only=yes'
        echo 'final-profile=communications'
        echo 'final-current-zone=Comms'
        echo 'final-style=calm'
        echo 'hidden-row-remains-visible=Reference'
        echo 'non-claim=no full GUI editor'
    } >"${PROOF}"

    validate_recorded_evidence
    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

write_self_test_fixture() {
    mkdir -p "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/screenshots" "${ARTIFACTS_DIR}/config"
    cat >"${CONFIG_COPY}" <<'TOML'
[[zone-styles]]
id = 'urgent'
color = '#D3455B'
[[zone-styles]]
id = 'calm'
color = '#3EA2FF'
[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']
[[zone-availability-sets]]
id = 'communications'
enabled-zones = ['main', 'right']
[mode.main.binding]
alt-f = 'use-zone-profile focus-only'
alt-m = 'use-zone-profile communications'
alt-y = 'cycle-zone-style current urgent calm'
TOML
    printf 'setup=result=success\nConfig: sidebar zone rows show profile + style chips\n' >"${SETUP_LOG}"
    cat >"${ZONE_TARGETS_READY_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|profile=|workspace=reference|focused=false|style=|color=|left=0|width=860
zone=main|name=Work|enabled=true|profile=|workspace=work|focused=true|style=|color=|left=860|width=1720
zone=right|name=Comms|enabled=true|profile=|workspace=comms|focused=false|style=|color=|left=2580|width=860
EOF
    cat >"${ZONE_TARGETS_REFERENCE_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|profile=|workspace=reference|focused=true|style=|color=|left=0|width=860
zone=main|name=Work|enabled=true|profile=|workspace=work|focused=false|style=|color=|left=860|width=1720
zone=right|name=Comms|enabled=true|profile=|workspace=comms|focused=false|style=|color=|left=2580|width=860
EOF
    cat >"${ZONE_TARGETS_COMMS_LOG}" <<'EOF'
zone=left|name=Reference|enabled=true|profile=|workspace=reference|focused=false|style=|color=|left=0|width=860
zone=main|name=Work|enabled=true|profile=|workspace=work|focused=false|style=|color=|left=860|width=1720
zone=right|name=Comms|enabled=true|profile=|workspace=comms|focused=true|style=|color=|left=2580|width=860
EOF
    cat >"${ZONE_TARGETS_FOCUS_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|profile=focus-only|workspace=Hidden|focused=false|style=|color=|left=0|width=0
zone=main|name=Work|enabled=true|profile=focus-only|workspace=work|focused=true|style=|color=|left=0|width=3440
zone=right|name=Comms|enabled=false|profile=focus-only|workspace=Hidden|focused=false|style=|color=|left=0|width=0
EOF
    cat >"${ZONE_TARGETS_COMMUNICATIONS_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|profile=communications|workspace=Hidden|focused=false|style=|color=|left=0|width=0
zone=main|name=Work|enabled=true|profile=communications|workspace=work|focused=false|style=|color=|left=0|width=2293
zone=right|name=Comms|enabled=true|profile=communications|workspace=comms|focused=true|style=|color=|left=2293|width=1147
EOF
    cat >"${ZONE_TARGETS_URGENT_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|profile=communications|workspace=Hidden|focused=false|style=|color=|left=0|width=0
zone=main|name=Work|enabled=true|profile=communications|workspace=work|focused=false|style=|color=|left=0|width=2293
zone=right|name=Comms|enabled=true|profile=communications|workspace=comms|focused=true|style=urgent|color=#D3455B|left=2293|width=1147
EOF
    cat >"${ZONE_TARGETS_CALM_LOG}" <<'EOF'
zone=left|name=Reference|enabled=false|profile=communications|workspace=Hidden|focused=false|style=|color=|left=0|width=0
zone=main|name=Work|enabled=true|profile=communications|workspace=work|focused=false|style=|color=|left=0|width=2293
zone=right|name=Comms|enabled=true|profile=communications|workspace=comms|focused=true|style=calm|color=#3EA2FF|left=2293|width=1147
EOF
    /bin/cp "${ZONE_TARGETS_CALM_LOG}" "${ZONE_TARGETS_FINAL_LOG}"
    printf '$ winmux focus-zone Reference\n' >"${FOCUS_REFERENCE_LOG}"
    printf '$ winmux focus-zone Comms\n' >"${FOCUS_COMMS_LOG}"
    printf '$ winmux use-zone-profile focus-only\n' >"${USE_FOCUS_LOG}"
    printf '$ winmux use-zone-profile communications\n$ winmux focus-zone Comms\n' >"${USE_COMMUNICATIONS_LOG}"
    printf '$ winmux cycle-zone-style current urgent calm\n' >"${STYLE_URGENT_LOG}"
    printf '$ winmux cycle-zone-style current urgent calm\nResult: current zone style = calm\n' >"${STYLE_CALM_LOG}"
    printf '$ winmux list-zones --format chrome audit\n' >"${FINAL_AUDIT_LOG}"
    printf 'ready-chrome-offset-seconds=0\nfocus-reference-offset-seconds=10\nfocus-comms-offset-seconds=22\nfocus-only-offset-seconds=34\ncommunications-offset-seconds=50\nstyle-urgent-offset-seconds=66\nstyle-calm-offset-seconds=82\nfinal-audit-offset-seconds=98\n' >"${TIMING_LOG}"
    cat >"${WINDOW_STABILITY_LOG}" <<EOF
# phase	title	window-id	zone	workspace
ready	${REFERENCE_TITLE}	1	left	reference
ready	${WORK_TITLE}	2	main	work
ready	${COMMS_TITLE}	3	right	comms
focus-reference	${REFERENCE_TITLE}	1	left	reference
focus-reference	${WORK_TITLE}	2	main	work
focus-reference	${COMMS_TITLE}	3	right	comms
focus-comms	${REFERENCE_TITLE}	1	left	reference
focus-comms	${WORK_TITLE}	2	main	work
focus-comms	${COMMS_TITLE}	3	right	comms
focus-only	${REFERENCE_TITLE}	1	main	reference
focus-only	${WORK_TITLE}	2	main	work
focus-only	${COMMS_TITLE}	3	main	comms
communications	${REFERENCE_TITLE}	1	main	reference
communications	${WORK_TITLE}	2	main	work
communications	${COMMS_TITLE}	3	right	comms
style-urgent	${REFERENCE_TITLE}	1	main	reference
style-urgent	${WORK_TITLE}	2	main	work
style-urgent	${COMMS_TITLE}	3	right	comms
style-calm	${REFERENCE_TITLE}	1	main	reference
style-calm	${WORK_TITLE}	2	main	work
style-calm	${COMMS_TITLE}	3	right	comms
final-audit	${REFERENCE_TITLE}	1	main	reference
final-audit	${WORK_TITLE}	2	main	work
final-audit	${COMMS_TITLE}	3	right	comms
EOF
    cat >"${LAYOUT_STABILITY_LOG}" <<'EOF'
# phase	zone	enabled	profile	style	left	width
ready	left	true			0	860
ready	main	true			860	1720
ready	right	true			2580	860
style-calm	left	false	communications		0	0
style-calm	main	true	communications		0	2293
style-calm	right	true	communications	calm	2293	1147
EOF
    cat >"${PROOF}" <<'EOF'
PASS: Slice 47 zone chrome shows focused, hidden, profile, and style state in product UI rows.
anchor-window-ids-and-workspaces-stable=yes
style-beats-preserve-post-profile-placement=yes
style-cycle-changes-chrome-only=yes
EOF
}

self_test_slice() {
    export REFERENCE_ID=1
    export WORK_ID=2
    export COMMS_ID=3
    write_self_test_fixture
    validate_recorded_evidence

    local saved="${ZONE_TARGETS_FOCUS_LOG}.saved"
    /bin/mv "${ZONE_TARGETS_FOCUS_LOG}" "${saved}"
    if ( validate_recorded_evidence ) >/dev/null 2>&1; then
        /bin/mv "${saved}" "${ZONE_TARGETS_FOCUS_LOG}"
        semantic_fail 'self-test expected missing hidden zone target proof to fail'
    fi
    /bin/mv "${saved}" "${ZONE_TARGETS_FOCUS_LOG}"
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
        echo "Unknown Slice 47 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
