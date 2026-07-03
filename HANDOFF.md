# Handoff Prompt

Read `AGENTS.md` first. State update since this prompt was written
(2026-07-02, later the same day): the working tree is clean at `e8b5173a`
on `codex-columns`, pushed to the `fork` remote (`prateek/winmux`, now the
default branch). Dogfood distribution, signing, and release tooling exist
(`script/dogfood-release`, `script/setup-signing`; see AGENTS.md), the
user is dogfooding `0.51.0-dogfood.2` on real hardware, and
`docs/dogfood-notes.md` records classified findings. Slices 52-55 are
planned from that feedback; Slices 53 and 54 are dogfood blockers that
take priority over Slice 52. The Slice 51 instructions below remain the
operative path to beta acceptance and are unchanged except that the
"previous agent" checkpoint commit `250abd66` now has further commits on
top of it (docs, plan slices, release tooling — no product-code changes).

Use this prompt with a fresh agent:

```text
You are continuing WinMux columnar-zones work in:

/Users/prateek/orca/workspaces/winmux/codex-columns

Start by reading:
- docs/plans/columnar-zones.md around Slice 50 and Slice 51
- HANDOFF.md
- /tmp/winmux-codex-columns-review-handoff.md
- script/e2e/check-slice-51-beta-acceptance
- script/e2e/tart-recording-harness
- script/e2e/guest/slice-51-beta-acceptance.sh

Current state:
- The previous agent committed a checkpoint that implements the reviewer handoff fixes, hardens Slice 50/51 package and beta gates, updates the Slice 50 accepted artifact to `artifacts/e2e/slice-50-round2-review-20260702T175701Z`, and fixes the Slice 51 event-manifest leading-tab blocker in `script/e2e/tart-recording-harness`.
- Slice 50 round-2 package evidence is accepted:
  `artifacts/e2e/slice-50-round2-review-20260702T175701Z`
- Its review and post-review logs are persisted:
  `logs/review-lint.log`
  `logs/post-review-verify.log`
- Its retrospectives are present:
  `retrospectives/process-plan.md`
  `retrospectives/code-harness.md`
  `retrospectives/artifact-product.md`
- The older `artifacts/e2e/slice-50-pre-tart-20260702T135154Z` is superseded package proof. Do not use it as the current accepted Slice 50 package artifact.

Important: Slice 51 is not accepted yet.

Before running Tart for Slice 51:
1. Finish or explicitly resolve the remaining unchecked Slice 51 pre-slice cleanup items in `docs/plans/columnar-zones.md`:
   - support-bundle schema self-test coverage
   - artifact-review output contract
   - reviewer-attempt ledger semantics
   - final desktop policy
2. Regenerate Slice 51 pre-Tart freshness, because the previous freshness and all three pre-Tart reports are stale after the event-manifest fix.
3. Run three no-context pre-Tart reviewers with `fork_context=false` and require clean reports under:
   - `artifacts/e2e/<slice-51-run>/reviews/pre-tart/process-plan.md`
   - `artifacts/e2e/<slice-51-run>/reviews/pre-tart/code-harness.md`
   - `artifacts/e2e/<slice-51-run>/reviews/pre-tart/artifact-product.md`
4. Do not proceed beyond the slice until the no-context review gate is clean.

Known stale/blocked pre-Tart reports to ignore except as lineage:
- `artifacts/e2e/slice-51-pre-tart-20260702T182031Z/reviews/pre-tart/process-plan.md`
- `artifacts/e2e/slice-51-pre-tart-20260702T182031Z/reviews/pre-tart/code-harness.md`
- `artifacts/e2e/slice-51-pre-tart-20260702T182031Z/reviews/pre-tart/artifact-product.md`

Suggested next command sequence:

1. Verify the committed tree:
   `git status --short`
   `git log -1 --oneline`

2. Run cheap Slice 51 checks:
   `bash -n script/e2e/tart-recording-harness script/e2e/check-slice-51-beta-acceptance script/e2e/guest/slice-51-beta-acceptance.sh`
   `./script/e2e/check-slice-51-beta-acceptance --self-test`
   `./script/e2e/tart-recording-harness annotation-preflight`

3. Run the focused handoff regression tests:
   `swift test --filter 'DoctorCommandTest|FocusCommandTest|ZoneCommandTest|WorkspaceNamingTest'`

4. Run Slice 50 replacement closeout if not already present:
   `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-50-round2-review-20260702T175701Z > artifacts/e2e/slice-50-round2-review-20260702T175701Z/logs/closeout-check.log 2>&1`

5. Start a fresh Slice 51 pre-Tart run with a new run id. Use the external SSD Tart home:
   `TART_HOME=/Volumes/RiftTartVMs/tart WINMUX_E2E_RUN_ID=slice-51-<timestamp> make e2e-slice-51`

Expected first run behavior:
- It should run pre-Tart checks, write `reviews/pre-tart/freshness.env`, then stop until the three no-context pre-Tart reports exist.
- After reviewers pass, rerun the same command to start the real Tart recording.

Rules to preserve:
- Do not claim Slice 51 is accepted until Tart recording, no-context artifact review, review lint, post-review verifier, closeout, and all three retrospectives are complete.
- Do not accept logs-only proof. Slice 51 must include playable annotated/raw recordings, contact sheet, sample and event manifests, expected chips, mouse event log, and screenshots `07a` through `07g`.
- The mouse proof must distinguish no-modifier freeform drag from Option-held whole-zone snap into Comms.
- The final review must compare against accepted Slice 36-50 artifacts, root videos, README guidance, and `resources/screenshots/winmux-overview.png` plus `resources/screenshots/tab-groups.png`.
- Keep Slice 49 classified as docs evidence, not product-media evidence.
- Do not revert existing user or prior-agent changes. Work with the current tree.
```
