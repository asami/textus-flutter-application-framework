# Submission facade and transfer resource binding

The planned [TKL delivery facade](tkl-managed-material-delivery.md), decided
2026-10-24, replaces client-owned physical destination provisioning for the new
route. Existing facade descriptions below record the delivered API, not proof
of TKL support. Core supplies TKL-derived destination and delivery state; TFAF
must not create a second provider configuration authority.

Current status: TFAF3-01 is accepted after parent intake, independent protected
Step review and the admitted comment-only M0 closure. Parent post-Core consumer
software validation passed under tfaf3-01-consumer-validation-20261011@1.
The exact owning Step commit remains pending. Core Phase 2 is accepted at release
`314b19b78fdf5eb2a5ee7922f81284a476912350`, with all 844 tests passing.
C2/App integration acceptance, TFAF full Phase validation/review/release
and App Phase 6.1 closure remain pending; Core closure accepts none of them.

Owner: TFAF owns the public borrowed facades, presentation callbacks, resource
binding and current counts. Core owns immutable intent, durable queue/configuration,
original bytes, execution and native capability. App owns current-edit flush,
request construction, ISBN OR title eligibility, domain labels, navigation and
the lifetime of Core resources.

Update rule: Update this note and CF1–CF8 together for an admitted behavior change.
Record actual parent validation and independent acceptance separately in the
[historical delivery journal](../journal/2026/10/2026-10-10-esa6-06-submission-facade-and-binding.md)
and the [owning Step receipt](../journal/2026/10/2026-10-11-tfaf3-01-acceptance.md).
Preserve source/software/native/Drive/own-Phase/whole-Step acceptance distinctions.
Append dated owning evidence; preserve the snapshots below and all public contracts.

## Historical initial entry status — 2026-10-11, before validation

At initial authoring, PHASE-3 / TFAF3-01 / TFAF3-01-D-entry documentary adoption
was being authored; consumer refresh, independent owning review and exact Step
commit were pending. This snapshot is superseded for software validation only
by the dated parent receipt below; owning review/commit remain pending.

## Historical C1 software snapshot — 2026-10-10

PHASE-6.1 / ESA6-06 / C1 source and executable specifications
authored under esa61-submission-tfaf-c1-manifest-20261010@1. Parent C1 software
validation is complete: initial 14-suite accumulator 111 passed; final four new
suites 26 passed after mechanical syntax, formatting and GWT comment corrections.
Final analysis found no issues; dry formatting checked 11 files with zero changes;
diff check passed. Independent complete C acceptance remains pending. C2, App D,
native/Drive, upstream own-Phase and whole-Step/Phase acceptance remain open.

## Public borrowed APIs

Import the [public TFAF library](../../lib/textus_flutter_application_framework.dart)
and [public Core library](../../../textus-flutter-core/lib/textus_flutter_core.dart)
for Core values. Constructors perform no IO.

SubmissionFacade(service: service) borrows the exact supplied Core service.
It forwards commit(SubmissionRequest), retry(String), requestRun(String),
find(String), and findForSubject(String kind, String subjectId).
findTransferStatus, findTransferStatusForSubject and listTransferStatuses require
observedAt; networkState independently defaults to SubmissionNetworkState.unknown
on every call. Exact values, futures, defaults and errors pass through without
normalization, copying or caching. There is no runner, default resource acquisition,
credential lookup or facade close.

App freezes current edits before constructing intent. Commit durably accepts
intent and requests a wake; it performs no upload or submit. Reads and navigation
neither schedule nor run transfer work. Only the actual Core/native driver runs
work. Original and resource ownership stays with the composing owner.

SubmissionConfigurationFacade(store: store) borrows a generic store. Its .android
factory binds the same actual AndroidSubmissionConfigurationStore to configuration
and native operations. Both forward snapshot, putDrive, putHttp, select with
nullable storageConnectionId/transportConnectionId, and setReferenceAccess with
required transportConnectionId/storageConnectionIds. Null selection clears future
defaults; queued intent is never retargeted. Missing access is unknown; an empty
list is explicit revocation.

hasDriveAuthorization and hasHttpCredentialWriter describe bound operations,
never platform readiness, credential availability, connectivity or remote access.
Android-bound authorizationState and authorizeDrive return exact Core
SubmissionAuthorizationState. setHttpBearerToken(String, String?) is an explicit
ephemeral write. Generic native calls throw fixed UnsupportedError before IO.
There is no token getter, retained secret, unrelated callback store or facade
disposal. Native platform checks, availability/grants and safe errors remain Core.

