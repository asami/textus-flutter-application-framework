# ESA6 original-only photo facade — 2026-10-06

Status: Authored for PHASE-6 / ESA6-03 / ESA6-03-A; pending parent focused
validation, independent complete-Step review and acceptance. No validation was
executed by the implementation worker. Physical acceptance and full release
suites remain due. Owner: TFAF, common interaction forwarding.

`PhotoCaptureFacade.captureOriginal()` and `recoverOriginal()` directly forward
Core's `Future<CaptureMaterialReference?>` without catches, transforms, second
imports, settings/readiness prerequisites or provider/report work. Core owns the
actual camera result, unchanged original bytes/media/UTC/name, durable same-store
reference and shared guard. Null cancellation/empty recovery, exact permission,
camera/import failures and actual unsupported camera propagate unchanged.

Core's one service guard excludes original-only and all existing recognition,
acquisition and readiness actions reciprocally, including pending import. It
releases on success, failure or cancellation; the facade adds no guard or retry.
Accepted original ownership is preserved without deletion or rollback. Later
explicit recognition/comparison forwards unchanged original/report lineage.
Factory ownership and existing settings-backed controller/panel APIs are retained.

## Authored public executable scenarios

Scenarios in `test/photo_capture_facade_test.dart` use public flutter_test
operations with adjacent Given/When/Then comments at setup/action/assertion.
They use real FileCaptureStore and finite injected camera/provider gates, which
do not establish physical device or native inference acceptance.

| Scenario | Authored behavior |
| --- | --- |
| A1/A2 | No settings composition; exact Core saved reference identity, fresh-store original metadata/bytes, one import per actual image, consumed recovery, null capture/recovery and zero provider/read/report work. |
| A3 | Capture/recovery permission/camera/import/unsupported matrix; exact failure forwarding, no retries/fabricated results, next explicit operation and retained original bytes. |
| A4 | Held original capture/recovery/import excludes every facade photo/readiness API plus direct Core originals; reciprocal direct Core capture/recover/recognize/compare/probe/prepare excludes facade originals; finite cancellation releases shared ownership. |
| A5 | Explicit later recognize/compare uses the original-only reference once, with fresh durable raw history and preserved desired/actual/fallback/shared-attempt lineage. |

The existing facade recognition, report-failure, readiness and default-factory
scenarios retain their assertions. Same-file fixture extensions supply actual
saved references, one-shot recovery and finite started/gate signals; there is no
unrelated debt or new helper path.

## Consumption and pending evidence

App ESA6-03-B owns direct annotation text, page attachment, incomplete Draft
and reentry using these common APIs. ESA6-05 real local List/Detail and exact
physical P1–P8 remain due. Complete ESA6-03, independent review/acceptance,
Core/TFAF release full suites and App aggregate Phase6.1 validation remain
pending; Phase6.1 is unstarted.

Parent-selected Core/TFAF analysis and Core representative/accumulators plus
TFAF facade/controller/panel/storage accumulators are pending. No pass,
Step/Phase closure, review, commit, publication or device evidence is claimed.
All earlier native/device results and failures retain their stated scope. See
the [usage note](../../../notes/common-photo-recognition-interaction.md).

## Actual parent preflight and platform stop — 2026-10-06

Parent exact10paths preflight and all three repository `git diff --check` results
passed. All owned-file whitespace/final-newline checks and48 relative-link checks
passed as well. These static preflight results do not establish current compiler
or executable-specification acceptance.

The first selected Core `flutter analyze` request was submitted with
`require_escalated`, but CreateProcess rejected it before execution because
automatic approval review could not complete: the selected review model was at
capacity. The platform stated the action was not executed, identified a review
failure rather than an unsafe-action determination, and instructed that the
approval check must not be bypassed. Parent retained the actual raw request/result
under the App root at
`.codex-workflow/phases/PHASE-6/platform-review-failure-esa6-03-a-core-analyze-20261006.json`.

No selected analyze/test process started; no exit status, pass, test count or
session exists. The remaining four jobs were not submitted. No automatic retry,
alternate route or repair was consumed. The observed pre-existing private
constructor parameter spelling remains pending parent compiler verification;
no compatibility pass, repair or design change is admitted. Earlier successful
receipts retain their recorded historical scope. Focused validation, independent
complete-Step review/acceptance, physical acceptance and full release obligations
remain pending.

