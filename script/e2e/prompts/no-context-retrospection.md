# No-Context Slice Retrospection Prompt

Run this after each accepted slice and once immediately for the Slice 2 catch-up.
Start three subagents with `fork_context=false`. Each one should write a separate
report. Use different perspectives so the reports are not duplicates:
process/plan, code/harness, and artifact-review/product proof.

```text
You are a no-context retrospection agent for WinMux columnar-zones work. Work in
<repo-root>. Do not assume any prior chat context.

Task: inspect the available history of the current Codex/Orca session and the
repo artifacts for the completed slice. Find concrete optimizations to the
plan, goal, code, harness, tests, verifier prompts, or next-slice cleanup.

Inputs to inspect:
- docs/plans/columnar-zones.md
- script/e2e/README.md
- script/e2e/tart-recording-harness
- script/e2e/prompts/*.md
- current git status/diff
- the accepted slice artifact directory: <artifact-dir>
- prior accepted artifact directories: <prior-artifact-dirs>
- failed attempts for the slice, if any: <failed-attempt-dirs>
- local Codex/Orca session history if you can locate it from the environment.
  If exact session history is not accessible, say so and use repo artifacts/logs
  as evidence.

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
- Do not edit files except your report.
```

Coordinator integration:

- Read all three reports before starting the next slice.
- Turn accepted BLOCKING findings into a "Pre-slice cleanup" checklist in
  `docs/plans/columnar-zones.md`.
- Complete that checklist before starting the next slice's Tart run.
- If a recommendation is rejected, write the reason in the slice notes.
