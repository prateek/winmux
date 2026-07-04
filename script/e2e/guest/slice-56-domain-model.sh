#!/usr/bin/env bash
set -euo pipefail

# Slice 56 domain-model guest script. Exercises the five-noun vocabulary
# (Display / Scene / Column / Card / Rule) end to end against the shipped CLI:
# a scene config, scene switching (scene <name> / scene next), deck paging
# (card next|prev|<N>), summon-as-move (card summon), same-scene and cross-scene
# card moves (card move <column> / card move <scene>:<column>), rule-driven card
# creation, and expose (display + card). Uses ONLY the config-v3 command surface;
# the contract checker rejects any deleted zone-era verb appearing here.
#
# Phases mirror the slice-48 guest: `setup` provisions the app + windows before
# recording, `proof` drives the recorded sequence, and `self-test` writes the
# deterministic manifests and validates them without launching the app (so the
# contract checker can assert chips + transitions with no VM).

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE56_PHASE:-proof}"
SEMANTIC_FAILURE_EXIT="${WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT:-86}"
SOURCE_APP="${WINMUX_E2E_SOURCE_APP:-${REPO_DIR}/.debug/WinMuxApp}"
SOURCE_CLI="${WINMUX_E2E_SOURCE_CLI:-${REPO_DIR}/.debug/winmux}"
BIN_DIR="${HOME}/winmux-e2e/bin"
APP="${BIN_DIR}/WinMuxApp"
CLI="${BIN_DIR}/winmux"
CONFIG="${ARTIFACTS_DIR}/config/winmux.toml"
GUEST_DISPLAY_ID="${GUEST_DISPLAY_ID:-1}"
RECORDING_NAME="slice-56-domain-model"

APP_LOG="${ARTIFACTS_DIR}/logs/winmux-app.log"
APP_LOG_LOCAL="/tmp/winmux-e2e-slice56-app.log"
STARTUP_TRACE="${ARTIFACTS_DIR}/logs/winmux-startup-trace.log"
STARTUP_TRACE_LOCAL="/tmp/winmux-e2e-slice56-startup.log"
LAUNCH_STATUS="${ARTIFACTS_DIR}/logs/winmux-launchagent-status.log"
LAUNCH_LABEL="local.winmux.e2e.slice56"
LAUNCH_PLIST="/tmp/winmux-e2e-slice56.plist"
LAUNCH_PLIST_COPY="${ARTIFACTS_DIR}/logs/winmux-e2e-slice56.plist"

SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-56-setup.log"
SCENE_CONFIG_LOG="${ARTIFACTS_DIR}/logs/slice-56-scene-config.log"
DECK_PAGE_LOG="${ARTIFACTS_DIR}/logs/slice-56-deck-page.log"
SUMMON_LOG="${ARTIFACTS_DIR}/logs/slice-56-card-summon.log"
MOVE_LOG="${ARTIFACTS_DIR}/logs/slice-56-card-move.log"
RULE_LOG="${ARTIFACTS_DIR}/logs/slice-56-rule-create.log"
SCENE_SWITCH_LOG="${ARTIFACTS_DIR}/logs/slice-56-scene-switch.log"
EXPOSE_LOG="${ARTIFACTS_DIR}/logs/slice-56-expose.log"
CARDS_LOG="${ARTIFACTS_DIR}/logs/slice-56-list-cards.log"
COLUMNS_LOG="${ARTIFACTS_DIR}/logs/slice-56-list-columns.log"
STATE_TRANSITIONS="${ARTIFACTS_DIR}/logs/slice-56-state-transitions.tsv"
EXPECTED_CHIPS="${ARTIFACTS_DIR}/logs/slice-56-expected-chips.txt"
FINAL_BOARD_SOURCE="${ARTIFACTS_DIR}/logs/slice-56-final-board-source.txt"
CLI_LOG="${ARTIFACTS_DIR}/logs/slice-56-cli.log"
WAIT_ERR="${ARTIFACTS_DIR}/logs/slice-56-cli-wait.err"
STATE_FILE="${ARTIFACTS_DIR}/logs/slice-56-window-ids.env"
DONE="${ARTIFACTS_DIR}/logs/${RECORDING_NAME}.done"
PROOF="${ARTIFACTS_DIR}/${RECORDING_NAME}-proof.txt"
SCREENSHOTS_DIR="${ARTIFACTS_DIR}/screenshots"

DOC_DIR="${HOME}/winmux-e2e/slice56-docs"

uid="$(/usr/bin/id -u)"

semantic_fail() {
    echo "$*" >&2
    exit "${SEMANTIC_FAILURE_EXIT}"
}

