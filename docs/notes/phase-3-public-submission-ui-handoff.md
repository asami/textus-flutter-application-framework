# Phase 3 public submission UI handoff

Current status: TFAF3-03 is accepted after complete parent intake and fresh independent protected Step review PASS over 66 selected paths, six owning files and both whole target programs. Actual FA1 1, eight-suite App 105, clean App analysis and dry two-target formatting with zero changes remain relevant; retained producer evidence is representative 1, 30 suites / 290, clean analysis and dry 21 / 0 changed. Its exact six-path native Step commit remains pending. TFAF3-01 and TFAF3-02 remain accepted and committed. Phase 3 stays active; complete package driver, sole comprehensive Phase review and distinct release, plus separate App owning/aggregate gates, remain pending.


Owner: textus-flutter-application-framework Phase 3 owns reusable public UI;
Core owns durable producers; the composing App owns domain integration and resources.

Update rule: append attributable parent terminal results, independent review and
verified commits separately. Preserve historical failed/final scopes and native/remote
limits. An admitted behavior change must update its existing executable specifications
through the owning workflow. This initial handoff changes no API or normative contract.

Accepted predecessors are Core release
`314b19b78fdf5eb2a5ee7922f81284a476912350`, TFAF3-01 commit
`19998a2b188e9df2332b7389a8a523f78e1fb699` and TFAF3-02 commit
`b80b739f3457c71f50ab4f7605a5e891f1ed4bea`. Step commits are intermediate
owning acceptance, not standalone TFAF package releases. Earlier pending-commit
statements in settled notes/journals are historical snapshots superseded by these
verified commits and the current Phase/checklist.

## Historical initial current-status snapshot — 2026-10-11

Historical initial Step 3 authoring snapshot before parent intake/software
validation; its pending/NOT RUN statements are superseded by the dated actual
parent receipt below. Exact original selections and outcomes remain retained.

Current status: initial TFAF3-03 documentary authoring complete under
`tfaf3-03-documentary-handoff-manifest-20261011@1`. Parent intake, new App
consumer checks, independent owning Step review and exact Step commit are pending.
Phase 3 remains active; its full driver, comprehensive review and distinct release
and separate App Step/Phase/aggregate gates remain pending.

## Existing public surface

Import [the public TFAF library](../../lib/textus_flutter_application_framework.dart)
and public Core values; consumers use no private package imports.
The settled contracts remain [facades and transfer binding](submission-facade-and-transfer-binding.md)
and [settings and status UI](submission-settings-and-status-ui.md).

| Public symbols | Existing responsibility |
| --- | --- |
| `SubmissionFacade` | Borrow the exact `SubmissionService`; forward Commit, retry, requestRun and fresh reads with exact values/defaults/errors. No runner or facade close. |
| `SubmissionConfigurationFacade` | Borrow the supplied configuration store; generic capability binding and `.android` binding remain distinct. Explicit snapshot/definitions/selections/reference-access/auth/credential operations do not establish readiness. |
| `SubmissionPresentationConfiguration` | Pure configured list/detail, upload/submission, item, destination, state, waiting, action, file and time labels. |
| `SubmissionStatusResourceRecord`, `SubmissionStatusBinding` | Exact typed Core status through standard resource configuration and fresh supported actions; no copied queue or transport state machine. |
| `SubmissionStatusSummary` | Disjoint current waiting/running/attention/completed counts; actual acknowledgement is required for completion. |
| `SubmissionSettingsController`, `SubmissionSettingsPage` | Explicit configuration loads/writes and literal safe authorization observations; page borrows controller. |
| `SubmissionStatusWorkspace`, `SubmissionStatusPage` | List/detail, per-file receipts, safe request-specific scheduling notice and optional typed Open item callback. |
| `SubmissionCommitInvocation`, `SubmissionCommitController`, `SubmissionCommitButton` | Borrow one App callback; owner validity and eligibility fence explicit Commit. Receipt means durable queued intent, with scheduling warning separately. |
| `SubmissionStatusOverviewController`, `SubmissionStatusSummaryPanel` | Fresh explicit summary load/Refresh and optional App navigation; unloaded/loading/fault are distinct from successful empty counts. |

