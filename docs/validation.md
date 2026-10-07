# Validation Evidence

Validation is recorded in explicit layers. Automated coverage is never confused with manual or semantic verification, engineering tests are never confused with product quality, and design truth is never confused with runtime truth.

## Verification layers

The private production project's acceptance matrix uses three markers:

| Marker | Meaning |
| --- | --- |
| `[A]` | Executable test coverage (tests/) |
| `[S]` | Prompt structure checks (test-prompts-contract.ps1) |
| `[W]` | Manual walkthrough (agent behavior semantics that scripts cannot verify) |

`[A]` proves what a script can prove. `[W]` scenarios remain manual judgments. Neither implies that a specific runtime executed successfully on a specific day.

A fourth layer was made explicit after the October 2026 quality regression: **editorial quality**. The engineering gates and existing checks were passing while the brief got worse, so passing tests is not treated as evidence that the product is good.

## Test suite

At production baseline `1b5c8a8`, the suite has **30 test files**:

- **27 PowerShell test entry points** (`tests/test-*.ps1`). All 27 passed in the pre-merge Windows acceptance run (Windows 11, PowerShell 7.4, Node 24).
- **3 JavaScript test files** for the config and Settings engines. They are run by their PowerShell wrappers.

| Area | Test files | Covers |
| --- | --- | --- |
| Gates and status | `test-validator-expression-guard.ps1`, `test-brief-written.ps1`, `test-status-update-contract.ps1`, `test-stage2-3-contract.ps1`, `test-daily-brief-optimization.ps1` | Validator hard gates; post-write guard; status-patch contract (monotonic `email_sent`, `brief_path` for SENDABLE); Stage 2/3 gate matrix; manual-review defense; rescue recovery; config schema and budget safety |
| Stage context and context budgets | `test-stage-context.ps1`, `test-prompts-contract.ps1` | Deterministic stage context (date, paths, config subset, time budget, deduplication window); evidence `OK` / `ANOMALY` / `UNUSABLE` / `MISSING`, including that a legitimate news domain is not flagged; every required field; the news floor; finalize Check / Approve / send; read-chain assertions and per-stage byte budgets |
| Config and migration | `test-config-authority.ps1`, `test-config-v2.ps1`, `test-config-v2-migration.ps1`, `test-profile-switch.ps1`, `test-config-panel.ps1`, `config-v2.test.js` | Single config authority; Profile snapshots and isolation; explicit, fail-closed migration; transactional Profile switching; config rules |
| Settings | `test-settings-engine.ps1`, `test-settings-server.ps1`, `test-settings-ui.ps1`, `settings-engine.test.js`, `settings-ui.test.js` | Settings engine edits; the local server's save safety chain; the settings window product layer |
| Doctor and runtime | `test-doctor.ps1`, `test-runtime-paths.ps1`, `test-runtime-migration.ps1`, `test-no-machine-paths.ps1` | Environment Doctor states and overall summary; the machine-local runtime contract and its migration; no machine-specific paths in shared files |
| Knowledge and recaps | `test-knowledge-append.ps1`, `test-knowledge-contract.ps1`, `test-knowledge-migrate.ps1`, `test-knowledge-validate.ps1`, `test-reminder-contract.ps1`, `test-weekly-paths.ps1`, `test-weekly-mixed-profile.ps1` | Append-only knowledge records behind a schema gate, with migration; reminder contract; weekly recap paths across Profiles |
| Documentation | `test-documentation.ps1` | Repository-wide documentation checks |

Selected tests were verified by **reverse testing**: a guard was temporarily removed, the matching test failed, the guard was restored, and the test passed again. This covered the new evidence checks, the news floor, and the migration of an old zero-news setting.

Run locally with, for example:

```powershell
pwsh -File tests\test-stage-context.ps1
pwsh -File tests\test-prompts-contract.ps1
pwsh -File tests\test-stage2-3-contract.ps1
```

The production repository does not configure CI. The tests are local and re-runnable, and this showcase does not claim CI coverage.

## End-to-end smoke (no real data, no real mail)

Before the quality upgrade was merged, a Windows end-to-end smoke ran against a temporary data root whose path contained Chinese characters and spaces. It used a fake email tool that records its arguments and sends nothing. The flow ran from valid evidence through the stage context, the brief, the finalize check, SENDABLE with `brief_path`, and the delivery entry, to `email_sent=true`.

Degraded and failing cases behaved as designed:

- 2–3 news items: sent as a degraded brief;
- 1 item: refused below the floor;
- missing required fields: never `OK`;
- re-running after a successful send: no second send.

## Context budget evidence

Normal-path fixed instructions, measured in UTF-8 bytes from the production repository:

| Stage | Before the quality upgrade | After (`1b5c8a8`) | Test budget |
| --- | ---: | ---: | ---: |
| Collector | 57 245 | 22 329 | 26 000 |
| Writer | 56 855 | 14 819 | 18 000 |

The budget leaves about 15–20 % headroom. A genuinely useful editorial paragraph does not fail mechanically, but any drift back toward the old engineering-heavy chains does. See [excerpt 05](../code/05-context-budget-guard.ps1).

## Editorial quality

- **How it is judged today.** The owner reads real briefs. After a qualitative review of the first real run following the upgrade (2026-10-07), the owner found editorial quality clearly restored and adopted that brief as a new editorial reference.
- **What exists but is not yet a gate.** A scored rubric draft covers curation, explanation, relevance, density, coherence, and finishability, with factual trust as a veto. Its intended use is offline: fixed evidence fixtures, scored before and after prompt or model changes. It is not yet in use and does not run in the daily pipeline.
- **Fidelity.** Proper names, numbers, and dates carried from verified evidence must remain accurate; translation or transliteration must not change the underlying entity or fact. This is an offline benchmark and review item, not a production gate. It adds no LLM reviewer to the daily run.

## What is not claimed

- No live runtime statistics: no token measurements, run durations, delivery counts, success rates, or uptime claims.
- No A/B test or statistical validation of the quality upgrade. The outcome above is the owner's qualitative assessment. It does not make that brief a factual gold standard.
- No claim that `[A]` coverage proves agent semantic behavior or editorial quality.
- No claim that a design documented here equals a verified runtime execution, or that any scheduled job exists or ran.
- No claim that the one-full-run mode or non-Windows platforms are production-validated.
- No real runtime artifacts are reproduced, even in redacted form.

## Sanitized failure replays

Two real failure classes shaped the current design. Both are described here at scenario level only.

**1. Untrusted evidence deadlock (v1).**

> The day's evidence set exists, but part of it is untrusted: several news items point at an outlet homepage instead of a specific article. The brief fails a P1 self-check, the run is marked for manual review, and no stage has authority to repair the evidence.

Under the earlier design this state could deadlock. Under the current design:

1. a deterministic check names the defective items, and Stage 2 repairs only those, once;
2. unusable or below-floor evidence escalates to Stage 3, which holds full rescue authority and restores the run through the full gate;
3. if the second full gate still fails, delivery stays BLOCKED and the run remains with a human.

**2. Over-checking verified evidence (October 2026).**

> Evidence verified by the Collector reaches the Writer. A second, LLM-based health check flags a legitimate news domain as untrusted and drops already-verified items. The brief still passes every gate, but it ships shorter and thinner.

Under the current design, the Writer trusts evidence that the deterministic check marks `OK`. The check inspects structure only and never judges domain trust. Approval and sending go through a finalize script that confirms every verified news item reaches the brief.

No account, path, outlet name, real brief, or runtime artifact is attached to these replays.