## F-ESA6-03-B-01 guarded original forwarding authoring — 2026-10-06

PHASE-6 / ESA6-03 / ESA6-03-B-R parent selects exact
`PhotoCaptureFacade.readOriginal(material)` forwarding to the borrowed Core
service. It preserves reference, bytes and actual error semantics; Core owns
the shared guard until borrowed store IO settles. No facade guard, readiness
selection, storage/lifetime authority, schema or continuous capture/read lease
is added. Existing common capture/recovery/readiness calls already reach Core.

| Scenario | Authored regression evidence in the existing facade spec |
| --- | --- |
| R1 | Exact material reference forwarded once, original-only saved metadata/bytes, unsupported camera/unavailable providers, caller mutation and repeated/fresh same-store reopen with zero implicit acquisition/provider/report work. |
| R2 | Observed finite actual material-read gate excludes every facade and direct Core photo/readiness/read API before effects; success or exact injected material-read error settles before a subsequent borrowed Core read is admitted. Original bytes and empty history remain durable. |
| R3 | Existing held original capture/recovery/import and direct Core recognition/comparison/probe/preparation cases also reject facade/direct original reads before a second read. |

Adjacent Given/When/Then locate setup/actions/assertions in each modified finite
branch. Same-file fixture debt completed: material reference observation and
separate materialReadGate/Started/Error; existing document readError semantics,
default counters and old scenarios remain. No unrelated debt is admitted.

Authoring is complete and unvalidated. Parent-selected actual validation and
fresh M2 complete-Step03 protected focused conformance remain required; no pass,
runtime closure, review, acceptance, commit or physical result is asserted.
Prior capacity failure and unverified constructor spelling remain retained,
without execution/retry. All prior receipt limits and physical/release/Phase6.1
obligations remain.

## ESA6-03 independent acceptance and commit preparation — 2026-10-07

Current status: Complete ESA6-03 A+B+F software acceptance is PASS; its
Step03-only commit is deferred pending prerequisite Step02/05 acceptance.

Owner: TFAF maintainer, coordinated by PHASE-6.

Update rule: Append actual admitted evidence and dated supersession; retain all
earlier raw failures, dates and held/pending records with their original scope.

Independent reviewer /root/esa6_03_acceptance_review_20261007 returned PASS for
complete A+B+F over 18 owned and 32 affected paths, with zero CPB/HYG/DEV.
Review reference esa6-03-acceptance-20261007@1 was admitted to typed ledger
esa6-review-ledger-20261006@6; parent append/save/read/require_review succeeded.
F-ESA6-03-B-01 is independently RESOLVED. This supersedes the earlier pending
Step03 independent-review and original repair18 conformance statuses. It grants
Step03 software acceptance only; Step02, Step05 and Phase acceptance remain due.

All 14 parent-selected validation obligations passed in the actual recovery.
Current TFAF analyze passed exit0; the capture accumulator passed 50 cases,
detail representative 16 and common accumulator 95, for 161 distinct selected
TFAF cases.

Commit preparation found 16 direct import edges to files absent from committed
HEAD outside the 18-file Step03 target, 15 dirty consumed-input edges and shared
Step05 path content. The actual index was empty in all three roots. A Step03-only
commit is deferred until prerequisite Step02/05 acceptance permits coherent,
dependency-ordered exact per-root commits. No intake, runner, staging or commit
occurred. This changes sequencing only; acceptance criteria, feature/protocol,
ownership, public API and original bases retain their existing authority.

Plain evidence records: review-admission-esa6-03-20261007.json,
sealed-source-esa6-03-20261007.json, validation-recovery-execution-20261007.json
and step-commit-preparation-esa6-03-20261007.json.

Prereview33 remains consumed; original repair18 is explicitly accepted by the
independent F closure, with no blanket acceptance of later harness repairs.
Step/Phase review repairs remain 0; nonconverging remains 0/limit3. The original
Goal remains active under the existing authority, binding, start and epoch.

Remaining gates: independent complete Step05 A+B review; complete Step02
S+A+E+B protected-focused review after exact Pixel11Pro and separate
standard-only Android P1–P8, including P7 actual saved-ID Candidates List/Detail
restart; per-root Step commits; upstream full release validation; and one
independent full Phase review/release. App aggregate validation remains deferred
to unstarted Phase6.1. Selected software evidence establishes no full-suite or
physical-device acceptance.
