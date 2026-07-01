#!/usr/bin/env bash

recording_timing_fail() {
    if declare -F semantic_fail >/dev/null 2>&1; then
        semantic_fail "$*"
    fi
    echo "$*" >&2
    exit 86
}

recording_timing_now() {
    printf '%s\n' "${WINMUX_E2E_TIMING_NOW:-${SECONDS:-0}}"
}

recording_timing_is_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

recording_timing_sleep() {
    local duration="$1"
    if [ -n "${WINMUX_E2E_TIMING_SLEEP_LOG:-}" ]; then
        printf '%s\n' "$duration" >>"${WINMUX_E2E_TIMING_SLEEP_LOG}"
        if [ -n "${WINMUX_E2E_TIMING_NOW:-}" ]; then
            WINMUX_E2E_TIMING_NOW="$(
                /usr/bin/awk -v now="${WINMUX_E2E_TIMING_NOW}" -v duration="$duration" \
                    'BEGIN { printf "%.3f\n", now + duration }'
            )"
            export WINMUX_E2E_TIMING_NOW
        fi
        return 0
    fi
    sleep "$duration"
}

sleep_until_recording_offset() {
    local start="$1"
    local end="$2"
    local label="$3"
    local now duration

    recording_timing_is_number "$start" \
        || recording_timing_fail "caption start for ${label} is not numeric: ${start}"
    recording_timing_is_number "$end" \
        || recording_timing_fail "caption end for ${label} is not numeric: ${end}"
    /usr/bin/awk -v start="$start" -v end="$end" 'BEGIN { exit(start <= end ? 0 : 1) }' \
        || recording_timing_fail "caption window for ${label} is invalid: ${start}-${end}"

    now="$(recording_timing_now)"
    recording_timing_is_number "$now" \
        || recording_timing_fail "recording clock for ${label} is not numeric: ${now}"
    /usr/bin/awk -v now="$now" -v end="$end" 'BEGIN { exit(now <= end ? 0 : 1) }' \
        || recording_timing_fail "already past caption window for ${label}: now=${now}, end=${end}"

    if /usr/bin/awk -v now="$now" -v start="$start" 'BEGIN { exit(now < start ? 0 : 1) }'; then
        duration="$(
            /usr/bin/awk -v now="$now" -v start="$start" \
                'BEGIN { printf "%.3f\n", start - now }'
        )"
        recording_timing_sleep "$duration"
    fi

    now="$(recording_timing_now)"
    /usr/bin/awk -v now="$now" -v start="$start" -v end="$end" \
        'BEGIN { exit(now >= start && now <= end ? 0 : 1) }' \
        || recording_timing_fail "not inside caption window for ${label}: now=${now}, window=${start}-${end}"
}

recording_timing_helpers_self_test() {
    local tmp_dir="${1:-}"
    if [ -z "$tmp_dir" ]; then
        tmp_dir="$(mktemp -d)"
    else
        mkdir -p "$tmp_dir"
    fi

    local sleep_log="${tmp_dir}/recording-timing-sleeps.log"
    : >"$sleep_log"

    WINMUX_E2E_TIMING_NOW=2
    WINMUX_E2E_TIMING_SLEEP_LOG="$sleep_log"
    export WINMUX_E2E_TIMING_NOW WINMUX_E2E_TIMING_SLEEP_LOG

    sleep_until_recording_offset 5 10 "self-test delayed action"
    grep -Fx '3.000' "$sleep_log" >/dev/null \
        || recording_timing_fail "self-test did not sleep until the caption start"
    [ "$WINMUX_E2E_TIMING_NOW" = "5.000" ] \
        || recording_timing_fail "self-test clock did not advance to caption start"

    sleep_until_recording_offset 5 10 "self-test in-window action"
    [ "$(wc -l <"$sleep_log" | tr -d ' ')" = "1" ] \
        || recording_timing_fail "self-test slept while already inside the caption window"

    if (
        WINMUX_E2E_TIMING_NOW=11
        WINMUX_E2E_TIMING_SLEEP_LOG="$sleep_log"
        export WINMUX_E2E_TIMING_NOW WINMUX_E2E_TIMING_SLEEP_LOG
        sleep_until_recording_offset 5 10 "self-test late action"
    ) >/dev/null 2>&1; then
        recording_timing_fail "self-test late action unexpectedly passed"
    fi

    if (
        WINMUX_E2E_TIMING_NOW=1
        WINMUX_E2E_TIMING_SLEEP_LOG="$sleep_log"
        export WINMUX_E2E_TIMING_NOW WINMUX_E2E_TIMING_SLEEP_LOG
        sleep_until_recording_offset 12 10 "self-test invalid window"
    ) >/dev/null 2>&1; then
        recording_timing_fail "self-test invalid caption window unexpectedly passed"
    fi

    printf 'result=success\n'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${WINMUX_E2E_RECORDING_TIMING_HELPERS_PHASE:-}" in
        self-test)
            recording_timing_helpers_self_test "${ARTIFACTS_DIR:-}"
            ;;
        "")
            ;;
        *)
            echo "Unknown recording-timing-helpers phase: ${WINMUX_E2E_RECORDING_TIMING_HELPERS_PHASE}" >&2
            exit 64
            ;;
    esac
fi
