#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE31_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-31-relaunch-saved-layout"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice31-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice31-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice31"
LAUNCH_PLIST="/tmp/winmux-e2e-slice31.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice31.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-31-relaunch-setup.log"
WINDOW_SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-31-windows-setup.log"
WINDOW_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-31-windows-before.log"
WINDOW_AFTER_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-31-windows-after-relaunch.log"
WINDOW_PRODUCT_READY_LOG="${ARTIFACTS_DIR}/logs/slice-31-product-windows-ready.log"
WINDOW_PRODUCT_AFTER_SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-31-product-windows-after-save.log"
WINDOW_PRODUCT_AFTER_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-31-product-windows-after-relaunch.log"
WINDOW_PRODUCT_FINAL_LOG="${ARTIFACTS_DIR}/logs/slice-31-product-windows-final.log"
ZONES_BEFORE_LOG="${ARTIFACTS_DIR}/logs/slice-31-zones-before.log"
ZONES_RESIZED_LOG="${ARTIFACTS_DIR}/logs/slice-31-zones-after-resize.log"
ZONES_AFTER_SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-31-zones-after-save.log"
ZONES_AFTER_RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-31-zones-after-relaunch.log"
RESIZE_LOG="${ARTIFACTS_DIR}/logs/slice-31-resize-zone.log"
SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-31-save-zone-layout.log"
RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-31-relaunch.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-31-command-timing.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-31-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-31-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-31-window-ids.env"
CONFIG_SHA_BEFORE="${ARTIFACTS_DIR}/logs/slice-31-config-before.sha256"
CONFIG_SHA_AFTER_SAVE="${ARTIFACTS_DIR}/logs/slice-31-config-after-save.sha256"
BACKUP_SHA="${ARTIFACTS_DIR}/logs/slice-31-config-backup.sha256"
BACKUP_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-31-backup-path.txt"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-31-config-before.toml"
CONFIG_AFTER_COPY="${ARTIFACTS_DIR}/logs/slice-31-config-after.toml"
CONFIG_BACKUP_COPY="${ARTIFACTS_DIR}/logs/slice-31-config-backup.toml"
MEASUREMENTS="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.measurements.tsv"
PROOF_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-31-relaunch-saved-layout-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/zone-relaunch-docs"
REFERENCE_DOC="${DOC_DIR}/research-reference.rtf"
WORK_DOC="${DOC_DIR}/focus-draft.rtf"
COMMS_DOC="${DOC_DIR}/team-inbox.rtf"

uid="$(/usr/bin/id -u)"

# shellcheck source=script/e2e/guest/zone-window-helpers.sh
. "${REPO_DIR}/script/e2e/guest/zone-window-helpers.sh"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

semantic_fail() {
    echo "$*" >&2
    exit 86
}

config_sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

rtf_escape_line() {
    /usr/bin/sed -e 's/\\/\\\\/g' -e 's/{/\\{/g' -e 's/}/\\}/g'
}

write_zone_doc() {
    local path="$1"
    local heading="$2"
    local subheading="$3"
    local detail="$4"
    cat >"${path}" <<RTF
{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}{\f1 Menlo;}}\viewkind4\uc1\margl540\margr540\pard\ql\f0\fs80\b ${heading}\b0\par\f0\fs42 ${subheading}\par\par\f1\fs30 ${detail}\par}
RTF
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
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