Configuration routes borrow the same owned Core store. Retire those routes before
rebuilding immutable adapter/resource composition after definition changes.
Do not simultaneously own independent native configuration handles or replace a
queued request's destination identity.

## Presentation and existing resource composition

Immutable SubmissionPresentationConfiguration requires listTitle, detailTitle,
uploadLabel, submissionLabel and these exact pure callbacks:

- String Function(SubmissionTransferStatus) itemLabel
- String Function(String?) storageDestinationLabel
- String Function(String) transportDestinationLabel

Optional callbacks are String Function(SubmissionTransferOperationState)
operationStateLabel, String Function(SubmissionTransferWaitingReason)
waitingReasonLabel, String Function(SubmissionTransferAction) actionLabel,
String Function(SubmissionFileTransferStatus) fileLabel and
String Function(DateTime) formatTime. Generic English defaults cover every Core
enum; file name/key and actual ISO timestamps retain their meaning. All callbacks
must be pure presentation with no command, credential or storage authority.
Unknown measurable progress never becomes a percentage.

SubmissionStatusResourceRecord retains the exact Core status. Its inherited id
is requestId and display values are immutable strings rather than durable
serialization. SubmissionStatusBinding borrows facade/presentationConfiguration;
its optional now defaults to DateTime.now and networkState defaults to unknown.
Each list/detail read obtains a fresh Core projection. Null means absent and
query errors propagate; no status cache or duplicate queue exists.

The binding's configuration is standard ResourceListDetailConfiguration, with
primary name and secondary operations. Operations displays both labeled states
on separate lines. Detail fields are name, operations, upload, submission,
storageDestination, transportDestination, updatedAt, uploadWaiting,
submissionWaiting, uploadFailure, submissionFailure, nextAttemptAt and
acknowledgement. Absent causes/failures/deadlines/acknowledgements stay empty.
Actual acknowledgement time and uncertain outcome are distinct. Exact files and
receipt counts remain accessible on the wrapped status.

~~~dart
final binding = SubmissionStatusBinding(
  facade: facade,
  presentationConfiguration: presentation,
);
final viewModel = ResourceViewModel(
  dataSource: binding,
  actionHandler: binding,
);
// Supply viewModel and binding.configuration to ResourceListDetail.
// Dispose viewModel before/with awaiting binding.detach().
~~~

Existing [resource lifecycle](resource-list-detail-lifecycle.md) and
[adaptive display ownership](adaptive-list-detail-display-model.md) apply directly.
Binding creates no views or notifications. Route composition owns its view model
and supplied display model; the existing widget borrows them.

## Actions, retirement and counts

actionsFor accepts only typed records and offers exact supported retry/requestRun
enum names with configured labels. execute rejects detached, busy, foreign,
unknown and unsupported observed actions before IO, reserves actionBusy
synchronously and queries the same request id freshly. Missing/stale actions
throw StateError. Owner checks follow awaits and immediately precede one command;
no callback or await separates that last check and dispatch.

lastActionResult retains the exact successful current SubmissionCommitResult.
A new accepted action or detach clears it. Its scheduling notice means durable
intent is queued, never submission success. An initiated Core command may finish
durably after route detach with no late result publication.

detach synchronously sets isDetached and rejects new reads/actions. It returns
the same idempotent future joining every accepted read/command, including reentrant
clock/network/presentation callback cases. Late results fail instead of publishing.
Detach closes none of the borrowed Core resources. Dispose the route view model
before/with detach, await the join, then let the Core owner drain and close its own
resources. This prevents retired notifications and action-success refresh.

SubmissionStatusSummary.fromStatuses derives disjoint current counts: completed
requires upload succeeded/notRequired plus submission succeeded; otherwise
failed/outcomeUnknown or uncertain acknowledgement needs attention; otherwise
either running operation counts running; everything else counts waiting. It has
no command/cache/state-transition authority. Home owns navigation. Upload/wake
success never establishes downstream Candidate success.

## Authored specifications and delivery limits

