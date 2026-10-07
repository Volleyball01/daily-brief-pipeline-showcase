# Design Decisions

This document explains why the pipeline is shaped the way it is. It describes the private production repository's design and contracts at `1b5c8a8` (2026-10-07). It makes no claim about a specific runtime's execution history.

Decisions 1–5 come from v1 and are updated where the implementation changed. Decisions 6–10 come from the product-layer upgrade. Decisions 11–15 come from the editorial quality upgrade.

## Part I — Reliability core

### 1. Structured evidence as the handoff boundary

In this project, the design was motivated by context growth. Search and page-fetch results stayed in the conversation, so by the time the agent wrote, it was working from a large, noisy context. The pipeline replaces shared context with files:

```text
Collector ──(atomic evidence JSON)──> Writer ──(brief + status)──> Delivery
```

- The Collector opens final source pages, verifies claims, and writes structured evidence (weather, news, deep reading, sources).
- A deterministic script checks that evidence before the Writer starts. The Writer's normal path writes from evidence the check marks `OK`.
- If the check names item-level problems (`ANOMALY`), Stage 2 may perform one bounded repair pass on those items.
- If the evidence is unusable or below the news floor, the run escalates to the Supervisor.

Neither stage needs the other's conversation.

The Collector's atomic write contract is a design-level prompt contract in the private repository: write to a temporary file in the same directory, re-read it, validate it as JSON, then replace the final file with a safe move. It is documented here and in the architecture diagram because it is a contract, not an executable script. This showcase does not present it as executable evidence.

### 2. Deterministic validator as the hard gate

Content quality must not depend on the model's mood. The validator is a dependency-free PowerShell script. It deterministically checks:

- the title date and weekday against the configured timezone;
- required sections, and weather fields and sources for each configured location;
- named Markdown source links in the weather and news sections;
- duplicate source URLs;
- unresolved template placeholders and template rule leaks;
- internal collection or process noise leaking into the public body;
- language rules for the closing note.

The validator is the hard gate. No stage may send while it fails, and the delivery entry re-runs it immediately before sending.

### 3. Explicit approval state and a single delivery entry

`delivery_allowed` means exactly one thing: all content gates passed and sending is allowed. It does not mean the transport will succeed. `email_sent` records whether the transport actually succeeded.

This separation matters:

- A transport failure keeps `delivery_allowed=true`, `gate_status=SENDABLE`, and `email_sent=false`, and records an `error`. A later stage may resend.
- Only a content-gate failure (a validator re-fail, a self-check fail, or an approval-whitelist miss) returns the run to BLOCKED.
- Once `email_sent=true` is persisted, a normal status patch cannot reset it to false. The delivery record is monotonic.
- A patch cannot enter SENDABLE unless `brief_path` names the existing, non-empty brief that will be sent. Approval is bound to a concrete file.

All content stages deliver through one guarded script. It re-runs the validator, checks the approval whitelist, and refuses when `manual_review_required=true`, even if other gate fields were wrongly set to SENDABLE by a bug.

### 4. Bounded repair, then full rescue, then human review

Repair is a gradient, not an open-ended license to improvise:

1. **Stage 2 (Writer): bounded local repair.** The deterministic evidence check names the defective items: a missing field, an unverified item, a site-root or search-page URL, or a duplicate. For each named item, the Writer re-opens its source, then runs at most one targeted search. It fixes the item, or drops it only if it still cannot be verified, and keeps `sources.json` consistent with `news.json`. Unnamed items stay untouched. No new research topics, and no second repair round.
2. **Stage 3 (Supervisor): full rescue authority.** When evidence is missing, unusable, or below the news floor, the Supervisor may re-verify, fix, delete, replace, or fully rebuild evidence and the unsent brief. It follows the full Collector and Writer quality rules, so rescue never lowers fact reliability. Before writing SENDABLE, it runs the same deterministic finalize check the Writer uses. After a successful rescue, failed-state residue is cleared (`manual_review_required=false`, `supervisor_status=PASS`), while `blocked_at` is kept as history.
3. **At most one corrective pass, then BLOCKED + human review.** If the second full gate still fails, the run is handed to a human and the delivery script refuses to send.

The gradient exists because of a real failure mode: evidence that *exists* but is *untrusted*. When several news items point at an outlet homepage instead of a specific article, a no-search rule and a write-from-evidence-only rule combine into a deadlock: no stage is allowed to fix what no stage trusts. The fix was to make repair scope explicit at each stage. Decision 13 describes the later correction in the opposite direction.

### 5. Design truth vs runtime truth

This repository describes the intended design and the source-of-truth rules. The runtime system records what actually ran, when, and with which result. The two are kept separate:

- repository docs win for intended design and contracts;
- runtime logs and active records win for actual execution;
- a reference schedule is a desired-state example, never proof that a job actually ran.

The showcase therefore never presents a design as a measured runtime result.

## Part II — Product layer

### 6. One config authority, with explicit and fail-closed migration

Earlier versions had a full config and separate runtime configs that could drift apart. Now one canonical config is the only authority, and every runtime consumer reads it.

- **Profiles.** Each Location Profile is a complete snapshot of the canonical config. Shared fields propagate to every Profile; location-specific fields stay with the Profile.
- **Migration is never implicit.** It is a separate tool that previews first and applies only on request. It stages and validates the complete new layout, checks source hashes, backs up every original, and validates the read-back.
- **Conflicts stop the migration.** Conflicting shared preferences, or unknown fields without a preservation rule, fail closed before any original is changed.