refresh_product_window_log() {
    local path="$1"
    /usr/bin/osascript <<'APPLESCRIPT' >"${path}" 2>>"${WAIT_ERR}"
set outputLines to {}
tell application "System Events"
    repeat with proc in application processes
        set procName to name of proc as text
        set procBundle to ""
        try
            set procBundle to bundle identifier of proc as text
        end try
        set procBackground to false
        try
            set procBackground to background only of proc
        end try
        if procBackground is false then
            repeat with win in windows of proc
                set winVisible to true
                try
                    set winVisible to visible of win
                end try
                if winVisible is true then
                    set winTitle to ""
                    try
                        set winTitle to name of win as text
                    end try
                    set winPosition to {0, 0}
                    set winSize to {0, 0}
                    try
                        set winPosition to position of win
                    end try
                    try
                        set winSize to size of win
                    end try
                    set end of outputLines to procBundle & "|" & procName & "|" & winTitle & "|x=" & (item 1 of winPosition as text) & "|y=" & (item 2 of winPosition as text) & "|width=" & (item 1 of winSize as text) & "|height=" & (item 2 of winSize as text)
                end if
            end repeat
        end if
    end repeat
end tell
set oldDelimiters to AppleScript's text item delimiters
set AppleScript's text item delimiters to linefeed
set outputText to outputLines as text
set AppleScript's text item delimiters to oldDelimiters
return outputText
APPLESCRIPT
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

textedit_window_set_ok() {
    local path="$1"
    local count

    count="$(/usr/bin/awk 'NF { count++ } END { print count + 0 }' "$path")"
    [ "$count" = "3" ] || return 1
    for title in research-reference.rtf focus-draft.rtf team-inbox.rtf; do
        [ "$(/usr/bin/awk -F'|' -v title="$title" '$2 == title { count++ } END { print count + 0 }' "$path")" = "1" ] \
            || return 1
    done
    [ -z "$(/usr/bin/awk -F'|' '$0 != "" && $2 != "research-reference.rtf" && $2 != "focus-draft.rtf" && $2 != "team-inbox.rtf" { print $2 }' "$path")" ] \
        || return 1
}

product_window_log_clean() {
    local path="$1"
    /usr/bin/awk -F'|' '
        function is_expected_textedit(bundle, app, title) {
            return bundle == "com.apple.TextEdit" &&
                app == "TextEdit" &&
                (title == "research-reference.rtf" ||
                 title == "focus-draft.rtf" ||
                 title == "team-inbox.rtf")
        }
        function is_winmux_chrome(bundle, app, title) {
            bundle = tolower(bundle)
            app = tolower(app)
            return index(bundle, "winmux") > 0 ||
                index(app, "winmux") > 0
        }
        NF {
            row_count++
            if (NF != 7) {
                printf("bad-field-count:%s\n", $0) > "/dev/stderr"
                invalid = 1
                next
            }
            if (is_expected_textedit($1, $2, $3)) {
                titles[$3]++
                next
            }
            if (is_winmux_chrome($1, $2, $3)) {
                chrome_count++
                next
            }
            if ($1 == "com.apple.TextEdit") {
                printf("unexpected-textedit-title:%s\n", $3) > "/dev/stderr"
            } else {
                printf("unexpected-visible-window:%s:%s:%s\n", $1, $2, $3) > "/dev/stderr"
            }
            invalid = 1
        }
        END {
            if (titles["research-reference.rtf"] != 1 ||
                titles["focus-draft.rtf"] != 1 ||
                titles["team-inbox.rtf"] != 1) {
                printf("unexpected-title-set\n") > "/dev/stderr"
                invalid = 1
            }
            if (row_count < 3) {
                printf("unexpected-count:%d\n", row_count) > "/dev/stderr"
                invalid = 1
            }
            exit(invalid ? 1 : 0)
        }
    ' "$path"
}

assert_product_window_log_clean() {
    local path="$1"
    local context="$2"
    if product_window_log_clean "$path"; then
        return 0
    fi

    echo "${context}: expected only the three Slice 31 TextEdit task documents plus WinMux chrome in the product view" >&2
    cat "$path" >&2 || true
    semantic_fail "${context}: product view contains unrelated or proof windows"
}

product_windows_match_zones() {
    local product_log="$1"
    local zones_log="$2"
    /usr/bin/awk -F'|' '
        function field_value(prefix,   i) {
            for (i = 1; i <= NF; i++) {
                if (index($i, prefix "=") == 1) {
                    return substr($i, length(prefix) + 2)
                }
            }
            return ""
        }
        function expected_zone_for_title(title) {
            if (title == "research-reference.rtf") return "left"
            if (title == "focus-draft.rtf") return "main"
            if (title == "team-inbox.rtf") return "right"
            return ""
        }
        FNR == NR {
            zone = substr($1, length("zone=") + 1)
            left[zone] = field_value("left") + 0
            width[zone] = field_value("width") + 0
            right[zone] = left[zone] + width[zone]
            next
        }
        $1 == "com.apple.TextEdit" && $2 == "TextEdit" {
            zone = expected_zone_for_title($3)
            if (zone == "") next
            x = field_value("x") + 0
            window_width = field_value("width") + 0
            window_right = x + window_width
            tolerance = 4
            if (!(zone in left) || x < left[zone] - tolerance || window_right > right[zone] + tolerance) {
                printf("physical-zone-mismatch:%s:%s:x=%s:right=%s:zone-left=%s:zone-right=%s\n", $3, zone, x, window_right, left[zone], right[zone]) > "/dev/stderr"
                invalid = 1
            }
            seen[$3] = 1
        }
        END {
            if (!seen["research-reference.rtf"] || !seen["focus-draft.rtf"] || !seen["team-inbox.rtf"]) {
                printf("physical-zone-missing-title\n") > "/dev/stderr"
                invalid = 1
            }
            exit(invalid ? 1 : 0)
        }
    ' "$zones_log" "$product_log"
}

assert_product_windows_match_zones() {
    local product_log="$1"
    local zones_log="$2"
    local context="$3"
    if product_windows_match_zones "$product_log" "$zones_log"; then
        return 0
    fi

    echo "${context}: expected task documents to be physically inside their zone columns" >&2
    cat "$product_log" >&2 || true
    cat "$zones_log" >&2 || true
    semantic_fail "${context}: product window coordinates do not match expected zones"
}

assert_exact_textedit_documents() {
    local path="$1"
    local context="$2"
    if textedit_window_set_ok "$path"; then
        return 0
    fi

    echo "${context}: expected exactly the three Slice 31 TextEdit task documents" >&2
    cat "$path" >&2 || true
    semantic_fail "${context}: unexpected visible TextEdit window set"
}

wait_for_exact_textedit_documents() {
    for _ in $(seq 1 60); do
        if refresh_window_log "${WINDOW_SETUP_LOG}" && textedit_window_set_ok "${WINDOW_SETUP_LOG}"; then
            return 0
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

display_percent() {
    local value="$1"
    /usr/bin/awk -v value="$value" 'BEGIN {
        pct = value * 100
        if (pct == int(pct)) {
            printf "%d%%", pct
        } else {
            printf "%.1f%%", pct
        }
    }'
}

measurement_chip_for_log() {
    local path="$1"
    local left main right
    left="$(display_percent "$(zone_field "$path" left effective)")"
    main="$(display_percent "$(zone_field "$path" main effective)")"
    right="$(display_percent "$(zone_field "$path" right effective)")"
    printf 'Reference %s | Work %s | Comms %s\n' "$left" "$main" "$right"
}

append_measurements() {
    local phase_name="$1"
    local zones_log="$2"
    local left_configured main_configured right_configured
    local left_effective main_effective right_effective
    local left_width main_width right_width chip
    left_configured="$(zone_field "$zones_log" left configured)"
    main_configured="$(zone_field "$zones_log" main configured)"
    right_configured="$(zone_field "$zones_log" right configured)"
    left_effective="$(zone_field "$zones_log" left effective)"
    main_effective="$(zone_field "$zones_log" main effective)"
    right_effective="$(zone_field "$zones_log" right effective)"
    left_width="$(zone_field "$zones_log" left width)"
    main_width="$(zone_field "$zones_log" main width)"
    right_width="$(zone_field "$zones_log" right width)"
    chip="$(measurement_chip_for_log "$zones_log")"
    {
        printf '%s\tleft\tReference\t%s\t%s\t%s\t%s\n' \
            "$phase_name" "$left_configured" "$left_effective" "$left_width" "$chip"
        printf '%s\tmain\tWork\t%s\t%s\t%s\t%s\n' \
            "$phase_name" "$main_configured" "$main_effective" "$main_width" "$chip"
        printf '%s\tright\tComms\t%s\t%s\t%s\t%s\n' \
            "$phase_name" "$right_configured" "$right_effective" "$right_width" "$chip"
    } >>"${MEASUREMENTS}"
}

measurement_field() {
    local phase_name="$1"
    local zone_id="$2"
    local field="$3"
    /usr/bin/awk -F'\t' -v phase="$phase_name" -v zone="$zone_id" -v field="$field" '
        BEGIN {
            indexByName["configured"] = 4
            indexByName["effective"] = 5
            indexByName["pixel-width"] = 6
            indexByName["chip"] = 7
        }
        $1 == phase && $2 == zone {
            print $indexByName[field]
            exit
        }
    ' "${MEASUREMENTS}"
}

backup_path_from_save_log() {
    /usr/bin/awk -F': ' '$1 == "Backup" { print $2; exit }' "$1"
}

assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    [ "$actual" = "$expected" ] || semantic_fail "${message}: expected '${expected}', got '${actual}'"
}