| Spec | Observable authored evidence |
| --- | --- |
| CF1 | Real originals/SQLite Commit, exact Unicode/context, re-Commit/distinct reopen, inert reads/errors/borrowed reuse |
| CF2 | Partial upload retry/receipt reuse, uncertain acknowledgement and same-intent controlled submit |
| CF3 | Fresh typed immutable mapping, changed receipts, absent/error distinction and existing view failure flags |
| CF4 | Foreign/unknown/missing/stale actions, busy reservation, held query/command detach joins and reentrant fencing |
| CF5 | Generic/native capabilities, actual Android store/channel arguments, explicit auth/token writes and Core errors |
| CF6 | Literal old/current snapshots, unrelated defaults, immutable access replace/revoke and config-only JSON reload |
| CF7 | Public projections, disjoint counts, all enum defaults/custom callbacks and no fabricated percent/time |
| CF8 | Existing model/display/ListDetail lifecycle, scheduling notices, action failures and retired late-completion suppression |

The fixture imports public packages only, opens real FileCaptureStore/SQLite with
injected databaseFactoryFfi and never replaces the global factory. Controlled
ports have explicit gates/failures. Cleanup releases gates, drains service, closes
queue handles, then removes only the test directory. Memory configuration and
mocked native channel prove software forwarding, not native durability.

The following delivery-limit snapshot was authored for C1 on 2026-10-10;
the dated owning projection below supplies the present status.

C2 remains pending: shared configuration controller/settings, status screen with
per-file detail/safe notices/material callback, shared Commit control and Home
summary. D owes actual App edit-flush/ISBN OR title/immutable-intent/labels/navigation
integration and native encrypted write/reopen/headless/revocation proof. ESA6-07
separately owes actual Drive binary upload/readback and remote reference access.
Native/Drive/whole ESA6-06/final App Phase acceptance remain pending.

Core Phase 2 and TFAF Phase 3 remain planned with execution not started in the
producer handoff. C1 starts/closes neither; attributable package/Phase validation,
review and release handoffs stay separate before final dependent runtime acceptance.
Historical S1/S2 documentation Hygiene remains outside this manifest.

Implementation editor executed no validation, formatter, dependency, build,
runtime, device or network commands. Source inspection and owned-file authoring
establish no software acceptance. Parent owns representative/accumulator/analysis/
format/diff gates and independent complete C review.

Related contracts: [Core intent](../../../textus-flutter-core/docs/notes/durable-material-submission.md),
[status](../../../textus-flutter-core/docs/notes/background-transfer-status-contract.md),
[reference access](../../../textus-flutter-core/docs/notes/submission-reference-access-contract.md),
[connections](../../../textus-flutter-core/docs/notes/submission-http-drive-connections.md),
[native ownership](../../../textus-flutter-core/docs/notes/android-submission-runtime.md)
and [App Phase 6.1](../../../../../docs/phase/phase-6.1.md)
with its [checklist](../../../../../docs/phase/phase-6.1-checklist.md).

## Owning contract and consumer adoption — 2026-10-11

The accepted Core release is `314b19b78fdf5eb2a5ee7922f81284a476912350`.
Its [Phase 2 completion journal](../../../textus-flutter-core/docs/journal/2026/10/2026-10-11-phase-2-completion.md)
records three accepted Step commits, the sole comprehensive review and focused
cycle1 closure, clean analysis, all 844 tests passing and exit 0 from the full
package driver. The verified release handoff is the producer evidence; the
journal's pre-commit projection retains its original chronology.

| Owner / boundary | Owning contract and actual evidence scope |
| --- | --- |
| Core: SubmissionService, SubmissionConfigurationStore, AndroidSubmissionConfigurationStore, SubmissionTransferStatus | Accepted durable two-operation producer; immutable identities/values/errors/defaults/actions and resource ownership remain Core. Full 844-pass release is Core package evidence. |
| TFAF: SubmissionFacade, SubmissionConfigurationFacade, SubmissionPresentationConfiguration, SubmissionStatusBinding, SubmissionStatusSummary | Exact borrowed forwarding, generic presentation and existing ResourceViewModel/configuration/lifecycle. TFAF3-01 adopts these contracts; in the initial PLAN/authoring snapshot its representative, 14-suite accumulator and analysis refresh were planned and not yet executed. See the subsequent parent receipt below. |
| App: BookSubmissionComposition, BookSubmissionService, bookSubmissionPresentation | App freezes edits, applies ISBN OR title eligibility, constructs immutable Book intent with opaque context, supplies labels and owns navigation. Eight suites / 100 controlled host checks are scoped consumer history; whole App acceptance remains pending. |

