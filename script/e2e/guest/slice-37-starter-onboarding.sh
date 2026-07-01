#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE37_PHASE:-proof}"
SOURCE_APP="${REPO_DIR}/.debug/WinMuxApp"
SOURCE_CLI="${REPO_DIR}/.debug/winmux"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
STARTER_CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
UNCOMMENTED_CONFIG="${ARTIFACTS_DIR}/logs/slice-37-starter-config-uncommented.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-37-starter-onboarding"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice37-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice37-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice37"
LAUNCH_PLIST="/tmp/winmux-e2e-slice37.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice37.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-37-setup.log"
CONFIG_BEFORE_COPY="${ARTIFACTS_DIR}/logs/slice-37-starter-config-before.toml"
CONFIG_CHECK_LOG="${ARTIFACTS_DIR}/logs/slice-37-config-check.log"
LIST_ZONES_LOG="${ARTIFACTS_DIR}/logs/slice-37-list-zones.log"
FOCUS_ZONE_LOG="${ARTIFACTS_DIR}/logs/slice-37-focus-zone-comms.log"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-37-cli.log"
TIMING_LOG="${ARTIFACTS_DIR}/logs/slice-37-command-timing.log"
VISIBLE_UNCOMMENTED_TEMPLATE="${ARTIFACTS_DIR}/logs/slice-37-visible-uncommented-template.txt"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-37-cli-wait.err"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/slice-37-starter-onboarding-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"
DOC_DIR="${HOME}/winmux-e2e/starter-template-docs"
COMMENTED_DOC="${DOC_DIR}/starter-template-commented.rtf"
UNCOMMENTED_DOC="${DOC_DIR}/starter-template-uncommented.rtf"
RESULT_DOC="${DOC_DIR}/starter-template-result.rtf"

uid="$(/usr/bin/id -u)"

semantic_fail() {
    echo "$*" >&2
    exit 86
}

# shellcheck source=script/e2e/guest/recording-timing-helpers.sh
source "${REPO_DIR}/script/e2e/guest/recording-timing-helpers.sh"

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
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

write_result_doc() {
    {
        printf 'Slice 37: starter ultrawide template\n'
        printf '\n'
        printf '$ winmux config --check %s\n' "${UNCOMMENTED_CONFIG}"
        cat "${CONFIG_CHECK_LOG}"
        printf '\n'
        printf "$ winmux list-zones --format 'zone=%%{monitor-zone-id}|name=%%{monitor-zone-name}'\n"
        cat "${LIST_ZONES_LOG}"
        printf '\n'
        printf '$ winmux focus-zone Comms\n'
        cat "${FOCUS_ZONE_LOG}"
        printf '\n'
        printf 'Next step: use zone-mode bindings, focus-zone, or move-node-to-zone to work across the columns.\n'
    } >"${ARTIFACTS_DIR}/logs/slice-37-visible-result.txt"
    write_text_doc "${ARTIFACTS_DIR}/logs/slice-37-visible-result.txt" \
        'Uncommented template validates and creates zones' \
        "${RESULT_DOC}"
}

write_visible_uncommented_template() {
    /bin/bash "${REPO_DIR}/script/e2e/write-visible-proof-excerpt" \
        --input "${UNCOMMENTED_CONFIG}" \
        --output "${VISIBLE_UNCOMMENTED_TEMPLATE}" \
        --title 'Active TOML excerpt from the uncommented WINMUX ULTRAWIDE ZONES TEMPLATE' \
        --required-table-regex '^[[:space:]]*\[\[zones\]\]' \
        --max-table-line 12 \
        --binding-table '[mode.zone.binding]' \
        --binding-keys 'tab a y c' \
        --forbid-regex '^[[:space:]]*# ?\[\[zones\]\]' \
        --summary 'Resulting named columns from the active layout: Reference | Work | Comms'
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

uncomment_template() {
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
    ' "${STARTER_CONFIG}" >"${UNCOMMENTED_CONFIG}"
}

write_zones_log() {
    "${CLI}" list-zones \
        --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|layout=%{monitor-zone-layout-id}|enabled=%{monitor-zone-enabled}|configured=%{monitor-zone-configured-width}|effective=%{monitor-zone-effective-width}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}' \
        >"${LIST_ZONES_LOG}" 2>>"${WAIT_ERR}"
    cat "${LIST_ZONES_LOG}"
}