Two destination identities remain separate: nullable storage connection and required
transport connection. The App supplies `storageDestinationLabel(String?)` and
`transportDestinationLabel(String)`, plus `uploadLabel`, `submissionLabel`, item
labels and titles. No Book, ISBN, Editing Studio, TKL or experiment identities are
embedded in TFAF. Only currently supported explicit actions dispatch commands.
Constructors, builds, selection, navigation and overview reads perform no transfer
or authorization; standard guarded read-only mounted `ResourceListDetail` load
remains supported.

Upload and submission states, waiting reasons, failures, actions and receipts stay
separate. Upload success is not matching ACK, server acceptance or Candidate formation.
Unknown/indeterminate and dependency waiting remain visible. Retry preserves immutable
intent and successful upload receipts instead of repeating completed uploads.

## Owner and consumer map

| Owner / consumer | Responsibility |
| --- | --- |
| Core: `SubmissionRequest`, `SubmissionService`, `SubmissionTransferStatus`, `SubmissionConfigurationStore`, `SubmissionReferenceAccessPolicy` | Durable immutable intent/configuration, auth observations, originals, providers/adapters, two operations, reference access and background execution. |
| TFAF public library and common UI | Borrowed forwarding, reusable presentation/controllers/resource binding, summary and explicit supported controls. No Book policy or independent transport state machine. |
| App: `BookSubmissionComposition`, `BookSubmissionWorkspacePage`, `BookSubmissionService`, `bookSubmissionPresentationConfiguration` | Flush current edits, recheck invocation validity after every await and immediately before Commit; apply ISBN OR title eligibility; freeze current original photo/audio, manual editable transcript, provenance and opaque context. |
| App: `HomePage`, `LocalBookMaterialDetail` | Configure Home waiting/attention entry, exact typed Material return and editing context, and own resource lifetimes. |

ExecutionContext/presentation context including arm data travels unchanged. TFAF
interprets no A/B or multiarm policy. Exact binary originals, Unicode and manual
whitespace corrections remain retained in the final immutable App snapshot.
Home summary is a configured entry, not a new main-tab requirement. Typed Open item
receives the current exact status and returns to the App's exact Material context.

Configuration identities are immutable; selections affect future intent without
retargeting queued work. Missing access is Unknown; explicitly empty access means
No access. Authorization enums are observations, not connectivity/access grants.
Credential input is obscured and ephemeral, cleared before explicit dispatch and on
replacement/unmount; it has no logging, readback, retained token or readiness inference.
`configurationMayHaveChanged` records issued changes conservatively before await.

## Borrowing and fixture ownership

Retirement before dispatch rejects stale callbacks and late publication. Issued
accepted work drains before borrowed Core cleanup. Remove/retire routes, dispose
owned view models and await binding/controller/workspace detach joins before the
App closes its Core stores/services. Workspace owns its binding/view model and its
default display only; supplied display/facade remain borrowed. Controllers dispose
only their notifier resources and do not cancel an issued durable Commit.

[SubmissionFixture](../../test/support/submission_fixture.dart) belongs exclusively
to `test/support`, is not a production export or fallback, and imports public
packages. Each scenario owns private real filesystem originals and SQLite with
injected `databaseFactoryFfi`, without a global factory replacement. Independently
controlled storage/transport/scheduler/access ports provide timing, failures and ACK;
binary bytes, Unicode, manual whitespace and opaque context are exact. Cleanup releases
gates, drains services, closes queue handles, then removes only the scenario directory.
Memory configuration and mocked native channels establish forwarding only.

## Evidence and limits

Parent receipt `tfaf3-02-consumer-validation-20261011@1` records actual CU3
representative 1 pass, combined 30 suites / 290 passes / 0 failures, lib/test
`No issues found!`, and final dry-format 21 files / 0 changed, all final exits 0.
These accepted host producer checks are reused for the unchanged settled programs.
The [Step 3 journal](../journal/2026/10/2026-10-11-tfaf3-03-acceptance.md)
retains exact actual raw-log locators and selected future commands.

Historical App evidence remains scoped: 100 controlled private-file/SQLite cases;
17 BH plus 55 mapper/service cases (72) for injected HTTP wire/provenance/context;
final navigation 46 and affected-consumer 360 after compact-heading correction.
Prior failed navigation fix28/fix29, Step 2 initial dry-format failure and its
mechanical three-suite correction remain historical; final results erase none of them.
These are producer handoff evidence, not App owning acceptance or new Step 3 PASS.

