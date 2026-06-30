#!/usr/bin/env bash

ensure_window_in_zone() {
    local id="$1"
    local title="$2"
    local zone_name="$3"
    local expected_zone="$4"
    local window_log="${5:-${WINDOW_SETUP_LOG:?}}"
    local cli_log="${6:-${CLI_LOG:?}}"

    refresh_window_log "$window_log"
    local actual_zone
    actual_zone="$(field_for_title "$window_log" "$title" zone)"
    if [ "$actual_zone" = "$expected_zone" ]; then
        {
            echo "setup: ${title} already in zone ${expected_zone}; no setup move needed"
            echo "setup: skipped move-node-to-zone --window-id ${id} ${zone_name}"
        } | tee -a "$cli_log"
        return
    fi

    {
        echo "setup: ${title} -> ${zone_name}"
        echo "$ winmux move-node-to-zone --window-id ${id} ${zone_name}"
        "${CLI}" move-node-to-zone --window-id "${id}" "${zone_name}"
    } | tee -a "$cli_log"
    refresh_window_log "$window_log"
    assert_window_zone "$window_log" "$title" "$expected_zone"
}

zone_window_helpers_self_test() {
    local tmp_dir="${1:-}"
    if [ -z "$tmp_dir" ]; then
        tmp_dir="$(mktemp -d)"
    else
        mkdir -p "$tmp_dir"
    fi
    local state_file="${tmp_dir}/zone-state.txt"
    local cli_invocations="${tmp_dir}/cli-invocations.log"
    local cli_log="${tmp_dir}/cli.log"
    local window_log="${tmp_dir}/windows.log"
    local cli_stub="${tmp_dir}/winmux-stub"

    cat >"$cli_stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${ZONE_WINDOW_HELPERS_SELF_TEST_INVOCATIONS:?}"
printf 'main\n' >"${ZONE_WINDOW_HELPERS_SELF_TEST_STATE:?}"
SH
    chmod +x "$cli_stub"

    refresh_window_log() {
        local out="$1"
        local zone
        zone="$(cat "$state_file")"
        printf '1|demo.rtf|zone=%s|workspace=work|monitor=Main\n' "$zone" >"$out"
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

    assert_window_zone() {
        local path="$1"
        local title="$2"
        local expected_zone="$3"
        local actual_zone
        actual_zone="$(field_for_title "$path" "$title" zone)"
        [ "$actual_zone" = "$expected_zone" ] || {
            printf 'expected %s in %s, got %s\n' "$title" "$expected_zone" "${actual_zone:-missing}" >&2
            return 1
        }
    }

    export ZONE_WINDOW_HELPERS_SELF_TEST_STATE="$state_file"
    export ZONE_WINDOW_HELPERS_SELF_TEST_INVOCATIONS="$cli_invocations"
    CLI="$cli_stub"

    printf 'main\n' >"$state_file"
    : >"$cli_invocations"
    : >"$cli_log"
    ensure_window_in_zone 1 demo.rtf Work main "$window_log" "$cli_log"
    [ ! -s "$cli_invocations" ] || {
        printf 'ensure_window_in_zone invoked CLI for no-op setup\n' >&2
        return 1
    }
    grep -F 'no setup move needed' "$cli_log" >/dev/null \
        || {
            printf 'ensure_window_in_zone did not log no-op setup\n' >&2
            return 1
        }

    printf 'left\n' >"$state_file"
    ensure_window_in_zone 1 demo.rtf Work main "$window_log" "$cli_log"
    grep -F 'move-node-to-zone --window-id 1 Work' "$cli_invocations" >/dev/null \
        || {
            printf 'ensure_window_in_zone did not invoke CLI for wrong-zone setup\n' >&2
            return 1
        }
    grep -F 'setup: demo.rtf -> Work' "$cli_log" >/dev/null \
        || {
            printf 'ensure_window_in_zone did not log intentional setup move\n' >&2
            return 1
        }

    printf 'result=success\n'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${WINMUX_E2E_ZONE_WINDOW_HELPERS_PHASE:-}" in
        self-test)
            zone_window_helpers_self_test "${ARTIFACTS_DIR:-}"
            ;;
        "")
            ;;
        *)
            echo "Unknown zone-window-helpers phase: ${WINMUX_E2E_ZONE_WINDOW_HELPERS_PHASE}" >&2
            exit 64
            ;;
    esac
fi