assert_empty_or_none() {
    local actual="$1"
    local message="$2"
    case "$actual" in
        ''|none) ;;
        *) semantic_fail "${message}: expected empty or none, got '${actual}'" ;;
    esac
}

assert_float_gt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="$left" -v right="$right" 'BEGIN { exit(left > right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} > ${right}"
}

assert_float_lt() {
    local left="$1"
    local right="$2"
    local message="$3"
    /usr/bin/awk -v left="$left" -v right="$right" 'BEGIN { exit(left < right ? 0 : 1) }' \
        || semantic_fail "${message}: expected ${left} < ${right}"
}

assert_float_approximately_equal() {
    local left="$1"
    local right="$2"
    local tolerance="$3"
    local message="$4"
    /usr/bin/awk -v left="$left" -v right="$right" -v tolerance="$tolerance" '
        function abs(x) { return x < 0 ? -x : x }
        BEGIN { exit(abs(left - right) <= tolerance ? 0 : 1) }
    ' || semantic_fail "${message}: expected ${left} ~= ${right} within ${tolerance}"
}

sleep_until() {
    local target="$1"
    while [ "${SECONDS}" -lt "${target}" ]; do
        sleep "$((target - SECONDS))"
    done
}

assert_startup_trace_loaded_relaunch_state() {
    local trace_path="${STARTUP_TRACE_LOCAL}"
    [ -f "${trace_path}" ] || trace_path="${STARTUP_TRACE}"
    grep -F 'persisted frozen world loaded: false' "${trace_path}" >/dev/null \
        || semantic_fail 'startup trace did not show the initial launch without persisted restart state'
    grep -F 'persisted frozen world loaded: true' "${trace_path}" >/dev/null \
        || semantic_fail 'startup trace did not show the relaunch loading persisted restart state'
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

wait_for_textedit_title() {
    local title="$1"
    local path="$2"
    for _ in $(seq 1 60); do
        refresh_window_log "$path"
        if [ -n "$(field_for_title "$path" "$title" id)" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
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
    ensure_window_in_zone "$@"
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
    /bin/cp "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}" || true
}

launch_winmux() {
    local phase_name="$1"
    write_launch_plist
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true

    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        /usr/bin/awk '/pid =/ { print $3; exit }' "${LAUNCH_STATUS}" >"${ARTIFACTS_DIR}/logs/winmux-app-${phase_name}.pid" || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-31-zone-count-${phase_name}.txt" 2>"${WAIT_ERR}"; then
            return
        fi
        sleep 1
    done

    echo "WinMux CLI did not become ready during ${phase_name}" >&2
    cat "${LAUNCH_STATUS}" >&2 || true
    copy_runtime_logs
    cat "${APP_LOG}" >&2 || true
    cat "${STARTUP_TRACE}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    exit 1
}

stop_winmux() {
    {
        echo "stop-command-offset-seconds=${SECONDS}"
        echo '$ launchctl bootout WinMux slice service'
    } >>"${RELAUNCH_LOG}"
    /bin/launchctl bootout "gui/${uid}" "${LAUNCH_PLIST}" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
        if ! "${CLI}" list-zones --count >/dev/null 2>&1; then
            echo 'stopped=yes' >>"${RELAUNCH_LOG}"
            copy_runtime_logs
            return 0
        fi
        sleep 1
    done
    echo 'stopped=unknown-cli-still-responded' >>"${RELAUNCH_LOG}"
    return 0
}

setup_slice() {
    rm -f \
        "${DONE}" "${SETUP_LOG}" "${WINDOW_SETUP_LOG}" "${WINDOW_BEFORE_LOG}" \
        "${WINDOW_AFTER_RELAUNCH_LOG}" "${WINDOW_PRODUCT_READY_LOG}" \
        "${WINDOW_PRODUCT_AFTER_SAVE_LOG}" "${WINDOW_PRODUCT_AFTER_RELAUNCH_LOG}" \
        "${WINDOW_PRODUCT_FINAL_LOG}" "${ZONES_BEFORE_LOG}" "${ZONES_RESIZED_LOG}" \
        "${ZONES_AFTER_SAVE_LOG}" "${ZONES_AFTER_RELAUNCH_LOG}" "${RESIZE_LOG}" \
        "${SAVE_LOG}" "${RELAUNCH_LOG}" "${TIMING_LOG}" "${CLI_LOG}" "${WAIT_ERR}" \
        "${STATE_FILE}" "${CONFIG_SHA_BEFORE}" "${CONFIG_SHA_AFTER_SAVE}" "${BACKUP_SHA}" \
        "${BACKUP_PATH_LOG}" "${CONFIG_BEFORE_COPY}" "${CONFIG_AFTER_COPY}" \
        "${CONFIG_BACKUP_COPY}" "${MEASUREMENTS}" "${PROOF_MANIFEST}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"

    {
        echo 'WinMux Slice 31: relaunch-safe saved layout'
        echo "Source App: ${SOURCE_APP}"
        echo "Source CLI: ${SOURCE_CLI}"
        echo "Config: ${CONFIG}"
        echo 'Commands: resize-zone Work width +10%; save-zone-layout; quit and relaunch WinMux'
    } | tee "${SETUP_LOG}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${CONFIG}"
    rm -rf "${BIN_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"

    write_zone_doc "${REFERENCE_DOC}" "Research Notes" "Reference zone" "Collect input, links, and source snippets."
    write_zone_doc "${WORK_DOC}" "Launch Draft" "Work zone" "Write the main plan while the center column grows."
    write_zone_doc "${COMMS_DOC}" "Team Inbox" "Comms zone" "Keep messages visible in the right column."

    /bin/cp "${CONFIG}" "${CONFIG_BEFORE_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_BEFORE}"
    launch_winmux initial
    /usr/bin/open -a TextEdit "${REFERENCE_DOC}" "${WORK_DOC}" "${COMMS_DOC}"
    wait_for_exact_textedit_documents || {
        echo 'Expected exactly the three Slice 31 TextEdit task documents' >&2
        cat "${WINDOW_SETUP_LOG}" >&2 || true
        exit 1
    }

    local reference_id work_id comms_id
    reference_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'research-reference.rtf' id)"
    work_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'focus-draft.rtf' id)"
    comms_id="$(field_for_title "${WINDOW_SETUP_LOG}" 'team-inbox.rtf' id)"
    test -n "${reference_id}"
    test -n "${work_id}"
    test -n "${comms_id}"

    move_window_to_zone "${reference_id}" 'research-reference.rtf' Reference left
    move_window_to_zone "${work_id}" 'focus-draft.rtf' Work main
    move_window_to_zone "${comms_id}" 'team-inbox.rtf' Comms right

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${work_id}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_exact_textedit_documents "${WINDOW_BEFORE_LOG}" 'Before resize'
    refresh_product_window_log "${WINDOW_PRODUCT_READY_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_READY_LOG}" 'Ready product view'
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    assert_product_windows_match_zones "${WINDOW_PRODUCT_READY_LOG}" "${ZONES_BEFORE_LOG}" 'Ready product view'
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'research-reference.rtf' left
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'focus-draft.rtf' main
    assert_window_zone "${WINDOW_BEFORE_LOG}" 'team-inbox.rtf' right

    {
        printf 'phase\tzone-id\tzone-name\tconfigured\teffective\tpixel-width\tchip\n'
    } >"${MEASUREMENTS}"
    append_measurements before "${ZONES_BEFORE_LOG}"

    cat >"${STATE_FILE}" <<STATE
REFERENCE_ID=${reference_id}
WORK_ID=${work_id}
COMMS_ID=${comms_id}
STATE

    {
        echo 'setup=result=success'
        echo 'ready-state=task-documents-visible'
        echo "reference-window-id=${reference_id}"
        echo "work-window-id=${work_id}"
        echo "comms-window-id=${comms_id}"
        echo "measurement-before=$(measurement_chip_for_log "${ZONES_BEFORE_LOG}")"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

write_slice_31_proof_manifest() {
    cat >"${PROOF_MANIFEST}" <<MANIFEST
kind	key	value
target	monitor	1
target	layout-id	balanced
command	resize	winmux resize-zone Work width +10%
command	save	winmux save-zone-layout
command	relaunch	launchctl bootout/bootstrap WinMux slice service
command	list-zones	winmux list-zones
timing	resize-command-offset-seconds	${resize_offset}
timing	save-command-offset-seconds	${save_offset}
timing	quit-command-offset-seconds	${quit_offset}
timing	relaunch-command-offset-seconds	${relaunch_offset}
timing	list-zones-after-relaunch-offset-seconds	${list_zones_offset}
safety	backup-path	${backup_path}
safety	backup-matches-original	yes
relaunch	app-stopped	yes
relaunch	app-restarted	yes
relaunch	widths-restored	yes
relaunch	no-runtime-resize-after-launch	yes
relaunch	runtime-override-values-cleared	yes
relaunch	persisted-restart-state-loaded	yes
continuity	documents-in-same-zones	yes
continuity	workspaces-preserved	yes
continuity	window-ids-stable	${window_ids_stable}
clean-view	before-visible-textedit-window-count	3
clean-view	before-visible-textedit-title-set	research-reference.rtf,focus-draft.rtf,team-inbox.rtf
clean-view	relaunched-visible-textedit-window-count	3
clean-view	relaunched-visible-textedit-title-set	research-reference.rtf,focus-draft.rtf,team-inbox.rtf
measurement	before	$(measurement_chip_for_log "${ZONES_BEFORE_LOG}")
measurement	resized	$(measurement_chip_for_log "${ZONES_RESIZED_LOG}")
measurement	relaunched	$(measurement_chip_for_log "${ZONES_AFTER_RELAUNCH_LOG}")
widths	before	${before_left},${before_main},${before_right}
widths	resized	${resized_left},${resized_main},${resized_right}
widths	saved	${saved_left},${saved_main},${saved_right}
widths	relaunched	${relaunched_left},${relaunched_main},${relaunched_right}
width-before	left	${before_left}
width-before	main	${before_main}
width-before	right	${before_right}
width-resized	left	${resized_left}
width-resized	main	${resized_main}
width-resized	right	${resized_right}
width-saved	left	${saved_left}
width-saved	main	${saved_main}
width-saved	right	${saved_right}
width-relaunched	left	${relaunched_left}
width-relaunched	main	${relaunched_main}
width-relaunched	right	${relaunched_right}
hash	config-before	${before_sha}
hash	config-after-save	${save_sha}
hash	config-backup	${backup_sha}
MANIFEST
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    : >"${RELAUNCH_LOG}"
    test -f "${STATE_FILE}"
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    test -n "${WORK_ID:-}"

    "${CLI}" focus-zone Work
    "${CLI}" focus --window-id "${WORK_ID}"
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_exact_textedit_documents "${WINDOW_BEFORE_LOG}" 'Before resize'
    write_zones_log "${ZONES_BEFORE_LOG}" >/dev/null
    {
        printf 'phase\tzone-id\tzone-name\tconfigured\teffective\tpixel-width\tchip\n'
    } >"${MEASUREMENTS}"
    append_measurements before "${ZONES_BEFORE_LOG}"
    refresh_product_window_log "${WINDOW_PRODUCT_READY_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_READY_LOG}" 'Ready product view'
    assert_product_windows_match_zones "${WINDOW_PRODUCT_READY_LOG}" "${ZONES_BEFORE_LOG}" 'Ready product view'
    sleep_until 8
    refresh_window_log "${WINDOW_BEFORE_LOG}"
    assert_exact_textedit_documents "${WINDOW_BEFORE_LOG}" 'Immediately before resize'
    refresh_product_window_log "${WINDOW_PRODUCT_READY_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_READY_LOG}" 'Immediately before resize product view'
    assert_product_windows_match_zones "${WINDOW_PRODUCT_READY_LOG}" "${ZONES_BEFORE_LOG}" 'Immediately before resize product view'

    local resize_offset save_offset quit_offset relaunch_offset list_zones_offset
    resize_offset="${SECONDS}"
    echo "resize-command-offset-seconds=${resize_offset}" >>"${TIMING_LOG}"
    {
        echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
        echo '$ winmux resize-zone Work width +10%'
        "${CLI}" resize-zone Work width +10%
    } | tee "${RESIZE_LOG}"
    sleep_until 18
    write_zones_log "${ZONES_RESIZED_LOG}" >/dev/null
    append_measurements resized "${ZONES_RESIZED_LOG}"
    capture_guest_screenshot '02-after-runtime-resize-slice-31'
    sleep_until 28

    save_offset="${SECONDS}"
    echo "save-command-offset-seconds=${save_offset}" >>"${TIMING_LOG}"
    {
        echo '$ winmux save-zone-layout'
        "${CLI}" save-zone-layout
    } | tee "${SAVE_LOG}"
    local backup_path
    backup_path="$(backup_path_from_save_log "${SAVE_LOG}")"
    test -n "${backup_path}"
    test -f "${backup_path}"
    printf '%s\n' "${backup_path}" >"${BACKUP_PATH_LOG}"
    /bin/cp "${backup_path}" "${CONFIG_BACKUP_COPY}"
    /bin/cp "${CONFIG}" "${CONFIG_AFTER_COPY}"
    config_sha256 "${CONFIG}" >"${CONFIG_SHA_AFTER_SAVE}"
    config_sha256 "${CONFIG_BACKUP_COPY}" >"${BACKUP_SHA}"
    write_zones_log "${ZONES_AFTER_SAVE_LOG}" >/dev/null
    append_measurements saved "${ZONES_AFTER_SAVE_LOG}"
    refresh_product_window_log "${WINDOW_PRODUCT_AFTER_SAVE_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_AFTER_SAVE_LOG}" 'After save product view'
    assert_product_windows_match_zones "${WINDOW_PRODUCT_AFTER_SAVE_LOG}" "${ZONES_AFTER_SAVE_LOG}" 'After save product view'
    capture_guest_screenshot '03-after-save-slice-31'
    sleep_until 38

    quit_offset="${SECONDS}"
    echo "quit-command-offset-seconds=${quit_offset}" >>"${TIMING_LOG}"
    stop_winmux
    capture_guest_screenshot '04-after-quit-slice-31'
    sleep_until 44

    relaunch_offset="${SECONDS}"
    echo "relaunch-command-offset-seconds=${relaunch_offset}" >>"${TIMING_LOG}"
    {
        echo "relaunch-command-offset-seconds=${relaunch_offset}"
        echo '$ launchctl bootstrap WinMux slice service'
    } >>"${RELAUNCH_LOG}"
    launch_winmux relaunch
    sleep_until 50
    list_zones_offset="${SECONDS}"
    echo "list-zones-after-relaunch-offset-seconds=${list_zones_offset}" >>"${TIMING_LOG}"
    write_zones_log "${ZONES_AFTER_RELAUNCH_LOG}" >/dev/null
    refresh_window_log "${WINDOW_AFTER_RELAUNCH_LOG}"
    assert_exact_textedit_documents "${WINDOW_AFTER_RELAUNCH_LOG}" 'After relaunch'
    append_measurements relaunched "${ZONES_AFTER_RELAUNCH_LOG}"
    refresh_product_window_log "${WINDOW_PRODUCT_AFTER_RELAUNCH_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_AFTER_RELAUNCH_LOG}" 'After relaunch product view'
    assert_product_windows_match_zones "${WINDOW_PRODUCT_AFTER_RELAUNCH_LOG}" "${ZONES_AFTER_RELAUNCH_LOG}" 'After relaunch product view'
    sleep_until 58
    capture_guest_screenshot '05-after-relaunch-slice-31'
    sleep_until 62
    refresh_product_window_log "${WINDOW_PRODUCT_FINAL_LOG}"
    assert_product_window_log_clean "${WINDOW_PRODUCT_FINAL_LOG}" 'Final product view'
    assert_product_windows_match_zones "${WINDOW_PRODUCT_FINAL_LOG}" "${ZONES_AFTER_RELAUNCH_LOG}" 'Final product view'

    local before_left before_main before_right
    local resized_left resized_main resized_right
    local saved_left saved_main saved_right
    local relaunched_left relaunched_main relaunched_right
    local relaunched_configured_left relaunched_configured_main relaunched_configured_right
    local before_sha save_sha backup_sha
    before_left="$(measurement_field before left effective)"
    before_main="$(measurement_field before main effective)"
    before_right="$(measurement_field before right effective)"
    resized_left="$(measurement_field resized left effective)"
    resized_main="$(measurement_field resized main effective)"
    resized_right="$(measurement_field resized right effective)"
    saved_left="$(measurement_field saved left effective)"
    saved_main="$(measurement_field saved main effective)"
    saved_right="$(measurement_field saved right effective)"
    relaunched_left="$(measurement_field relaunched left effective)"
    relaunched_main="$(measurement_field relaunched main effective)"
    relaunched_right="$(measurement_field relaunched right effective)"
    relaunched_configured_left="$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" left configured)"
    relaunched_configured_main="$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" main configured)"
    relaunched_configured_right="$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" right configured)"
    before_sha="$(cat "${CONFIG_SHA_BEFORE}")"
    save_sha="$(cat "${CONFIG_SHA_AFTER_SAVE}")"
    backup_sha="$(cat "${BACKUP_SHA}")"

    assert_float_approximately_equal "${before_left}" 0.25 0.000001 \
        'Before Reference effective width is not 25%'
    assert_float_approximately_equal "${before_main}" 0.5 0.000001 \
        'Before Work effective width is not 50%'
    assert_float_approximately_equal "${before_right}" 0.25 0.000001 \
        'Before Comms effective width is not 25%'
    assert_float_approximately_equal "${resized_left}" 0.2 0.000001 \
        'Resized Reference effective width is not 20%'
    assert_float_approximately_equal "${resized_main}" 0.6 0.000001 \
        'Resized Work effective width is not 60%'
    assert_float_approximately_equal "${resized_right}" 0.2 0.000001 \
        'Resized Comms effective width is not 20%'
    assert_float_gt "${resized_main}" "${before_main}" 'Work/main width did not grow before save'
    assert_float_lt "${resized_left}" "${before_left}" 'Reference/left width did not shrink before save'
    assert_float_lt "${resized_right}" "${before_right}" 'Comms/right width did not shrink before save'
    assert_float_approximately_equal "${saved_left}" "${resized_left}" 0.000001 \
        'Saved Reference effective width does not match resized width'
    assert_float_approximately_equal "${saved_main}" "${resized_main}" 0.000001 \
        'Saved Work effective width does not match resized width'
    assert_float_approximately_equal "${saved_right}" "${resized_right}" 0.000001 \
        'Saved Comms effective width does not match resized width'
    assert_float_approximately_equal "${relaunched_left}" "${resized_left}" 0.000001 \
        'Relaunched Reference width does not match saved runtime width'
    assert_float_approximately_equal "${relaunched_main}" "${resized_main}" 0.000001 \
        'Relaunched Work width does not match saved runtime width'
    assert_float_approximately_equal "${relaunched_right}" "${resized_right}" 0.000001 \
        'Relaunched Comms width does not match saved runtime width'
    assert_float_approximately_equal "${relaunched_configured_left}" "${resized_left}" 0.000001 \
        'Relaunched Reference configured width does not match saved runtime width'
    assert_float_approximately_equal "${relaunched_configured_main}" "${resized_main}" 0.000001 \
        'Relaunched Work configured width does not match saved runtime width'
    assert_float_approximately_equal "${relaunched_configured_right}" "${resized_right}" 0.000001 \
        'Relaunched Comms configured width does not match saved runtime width'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" left override-state)" configured \
        'Relaunched Reference should use configured width, not a runtime override'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" main override-state)" configured \
        'Relaunched Work should use configured width, not a runtime override'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" right override-state)" configured \
        'Relaunched Comms should use configured width, not a runtime override'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" left override)" \
        'Relaunched Reference should not retain a runtime override value'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" main override)" \
        'Relaunched Work should not retain a runtime override value'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH_LOG}" right override)" \
        'Relaunched Comms should not retain a runtime override value'
    [ "${save_sha}" != "${before_sha}" ] || semantic_fail 'save-zone-layout did not change config hash'
    assert_equal "${backup_sha}" "${before_sha}" 'backup file does not match original config'

    grep -F 'Saved zone layout' "${SAVE_LOG}" >/dev/null \
        || semantic_fail 'save output missing saved line'
    grep -F 'Backup:' "${SAVE_LOG}" >/dev/null \
        || semantic_fail 'save output missing backup path'
    grep -F 'relaunch-command-offset-seconds=' "${TIMING_LOG}" >/dev/null \
        || semantic_fail 'relaunch timing marker missing'
    grep -F 'stopped=yes' "${RELAUNCH_LOG}" >/dev/null \
        || semantic_fail 'relaunch log did not prove the app stopped'
    assert_startup_trace_loaded_relaunch_state

    for title in research-reference.rtf focus-draft.rtf team-inbox.rtf; do
        local expected_zone before_id after_id before_zone after_zone before_workspace after_workspace
        case "$title" in
            research-reference.rtf) expected_zone=left ;;
            focus-draft.rtf) expected_zone=main ;;
            team-inbox.rtf) expected_zone=right ;;
            *) expected_zone= ;;
        esac
        before_id="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" id)"
        after_id="$(field_for_title "$WINDOW_AFTER_RELAUNCH_LOG" "$title" id)"
        before_zone="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" zone)"
        after_zone="$(field_for_title "$WINDOW_AFTER_RELAUNCH_LOG" "$title" zone)"
        before_workspace="$(field_for_title "$WINDOW_BEFORE_LOG" "$title" workspace)"
        after_workspace="$(field_for_title "$WINDOW_AFTER_RELAUNCH_LOG" "$title" workspace)"
        [ -n "$before_id" ] && [ -n "$after_id" ] \
            || semantic_fail "Missing window title across relaunch logs: $title"
        assert_equal "$before_zone" "$expected_zone" "before zone mismatch for $title"
        assert_equal "$after_zone" "$expected_zone" "after relaunch zone mismatch for $title"
        assert_equal "$after_workspace" "$before_workspace" "workspace changed across relaunch for $title"
    done

    local window_ids_stable=yes
    for title in research-reference.rtf focus-draft.rtf team-inbox.rtf; do
        if [ "$(field_for_title "$WINDOW_BEFORE_LOG" "$title" id)" != "$(field_for_title "$WINDOW_AFTER_RELAUNCH_LOG" "$title" id)" ]; then
            window_ids_stable=no
        fi
    done

    write_slice_31_proof_manifest

    cat \
        "${WINDOW_BEFORE_LOG}" "${RESIZE_LOG}" "${ZONES_RESIZED_LOG}" \
        "${SAVE_LOG}" "${RELAUNCH_LOG}" "${ZONES_AFTER_RELAUNCH_LOG}" \
        "${WINDOW_AFTER_RELAUNCH_LOG}" "${WINDOW_PRODUCT_READY_LOG}" \
        "${WINDOW_PRODUCT_AFTER_SAVE_LOG}" "${WINDOW_PRODUCT_AFTER_RELAUNCH_LOG}" \
        "${WINDOW_PRODUCT_FINAL_LOG}" >"${CLI_LOG}"

    {
        echo 'WinMux Slice 31: relaunch-safe saved layout'
        echo
        echo 'Commands:'
        cat "${RESIZE_LOG}"
        cat "${SAVE_LOG}"
        cat "${RELAUNCH_LOG}"
        echo
        echo "backup-path=${backup_path}"
        echo "config-sha-before=${before_sha}"
        echo "config-sha-after-save=${save_sha}"
        echo "config-backup-sha=${backup_sha}"
        echo "measurement-before=$(measurement_chip_for_log "${ZONES_BEFORE_LOG}")"
        echo "measurement-resized=$(measurement_chip_for_log "${ZONES_RESIZED_LOG}")"
        echo "measurement-relaunched=$(measurement_chip_for_log "${ZONES_AFTER_RELAUNCH_LOG}")"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: save-zone-layout persists the resized 20/60/20 layout, and a fresh WinMux launch reads that saved layout without another runtime resize command.'
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
    copy_runtime_logs
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/config" "${ARTIFACTS_DIR}/logs"
    zone_window_helpers_self_test "${ARTIFACTS_DIR}/logs/zone-window-helper-self-test"

    local before_fixture="${ZONES_BEFORE_LOG}"
    local zones_fixture="${ZONES_RESIZED_LOG}"
    local relaunched_fixture="${ZONES_AFTER_RELAUNCH_LOG}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Research|left=64.0|width=844.0|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.5|override=|override-state=configured|workspace=Draft|left=908.0|width=1688.0|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Inbox|left=2596.0|width=844.0|physical=1' \
        >"${before_fixture}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=Research|left=64.0|width=675.2|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.6|override=0.6|override-state=runtime|workspace=Draft|left=739.2|width=2025.6|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.2|override=0.2|override-state=runtime|workspace=Inbox|left=2764.8|width=675.2|physical=1' \
        >"${zones_fixture}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.2|effective=0.2|override=|override-state=configured|workspace=Research|left=64.0|width=675.2|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.6|effective=0.6|override=|override-state=configured|workspace=Draft|left=739.2|width=2025.6|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.2|effective=0.2|override=|override-state=configured|workspace=Inbox|left=2764.8|width=675.2|physical=1' \
        >"${relaunched_fixture}"
    assert_equal "$(zone_field "${zones_fixture}" main width)" 2025.6 \
        'zone_field did not parse main width'
    assert_equal "$(measurement_chip_for_log "${zones_fixture}")" 'Reference 20% | Work 60% | Comms 20%' \
        'measurement_chip_for_log did not render expected chip'
    printf 'phase\tzone-id\tzone-name\tconfigured\teffective\tpixel-width\tchip\n' >"${MEASUREMENTS}"
    append_measurements resized "${zones_fixture}"
    assert_equal "$(measurement_field resized main effective)" 0.6 \
        'measurement_field did not parse main effective width'
    assert_equal "$(measurement_field resized right chip)" 'Reference 20% | Work 60% | Comms 20%' \
        'measurement_field did not parse chip'

    local save_log="${ARTIFACTS_DIR}/logs/slice-31-self-test-save.log"
    printf '%s\n' 'Saved zone layout' 'Backup: /tmp/winmux.toml.backup-20260630T000000Z' >"${save_log}"
    assert_equal "$(backup_path_from_save_log "${save_log}")" /tmp/winmux.toml.backup-20260630T000000Z \
        'backup_path_from_save_log did not parse backup path'

    local escaped
    escaped="$(printf '%s\n' 'path\with {braces}' | rtf_escape_line)"
    assert_equal "${escaped}" 'path\\with \{braces\}' \
        'rtf_escape_line did not escape backslashes and braces'

    local product_fixture="${ARTIFACTS_DIR}/logs/slice-31-self-test-product-windows.log"
    printf '%s\n' \
        'com.apple.TextEdit|TextEdit|research-reference.rtf|x=64|y=96|width=675|height=1180' \
        'com.example.WinMux|WinMuxApp|WinMux|x=16|y=48|width=380|height=980' \
        'com.apple.TextEdit|TextEdit|focus-draft.rtf|x=739|y=96|width=2026|height=1180' \
        'com.apple.TextEdit|TextEdit|team-inbox.rtf|x=2765|y=96|width=675|height=1180' \
        >"${product_fixture}"
    assert_product_window_log_clean "${product_fixture}" 'self-test clean product windows'
    assert_product_windows_match_zones "${product_fixture}" "${relaunched_fixture}" 'self-test clean product positions'
    printf '%s\n' \
        'com.apple.TextEdit|TextEdit|research-reference.rtf|x=64|y=96|width=675|height=1180' \
        'com.apple.Terminal|Terminal|sshd prompt|x=739|y=96|width=2026|height=1180' \
        'com.apple.TextEdit|TextEdit|team-inbox.rtf|x=2765|y=96|width=675|height=1180' \
        >"${product_fixture}.bad"
    if product_window_log_clean "${product_fixture}.bad" >/dev/null 2>&1; then
        semantic_fail 'product_window_log_clean accepted an unrelated visible Terminal window'
    fi
    printf '%s\n' \
        'com.apple.TextEdit|TextEdit|research-reference.rtf|x=64|y=96|width=675|height=1180' \
        'com.apple.TextEdit|TextEdit|WinMux proof notes.rtf|x=739|y=96|width=2026|height=1180' \
        'com.apple.TextEdit|TextEdit|team-inbox.rtf|x=2765|y=96|width=675|height=1180' \
        >"${product_fixture}.bad-title"
    if product_window_log_clean "${product_fixture}.bad-title" >/dev/null 2>&1; then
        semantic_fail 'product_window_log_clean accepted a proof-output TextEdit window with WinMux in the title'
    fi
    printf '%s\n' \
        'com.apple.TextEdit|TextEdit|research-reference.rtf|x=64|y=96|width=675|height=1180' \
        'com.apple.TextEdit|TextEdit|focus-draft.rtf|x=64|y=756|width=675|height=520' \
        'com.apple.TextEdit|TextEdit|team-inbox.rtf|x=2765|y=96|width=675|height=1180' \
        >"${product_fixture}.bad-physical"
    assert_product_window_log_clean "${product_fixture}.bad-physical" 'self-test bad physical clean product windows'
    if product_windows_match_zones "${product_fixture}.bad-physical" "${relaunched_fixture}" >/dev/null 2>&1; then
        semantic_fail 'product_windows_match_zones accepted Work document physically inside the Reference zone'
    fi

    local resize_offset=8 save_offset=28 quit_offset=38 relaunch_offset=44 list_zones_offset=50
    local backup_path=/tmp/winmux.toml.backup-20260630T000000Z
    local window_ids_stable=yes
    local before_left=0.25 before_main=0.5 before_right=0.25
    local resized_left=0.2 resized_main=0.6 resized_right=0.2
    local saved_left=0.2 saved_main=0.6 saved_right=0.2
    local relaunched_left=0.2 relaunched_main=0.6 relaunched_right=0.2
    local before_sha=before-sha save_sha=save-sha backup_sha=before-sha
    write_slice_31_proof_manifest
    grep -F $'clean-view\tbefore-visible-textedit-window-count\t3' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted before clean-view window count'
    grep -F $'clean-view\trelaunched-visible-textedit-title-set\tresearch-reference.rtf,focus-draft.rtf,team-inbox.rtf' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted relaunched clean-view title set'
    grep -F $'measurement\tbefore\tReference 25% | Work 50% | Comms 25%' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted before measurement chip'
    grep -F $'measurement\trelaunched\tReference 20% | Work 60% | Comms 20%' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted relaunched measurement chip'
    grep -F $'relaunch\truntime-override-values-cleared\tyes' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted runtime override clearing row'
    grep -F $'relaunch\tpersisted-restart-state-loaded\tyes' "${PROOF_MANIFEST}" >/dev/null \
        || semantic_fail 'proof manifest writer omitted persisted restart state row'

    printf '%s\n' 'result=success'
}

case "${PHASE}" in
    setup)
        setup_slice
        ;;
    proof)
        proof_slice
        ;;
    self-test)
        self_test_slice
        ;;
    *)
        echo "Unknown Slice 31 phase: ${PHASE}" >&2
        exit 2
        ;;
esac
