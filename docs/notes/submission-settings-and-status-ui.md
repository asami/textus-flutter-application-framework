# Submission settings and status UI

- Current status: TFAF3-02 is accepted after parent complete-source intake and fresh independent protected owning Step review PASS. Actual CU3 representative passed 1; combined 30-suite host refresh passed 290 with 0 failures; lib/test analysis found no issues; final dry formatting checked 21 files with 0 changed. Its exact 29-path Step commit is pending. TFAF3-01 is accepted and committed at 19998a2b188e9df2332b7389a8a523f78e1fb699. TFAF3-03 remains planned; Phase full driver/review/release and separate App/native/Drive/server/headless gates remain pending.
- Owner: TFAF shared presentation maintainer; App composition owns borrowed Core resources, current edits and navigation.
- Update rule: Keep this note aligned with the public C2 components and actual validation/review receipts. Record acceptance only after the responsible parent supplies its evidence; host controlled ports never establish native or Drive acceptance.

The [C1 facade and transfer binding](submission-facade-and-transfer-binding.md) retain Core authority for durable intent, safe configuration, immutable projections, authorization and execution. C2 adds presentation and current owner lifetimes over those contracts. Constructors are inert. Settings, Commit and summary mount/build/replacement start no commands. The status page composes the standard `ResourceListDetail`, preserving its guarded postframe read-only load, adaptive panes, hinge policies, selected detail and fresh supported actions.

## Explicit configuration

Create `SubmissionSettingsController(facade: facade)` and call `load()` at the App lifecycle boundary. Its page borrows that controller. Reload is an explicit read. Add Drive and Add HTTP construct immutable Core definitions only after user input. Registered IDs retain their account/folder or HTTPS endpoint; there is no retarget or delete operation. Add/load do not select defaults. Default selectors include None and pass both desired IDs, including null to clear. Selections apply to new submissions and do not rewrite queued requests.

Reference access is an operator declaration for one exact HTTP target and chosen Drive IDs. Missing means Unknown; an explicit empty set means No access. Saving does not grant or verify remote permissions. Authorization controls exist only when the facade binds that capability, act on the chosen Drive ID and display Core enum observations literally. Neither a recorded authorization nor a declaration proves connectivity or remote access.

Bearer input exists only with the bound credential writer. It is obscured, never prefilled or read back, and clears immediately before the exact target's explicit Set/Clear command. Clear sends null. Replacement and unmount clear and dispose the input buffer. Tokens have no public getter, readiness inference, configuration snapshot field, queue value or logging path.

Safe Core configuration failures retain their closed code/message. Argument errors become `configurationInvalid`; other failures become `configurationUnavailable`. Raw exceptions, causes and input are not published. `configurationMayHaveChanged` is monotonic and set immediately before an issued configuration/authorization/credential write, even if that write later fails or finishes after owner retirement. The App uses it to conservatively drain and recompose configuration consumers.

## Status and overview

`SubmissionStatusWorkspace` owns its C1 binding and `ResourceViewModel`. It owns the display model only when it creates the default. A supplied display and facade remain borrowed. The status page uses the binding's exact configuration and ordinary fresh retry/requestRun actions. No build, navigation, selection or overview read pumps a runner, uploads, submits or schedules work.

The detail supplement accepts only `SubmissionStatusResourceRecord`. Files appear in original request order, with configured labels and actual Core file states, safe original ID, media type and byte length. Stored time appears only for an actual storage receipt. It exposes no local paths, object URLs, reservations, credentials, guessed active file/failure or percentage. A scheduling warning is shown only for the selected request's exact last action result while no action runs: “Queued; background scheduling needs attention”. It conveys queued durable intent without server acceptance.

Optional Open item navigation reserves once, receives the current immutable Core status and checks mounted workspace and selected request before dispatch. Replacement/unmount fence late completion. Common UI interprets no Book, ISBN, TKL or downstream Candidate meaning.

`SubmissionStatusOverviewController.load()` always queries freshly, defaults network observation to unknown and clears an old summary when refresh begins. The summary panel performs explicit Refresh and optional App navigation only. Unloaded, loading and fault states display no fabricated counts. Successful empty input alone produces zero. Waiting/running/attention/completed retain the C1 disjoint partition; completed requires actual server acknowledgement, and no downstream success or percentage is inferred. App D loads overview at its own lifecycle boundaries.

## Commit and ownership handoff

`SubmissionCommitController` borrows one fixed App callback. `SubmissionCommitInvocation.isCurrent` describes owner validity, not execution consent or cancellation. App D must flush current edits, recheck that value after every await and immediately before queue Commit, revalidate current ISBN OR title, then freeze the original media/provenance request. TFAF contains no Book validation or Core acquisition logic.

