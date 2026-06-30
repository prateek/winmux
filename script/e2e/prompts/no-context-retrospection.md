# No-Context Slice Retrospection Prompt

Run this after each accepted slice and once immediately for the Slice 2 catch-up.
Start three subagents with `fork_context=false`. Each one should write a separate
report. Use different perspectives so the reports are not duplicates:
process/plan, code/harness, and artifact-review/product proof.

```text
You are a no-context retrospection agent for WinMux columnar-zones work. Work in
<repo-root>. Do not assume any prior chat context.

Task: inspect the repo artifacts for the completed slice. Repo files, artifacts,
logs, media, durable docs, failed-attempt directories, and current diff are
authoritative. Do not inspect local Codex/Orca session history unless the
coordinator explicitly names forensic mode for this retrospective. Any blocker
must cite repo or artifact evidence. Find concrete optimizations to the plan,
goal, code, harness, tests, verifier prompts, or next-slice cleanup.

Inputs to inspect:
- docs/plans/columnar-zones.md
- script/e2e/README.md
- script/e2e/tart-recording-harness
- script/e2e/guest/*.sh, when present
- script/e2e/configs/*.toml, when present
- script/e2e/prompts/*.md
- current git status/diff
- the accepted slice artifact directory: <artifact-dir>
- prior accepted artifact directories: <prior-artifact-dirs>
- failed attempts for the slice, if any: <failed-attempt-dirs>

If the coordinator explicitly requests forensic mode, local Codex/Orca session
history may be used as advisory context only. Bound that lookup tightly: search
by the exact artifact directory basename, recording name, or reviewer packet
path; inspect at most three exact-hit rollout/session files; ignore the
currently running session; stop after 10 shell commands or 3 minutes, whichever
comes first. If exact session history is not accessible, say so and use repo
artifacts/logs as evidence. Do not make session-history-only findings blocking.

Before relying on a prior accepted artifact path, verify that it contains product
media and an accepted `reviews/no-ctx-artifact-review.md`: either legacy final
line `PASS` / `PASS_WITH_NOTES`, or first nonblank line beginning `PASS:` /
`PASS_WITH_NOTES:` with final line `next slice allowed: yes`. If a listed path
lacks media or an accepted review, label it as superseded/pre-Tart-only, inspect
`docs/plans/columnar-zones.md` for the accepted-result block, and make the
corrected path or ambiguity a finding.

Perspective: <process-plan | code-harness | artifact-product>

Write your report to <retrospection-dir>/<agent-name>.md.

Report format:
1. Evidence inspected
2. Findings
3. Plan/doc changes recommended
4. Code/harness/test changes recommended
5. Mandatory pre-slice cleanup items

Constraints:
- Keep recommendations concrete and scoped.
- Prefer changes that prevent repeated failures over broad refactors.
- Mark any recommendation as BLOCKING if the next slice should not start until it
  is done.
- Mark stale accepted-artifact inputs as BLOCKING when they could cause the next
  slice or reviewer to compare against the wrong evidence.
- Do not edit files except your report.
- Do not run repair-capable artifact commands such as `verify-artifact` unless
  the coordinator explicitly asks for it. Those commands may generate reviewer
  packets, samples, or contact sheets. If you need a mechanical artifact check,
  use `make e2e-verify-slice-check RUN_DIR=<artifact-dir> ARGS=--require-review`,
  which must not create samples or reviewer packets. Prefer existing verifier
  logs and media files for report-only retrospection.
```

Coordinator integration:

- Read all three reports before starting the next slice.
- Turn accepted BLOCKING findings into a "Pre-slice cleanup" checklist in
  `docs/plans/columnar-zones.md`.
- Complete that checklist before starting the next slice's Tart run.
- If a recommendation is rejected, write the reason in the slice notes.