Native ND synthetic 68-byte Drive upload/fresh-process readback, NC policy and
NQ1–NQ4 persistence/WorkManager evidence retain their recorded scopes. Controlled
long consent is virtual time; supplied offline inputs are not a physical radio/OS-stop
experiment. Host checks establish no actual server receiver, whole Book Drive transfer,
successful native/headless upload or real long human consent. No exactly-once remote,
Candidate/enrichment/public-sharing or whole Book transfer claim follows.

Historical initial selected-command snapshot, superseded by the actual parent
receipt below: App FA1, the eight-suite accumulator, lib/test analysis and the two
owning-program dry-format check were selected, NOT RUN. Independent Step 3 review/commit and full
TFAF `scripts/validate-full.sh`, sole comprehensive Phase review and distinct release
remain required. App ESA6-06/07/08 owning and aggregate closure remain separate.

Related records: [Phase](../phase/phase-3.md), [checklist](../phase/phase-3-checklist.md),
[Step 1 journal](../journal/2026/10/2026-10-11-tfaf3-01-acceptance.md),
[Step 2 journal](../journal/2026/10/2026-10-11-tfaf3-02-acceptance.md),
[Hygiene](../journal/2026/10/2026-10-11-phase-3-hygiene-follow-up.md) and
[Development Candidate](../journal/2026/10/2026-10-11-phase-3-development-candidate-follow-up.md).
No new findings or Phase-clean conclusion are admitted by this authoring.

## Actual parent Step 3 consumer software receipt — 2026-10-11

Historical software/pre-review snapshot. Its pending-review and unchecked-box statements are superseded by the dated independent acceptance below; actual commands, results and limits remain retained.

Receipt `tfaf3-03-consumer-validation-20261011@1`, with selected requests
`tfaf3-03-validation-requests-20261011@1`, records completed parent initial
intake of all six owning paths, the full two-program public-library/test-fixture
source check and 56 local Markdown links. The checklist has 10 checked boxes;
all Step 3 and Phase closure gates remain unchecked. This projection changes no box.

Actual new parent software results are FA1 1 pass, the selected eight-suite
App accumulator 105 passes / 0 failures, App lib/test analysis `No issues found!`,
and owning Dart dry formatting 2 files / 0 changed. All four final commands exited
0; no repair was required. These results supersede initial selected NOT RUN and
pending-intake snapshots, whose exact commands remain preserved as history.
The documentary editor executed no validation, formatter or self-review.

| Actual execution | Raw log | Observed log terminal | Native terminal chunk | Final exit |
| --- | --- | --- | --- | --- |
| App_representative | [tfaf3-03-app-representative-20261011.log](/Users/asami/src/Project2026/nict-editing-studio-app/.codex-workflow/phases/PHASE-6.1/tfaf3-03-app-representative-20261011.log) | `00:05 +1: All tests passed!` | `638af9` | 0 |
| App_accumulator | [tfaf3-03-app-accumulator-20261011.log](/Users/asami/src/Project2026/nict-editing-studio-app/.codex-workflow/phases/PHASE-6.1/tfaf3-03-app-accumulator-20261011.log) | `01:21 +105: All tests passed!` | `61dab2` | 0 |
| App_analysis | [tfaf3-03-app-analysis-20261011.log](/Users/asami/src/Project2026/nict-editing-studio-app/.codex-workflow/phases/PHASE-6.1/tfaf3-03-app-analysis-20261011.log) | `No issues found!` | `b6198d` | 0 |
| TFAF_dry_format | [tfaf3-03-dry-format-20261011.log](/Users/asami/src/Project2026/nict-editing-studio-app/.codex-workflow/phases/PHASE-6.1/tfaf3-03-dry-format-20261011.log) | `Formatted 2 files (0 changed) in 0.01 seconds.` | `493929` | 0 |

