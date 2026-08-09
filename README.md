# Daily Brief Pipeline

![Daily Brief Pipeline](assets/hero.svg)

**Public engineering showcase** for a private agent-automation pipeline whose core rule is:

> **Verified evidence in. Explicit approval out.** An AI task may write only after verified evidence, and may deliver only after an explicit content-approval gate.

## What this repository is

This is a **showcase repository**, not an open-source distribution:

- The production project is a private system and remains private. It is not linked here.
- What is published is a curated set of real production evidence: architecture, design decisions, validation records, and a small number of reviewed source excerpts.
- The excerpts are published for portfolio and technical-review purposes only. **No open-source license is granted by this repository.**
- Cloning this repository does not produce a runnable system. No installer, release, or public edition is provided.

## The problem

A morning-brief automation receives a one-shot AI task: collect weather and news, verify sources, write a short Chinese Markdown brief, and deliver it by email — every day, unattended.

The production design was shaped around two recurring failure modes:

1. **Long-context degradation.** Search and page-fetch results accumulate in one long session; by the time the agent writes, the context is large, noisy, and error-prone.
2. **Unsafe auto-delivery.** An agent that both writes and sends can ship unverified, placeholder-filled, or internally noisy content — or resend after a transport failure without a clear record of what was approved.

The pipeline answers both with the same mechanism: **separate collection from writing, and separate content approval from transport success.**

## The pipeline

![Pipeline](assets/pipeline.svg)

The runtime is split into four independent stages. Stages exchange **structured evidence files**, not long conversation context:

1. **Collector** — opens final source pages, verifies claims, and atomically writes evidence JSON (weather, news, deep reading, sources).
2. **Writer/Sender** — writes from persisted evidence, runs a deterministic validator (hard gate), a P0/P1 self-check, and persists an explicit approval state before any delivery is possible. When it finds a local evidence defect (a single item's URL, source, time, or supporting fact), it may run one bounded targeted repair pass; systematically untrusted evidence is escalated to the Supervisor.
3. **Supervisor** — a conditional strong-model rescue stage. It first judges whether the day already succeeded; only unfinished, failed, or untrusted artifacts enter rescue.
4. **Recovery** — a mechanical stage that re-validates, sends only when approval already exists, and cleans up same-day artifacts on success.

Evidence files are the boundary: Collector never writes the final brief, the Writer's normal writing path starts from persisted evidence (with one bounded targeted repair for local defects), and no stage sends without the explicit approval state.

## The safety model

![Gate and recovery states](assets/gate-state.svg)

- **Deterministic validator as hard gate.** A dependency-free PowerShell validator checks date, structure, named source links, placeholders, and internal process noise. The model cannot override it.
- **Content approval is not transport success.** The status model separates `delivery_allowed` (all content gates passed) from `email_sent` (the transport actually succeeded). A failed send never resets content approval, so a later stage may safely resend; only a content-gate failure returns to BLOCKED.
- **Single guarded delivery entry.** All content stages deliver through one script that re-runs the validator, checks the approval whitelist, and refuses when a human-review flag is set — even if other gate fields were wrongly set to SENDABLE.
- **Monotonic delivery record.** Once a status file records `email_sent=true`, a normal status patch cannot reset it to false.

## Failure and recovery

Repair follows a bounded gradient instead of unlimited agent improvisation:

1. **Stage 2: bounded local repair** — for a local defect (one item's URL, source, time, or supporting fact), reopen that source, run one targeted search, fix or drop the item, and keep the evidence set consistent. One repair pass only.
2. **Stage 3: full rescue authority** — when evidence is systematically untrusted or missing, the Supervisor may re-verify, fix, delete, replace, or fully rebuild evidence and the unsent brief, then run the full gate again (at most one corrective pass).
3. **BLOCKED + human review** — if the second full gate still fails, delivery is refused and the run is handed to a human; the delivery script blocks even if other fields were mislabeled as ready.

This gradient was driven by a real failure mode: evidence that *exists* but is *untrusted* (for example, several news items pointing at an outlet homepage instead of a specific article). In that state, a no-search rule and a write-from-evidence-only rule combine to deadlock. The current design makes repair scope explicit and restores full quality rules during rescue — rescue never lowers fact reliability.

## Real-code evidence

Four curated excerpts, each with truthful provenance and a `verbatim` / `adapted (privacy and scope redactions only)` label:

| File | Theme | Label |
| --- | --- | --- |
| [code/01-validator-core-rules.ps1](code/01-validator-core-rules.ps1) | Deterministic validator: structure, named source links, placeholders, process-noise rejection | verbatim |
| [code/02-send-if-ready-gate.ps1](code/02-send-if-ready-gate.ps1) | Single guarded delivery entry: re-validation, approval whitelist, manual-review refusal, transport-failure handling | verbatim |
| [code/03-status-patch-protection.ps1](code/03-status-patch-protection.ps1) | File-based status patching: monotonic `email_sent` protection and atomic persistence | verbatim |
| [code/04-stage2-3-contract.ps1](code/04-stage2-3-contract.ps1) | Regression tests: manual-review defense gate and successful-rescue to SENDABLE recovery | adapted — privacy and scope redactions only; control flow unchanged |

See [code/README.md](code/README.md) for production source references, exact line ranges, and the redaction list.

## Validation

Validation evidence is recorded with explicit layers, and nothing is presented as something it is not:

- **Executable tests** — a dependency-free PowerShell test suite that re-runs locally: validator expression guard, status-patch contract, Stage 2/3 gate matrix, post-write guard, and prompt structure checks.
- **Manual walkthrough matrix** — semantic scenarios (agent behavior) that scripts cannot fully verify, kept separate from automated coverage.
- **Design truth vs runtime truth** — this showcase describes the repository's design and contracts. It does not claim live runtime statistics, token measurements, or delivery success rates.

The production repository does not currently configure CI; the tests are local and re-runnable. See [docs/validation.md](docs/validation.md).

## Design decisions

Why the pipeline looks the way it does — the evidence handoff, the hard validator gate, the explicit approval state, the repair gradient, and the design/runtime boundary — is documented in [docs/design-decisions.md](docs/design-decisions.md).

## Scope and privacy

- No real local paths, usernames, accounts, emails, logs, configuration values, status or evidence files, private repository URLs, or third-party article content are published.
- Chinese comments and Chinese strings inside the excerpts are facts of the production product, not translation debt.
- This repository deliberately stays small. It is a portfolio companion, not a second software project.

## License

This repository is published as a technical showcase. No open-source license is currently provided.