Historical C1 evidence is representative 1, early facade/configuration 9,
initial selected 14 suites / 111 passes and final four suites / 26 passes, with
clean final analysis and 11 dry-format targets / zero changes. Historical
[C2 software evidence](../journal/2026/10/2026-10-10-esa6-06-submission-settings-and-status-ui.md)
is representative 1 and 27 selected suites / 234 passes with clean analysis.
These results are borrowed software history, not owning TFAF Step acceptance.
The host refresh is required by the subsequently accepted Core evolution;
new documentation alone is not a reason to repeat native or remote experiments.

Real private originals/SQLite and controlled ports establish their exact local
software scopes. Memory configuration and native channel mocks establish
forwarding only. Prior native policy 37, NQ persistence/WorkManager and 68-byte
synthetic Drive/readback evidence retain their recorded limits; they establish
no whole Book-media/server transfer, successful headless upload, physical radio
toggle/OS-stop experiment or long real human consent wait. Original audio,
manual editable transcript, Unicode and provenance remain retained.

Owning independent Step review and exact commit, Steps TFAF3-02/03, full package
validation through scripts/validate-full.sh, sole comprehensive Phase review
and distinct release remain pending under [Phase 3](../phase/phase-3.md) and its
[checklist](../phase/phase-3-checklist.md). C2 source/UI, native/Drive and App
Step/Phase gates stay separate. Original shared Goal, App binding, bases, epoch,
R29 and global42/local40 repair history remain retained; the new owning ledger
does not replace or promote historical App reviews. No successor starts here.

## Actual parent post-Core consumer software receipt — 2026-10-11

Receipt: tfaf3-01-consumer-validation-20261011@1. The parent executed the
CF1 representative (1 pass, exit 0), selected 14-suite accumulator (125 passes,
exit 0) and lib/test analysis (No issues found, exit 0) after the accepted Core
handoff. This supersedes the initial planned/not-yet-executed consumer snapshot.
See the [owning receipt](../journal/2026/10/2026-10-11-tfaf3-01-acceptance.md#actual-parent-post-core-consumer-software-receipt--2026-10-11).

Private files/SQLite, controlled ports and mocked native configuration channels
establish host consumer software evidence only. This result supplies no actual
native, Drive, server, headless or whole-package proof. Parent final static
intake, independent protected Step review and exact commit remain pending.
Steps TFAF3-02/03, the comprehensive Phase review, full scripts/validate-full.sh
and distinct release remain required; no owning Step or Phase acceptance is claimed.

## 2026-10-11 — Owning TFAF3-01 acceptance before commit

Parent intake covered all 16 owning paths, nine complete target programs and 76
local Markdown links. The post-Core CF1 representative passed 1 case, the
selected 14-suite accumulator passed 125 cases, and analysis found no issues;
all commands exited 0. These are host consumer checks using private originals,
SQLite, controlled ports and mocked native configuration channels.

Independent protected reviewer `/root/tfaf3_01_owning_step_review_20261011`
recorded `tfaf3-01-owning-step-review-20261011@1` over the 44 selected paths.
It reported one authoring blocker, `CPB-TFAF3-01-GWT-001`, and no Hygiene or
Development Candidate findings. Registered editing corrected comment placement
in four existing test suites; executable statements, fixtures and order were
preserved. Parent exact-source/static verification admitted the M0 closure
`tfaf3-01-gwt-m0-amendment-20261011@1`, retaining the original review and its
finding. The latest Step chain has zero current blockers. No product tests or
independent review were repeated for this comment-only correction.

TFAF3-01 is accepted; the exact 16-path Step commit is still pending. This dated
receipt supersedes the pre-review pending statements in the earlier snapshots
above without changing their historical outcomes. Only Entry, the TFAF3-01
Core-handoff implementation item and its matching Core-contract behavior item
are checked. The composite evidence/review/commit item remains open until the
native commit is verified. TFAF3-02/03 remain planned. Complete package
scripts/validate-full.sh, the sole comprehensive Phase review, canonical journal
and checklist/index handoff and the distinct Phase release remain required.

No native, Drive, server, headless or whole-package result is inferred from the
host evidence. App Step/Phase/aggregate closure remains separate. Original Goal,
bases, epoch, scopes and review/repair history are retained. This projection
changes no executable, normative contract, configuration, fixture or test logic.
