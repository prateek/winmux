#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE32_PHASE:-proof}"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-32-divider-save-relaunch"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
CLI="${HOME}/winmux-e2e/bin/winmux"
SLICE26_SCRIPT="${REPO_DIR}/script/e2e/guest/slice-26-zone-divider-drag.sh"

uid="$(/usr/bin/id -u)"
LAUNCH_LABEL="local.winmux.e2e.slice26"
LAUNCH_PLIST="/tmp/winmux-e2e-slice26.plist"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice26-app.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice26-startup.log"
APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/slice-32-launchagent-status.log"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-32-divider-save-relaunch-setup.log"
DRAG_RUN_LOG="${ARTIFACTS_DIR}/logs/slice-32-delegated-divider-drag.log"
SAVE_LOG="${ARTIFACTS_DIR}/logs/slice-32-save-zone-layout.log"
RELAUNCH_LOG="${ARTIFACTS_DIR}/logs/slice-32-relaunch.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-32-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-32-cli-wait.err"
WINDOWS_AFTER_RELAUNCH="${ARTIFACTS_DIR}/logs/slice-32-windows-after-relaunch.log"
ZONES_AFTER_SAVE="${ARTIFACTS_DIR}/logs/slice-32-zones-after-save.log"
ZONES_AFTER_RELAUNCH="${ARTIFACTS_DIR}/logs/slice-32-zones-after-relaunch.log"
CONFIG_SHA_BEFORE_SAVE="${ARTIFACTS_DIR}/logs/slice-32-config-before-save.sha256"
CONFIG_SHA_AFTER_SAVE="${ARTIFACTS_DIR}/logs/slice-32-config-after-save.sha256"
BACKUP_SHA="${ARTIFACTS_DIR}/logs/slice-32-config-backup.sha256"
BACKUP_PATH_LOG="${ARTIFACTS_DIR}/logs/slice-32-backup-path.txt"
CONFIG_AFTER_COPY="${ARTIFACTS_DIR}/logs/slice-32-config-after.toml"
CONFIG_BACKUP_COPY="${ARTIFACTS_DIR}/logs/slice-32-config-backup.toml"
MEASUREMENTS="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.measurements.tsv"
PROOF_MANIFEST="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.proof-manifest.tsv"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-32-command-timing.log"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-32-divider-save-relaunch-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

semantic_fail() {
    echo "$*" >&2
    exit 86
}

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

config_sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

backup_path_from_save_log() {
    /usr/bin/awk -F': ' '$1 == "Backup" { print $2; exit }' "$1"
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
    }' "$path"
}

field_for_title() {
    local path="$1"
    local title="$2"
    local key="$3"
    /usr/bin/awk -F'|' -v title="$title" -v key="$key" '$2 == title {
        if (key == "id") { print $1; exit }
        for (i = 3; i <= NF; i++) {
            if (index($i, key "=") == 1) {
                print substr($i, length(key) + 2)
                exit
            }
        }
    }' "$path"
}

write_zones_log() {
    local path="$1"
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|override=%{monitor-zone-runtime-width-override}|override-state=%{monitor-zone-runtime-width-override-state}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"$path" 2>>"${WAIT_ERR}"
}

refresh_window_log() {
    local path="$1"
    "${CLI}" list-windows --workspace visible --app-bundle-id com.apple.TextEdit \
        --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}' \
        >"$path" 2>>"${WAIT_ERR}"
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
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
        ""|none) ;;
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

wait_until_seconds() {
    local target="$1"
    local remaining
    while [ "${SECONDS}" -lt "$target" ]; do
        remaining=$((target - SECONDS))
        if [ "$remaining" -gt 5 ]; then
            sleep 5
        else
            sleep "$remaining"
        fi
    done
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
    local zone_id zone_name configured effective pixel_width chip
    chip="$(measurement_chip_for_log "$zones_log")"
    for zone_id in left main right; do
        case "$zone_id" in
            left) zone_name=Reference ;;
            main) zone_name=Work ;;
            right) zone_name=Comms ;;
            *) zone_name="$zone_id" ;;
        esac
        configured="$(zone_field "$zones_log" "$zone_id" configured)"
        effective="$(zone_field "$zones_log" "$zone_id" effective)"
        pixel_width="$(zone_field "$zones_log" "$zone_id" width)"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$phase_name" "$zone_id" "$zone_name" "$configured" "$effective" "$pixel_width" "$chip" \
            >>"${MEASUREMENTS}"
    done
}