### 7. Settings writes are transactions

A local Settings window edits real configuration, so a half-written save is worse than no save. Every save follows the same chain:

- only allow-listed config files may be written;
- saving is refused while a daily run is in progress;
- saving is refused if any config file changed since the window loaded it;
- the proposed files are staged and validated in a temporary copy before anything is touched;
- each file about to change is backed up, and the backup is verified;
- files are written, read back byte for byte, and validated again;
- any failure restores every written file from the backup.

Settings listens on localhost only and never writes outside the config folder.

### 8. "Cannot confirm" is a first-class Doctor result

Each environment check reports one of four states: `ok`, `attention`, `unknown` (cannot confirm), or `error`. The overall result is the worst state among the required checks; optional checks never change it.

An unknown is never rounded up to healthy. Some facts, such as which files a packaged-app process can see, depend on where the check runs. The Doctor reports them as process-dependent observations rather than as machine facts.

### 9. A vendor-neutral core with a verified reference implementation

The core (config, Profiles, evidence, status, gates, prompts) does not assume a particular Agent product or model. Windows with PowerShell 7 is the fully verified reference implementation. Other platforms need agent-assisted adaptation of the outer layer (launcher, scheduling, notifications) and are not claimed as verified.

Skill source, user data, and machine-local tool paths are separate layers. Machine paths live only in a machine-level runtime file, never in config or Profiles.

### 10. Config is desired state, never proof of a scheduled job

Run times and switches in config describe what the user wants. They are not evidence that a scheduled job exists, is enabled, or ran.

The repository does not integrate with any scheduler vendor, and saving config never creates or enables a real job. Settings can produce a deployment request for the user's own Agent, and the result must be read back on the external platform. This extends decision 5 from execution history to deployment state.

## Part III — Editorial quality

### 11. Editorial quality is the primary objective

In October 2026 the engineering gates and existing checks were passing while the brief became shorter, thinner, and slower to produce. None of them caught the editorial regression. "Passed the gates" had quietly replaced "worth reading every morning" as the working objective. The correction made the order explicit:

> **Product / Editorial Quality > Research Integrity > Engineering Reliability.**

Gates exist to protect a high-quality result. A design that satisfies every contract but produces a worse brief is a regression.

### 12. Minimal high-signal context, loaded just in time

Model attention is finite. Irrelevant context and long lists of simultaneous rules measurably degrade judgment. The normal path now gives each stage only what that day's task needs:

- **Always read:** the stage prompt, which opens with who the brief is for and what makes it good, plus one short policy and the stage context.
- **Computed by script, never read by the model:** date, weekday, paths, the config subset for that stage, the time budget, and the deduplication window.
- **Read only when needed:** evidence repair (on `ANOMALY`) and the failure policy (on failure).
- **Maintenance only:** status schema, deployment, and design history.

Fixed normal-path instructions fell from 57 245 to 22 329 bytes for the Collector and from 56 855 to 14 819 bytes for the Writer. A test keeps them within a per-stage budget and asserts the read chain, so the context cannot quietly grow back.

Rules that are split across documents only help if each consumer stops reading the parts it does not need. Splitting the rules while every stage still read all of them had made the context bigger, not smaller.

### 13. Trust verified evidence; check structure with code, not a second LLM

The Writer used to run an LLM "health check" on evidence the Collector had already verified. On 2026-10-06 it flagged a legitimate news domain as untrusted and dropped verified items.

The check was replaced by a deterministic structural check. It looks for required fields, verification flags, site-root or search-page URLs, and duplicates. It never judges whether a domain is trustworthy; that judgment belongs to the Collector. Evidence that passes is trusted, and only named items are repaired.

State writing moved into a finalize script for the same reason. Approval patches are no longer hand-written by the model. The script also confirms mechanically that every news item in the evidence appears in the brief.

### 14. Degrade honestly

The news count is one contract derived from config:

- at or above the target: normal;
- between the floor and the target: a legitimate shorter brief, sent without padding or lowered verification;
- below the floor: not sendable, escalated to rescue, and reported as a failure if rescue cannot recover.

A short true brief is better than a padded one. A brief with almost no news usually signals a collection failure rather than a quiet day, so it is treated as one.

### 15. The maintainer knows a lot; the production Agent sees little

Changes to core product behavior start with research in the relevant domain: journalism, weather communication, information design, personalization, behavioral science, or Agent context engineering.

That research stays in maintenance documents. Production prompts receive only the compressed result:

```text
research → design principle → compact production signal
```

and never:

```text
research → a hundred if/else rules → read in full every morning
```

See [editorial-quality.md](editorial-quality.md) for the distilled principles.

## Deliberately out of scope

- Weekly, monthly, archive, and knowledge subsystems exist in production and are mentioned only at summary level. Their prompts and code are not part of this showcase.
- The Settings UI and Doctor are described, not shown. No screenshots are published.
- No real outputs, emails, status files, evidence files, Profile names, locations, or runtime artifacts are published.
- No benchmark numbers, run durations, token or cost measurements, model-routing details, or delivery statistics are published. Prompt sizes are published because they are design facts measured from the repository.