The button requires App eligibility and displays the App reason when disabled. An explicit live click reserves one callback. Success shows the exact request ID as queued for background submission, with a separate safe scheduling warning when necessary. A callback fault shows only “Could not queue submission.” Queued receipt is distinct from server submission acceptance.

Every controller reserves accepted work before notification or external callbacks. Reentrant detach before dispatch prevents Core/App calls. Retirement immediately fences future dispatch/publication and joins already accepted work. A previously issued durable write/Commit may finish; it is neither cancelled nor closed by the UI. Dispose is idempotent and cleans only notifier resources. Remove the page before/while detaching its workspace; await all relevant detach futures before closing borrowed Core stores/services. Workspace retirement disposes its VM, immediately fences the binding, drains it, and then disposes only its owned default display.

The settings route composes alongside adaptive Common Settings. It does not replace the existing engine. Controls wrap and scrolling detail/forms remain usable with narrow screens and large application text. `ApplicationTextScaling` and the text-aware app bar are reused when present.

The seven new suites author CU1–8, including `CU3 explicit Commit and status page preserve two-stage durable intent`. Real filesystem originals and SQLite handles support host specifications; controlled scheduler, storage, transport, access and native-channel observations remain test evidence only. The parent owns the representative and accumulated suites, analysis, formatting checks, diff verification, independent review and all subsequent acceptance transitions.

## Historical C2 software receipt — 2026-10-10

Before this owning adoption, the parent host representative passed 1 case and
27-suite accumulator passed 234 cases with no failures; analysis was clean.
These dated C2 results remain historical host evidence and supply no current
owning review/commit or native/Drive/server acceptance.

## Historical prior current-status snapshot

The following status was recorded before the owning receipt below; it is retained
as history and does not state the current Step status.

- Current status: Owning TFAF3-02 documentary/specification-conformance adoption in progress. Selected CU3 representative, combined 30-suite host refresh, analysis and 21-target dry format have not yet run. Independent owning Step review/commit and Phase full driver/review/release are pending.

## Historical initial owning TFAF3-02 adoption — 2026-10-11, before validation

Historical initial-authoring snapshot, superseded by the actual receipt below:
The current owning documentary/specification-conformance adoption is in progress
under `tfaf3-02-documentary-spec-entry-manifest-20261011@1`. Explanatory comments
in existing CU1–CU8 and G1–G6 scenarios are adopted without executable changes.
The parent-selected CU3 representative, combined 30-suite host refresh, lib/test
analysis and dry formatting over 21 targets have not yet run. Parent full source
intake, independent protected Step acceptance and exact Step commit are pending.
Phase full validation through `scripts/validate-full.sh`, its sole comprehensive
review and distinct release remain required. TFAF3-03 remains planned; public
exports and fixture handoff belong to that Step. Intermediate Step commits are
not package releases. App acceptance and native/Drive/server/headless proof
remain separate.

Core Phase 2 is closed at `314b19b78fdf5eb2a5ee7922f81284a476912350`.
TFAF3-01 is accepted and committed at
`19998a2b188e9df2332b7389a8a523f78e1fb699`. Earlier pending-commit paragraphs
are historical snapshots superseded by this verified native commit. Original
shared Goal, App binding, bases, epoch, R29 and global42/local40 history remain;
the owning TFAF ledger does not replace or promote the App reviews.

| Owner / consumer | Settled boundary adopted by Step 2 |
| --- | --- |
| Core | Borrowed configuration/status producers retain immutable identities, safe errors, exact defaults, durable intent, originals, operations and resource ownership. Generic capability binding and Android binding remain distinct from readiness or permission grants. |
| TFAF settings | Explicit loads/writes only; defaults affect new intent; missing and explicitly empty access differ. Authorization observations are literal and capability-bound. Bearer input is obscured/ephemeral, clears before dispatch and on replacement/unmount, and has no getter or retention. Issued writes mark configurationMayHaveChanged monotonically before await. |
| TFAF status, Commit and overview | Standard ResourceListDetail read-only mount load, exact two-stage status/file receipts, fresh supported actions, request-specific scheduling warning and typed navigation. Commit borrows one App callback; queued intent is separate from acknowledgement. Overview distinguishes unloaded/loading/fault from actual empty counts. |
| TFAF lifetimes and layout | Busy reservations precede notifications, retirement is synchronous, accepted work drains and late publication is fenced. Borrowed resources remain with their owner. Common Settings/resource layout, narrow/wide/fold/hinge and scaled scrolling/wrapping retain their settled behavior. |
| App | Flush current edits, recheck owner validity after awaits, apply ISBN OR title eligibility, freeze domain request/originals/provenance/opaque context, supply labels/navigation and retire views before closing Core resources. App own acceptance remains open. |

Current owner evidence is recorded in the [owning Step journal](../journal/2026/10/2026-10-11-tfaf3-02-acceptance.md)
under [Phase 3](../phase/phase-3.md) and its [checklist](../phase/phase-3-checklist.md).