wait_for_cli() {
    local phase_name="$1"
    for _ in $(seq 1 60); do
        /bin/launchctl print "gui/${uid}/${LAUNCH_LABEL}" >"${LAUNCH_STATUS}" 2>&1 || true
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-32-zone-count-${phase_name}.txt" 2>>"${WAIT_ERR}"; then
            return 0
        fi
        sleep 1
    done
    cat "${LAUNCH_STATUS}" >&2 || true
    cat "${WAIT_ERR}" >&2 || true
    return 1
}

stop_winmux() {
    {
        printf 'quit-command-offset-seconds=%s\n' "$SECONDS"
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
}

relaunch_winmux() {
    {
        printf 'relaunch-command-offset-seconds=%s\n' "$SECONDS"
        echo '$ launchctl bootstrap WinMux slice service'
    } >>"${RELAUNCH_LOG}"
    /bin/launchctl bootstrap "gui/${uid}" "${LAUNCH_PLIST}"
    /bin/launchctl kickstart -k "gui/${uid}/${LAUNCH_LABEL}" >/dev/null 2>&1 || true
    wait_for_cli relaunch
}

assert_startup_trace_loaded_relaunch_state() {
    copy_runtime_logs
    grep -F 'persisted frozen world loaded: false' "${STARTUP_TRACE}" >/dev/null \
        || semantic_fail 'startup trace did not show the initial launch without persisted restart state'
    grep -F 'persisted frozen world loaded: true' "${STARTUP_TRACE}" >/dev/null \
        || semantic_fail 'startup trace did not show the relaunch loading persisted restart state'
}

assert_window_zone() {
    local path="$1"
    local title="$2"
    local expected_zone="$3"
    local actual_zone
    actual_zone="$(field_for_title "$path" "$title" zone)"
    [ "$actual_zone" = "$expected_zone" ] \
        || semantic_fail "Expected ${title} in zone ${expected_zone}, got ${actual_zone:-missing}"
}

write_proof_manifest() {
    cat >"${PROOF_MANIFEST}" <<MANIFEST
kind	key	value
target	monitor	1
target	layout-id	balanced
command	drag	drag Work|Comms divider
command	save	winmux save-zone-layout
command	relaunch	launchctl bootout/bootstrap WinMux slice service
command	list-zones	winmux list-zones
timing	save-command-offset-seconds	${save_offset}
timing	quit-command-offset-seconds	${quit_offset}
timing	relaunch-command-offset-seconds	${relaunch_offset}
timing	list-zones-after-relaunch-offset-seconds	${list_zones_offset}
safety	backup-path	${backup_path}
safety	backup-matches-original	yes
drag	source-proof	logs/slice-26-zone-divider-drag.proof-manifest.tsv
drag	target	Work|Comms divider
drag	widths-changed	yes
save	config-changed	yes
relaunch	app-stopped	yes
relaunch	app-restarted	yes
relaunch	dragged-widths-restored	yes
relaunch	no-runtime-resize-after-launch	yes
relaunch	runtime-override-values-cleared	yes
relaunch	persisted-restart-state-loaded	yes
continuity	documents-in-same-zones	yes
measurement	before	$(measurement_chip_for_log "${ZONES_BEFORE_DRAG}")
measurement	dragged	$(measurement_chip_for_log "${ZONES_AFTER_DRAG}")
measurement	saved	$(measurement_chip_for_log "${ZONES_AFTER_SAVE}")
measurement	relaunched	$(measurement_chip_for_log "${ZONES_AFTER_RELAUNCH}")
width-before	left	${before_left}
width-before	main	${before_main}
width-before	right	${before_right}
width-dragged	left	${dragged_left}
width-dragged	main	${dragged_main}
width-dragged	right	${dragged_right}
width-saved	left	${saved_left}
width-saved	main	${saved_main}
width-saved	right	${saved_right}
width-relaunched	left	${relaunched_left}
width-relaunched	main	${relaunched_main}
width-relaunched	right	${relaunched_right}
hash	config-before-save	${before_save_sha}
hash	config-after-save	${after_save_sha}
hash	config-backup	${backup_sha}
MANIFEST
}

run_slice_26_phase() {
    local phase="$1"
    WINMUX_E2E_SLICE26_PHASE="$phase" \
        REPO_DIR="${REPO_DIR}" \
        ARTIFACTS_DIR="${ARTIFACTS_DIR}" \
        GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID}" \
        /bin/bash "${SLICE26_SCRIPT}"
}

