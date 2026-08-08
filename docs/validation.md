# Validation Evidence

Validation is recorded with explicit layers so that automated coverage is
never confused with manual or semantic verification, and design truth is never
confused with runtime truth.

## Verification layers

The private production project's acceptance matrix uses three markers:

| Marker | Meaning |
| --- | --- |
| `[A]` | Executable test coverage (tests/) |
| `[S]` | Prompt structure checks (test-prompts-contract.ps1) |
| `[W]` | Manual walkthrough (agent behavior semantics that scripts cannot verify) |

`[A]` proves what a script can prove. `[W]` scenarios are still manual
judgments. Neither implies a specific runtime executed successfully on a
specific day.

## Test suite

The private repository ships a dependency-free PowerShell test suite that runs
locally:

| Test script | Covers |
| --- | --- |
| `test-validator-expression-guard.ps1` | Expression-quality hard gates (public-body noise, kana, long English fragments, template residue; normal brief passes) |
| `test-brief-written.ps1` | Post-write guard: file exists, non-empty, no placeholders, correct date, weather source present |
| `test-status-update-contract.ps1` | Status patch contract, including the monotonic `email_sent` guard matrix |
| `test-stage2-3-contract.ps1` | Stage 2/3 gate matrix: SENDABLE persistence, manual-review defense, successful-rescue recovery |
| `test-daily-brief-optimization.ps1` | Config schema, budget safety, prompt contract assertions |
| `test-prompts-contract.ps1` | Prompt structure checks |

Run locally with:

```powershell
pwsh -File tests\test-stage2-3-contract.ps1
pwsh -File tests\test-validator-expression-guard.ps1
```

The production repository does not currently configure CI. The tests are local
and re-runnable; this showcase does not claim CI coverage.

## What is not claimed

- No live runtime statistics: no token measurements, delivery counts, success
  rates, or uptime claims.
- No claim that `[A]` coverage proves agent semantic behavior.
- No claim that a design documented here equals a verified runtime execution.
- No real runtime artifacts are reproduced, even in redacted form.

## Sanitized failure replay

The repair gradient in this showcase comes from a real failure class that is
described here at scenario level only:

> The day's evidence set exists, but part of it is untrusted: several news
> items point at an outlet homepage instead of a specific article. The brief
> fails a P1 self-check, the run is marked for manual review, and no stage has
> authority to repair the evidence.

Under the earlier design this state could deadlock. Under the current design:

1. Stage 2 first judges whether the defect is local (repairable in one pass)
   or systematic (escalate).
2. Stage 3, when escalated, holds full rescue authority and restores the run
   through the full gate; after success, the manual-review flag is cleared and
   the state returns to SENDABLE.
3. If the second full gate still fails, delivery stays BLOCKED and the run
   remains with a human.

No date, account, path, or real artifact is attached to this replay.
