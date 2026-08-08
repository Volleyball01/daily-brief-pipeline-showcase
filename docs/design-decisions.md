# Design Decisions

This document explains why the pipeline is shaped the way it is. It describes
the private production repository's design and contracts; it does not claim
anything about a specific runtime's execution history.

## 1. Structured evidence as the handoff boundary

The biggest reliability problem in a one-shot AI automation is context: every
search result and page fetch stays in the conversation, so by the time the
agent writes, it is working from a large, noisy context and is more likely to
degrade or hallucinate.

The pipeline replaces shared context with files:

```text
Collector ──(atomic evidence JSON)──> Writer ──(brief + status)──> Delivery
```

The Collector opens final source pages, verifies claims, and writes structured
evidence (weather, news, deep reading, sources). The Writer's normal writing
path starts from that evidence. If it finds a local evidence defect (a single
item's URL, source, time, or supporting fact), Stage 2 may perform one bounded
targeted repair pass; if the evidence is systematically untrusted, it escalates
to the Supervisor. Neither stage needs the other's conversation.

The Collector's atomic write contract is a design-level prompt contract in the
private repository: write to a temporary file in the same directory, re-read it,
validate it as JSON, then replace the final file with a safe move. It is
documented here and in the architecture diagram because it is a contract, not
an executable script; this showcase does not present it as executable evidence.

## 2. Deterministic validator as the hard gate

Content quality cannot depend on the model's mood. The validator is a
dependency-free PowerShell script that checks, deterministically:

- title date and weekday against the configured timezone;
- required sections and field shapes;
- named Markdown source links in the weather and news sections;
- duplicate source URLs;
- unresolved template placeholders;
- internal collection / process noise leaking into the public body;
- language rules for the closing note.

The validator is the hard gate: no stage may send when it fails, and the
delivery entry re-runs it immediately before sending.

## 3. Explicit approval state and a single delivery entry

`delivery_allowed` means exactly one thing: all content gates passed and
sending is allowed. It does not mean the transport will succeed. `email_sent`
records whether the transport actually succeeded.

This separation matters:

- A transport failure keeps `delivery_allowed=true`, `gate_status=SENDABLE`,
  and `email_sent=false`, and records an `error`. A later stage may resend.
- Only a content-gate failure (validator re-fail, self-check fail, approval
  whitelist miss) returns the run to BLOCKED.
- Once `email_sent=true` is persisted, a normal status patch cannot reset it
  to false — the delivery record is monotonic.

All content stages deliver through one guarded script. It re-runs the
validator, checks the approval whitelist, and refuses when
`manual_review_required=true`, even if other gate fields were wrongly set to
SENDABLE by a bug.

## 4. Bounded repair, then full rescue, then human review

Repair is a gradient, not an open-ended license to improvise:

1. **Stage 2 (Writer): bounded local repair.** One repair pass for local
   defects — a single item's URL, source, time, or supporting fact. Reopen the
   item's source, one targeted search per defective item, fix or drop the
   item, keep `sources.json` consistent with `news.json`. No new research
   topics.
2. **Stage 3 (Supervisor): full rescue authority.** When evidence is missing
   or systematically untrusted, the Supervisor may re-verify, fix, delete,
   replace, or fully rebuild evidence and the unsent brief, following the full
   Collector + Writer quality rules — rescue never lowers fact reliability.
   After a successful rescue, failed-state residue is cleared
   (`manual_review_required=false`, `supervisor_status=PASS`) while
   `blocked_at` is kept as history.
3. **At most one corrective pass, then BLOCKED + human review.** If the second
   full gate still fails, the run is handed to a human and the delivery script
   refuses to send.

The gradient exists because of a real failure mode: evidence that *exists* but
is *untrusted*. When several news items point at an outlet homepage instead of
a specific article, a no-search rule and a write-from-evidence-only rule
combine into a deadlock: no stage is allowed to fix what no stage trusts. The
fix was to make repair scope explicit at each stage.

## 5. Design truth vs runtime truth

This repository describes the intended design and source-of-truth rules. The
runtime system records what actually ran, when, and with which result. The two
are kept separate:

- repository docs win for intended design and contracts;
- runtime logs and active records win for actual execution;
- a reference cron snapshot is a desired-state example, never proof that a job
  actually ran.

The showcase therefore never presents a design as a measured runtime result.

## 6. Deliberately out of scope

- The private project has Weekly, Monthly, and Knowledge subsystems. They exist
  and are not part of this showcase.
- No real outputs, screenshots, emails, status files, evidence files, or
  runtime artifacts are published.
- No benchmark numbers, token measurements, or delivery statistics are
  published unless they can be re-verified from current production sources.