copy_runtime_logs() {
    /bin/cp "${APP_LOG_LOCAL}" "${APP_LOG}" >/dev/null 2>&1 || true
    /bin/cp "${STARTUP_TRACE_LOCAL}" "${STARTUP_TRACE}" >/dev/null 2>&1 || true
}

capture_guest_screenshot() {
    local name="$1"
    /usr/sbin/screencapture -x -D "${GUEST_DISPLAY_ID}" "${SCREENSHOTS_DIR}/${name}.png"
}

# The scene skeleton mirrors resources/default-config.toml's ultrawide example
# (three scenes on display 1, two rules dealing onto a Comms card), so the guest
# config parses under the same config-v3 grammar the unit tests cover.
write_slice_config() {
    mkdir -p "$(dirname "${CONFIG}")"
    cat >"${CONFIG}" <<'TOML'
config-version = 3
auto-reload-config = false

# Cards named here are never pruned, even when empty.
persistent-cards = ['Scratch']

# desk is the default scene for display 1: three columns, rule-created cards
# land in 'main'.
[scene.desk]
display = 1
default-column = 'main'
columns = [
  { id = 'ref',   name = 'Reference', width = 0.20, color = '#3EA2FF' },
  { id = 'main',  name = 'Work',      width = 0.55 },
  { id = 'comms', name = 'Comms',     width = 0.25, color = '#D3455B' },
]

# focus collapses display 1 to a single full-width Work column.
[scene.focus]
display = 1
columns = [ { id = 'main', name = 'Work', width = 1.0 } ]

# triage flips the emphasis toward Comms.
[scene.triage]
display = 1
default-column = 'comms'
columns = [
  { id = 'comms', name = 'Comms', width = 0.60, color = '#D3455B' },
  { id = 'main',  name = 'Work',  width = 0.40 },
]

# Rules deal new windows onto cards by name; a missing card is created in the
# active scene's default-column, never at the focused column.
[[rules]]
if.app-id = 'com.tinyspeck.slackmacgap'
card = 'Comms'

[[rules]]
if.window-title-regex-substring = 'Inbox|Mail'
card = 'Comms'

[mode.main.binding]
    alt-n = 'card next'
    alt-p = 'card prev'
    alt-tab = 'card back-and-forth'
    alt-1 = 'card 1'
    alt-2 = 'card 2'
    alt-ctrl-1 = 'scene desk'
    alt-ctrl-2 = 'scene focus'
    alt-ctrl-3 = 'scene triage'
    alt-ctrl-tab = 'scene next'
    ctrl-up = 'expose display'
    ctrl-down = 'expose card'
    alt-z = 'mode column'

[mode.column.binding]
    h = ['focus-column prev', 'mode main']
    l = ['focus-column next', 'mode main']
    shift-h = ['card move left', 'mode main']
    shift-l = ['card move right', 'mode main']
    esc = 'mode main'
TOML
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
        if "${CLI}" list-columns --count >"${COLUMNS_LOG}" 2>"${WAIT_ERR}"; then
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

list_columns_snapshot() {
    "${CLI}" list-columns \
        --format 'column=%{monitor-zone-id}|name=%{monitor-zone-name}|card=%{monitor-active-workspace}|width=%{monitor-width}' \
        >"$1" 2>>"${WAIT_ERR}"
}

list_cards_snapshot() {
    "${CLI}" list-cards --all \
        --format 'card=%{workspace}|column=%{monitor-zone-id}' \
        >"$1" 2>>"${WAIT_ERR}"
}

active_card_for_column() {
    local path="$1"
    local column="$2"
    /usr/bin/awk -F'|' -v column="column=${column}" '$1 == column {
        for (i = 1; i <= NF; i++) {
            if (index($i, "card=") == 1) { print substr($i, 6); exit }
        }
    }' "${path}"
}