setup_slice() {
    rm -f \
        "${SETUP_LOG}" "${DRAG_RUN_LOG}" "${SAVE_LOG}" "${RELAUNCH_LOG}" "${CLI_LOG}" \
        "${WAIT_ERR}" "${WINDOWS_AFTER_RELAUNCH}" "${ZONES_AFTER_SAVE}" \
        "${ZONES_AFTER_RELAUNCH}" "${CONFIG_SHA_BEFORE_SAVE}" \
        "${CONFIG_SHA_AFTER_SAVE}" "${BACKUP_SHA}" "${BACKUP_PATH_LOG}" \
        "${CONFIG_AFTER_COPY}" "${CONFIG_BACKUP_COPY}" "${MEASUREMENTS}" \
        "${PROOF_MANIFEST}" "${TIMING_LOG}" "${DONE}" "${PROOF}" \
        "${SCREENSHOTS_DIR}/08-after-save-slice-32.png" \
        "${SCREENSHOTS_DIR}/09-after-quit-slice-32.png" \
        "${SCREENSHOTS_DIR}/10-after-relaunch-slice-32.png"
    {
        echo 'WinMux Slice 32: save and relaunch a dragged divider layout'
        echo "Config: ${CONFIG}"
        echo 'Action: drag Work|Comms divider, save-zone-layout, quit, relaunch, list-zones'
    } | tee "${SETUP_LOG}"
    run_slice_26_phase setup
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    : >"${RELAUNCH_LOG}"
    run_slice_26_phase proof | tee "${DRAG_RUN_LOG}"

    local ZONES_BEFORE_DRAG="${ARTIFACTS_DIR}/logs/slice-26-zones-before.log"
    local ZONES_AFTER_DRAG="${ARTIFACTS_DIR}/logs/slice-26-zones-after.log"
    local WINDOWS_AFTER_DRAG="${ARTIFACTS_DIR}/logs/slice-26-windows-after.log"
    test -s "${ZONES_BEFORE_DRAG}"
    test -s "${ZONES_AFTER_DRAG}"
    test -s "${WINDOWS_AFTER_DRAG}"

    local before_left before_main before_right
    local dragged_left dragged_main dragged_right
    before_left="$(zone_field "${ZONES_BEFORE_DRAG}" left effective)"
    before_main="$(zone_field "${ZONES_BEFORE_DRAG}" main effective)"
    before_right="$(zone_field "${ZONES_BEFORE_DRAG}" right effective)"
    dragged_left="$(zone_field "${ZONES_AFTER_DRAG}" left effective)"
    dragged_main="$(zone_field "${ZONES_AFTER_DRAG}" main effective)"
    dragged_right="$(zone_field "${ZONES_AFTER_DRAG}" right effective)"
    assert_float_gt "${dragged_main}" "${before_main}" 'Work/main width did not grow during delegated divider drag'
    assert_float_lt "${dragged_right}" "${before_right}" 'Comms/right width did not shrink during delegated divider drag'
    assert_float_approximately_equal "${dragged_left}" "${before_left}" 0.001 \
        'Reference/left width changed during delegated adjacent divider drag'

    {
        printf 'phase\tzone-id\tzone-name\tconfigured\teffective\tpixel-width\tchip\n'
    } >"${MEASUREMENTS}"
    append_measurements before "${ZONES_BEFORE_DRAG}"
    append_measurements dragged "${ZONES_AFTER_DRAG}"

    local before_save_sha after_save_sha backup_sha backup_path
    before_save_sha="$(config_sha256 "${CONFIG}")"
    printf '%s\n' "${before_save_sha}" >"${CONFIG_SHA_BEFORE_SAVE}"

    wait_until_seconds 39
    local save_offset
    save_offset="${SECONDS}"
    echo "save-command-offset-seconds=${save_offset}" >>"${TIMING_LOG}"
    {
        echo '$ winmux save-zone-layout'
        "${CLI}" save-zone-layout
    } | tee "${SAVE_LOG}"
    backup_path="$(backup_path_from_save_log "${SAVE_LOG}")"
    test -n "${backup_path}"
    test -f "${backup_path}"
    printf '%s\n' "${backup_path}" >"${BACKUP_PATH_LOG}"
    /bin/cp "${backup_path}" "${CONFIG_BACKUP_COPY}"
    /bin/cp "${CONFIG}" "${CONFIG_AFTER_COPY}"
    after_save_sha="$(config_sha256 "${CONFIG}")"
    backup_sha="$(config_sha256 "${CONFIG_BACKUP_COPY}")"
    printf '%s\n' "${after_save_sha}" >"${CONFIG_SHA_AFTER_SAVE}"
    printf '%s\n' "${backup_sha}" >"${BACKUP_SHA}"
    [ "${after_save_sha}" != "${before_save_sha}" ] || semantic_fail 'save-zone-layout did not change config after divider drag'
    assert_equal "${backup_sha}" "${before_save_sha}" 'backup config does not match pre-save config'
    write_zones_log "${ZONES_AFTER_SAVE}"
    append_measurements saved "${ZONES_AFTER_SAVE}"
    capture_guest_screenshot '08-after-save-slice-32'

    local saved_left saved_main saved_right
    saved_left="$(zone_field "${ZONES_AFTER_SAVE}" left effective)"
    saved_main="$(zone_field "${ZONES_AFTER_SAVE}" main effective)"
    saved_right="$(zone_field "${ZONES_AFTER_SAVE}" right effective)"
    assert_float_approximately_equal "${saved_left}" "${dragged_left}" 0.000001 \
        'Saved Reference effective width does not match dragged width'
    assert_float_approximately_equal "${saved_main}" "${dragged_main}" 0.000001 \
        'Saved Work effective width does not match dragged width'
    assert_float_approximately_equal "${saved_right}" "${dragged_right}" 0.000001 \
        'Saved Comms effective width does not match dragged width'

    wait_until_seconds 49
    local quit_offset
    quit_offset="${SECONDS}"
    echo "quit-command-offset-seconds=${quit_offset}" >>"${TIMING_LOG}"
    stop_winmux
    capture_guest_screenshot '09-after-quit-slice-32'

    wait_until_seconds 59
    local relaunch_offset
    relaunch_offset="${SECONDS}"
    echo "relaunch-command-offset-seconds=${relaunch_offset}" >>"${TIMING_LOG}"
    relaunch_winmux
    sleep 4

    wait_until_seconds 69
    local list_zones_offset
    list_zones_offset="${SECONDS}"
    echo "list-zones-after-relaunch-offset-seconds=${list_zones_offset}" >>"${TIMING_LOG}"
    write_zones_log "${ZONES_AFTER_RELAUNCH}"
    refresh_window_log "${WINDOWS_AFTER_RELAUNCH}"
    capture_guest_screenshot '10-after-relaunch-slice-32'
    append_measurements relaunched "${ZONES_AFTER_RELAUNCH}"

    local relaunched_left relaunched_main relaunched_right
    relaunched_left="$(zone_field "${ZONES_AFTER_RELAUNCH}" left effective)"
    relaunched_main="$(zone_field "${ZONES_AFTER_RELAUNCH}" main effective)"
    relaunched_right="$(zone_field "${ZONES_AFTER_RELAUNCH}" right effective)"
    assert_float_approximately_equal "${relaunched_left}" "${dragged_left}" 0.000001 \
        'Relaunched Reference width does not match dragged saved width'
    assert_float_approximately_equal "${relaunched_main}" "${dragged_main}" 0.000001 \
        'Relaunched Work width does not match dragged saved width'
    assert_float_approximately_equal "${relaunched_right}" "${dragged_right}" 0.000001 \
        'Relaunched Comms width does not match dragged saved width'
    assert_float_approximately_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" left configured)" "${dragged_left}" 0.000001 \
        'Relaunched Reference configured width does not match dragged width'
    assert_float_approximately_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" main configured)" "${dragged_main}" 0.000001 \
        'Relaunched Work configured width does not match dragged width'
    assert_float_approximately_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" right configured)" "${dragged_right}" 0.000001 \
        'Relaunched Comms configured width does not match dragged width'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" left override-state)" configured \
        'Relaunched Reference should use configured width, not a runtime override'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" main override-state)" configured \
        'Relaunched Work should use configured width, not a runtime override'
    assert_equal "$(zone_field "${ZONES_AFTER_RELAUNCH}" right override-state)" configured \
        'Relaunched Comms should use configured width, not a runtime override'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH}" left override)" \
        'Relaunched Reference should not retain a runtime override value'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH}" main override)" \
        'Relaunched Work should not retain a runtime override value'
    assert_empty_or_none "$(zone_field "${ZONES_AFTER_RELAUNCH}" right override)" \
        'Relaunched Comms should not retain a runtime override value'
    grep -F 'stopped=yes' "${RELAUNCH_LOG}" >/dev/null \
        || semantic_fail 'relaunch log does not prove WinMux stopped'
    assert_startup_trace_loaded_relaunch_state

    assert_window_zone "${WINDOWS_AFTER_RELAUNCH}" 'reference-divider.rtf' left
    assert_window_zone "${WINDOWS_AFTER_RELAUNCH}" 'work-divider.rtf' main
    assert_window_zone "${WINDOWS_AFTER_RELAUNCH}" 'comms-divider.rtf' right

    write_proof_manifest
    cat \
        "${ZONES_BEFORE_DRAG}" "${ZONES_AFTER_DRAG}" "${SAVE_LOG}" "${RELAUNCH_LOG}" \
        "${ZONES_AFTER_SAVE}" "${ZONES_AFTER_RELAUNCH}" "${WINDOWS_AFTER_RELAUNCH}" \
        >"${CLI_LOG}"

    {
        echo 'WinMux Slice 32: save and relaunch a dragged divider layout'
        echo
        echo 'Drag source proof: logs/slice-26-zone-divider-drag.proof-manifest.tsv'
        echo "measurement-before=$(measurement_chip_for_log "${ZONES_BEFORE_DRAG}")"
        echo "measurement-dragged=$(measurement_chip_for_log "${ZONES_AFTER_DRAG}")"
        echo "measurement-relaunched=$(measurement_chip_for_log "${ZONES_AFTER_RELAUNCH}")"
        echo "backup-path=${backup_path}"
        echo "config-sha-before-save=${before_save_sha}"
        echo "config-sha-after-save=${after_save_sha}"
        echo "config-backup-sha=${backup_sha}"
        cat "${TIMING_LOG}"
        echo
        echo 'PASS: dragging the Work|Comms divider, running save-zone-layout, and relaunching WinMux restores the dragged widths as configured layout widths without another resize command.'
    } >"${PROOF}"

    {
        echo 'result=success'
        echo 'failure_count=0'
        echo 'final_result=success'
    } | tee "${DONE}"
    copy_runtime_logs
}

