#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE5_PHASE:-proof}"
SETUP_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-setup.log"
PROOF_LOG="${ARTIFACTS_DIR}/logs/slice-5-sidebar-action.log"

case "$PHASE" in
    setup)
        {
            echo 'Slice 5 sidebar setup scaffold is wired.'
            echo 'TODO: launch WinMux with the sidebar-enabled config, stage visible zone workspaces, and capture ready state before recording.'
        } >"$SETUP_LOG"
        echo 'Slice 5 sidebar setup is not implemented yet' >&2
        exit 64
        ;;
    proof)
        {
            echo 'Slice 5 sidebar proof scaffold is wired.'
            echo 'TODO: drag or move one visible sidebar item into a zone target and prove before/after state.'
        } >"$PROOF_LOG"
        echo 'Slice 5 sidebar proof is not implemented yet' >&2
        exit 64
        ;;
    *)
        echo "Unknown WINMUX_E2E_SLICE5_PHASE: $PHASE" >&2
        exit 64
        ;;
esac