The native terminal receipts above have redirected output; the supplied raw-log
readbacks establish the terminal test/analysis/format messages. The new actual
105-case count replaces no historical 100-case result: each retains its own scope.
Retained TFAF producer receipt `tfaf3-02-consumer-validation-20261011@1` remains
relevant: CU3 1, 30 suites / 290 passes / 0 failures, clean analysis and dry
21 / 0 changed. Accepted Core release
`314b19b78fdf5eb2a5ee7922f81284a476912350`, TFAF Step 1
`19998a2b188e9df2332b7389a8a523f78e1fb699` and Step 2
`b80b739f3457c71f50ab4f7605a5e891f1ed4bea` remain unchanged.

FA1 covers saved original photo/audio, current edits, common Commit, Home entry,
common status, typed exact Material return and rebuild. The eight suites cover
public Book/Core/TFAF settings, status/editor/navigation/root lifetimes,
success/failure/retry/offline and actual private-file/SQLite reopen with controlled
ports. This is the current public producer/consumer software boundary, not App
owning ESA6-06/07/08 acceptance or complete package validation.

Private real originals/SQLite and controlled ports establish host evidence only.
They establish no actual server receiver, whole Book Drive upload, native/headless
upload, physical radio/OS-stop experiment or real long human-consent success.
Existing ND synthetic 68-byte/NC/NQ limits, failed/final historical scopes and
separate upload/ACK/Candidate meanings remain intact.

Fresh independent protected Step 3 review and exact owning commit remain pending;
no owning Step or Phase acceptance is claimed. Phase 3 remains active with its
original three Steps / 49-path scope. Complete package `scripts/validate-full.sh`,
the sole comprehensive Phase review, canonical journal/checklist/index handoff
and distinct Phase release remain required; all App owning/aggregate gates remain
separate. Original authority/bases/binding/epoch/ledger6, Core80/TFAF49/App153,
R29/global42/local40 and repair counters/history are retained. No new findings,
repair, counter reset, normative reinterpretation or successor authority is added.

This four-document factual projection is authored under
`tfaf3-03-documentary-handoff-manifest-20261011@2`; parent owns factual/static
intake of the projection and subsequent review/acceptance transitions.

## 2026-10-11 — Owning TFAF3-03 acceptance before commit

Fresh independent protected reviewer `/root/tfaf3_03_owning_step_review_20261011`
returned sealed PASS in `tfaf3-03-owning-step-review-20261011@1`. All 66 selected
paths, all six owning files and both complete target programs were covered.
Current Boundary Blockers, Hygiene and Development Candidates are all zero.
The parent admitted the actual native final result at owning review ledger
revision 7; this is Step 3 acceptance, not the comprehensive Phase review.

Parent actual FA1 1 pass, eight-suite App accumulator 105 passes / 0 failures,
clean App lib/test analysis and two-target dry formatting / 0 changed remain
relevant. Retained producer evidence is CU3 1, 30 suites / 290 passes / 0
failures, clean analysis and final 21-target dry formatting / 0 changed. Exact
raw logs and native terminal receipts remain in the prior software receipt.
Only factual documentary status is projected here; no executable, fixture,
configuration, API, dependency or validation result changes, and no tests repeat.

Step 3 is accepted; its exact six-path native commit remains pending. The
fixture/composition implementation and matching two-destination-label/Home/
typed Material-return handoff behavior are now checked, making 12 checked
boxes. The composite evidence/review/commit item remains open until the native
commit is verified. Phase 3 remains active with the original three Steps and
49-path scope; complete package `scripts/validate-full.sh`, the sole comprehensive
review, canonical journal/checklist/index handoff and distinct release remain
required. App ESA6-06/07/08 owning acceptance and final aggregate gates stay separate.

Core release `314b19b78fdf5eb2a5ee7922f81284a476912350` and TFAF Step commits
`19998a2b188e9df2332b7389a8a523f78e1fb699` /
`b80b739f3457c71f50ab4f7605a5e891f1ed4bea` remain accepted. Host controlled
fixtures do not establish actual server ACK/Candidate formation, whole Book
Drive transfer, successful headless upload, physical radio/OS-stop or long human
consent. Native ND/NC/NQ and historical failed/final scopes retain their limits.
Original authority/bases/epoch, Core80/TFAF49/App153 and R29/global42/local40,
repair counters and DISC-TFAF3-03-RESUME-ADJACENCY-001 remain historical. No new
finding, semantic repair, counter reset, successor or Phase closure is introduced.
