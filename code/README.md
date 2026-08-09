# Code Evidence

Four curated excerpts from the private production repository. Every excerpt
states its production source, production baseline, and an honest
`verbatim` / `adapted (privacy and scope redactions only)` label. The full
system remains private; these excerpts are published for portfolio and
technical-review purposes only.

## Provenance and labels

| File | Production source | Production lines | Label | What it shows |
| --- | --- | --- | --- | --- |
| [01-validator-core-rules.ps1](01-validator-core-rules.ps1) | `scripts/validate-daily-brief.ps1` | 206-251, 253-287, 347-405, 407-432 | verbatim | Deterministic hard gate: required sections, weather fields and named source links, news links, forbidden process / AI chatter, unresolved placeholders, public-body process-noise HARD FAIL |
| [02-send-if-ready-gate.ps1](02-send-if-ready-gate.ps1) | `scripts/send-if-ready.ps1` | 104-150, 179-200, 201-253 | verbatim | Single guarded delivery entry: gate condition checks, manual-review refusal, approval whitelist, send block with transport-failure handling that keeps content approval intact |
| [03-status-patch-protection.ps1](03-status-patch-protection.ps1) | `scripts/update-daily-brief-status.ps1` | 165-212 | verbatim | File-based status patching: monotonic `email_sent` protection and atomic persistence (temp file + safe move) |
| [04-stage2-3-contract.ps1](04-stage2-3-contract.ps1) | `tests/test-stage2-3-contract.ps1` | 135-173, 188-256 | adapted — privacy and scope redactions only; control flow unchanged | Regression tests: `manual_review_required` defense gate and successful rescue restoring SENDABLE |

Production baseline: private repository `main` @ `15b539a`.

## What "verbatim" means here

- The selected production line ranges are copied byte-for-byte, including
  original Chinese comments, strings, and spacing.
- Only the header comment at the top of each file was added.
- Where multiple line ranges are listed, the ranges are concatenated directly;
  the omitted lines are documented by the range list.
- Line endings may be normalized to the platform default; content is otherwise
  unchanged.

## What "adapted (privacy and scope redactions only)" means here

- Same as verbatim, except specific private or runtime-bound values are
  replaced by placeholders or generic terms, and a source-name reference is
  generalized for scope reasons (the production test fixture named an outlet).
- The date, timestamp, helper-name, subject-format, and outlet-name changes are
  redactions only: no structure, logic, or control flow was changed.

### Redaction list for 04-stage2-3-contract.ps1

| Redaction | Published as |
| --- | --- |
| Production helper script name | `scripts\<notify-helper>.ps1` |
| Email subject format (original Chinese value) | `yyyy-MM-dd <subject>` |
| Test dates (original values) | `2026-01-01` / `2026-01-02` / `2026-01-03` |
| Timestamp (original value) | `2026-01-01T08:23:14+09:00` |
| P1 message referencing an outlet by name | `P1: 3 news URLs point to the outlet homepage` |
| Rescue action message referencing an outlet by name | `rescued: re-verified news items, replaced homepage URLs` |

## Honesty notes

- None of these files is runnable on its own. They reference production
  helpers that are not published here (`Add-Error`, `Add-Warning`,
  `Assert-True`, `Get-StatusObject`, the email command contract, and so on).
- The excerpts contain no real paths, user names, accounts, emails, logs,
  configuration values, status or evidence files, or credentials.
- Chinese comments and Chinese strings are preserved as production facts;
  the production brief itself is a Chinese-language product.
- No excerpt is presented as a full system, and none grants a license (see
  repository README).

## Glossary

- **Evidence**: structured JSON files (weather, news, deep reading, sources)
  written by the Collector and consumed by the Writer and Supervisor.
- **Hard gate**: the deterministic validator. Delivery is impossible while it
  fails.
- **SENDABLE**: persisted state meaning all content gates passed and sending
  is allowed; it never guarantees transport success.
- **delivery_allowed**: content-approval flag. A transport failure must not
  reset it to false.
- **email_sent**: monotonic delivery record; a normal status patch cannot
  reset it from true to false.
- **manual_review_required**: human-review flag; the delivery entry refuses to
  send while it is true, even if other gate fields look SENDABLE.
- **Bounded local repair**: Stage 2's one-pass fix for single-item evidence
  defects.
- **Full rescue authority**: Stage 3's power to re-verify, fix, rebuild, and
  rewrite during rescue, without lowering fact reliability.