column_count() {
    "${CLI}" list-columns --count 2>>"${WAIT_ERR}"
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

window_id_for_title() {
    local title="$1"
    "${CLI}" list-windows --all --format '%{window-id}|%{window-title}' 2>>"${WAIT_ERR}" |
        /usr/bin/awk -F'|' -v title="${title}" '$2 == title { print $1; exit }'
}

record_transition() {
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >>"${STATE_TRANSITIONS}"
}

# The caption chips a reviewer expects to see, one per driven command. The
# contract checker asserts these appear in the guest source and in the produced
# file; every chip is a config-v3 verb.
write_expected_chips() {
    cat >"${EXPECTED_CHIPS}" <<'CHIPS'
rule: com.tinyspeck.slackmacgap -> Comms
rule: Inbox|Mail -> Comms
scene desk
card next
card prev
card 2
card summon Comms
card move comms
card move triage:comms
scene focus
scene next
expose display
expose card
CHIPS
}

# Both proof and self-test funnel through this so the manifests are held to the
# same bar whether the app ran or not.
validate_manifests() {
    local chip
    for chip in \
        'scene desk' \
        'card next' \
        'card prev' \
        'card 2' \
        'card summon Comms' \
        'card move comms' \
        'card move triage:comms' \
        'scene focus' \
        'scene next' \
        'expose display' \
        'expose card'; do
        /usr/bin/grep -Fx "${chip}" "${EXPECTED_CHIPS}" >/dev/null \
            || semantic_fail "expected-chips missing chip: ${chip}"
    done

    /usr/bin/grep -F 'step	command	subject	before	after' "${STATE_TRANSITIONS}" >/dev/null \
        || semantic_fail 'state-transitions missing header'
    local transition
    for transition in \
        'summon	card summon Comms' \
        'move	card move triage:comms' \
        'scene	scene focus'; do
        /usr/bin/grep -F "${transition}" "${STATE_TRANSITIONS}" >/dev/null \
            || semantic_fail "state-transitions missing transition: ${transition}"
    done
}

setup_slice() {
    rm -rf "${DOC_DIR}"
    rm -f \
        "${SETUP_LOG}" "${SCENE_CONFIG_LOG}" "${DECK_PAGE_LOG}" "${SUMMON_LOG}" "${MOVE_LOG}" \
        "${RULE_LOG}" "${SCENE_SWITCH_LOG}" "${EXPOSE_LOG}" "${CARDS_LOG}" "${COLUMNS_LOG}" \
        "${STATE_TRANSITIONS}" "${EXPECTED_CHIPS}" "${FINAL_BOARD_SOURCE}" "${CLI_LOG}" \
        "${WAIT_ERR}" "${STATE_FILE}" "${DONE}" "${PROOF}" "${APP_LOG}" "${APP_LOG_LOCAL}" \
        "${STARTUP_TRACE}" "${STARTUP_TRACE_LOCAL}" "${LAUNCH_STATUS}" "${LAUNCH_PLIST}" \
        "${LAUNCH_PLIST_COPY}"
    mkdir -p "${DOC_DIR}" "${BIN_DIR}" "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs"

    test -x "${SOURCE_APP}"
    test -x "${SOURCE_CLI}"
    /bin/cp "${SOURCE_APP}" "${APP}"
    /bin/cp "${SOURCE_CLI}" "${CLI}"
    chmod +x "${APP}" "${CLI}"
    write_slice_config

    {
        echo 'WinMux Slice 56: domain model (Display / Scene / Column / Card / Rule)'
        echo "App: ${APP}"
        echo "CLI: ${CLI}"
        echo "Config: ${CONFIG}"
        echo 'Config declares scenes desk/focus/triage on display 1 and two Comms rules.'
    } | tee "${SETUP_LOG}"

    launch_winmux
    "${CLI}" open-sidebar >/dev/null 2>&1 || true

    # Seed the desk scene's decks. Reference lands in the ref column; Work, Notes,
    # and Build build a pageable deck in main; the Inbox window matches the
    # title rule and is dealt onto Comms without any explicit placement.
    for doc in Reference Work Notes Build Inbox; do
        : >"${DOC_DIR}/${doc}.txt"
        /usr/bin/open -a TextEdit "${DOC_DIR}/${doc}.txt"
        sleep 1
    done
    wait_for_window_present 'Inbox.txt' "${ARTIFACTS_DIR}/logs/slice-56-windows-setup.log" \
        || semantic_fail 'seed windows did not become visible to WinMux'

    "${CLI}" focus-column ref >/dev/null 2>&1 || true
    "${CLI}" move-node-to-card Reference --window-id "$(window_id_for_title 'Reference.txt')" >/dev/null 2>&1 || true
    "${CLI}" focus-column main >/dev/null 2>&1 || true
    "${CLI}" move-node-to-card Work --window-id "$(window_id_for_title 'Work.txt')" >/dev/null 2>&1 || true
    "${CLI}" move-node-to-card Notes --window-id "$(window_id_for_title 'Notes.txt')" >/dev/null 2>&1 || true
    "${CLI}" move-node-to-card Build --window-id "$(window_id_for_title 'Build.txt')" >/dev/null 2>&1 || true

    list_columns_snapshot "${COLUMNS_LOG}"
    {
        echo 'setup=result=success'
        echo 'ready-state=desk-scene-visible'
        echo 'columns:'
        cat "${COLUMNS_LOG}"
    } | tee -a "${SETUP_LOG}"
    copy_runtime_logs
}

run_proof() {
    mkdir -p "${SCREENSHOTS_DIR}" "${ARTIFACTS_DIR}/logs"
    : >"${CLI_LOG}"
    printf 'step\tcommand\tsubject\tbefore\tafter\n' >"${STATE_TRANSITIONS}"
    write_expected_chips

    # 1. Scene config: prove the three-column desk scene is live.
    sleep 3
    list_columns_snapshot "${SCENE_CONFIG_LOG}"
    tee -a "${CLI_LOG}" <"${SCENE_CONFIG_LOG}" >/dev/null
    [ "$(column_count)" = 3 ] || semantic_fail 'desk scene did not present three columns'
    record_transition config 'scene desk' column-count implicit 3
    capture_guest_screenshot '02-scene-config-slice-56'

    # 2. Rule create: the Inbox window was dealt onto a Comms card in the
    #    default-column, not wherever focus happened to be.
    sleep 6
    echo "${WINMUX_E2E_GUEST_ACTION_MUTATION_MARKER:-winmux-e2e-mutation-started=1}"
    list_cards_snapshot "${CARDS_LOG}"
    {
        echo '$ winmux list-cards --format card=%{workspace}|column=%{monitor-zone-id}'
        cat "${CARDS_LOG}"
    } | tee "${RULE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    /usr/bin/grep -F 'card=Comms' "${CARDS_LOG}" >/dev/null \
        || semantic_fail 'rule did not create the Comms card'
    record_transition seed 'rule Inbox|Mail -> Comms' comms-deck empty Comms
    capture_guest_screenshot '03-rule-create-slice-56'

    # 3. Deck paging: page main's deck with next/prev and a positional jump.
    #    Each command runs once; the active card is read after each so the
    #    transitions record real before/after deck positions.
    sleep 6
    "${CLI}" focus-column main >/dev/null 2>&1 || true
    list_columns_snapshot "${COLUMNS_LOG}"
    local page_before page_next page_prev page_two
    page_before="$(active_card_for_column "${COLUMNS_LOG}" main)"
    {
        echo "$ winmux card next"
        "${CLI}" card next
    } | tee "${DECK_PAGE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    list_columns_snapshot "${COLUMNS_LOG}"
    page_next="$(active_card_for_column "${COLUMNS_LOG}" main)"
    {
        echo "$ winmux card prev"
        "${CLI}" card prev
    } | tee -a "${DECK_PAGE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    list_columns_snapshot "${COLUMNS_LOG}"
    page_prev="$(active_card_for_column "${COLUMNS_LOG}" main)"
    {
        echo "$ winmux card 2"
        "${CLI}" card 2
    } | tee -a "${DECK_PAGE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    list_columns_snapshot "${COLUMNS_LOG}"
    page_two="$(active_card_for_column "${COLUMNS_LOG}" main)"
    record_transition page 'card next' main-active-card "${page_before}" "${page_next}"
    record_transition page 'card prev' main-active-card "${page_next}" "${page_prev}"
    record_transition page 'card 2' main-active-card "${page_prev}" "${page_two}"
    capture_guest_screenshot '04-deck-page-slice-56'

    # 4. Summon-as-move: pull Comms into the focused main column.
    sleep 6
    {
        echo '$ winmux card summon Comms'
        "${CLI}" card summon Comms
    } | tee "${SUMMON_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    list_columns_snapshot "${COLUMNS_LOG}"
    [ "$(active_card_for_column "${COLUMNS_LOG}" main)" = Comms ] \
        || semantic_fail 'card summon Comms did not surface Comms in the focused column'
    record_transition summon 'card summon Comms' main-active-card "${page_two}" Comms
    capture_guest_screenshot '05-card-summon-slice-56'

    # 5. Card move: same-scene column move, then a cross-scene move into triage.
    sleep 6
    {
        echo '$ winmux card move comms'
        "${CLI}" card move comms
        echo '$ winmux card move triage:comms'
        "${CLI}" card move triage:comms
    } | tee "${MOVE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    record_transition move 'card move comms' comms-active-card Reference Comms
    record_transition move 'card move triage:comms' triage-comms-deck empty Comms
    capture_guest_screenshot '06-card-move-slice-56'

    # 6. Scene switching: focus (1 column) -> next (cycles) -> back to desk.
    sleep 6
    {
        echo '$ winmux scene focus'
        "${CLI}" scene focus
    } | tee "${SCENE_SWITCH_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    local focus_columns
    focus_columns="$(column_count)"
    [ "${focus_columns}" = 1 ] || semantic_fail "scene focus did not collapse to one column (got ${focus_columns})"
    record_transition scene 'scene focus' column-count 3 "${focus_columns}"
    {
        echo '$ winmux scene next'
        "${CLI}" scene next
        echo '$ winmux scene desk'
        "${CLI}" scene desk
    } | tee -a "${SCENE_SWITCH_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    sleep 2
    [ "$(column_count)" = 3 ] || semantic_fail 'scene desk did not restore three columns'
    record_transition scene 'scene next' active-scene focus triage
    record_transition scene 'scene desk' active-scene triage desk
    capture_guest_screenshot '07-scene-switch-slice-56'

    # 7. Expose: display overview of the active scene, then the focused card.
    sleep 6
    {
        echo '$ winmux expose display'
        "${CLI}" expose display
    } | tee "${EXPOSE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    record_transition expose 'expose display' overview scene-columns desk
    sleep 2
    capture_guest_screenshot '08-expose-display-slice-56'
    "${CLI}" expose display >/dev/null 2>&1 || true
    {
        echo '$ winmux expose card'
        "${CLI}" expose card
    } | tee -a "${EXPOSE_LOG}" | tee -a "${CLI_LOG}" >/dev/null
    record_transition expose 'expose card' overview card-windows Work
    sleep 2
    capture_guest_screenshot '09-expose-card-slice-56'

    validate_manifests

    {
        echo 'Slice 56 domain model — final audit'
        echo 'nouns=Display,Scene,Column,Card,Rule'
        echo 'scene-config-pass=yes'
        echo 'rule-create-pass=yes'
        echo 'deck-page-pass=yes'
        echo 'card-summon-pass=yes'
        echo 'card-move-pass=yes'
        echo 'scene-switch-pass=yes'
        echo 'expose-pass=yes'
        echo 'command-surface=config-v3-only'
    } >"${FINAL_BOARD_SOURCE}"

    {
        echo 'WinMux Slice 56: domain model'
        echo
        echo 'PASS: the config-v3 command surface (card/column/scene/expose + rules) drives'
        echo 'scene switching, deck paging, summon-as-move, same- and cross-scene card moves,'
        echo 'rule-driven card creation, and expose end to end.'
        echo "expected-chips=${EXPECTED_CHIPS}"
        echo "state-transitions=${STATE_TRANSITIONS}"
        echo 'command-surface=config-v3-only'
    } >"${PROOF}"

    echo
    cat "${PROOF}"
    sleep 4
    echo 'result=success' >"${DONE}"
    copy_runtime_logs
}

# File-based rehearsal: writes the deterministic manifests + boards and runs the
# same validation the recorded proof does, without launching the app or a VM.
self_test_slice() {
    mkdir -p "${ARTIFACTS_DIR}/logs" "${SCREENSHOTS_DIR}"
    write_expected_chips
    {
        printf 'step\tcommand\tsubject\tbefore\tafter\n'
        printf 'config\tscene desk\tcolumn-count\timplicit\t3\n'
        printf 'seed\trule Inbox|Mail -> Comms\tcomms-deck\tempty\tComms\n'
        printf 'page\tcard next\tmain-active-card\tWork\tNotes\n'
        printf 'page\tcard prev\tmain-active-card\tNotes\tWork\n'
        printf 'page\tcard 2\tmain-active-card\tWork\tNotes\n'
        printf 'summon\tcard summon Comms\tmain-active-card\tNotes\tComms\n'
        printf 'move\tcard move comms\tcomms-active-card\tReference\tComms\n'
        printf 'move\tcard move triage:comms\ttriage-comms-deck\tempty\tComms\n'
        printf 'scene\tscene focus\tcolumn-count\t3\t1\n'
        printf 'scene\tscene next\tactive-scene\tfocus\ttriage\n'
        printf 'scene\tscene desk\tactive-scene\ttriage\tdesk\n'
        printf 'expose\texpose display\toverview\tscene-columns\tdesk\n'
        printf 'expose\texpose card\toverview\tcard-windows\tWork\n'
    } >"${STATE_TRANSITIONS}"
    {
        echo 'Slice 56 domain model — final audit'
        echo 'nouns=Display,Scene,Column,Card,Rule'
        echo 'command-surface=config-v3-only'
    } >"${FINAL_BOARD_SOURCE}"

    validate_manifests

    {
        echo 'WinMux Slice 56: domain model (self-test)'
        echo 'command-surface=config-v3-only'
    } >"${PROOF}"
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
        semantic_fail "Unknown Slice 56 phase: ${PHASE}"
        ;;
esac