assert_zone_present() {
    local zone_id="$1"
    local name="$2"
    /usr/bin/grep -F "zone=${zone_id}|name=${name}|" "${LIST_ZONES_LOG}" >/dev/null \
        || semantic_fail "list-zones missing ${zone_id}/${name}"
}

launch_winmux_with_uncommented_config() {
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
        <string>${UNCOMMENTED_CONFIG}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>WINMUX_DEFAULT_CONFIG_PATH</key>
        <string>${UNCOMMENTED_CONFIG}</string>
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
        copy_runtime_logs
        if "${CLI}" list-zones --count >"${ARTIFACTS_DIR}/logs/slice-37-zone-count.txt" 2>"${WAIT_ERR}"; then
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
        "${SETUP_LOG}" "${CONFIG_BEFORE_COPY}" "${UNCOMMENTED_CONFIG}" "${CONFIG_CHECK_LOG}" \
        "${LIST_ZONES_LOG}" "${FOCUS_ZONE_LOG}" "${CLI_LOG}" "${TIMING_LOG}" "${WAIT_ERR}" "${DONE}" "${PROOF}" \
        "${APP_LOG}" "${APP_LOG_LOCAL}" "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" \
        "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" "${LAUNCH_PLIST_COPY}"
    rm -rf "${DOC_DIR}"
    mkdir -p "${BIN_DIR}" "${DOC_DIR}"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    test -f "${STARTER_CONFIG}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    /bin/cp "${STARTER_CONFIG}" "${CONFIG_BEFORE_COPY}"

    grep -F '# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE' "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'starter config missing template begin marker'
    grep -F "# [[zones]]" "${CONFIG_BEFORE_COPY}" >/dev/null \
        || semantic_fail 'starter config missing commented zones template'
    if grep -E '^[[:space:]]*\[\[zones\]\]' "${CONFIG_BEFORE_COPY}" >/dev/null; then
        semantic_fail 'starter config should not enable zones before uncommenting'
    fi

    /usr/bin/awk '
        /# BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE/ { show = 1 }
        show == 1 { print }
        /# END WINMUX ULTRAWIDE ZONES TEMPLATE/ { exit }
    ' "${CONFIG_BEFORE_COPY}" >"${ARTIFACTS_DIR}/logs/slice-37-visible-commented-template.txt"
    write_text_doc "${ARTIFACTS_DIR}/logs/slice-37-visible-commented-template.txt" \
        'Commented starter template in generated config' \
        "${COMMENTED_DOC}"
    /usr/bin/open -a TextEdit "${COMMENTED_DOC}"
    sleep 3

    {
        echo 'WinMux Slice 37: starter onboarding companion'
        echo "Starter config: ${STARTER_CONFIG}"
        echo "Template marker: WINMUX ULTRAWIDE ZONES TEMPLATE"
        echo 'Commands: uncomment template; winmux config --check; winmux list-zones; winmux focus-zone Comms'
        echo 'setup=result=success'
    } | tee "${SETUP_LOG}"
}

proof_slice() {
    SECONDS=0
    : >"${TIMING_LOG}"
    sleep_until_recording_offset 8 17 "Action: uncomment WINMUX ULTRAWIDE ZONES TEMPLATE"
    echo "uncomment-template-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
    uncomment_template
    grep -E '^[[:space:]]*\[\[zones\]\]' "${UNCOMMENTED_CONFIG}" >/dev/null \
        || semantic_fail 'uncommented config missing active [[zones]]'
    grep -F "tab = ['cycle-zone-layout balanced focus', 'mode main']" "${UNCOMMENTED_CONFIG}" >/dev/null \
        || semantic_fail 'uncommented config missing zone mode layout binding'
    write_visible_uncommented_template
    write_text_doc "${VISIBLE_UNCOMMENTED_TEMPLATE}" \
        'Uncommented template is now active TOML' \
        "${UNCOMMENTED_DOC}"
    /usr/bin/open -a TextEdit "${UNCOMMENTED_DOC}"
    sleep 3
    capture_guest_screenshot '02-template-uncommented-slice-37'
    sleep 6

    sleep_until_recording_offset 17 30 "Run: WinMuxApp --config-path slice-37-starter-config-uncommented.toml"
    echo "launch-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    launch_winmux_with_uncommented_config

    sleep_until_recording_offset 30 38 "Run: winmux config --check slice-37-starter-config-uncommented.toml"
    echo "config-check-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "\$ winmux config --check ${UNCOMMENTED_CONFIG}"
        "${CLI}" config --check "${UNCOMMENTED_CONFIG}"
    } | tee "${CONFIG_CHECK_LOG}"
    grep -F 'Config OK:' "${CONFIG_CHECK_LOG}" >/dev/null \
        || semantic_fail 'config --check did not report success'

    sleep_until_recording_offset 38 48 "Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
    echo "list-zones-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo "$ winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'"
        write_zones_log
    } | tee "${CLI_LOG}"
    assert_zone_present left Reference
    assert_zone_present main Work
    assert_zone_present right Comms

    sleep_until_recording_offset 48 60 "Run: winmux focus-zone Comms"
    echo "focus-zone-offset-seconds=${SECONDS}" >>"${TIMING_LOG}"
    {
        echo '$ winmux focus-zone Comms'
        "${CLI}" focus-zone Comms
        echo 'focus-zone=Comms'
        echo 'result=success'
    } | tee "${FOCUS_ZONE_LOG}"
    cat "${FOCUS_ZONE_LOG}" >>"${CLI_LOG}"
    write_result_doc
    /usr/bin/open -a TextEdit "${RESULT_DOC}"
    sleep 6
    capture_guest_screenshot '03-config-check-and-zones-slice-37'
    sleep 8

    cat >"${PROOF}" <<PROOF_TEXT
