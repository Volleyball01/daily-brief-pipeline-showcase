# Code Evidence

Seven curated excerpts from the private production repository. Each excerpt states its production source, line ranges, production baseline, and an honest `verbatim` / `adapted (privacy and scope redactions only)` label. The full system remains private. These excerpts are published for portfolio and technical-review purposes only.

Production baseline: private repository `main` @ `1b5c8a8` (2026-10-07).

## Provenance and labels

| File | Production source | Production lines | Label | What it shows |
| --- | --- | --- | --- | --- |
| [01-validator-core-rules.ps1](01-validator-core-rules.ps1) | `scripts/validate-daily-brief.ps1` | 210-311, 378-465 | verbatim | Deterministic hard gate: required sections; per-location weather fields and named source links; news links and items; duplicate URLs; forbidden process / AI chatter; template residue; unresolved placeholders; public-body process noise (HARD FAIL) |
| [02-send-if-ready-gate.ps1](02-send-if-ready-gate.ps1) | `scripts/send-if-ready.ps1` | 128-289 | verbatim | Single guarded delivery entry: gate condition checks; delivery disabled by config; manual-review refusal; validator re-run before send; approval whitelist; transport-failure handling that keeps content approval intact |
| [03-status-patch-protection.ps1](03-status-patch-protection.ps1) | `scripts/update-daily-brief-status.ps1` | 170-229 | verbatim | File-based status patching: monotonic `email_sent`; a `brief_path` guard for entering SENDABLE; atomic persistence (temp file, then a safe move) |
| [04-stage2-3-contract.ps1](04-stage2-3-contract.ps1) | `tests/test-stage2-3-contract.ps1` | 54-74, 151-238, 253-322 | adapted — privacy and scope redactions only; control flow unchanged | Regression tests: a SENDABLE patch without a usable `brief_path` is rejected; the `manual_review_required` defense gate; a successful rescue restores SENDABLE, and the fake email tool is never called |
| [05-context-budget-guard.ps1](05-context-budget-guard.ps1) | `tests/test-prompts-contract.ps1` | 70-85, 94-103 | verbatim | Normal-path context guard: each stage starts from the deterministic stage context; engineering contracts stay out of the normal read chain; the mission comes before the interface; fixed instruction bytes stay within a per-stage budget |
| [06-settings-save-transaction.ps1](06-settings-save-transaction.ps1) | `scripts/settings/settings-server.ps1` | 316-410 | verbatim | Settings save transaction: allow-listed files; run-window lock; external-change guard; staging and validation before config is touched; verified backup; write with read-back; post-write validation; restore on any failure |
| [07-evidence-check-news-floor.ps1](07-evidence-check-news-floor.ps1) | `scripts/lib/stage-context.ps1` | 190-235, 309-338 | verbatim | The deterministic Stage 1 → Stage 2 handoff check that replaced an LLM "health check": a config-driven news floor; a structural URL check that never judges domain trust; per-item required fields; an honest degraded state |

### Changes since the v1 baseline

v1 (2026-08-10) published `01`–`04` from production `15b539a` (2026-08-04). Those excerpts were truthful for that baseline, and their `verbatim` labels were valid for it.

They were re-cut here so that this refresh represents the current implementation, responsibility boundaries, and finalize / status flow. The old excerpts did not become false. The v1 files remain in this repository's Git history.

## What "verbatim" means here

- The selected production line ranges are copied byte for byte, including the original Chinese comments, strings, and spacing.
- Only the header comment at the top of each file was added.
- When several line ranges are listed, they are concatenated directly. The range list documents which lines were omitted.
- Line endings may be normalized to the platform default. The content is otherwise unchanged.

## What "adapted (privacy and scope redactions only)" means here

- Same as verbatim, except that specific private or runtime-bound values are replaced by placeholders or generic terms. One source-name reference is also generalized for scope reasons, because the production test fixture names an outlet.
- The changes to dates, the timestamp, the subject format, and outlet names are redactions only. No structure, logic, or control flow was changed.

### Redaction list for 04-stage2-3-contract.ps1

| Redaction | Published as |
| --- | --- |
| Email subject format (original Chinese value) | `yyyy-MM-dd <subject>` |
| Test dates (original values) | `2026-01-01` / `2026-01-03` / `2026-01-04` / `2026-01-05` |
| Timestamp (original value) | `2026-01-01T08:23:14+09:00` |
| P1 message referencing an outlet by name | `P1: 3 news URLs point to the outlet homepage` |
| Rescue action message referencing an outlet by name | `rescued: re-verified news items, replaced homepage URLs` |

## Honesty notes

- None of these files runs on its own. They reference production helpers and variables that are not published here, for example `Add-Error`, `Add-Warning`, `Assert-True`, `Get-StatusObject`, `New-Result`, `Invoke-Validator`, `Test-RunWindowBlocked`, `New-DailyBriefRuntimeError`, `$brief3Dir`, and the runtime-path resolver.
- The excerpts contain no real paths, user names, accounts, emails, logs, configuration values, Profile names or locations, status or evidence files, or credentials. Test fixtures use temporary directories and a fake email tool that sends nothing.
- Chinese comments and strings are kept as production facts. The production brief itself is a Chinese-language product.
- No excerpt is presented as a full system, and none grants a license (see the repository README).

## Glossary

- **Evidence**: structured JSON files (weather, news, deep reading, sources). The Collector writes them; the Writer and Supervisor read them.
- **Stage context**: a deterministic JSON that a script computes for each stage. It contains the date, paths, the config subset that stage needs, the time budget, the deduplication window, and the evidence check result. In the normal path it replaces reading the full config and contracts.
- **Evidence status**:
  - `OK`: write from the evidence as is.
  - `ANOMALY`: named item-level problems; one bounded repair.
  - `UNUSABLE`: a section is missing, or there are fewer news items than the floor; escalate.
  - `MISSING`: the evidence has not been written yet.
- **News floor**: the fewest verified news items a sendable brief may carry, derived only from config. Between the floor and the target, the brief is a legitimate degraded result. Below the floor, it is not sendable.
- **Hard gate**: the deterministic validator. Delivery is impossible while it fails.
- **SENDABLE**: a persisted state meaning that all content gates passed and sending is allowed. It never guarantees that the transport succeeds. Entering it requires a `brief_path` that names the existing, non-empty brief.
- **delivery_allowed**: the content-approval flag. A transport failure must not reset it to false.
- **email_sent**: the monotonic delivery record. A normal status patch cannot reset it from true to false.
- **manual_review_required**: the human-review flag. While it is true, the delivery entry refuses to send, even if other gate fields look SENDABLE.
- **Bounded local repair**: Stage 2's single repair pass for item-level evidence problems named by the deterministic check.
- **Full rescue authority**: Stage 3's power to re-verify, fix, rebuild, and rewrite during a rescue, without lowering fact reliability.