self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/logs"
    WINMUX_E2E_SLICE26_PHASE=self-test \
        REPO_DIR="${REPO_DIR}" \
        ARTIFACTS_DIR="${ARTIFACTS_DIR}" \
        /bin/bash "${SLICE26_SCRIPT}" >/dev/null

    local ZONES_BEFORE_DRAG="${ARTIFACTS_DIR}/logs/slice-26-zones-before.log"
    local ZONES_AFTER_DRAG="${ARTIFACTS_DIR}/logs/slice-26-zones-after.log"
    local ZONES_AFTER_RELAUNCH="${ARTIFACTS_DIR}/logs/slice-32-zones-after-relaunch.log"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Research|left=64.0|width=844.0|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.5|override=|override-state=configured|workspace=Draft|left=908.0|width=1688.0|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Inbox|left=2596.0|width=844.0|physical=1' \
        >"${ZONES_BEFORE_DRAG}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Research|left=64.0|width=844.0|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.5|effective=0.575|override=0.575|override-state=runtime|workspace=Draft|left=908.0|width=1941.2|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.25|effective=0.175|override=0.175|override-state=runtime|workspace=Inbox|left=2849.2|width=590.8|physical=1' \
        >"${ZONES_AFTER_DRAG}"
    printf '%s\n' \
        'zone=left|name=Reference|layout=balanced|enabled=true|configured=0.25|effective=0.25|override=|override-state=configured|workspace=Research|left=64.0|width=844.0|physical=1' \
        'zone=main|name=Work|layout=balanced|enabled=true|configured=0.575|effective=0.575|override=|override-state=configured|workspace=Draft|left=908.0|width=1941.2|physical=1' \
        'zone=right|name=Comms|layout=balanced|enabled=true|configured=0.175|effective=0.175|override=|override-state=configured|workspace=Inbox|left=2849.2|width=590.8|physical=1' \
        >"${ZONES_AFTER_RELAUNCH}"
    assert_equal "$(measurement_chip_for_log "${ZONES_AFTER_DRAG}")" 'Reference 25% | Work 57.5% | Comms 17.5%' \
        'measurement chip did not render dragged divider widths'
    printf 'phase\tzone-id\tzone-name\tconfigured\teffective\tpixel-width\tchip\n' >"${MEASUREMENTS}"
    append_measurements dragged "${ZONES_AFTER_DRAG}"
    append_measurements relaunched "${ZONES_AFTER_RELAUNCH}"
    printf 'result=success\n'
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
        echo "Unknown Slice 32 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