PASS: starter config keeps zones commented by default, the WINMUX ULTRAWIDE ZONES TEMPLATE uncomments into parseable TOML, WinMux lists Reference, Work, and Comms zones after launch, and the user-facing focus-zone Comms command runs against the new zones.

config-check:
$(cat "${CONFIG_CHECK_LOG}")

list-zones:
$(cat "${LIST_ZONES_LOG}")

focus-zone:
$(cat "${FOCUS_ZONE_LOG}")
PROOF_TEXT
    echo 'result=success' >"${DONE}"
}

self_test() {
    mkdir -p "$(dirname "${STARTER_CONFIG}")" "$(dirname "${UNCOMMENTED_CONFIG}")"
    cat >"${STARTER_CONFIG}" <<'TOML'
[mode.zone.binding]
    s = ['cycle-zone-snap-policy freeform snap-to-zone', 'mode main']
    # BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE
    # tab = ['cycle-zone-layout balanced focus', 'mode main']
    # a = ['cycle-zone-availability focus-only communications full-dashboard', 'mode main']
    # y = ['cycle-zone-style current urgent calm', 'mode main']
    # c = ['cycle-zone-scene triage deep-work', 'mode main']

# [[zones]]
# monitor = 1
# layout-preset = 'balanced'
# END WINMUX ULTRAWIDE ZONES TEMPLATE
TOML

    uncomment_template
    grep -F "tab = ['cycle-zone-layout balanced focus', 'mode main']" "${UNCOMMENTED_CONFIG}" >/dev/null \
        || semantic_fail 'self-test uncommented config missing tab binding'
    grep -E '^[[:space:]]*\[\[zones\]\]' "${UNCOMMENTED_CONFIG}" >/dev/null \
        || semantic_fail 'self-test uncommented config missing active zones table'
    if grep -F '# [[zones]]' "${UNCOMMENTED_CONFIG}" >/dev/null; then
        semantic_fail 'self-test uncommented config kept commented zones table'
    fi
    write_visible_uncommented_template
    local active_table_line
    active_table_line="$(/usr/bin/grep -En '^[[:space:]]*\[\[zones\]\]' "${VISIBLE_UNCOMMENTED_TEMPLATE}" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)"
    [ -n "$active_table_line" ] && [ "$active_table_line" -le 12 ] \
        || semantic_fail 'self-test visible excerpt missing active [[zones]] within first 12 lines'
    for key in tab a y c; do
        grep -E "^[[:space:]]*${key} = " "${VISIBLE_UNCOMMENTED_TEMPLATE}" >/dev/null \
            || semantic_fail "self-test visible excerpt missing ${key} binding"
    done
    grep -F 'Reference | Work | Comms' "${VISIBLE_UNCOMMENTED_TEMPLATE}" >/dev/null \
        || semantic_fail 'self-test visible excerpt missing named-column summary'
    if grep -F '# [[zones]]' "${VISIBLE_UNCOMMENTED_TEMPLATE}" >/dev/null; then
        semantic_fail 'self-test visible excerpt kept commented zones table'
    fi
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
        self_test
        ;;
    *)
        echo "Unknown Slice 37 phase: ${PHASE}" >&2
        exit 64
        ;;
esac
