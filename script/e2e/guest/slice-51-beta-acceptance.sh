#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?}"
: "${ARTIFACTS_DIR:?}"

PHASE="${WINMUX_E2E_SLICE51_PHASE:-proof}"

semantic_fail() {
    echo "$*" >&2
    exit 86
}

self_test() {
    mkdir -p "${ARTIFACTS_DIR}/logs" "${ARTIFACTS_DIR}/docs" "${ARTIFACTS_DIR}/screenshots"
    printf 'kind=beta-acceptance\nslice=51\n' >"${ARTIFACTS_DIR}/logs/beta-acceptance-manifest.txt"
    printf '[winmux-e2e] Slice 51 guest harness self-test PASS\n'
}

case "$PHASE" in
    self-test)
        self_test
        ;;
    setup|proof)
        semantic_fail "Slice 51 guest ${PHASE} workflow is not implemented yet; finish the beta acceptance proof script before the first Tart recording"
        ;;
    *)
        semantic_fail "unknown Slice 51 phase: ${PHASE}"
        ;;
esac