## Actual parent TFAF3-02 consumer software receipt — 2026-10-11

Receipt `tfaf3-02-consumer-validation-20261011@1` records completed parent
source intake and actual selected host execution after accepted Core
`314b19b78fdf5eb2a5ee7922f81284a476912350` and TFAF3-01
`19998a2b188e9df2332b7389a8a523f78e1fb699`. The CU3 representative passed 1;
the combined 30-suite accumulator passed 290 with 0 failures; lib/test analysis
reported `No issues found!`; the final identical 21-target dry-format check
reported 0 changed. All four final commands exited 0. Parent static intake is
recorded as `tfaf3-02-implementation-static-final-20261011@1`.

The initial dry-format check exited 1 because three suites required canonical
invocation wrapping/indentation and optional call commas. Failure
`VAL-TFAF3-02-FORMAT-001` and
`tfaf3-02-format-fix-manifest-20261011@1` remain historical evidence.
The separate registered fix worker `/root/tfaf3_02_format_fix_20261011`
formatted only `test/submission_settings_controller_test.dart`,
`test/submission_commit_controller_test.dart` and
`test/submission_status_summary_panel_test.dart`: its command exited 0 and
reported 3 files changed. The parent inspected the mechanical delta and reused
the unchanged behavioral test/analysis evidence. The original failed log
`tfaf3-02-dry_format-20261011.log` and final
`tfaf3-02-dry_format-final-20261011.log` are retained alongside
`tfaf3-02-representative-20261011.log`, `tfaf3-02-accumulator-20261011.log` and
`tfaf3-02-analysis-20261011.log` in the parent App repository's
`.codex-workflow/phases/PHASE-6.1/`. This documentary editor performed no repair,
formatter or validation command.

This receipt supersedes the earlier initial-authoring/prevalidation statements
that selected commands had not executed or parent intake was pending. Historical
command selections, actual failures and C2/D2G/Step 1 results retain their original
scope. TFAF3-01 is accepted and natively committed at
`19998a2b188e9df2332b7389a8a523f78e1fb699`; its earlier pending-commit statements
are explicitly historical. Step 2 is review-pending, unaccepted and uncommitted;
no independent reviewer conclusion, acceptance or commit is asserted.

Private originals/SQLite, controlled ports and mocked native channels establish
selected host consumer software evidence only. This is not full TFAF package
validation or native/Drive/headless/server or App acceptance. TFAF3-03 remains
planned, including public-export/fixture handoff. Full `scripts/validate-full.sh`,
the sole comprehensive Phase review, applicable consumer evidence and distinct
Phase release remain required. The original three Steps, 49-path Phase, 29-path
Step, 21 targets, authority/bases/epoch and App R29/global42/local40 history are
retained. The five existing checked boxes remain unchanged; no new gate is checked.

This five-document projection is authored under
`tfaf3-02-documentary-spec-entry-manifest-20261011@2`, a documentary subset of
the initial 15 author paths. Parent factual/static intake and all subsequent
review/acceptance transitions remain parent-owned.

## 2026-10-11 — Owning TFAF3-02 acceptance before commit

Parent complete-source intake and relevant host software evidence cover the
29 owning paths and 21 complete Dart programs (11 production, 10 suites).
The CU3 representative passed 1 case; the combined 30-suite accumulator passed
290 cases with zero failures; analysis found no issues; final dry formatting
checked 21 files with zero changed. The initial formatter failure and its
three-suite formatting-only correction remain in the prior dated receipt.

Fresh independent protected reviewer `/root/tfaf3_02_owning_step_review_20261011`
recorded `tfaf3-02-owning-step-review-20261011@1`: SEALED_LEDGER PASS across
67 selected paths, all 29 owning paths, all 21 target programs and the one
configuration path. It reported no Current Boundary Blockers, Hygiene or
Development Candidates. The owning review ledger advanced from revision 4 to 5;
this is an owning Step acceptance, not the comprehensive Phase review.

TFAF3-02 is accepted; its exact 29-path commit remains pending. This receipt
supersedes the historical pre-review statuses without rewriting their outcomes.
The common-screen implementation and three matching presentation behavior items
are now checked. The composite evidence/review/commit item remains open until
the native commit is verified. TFAF3-03 public exports/fixture handoff, complete
package validation, the sole comprehensive Phase review and distinct release
remain required. Phase 3 stays active; TFAF3-01 remains committed at 19998a2.

Host checks use private originals, SQLite, controlled ports and native-channel
mocks. They do not establish native, Drive, server, headless, whole Book Material
transfer, physical radio/OS-stop or long human-consent acceptance. App Step and
Phase closure remain separate. Original Goal, bases, epoch, scopes and counters
are retained. This projection changes no executable, fixture, configuration,
public contract, validation outcome or runtime behavior; no test rerun is needed.
