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

### Current (`7daa53e`, third edition)

All tests now run through one entry point, `tests/run-tests.ps1`, in three tiers: fast, integration, and full. The full tier has **35 PowerShell test entry points**, which also run **4 JavaScript test files**, and takes about 90 seconds with four tests in parallel.

Tests added since `1b5c8a8` cover the weather fetch script and outdoor extras (`test-weather-fetch.ps1`, `test-weather-extras.ps1`, `test-weekend-weather.ps1`), the weekday sections (`test-local-columns-fetch.ps1`, `test-local-columns-check.ps1`, `test-seasonal-line.ps1`, `test-jp-holidays.ps1`), news-source availability checks (`test-news-sources.ps1`), the email layout (`test-email-theme.ps1`), and the test runner itself (`test-run-tests.ps1`).

For this edition, the full tier was run in parallel on a second Windows machine: 33 passed and 2 failed. Both failures were environment-only, a missing Python package and a PowerShell output-format difference, and they failed the same way on that machine at the previous production commit `212e498`. This is reported as observed; it is not presented as a clean acceptance run.

### Second-edition snapshot (`1b5c8a8`)

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

What happened next, measured the same way:

| Stage | `1b5c8a8` | Before the budget change (2026-10-30) | Budget since then | `7daa53e` |
| --- | ---: | ---: | ---: | ---: |
| Collector | 22 329 | about 25 700 | 30 000 | **28 143** |
| Writer | 14 819 | about 18 000 | 21 000 | **19 142** |

Reviewed features (a bounded follow-up query, research evidence status, the source-concentration review, weather extras) used up the headroom. The budget was raised once, to the same 15–20 % headroom over the measured size, with the reason written next to it in the test. The Collector later reached 29 968 bytes (99.9 %). Instead of raising the budget again, the weather rules needed only when the weather script fails, a location is not scripted, a field cannot be confirmed, or a warning needs a manual check moved into an on-demand document. Profiles whose locations have no weather script read that document on every run, so for them the total is about 1.2 KB higher than before the move.

## Editorial quality

- **How it is judged today.** The owner reads real briefs. After a qualitative review of the first real run following the upgrade (2026-10-07), the owner found editorial quality clearly restored and adopted that brief as a new editorial reference.
- **What exists but is not yet a gate.** A scored rubric draft covers curation, explanation, relevance, density, coherence, and finishability, with factual trust as a veto. Its intended use is offline: fixed evidence fixtures, scored before and after prompt or model changes. It is not yet in use and does not run in the daily pipeline.
- **Fidelity.** Proper names, numbers, and dates carried from verified evidence must remain accurate; translation or transliteration must not change the underlying entity or fact. This is an offline benchmark and review item, not a production gate. It adds no LLM reviewer to the daily run.

## Offline backtests

Some computed facts were checked against recorded data before they went into the brief. These are data checks on history, not runtime statistics of the pipeline.

### Air quality: choosing the source (28 days)

Reference: the local monitoring station's measured daily mean, over 28 days in October–November 2026.

| Source | Mean absolute error (µg/m³) | Level right |
| --- | ---: | ---: |
| Atmospheric model forecast | 10.3 | 9 / 28 |
| Commercial air-quality API (after-the-fact estimate) | 3.1 | 12 / 28 |
| **Estimate from the station's own recent measurements** | **2.2** | **24 / 28** |

Both the model and the commercial estimate ran consistently high, so the brief switched to station measurements.

### Air quality: choosing the method (371 days)

A full year (2025-11 to 2026-11), replayed day by day. Each morning uses only the measurements available at 07:00; the reference is that day's 07:00–21:00 measured mean. Levels follow the US AQI (2024) PM2.5 breakpoints.

| Method | MAE | Bias | Level right | Missed "moderate" days |
| --- | ---: | ---: | ---: | ---: |
| Always say "good" | — | — | 228 | 143 |
| Mean of the last 24 hours (first version) | 2.90 | −0.31 | 272 | 55 |
| Mean of the last 6 hours | 2.55 | −0.93 | 292 | 54 |
| **Mean of the last 6 hours + 0.9 (adopted)** | **2.42** | **−0.03** | **291** | **43** |
| Last 6 hours + rolling 60-day correction | 2.45 | +0.02 | 289 | 47 |
| Exponentially weighted (6-hour half-life) | 2.58 | −0.55 | 292 | 52 |

- **Is the gain real?** Against the first version the error difference is −0.48, with a 5-day block-bootstrap 95 % interval of [−0.69, −0.28].
- **Was 0.9 fitted after the fact?** A correction estimated only from the previous 60 days, never from the future, gives almost the same result (2.45).
- **Data delay.** If the data arrived two hours later than usual, the adopted method would still lead (2.61 against 3.03).
- **Later change of wording.** The brief now describes the estimate as the whole-day mean. Scored against the calendar-day 24-hour mean, the same method has an MAE of 1.75 and gets the level right on 302 of 361 days; the best possible fixed correction (0.6) reaches only 1.74 and 305, so the method was kept and only the wording changed.
- **Known limits.** Pollution that starts during the day cannot be seen in morning data: 37 of 54 such days are still missed. The best correction varies by season (0 to 2.7), and in April and August the adopted method is slightly worse than the first version. Estimates between 8 and 10 µg/m³ sit on a level boundary, so the brief writes "good to moderate" there.

The constants and the fallback are in [excerpt 08](../code/08-station-air-estimate.ps1).

### Rainbow hint: consistency, not accuracy

The rainbow hint is a rule on hourly rain, sunshine, and sun altitude. Over one year, the rule fired on 23 days with forecast data, and 83 % of those days also met the rule in reanalysis data; of the 104 days that met the rule in reanalysis, the forecast caught 18 %. This measures agreement between two weather datasets on the same rule, not against observed rainbows, so the brief only ever says a rainbow is possible.

### Calendar facts

Computed solar terms were checked against the official dates for 2026 and 2027 (48 dates, all matching), including terms that fall a few minutes from midnight. Public holidays were checked day by day against the government's published list for 2024–2027.

## What is not claimed

- No live runtime statistics: no token measurements, run durations, delivery counts, success rates, or uptime claims. The backtests above are offline checks on recorded data, not measurements of the pipeline in operation.
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
