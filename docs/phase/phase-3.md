# Phase 3 - Background Transfer Status UI

status=active
planned_at=2026-10-10
execution_owner=textus-flutter-application-framework
phase_owner=textus-flutter-application-framework
consumer_phase=nict-editing-studio-app Phase 6.1
split_full_test_policy=each-phase
split_full_validation_method=local-driver-acceptance
split_full_validation_driver=scripts/validate-full.sh
predecessor=Phase 2.1
execution_started=true
related_steps=ESA6-06, ESA6-07, ESA6-08

## Boundary

Connected upstream delivery for [app Phase 6.1](../../../../../docs/phase/phase-6.1.md).
This is the repository-owned Phase 3, with its own Steps, checklist,
validation, review and release closure. App Phase 6.1 ESA6-06/07/08 is the
consumer/integration owner, not a substitute for upstream acceptance. Existing
accepted work and app aggregate-validation ownership remain unchanged. Entry
selects the actual repository/worktree, available predecessor APIs and missing
bounded capabilities. The dated connected execution projection records the
current start and preserves the original planning scope. See
[the completion checklist](phase-3-checklist.md).


TFAF owns a reusable transfer-status list/detail screen through Core's public
API. Application configuration supplies work-item labels, operation/destination
labels, screen entry and domain navigation. Do not embed Book, TKL or Editing
Studio identities in the common component, and do not create another queue or
transport state machine.

- Show storage-upload and data-submission states separately for each work item
  in both list and detail. An overall summary must not hide either state.
- Detail shows destination, last update, waiting reason, available progress,
  failure and retry information; show per-file outcomes when Core supplies them.
- Present dependency waiting, offline/policy waiting, no-upload-required and
  unknown/interrupted outcomes accurately. Never infer submission from upload.
- Show indeterminate progress when no measurable progress exists. Offer only
  actions Core supports in the current state; trigger no transfer during build,
  navigation or state restoration.
- Provide composition hooks for Home waiting/attention summaries and navigation
  back to the consumer's Material without losing its editing context. A new
  main tab is not required.

## Work Stack

| ID | Step | Outcome | Status |
| --- | --- | --- | --- |
| TFAF3-01 | Core handoff and view contract | Consume accepted Core APIs and freeze configuration/state/action mapping. | accepted; exact commit pending |
| TFAF3-02 | Common screen and composition | Implement list/detail, supported actions, summary and navigation hooks. | planned |
| TFAF3-03 | Consumer acceptance | Verify fixtures and app composition, including failure/restart presentation. | planned |

## Entry and validation

Before execution, identify the current accepted predecessor/public APIs and the
exact remaining delta. Preserve already implemented connected app work and reuse
its relevant evidence; do not reimplement or claim it accepted merely by creating
this Phase. Freeze repository scope, dependencies and a calibrated execution
estimate at entry; no unsupported PROCEED/time estimate is asserted here.

Each Step receives focused behavioral validation and independent acceptance under
the execution workflow. Phase closure requires the complete package analysis/test
suite, affected-consumer evidence, one comprehensive Phase review, resolved current
blockers and a distinct release commit with the checklist/journal handoff. App-only
validation does not replace this package's full checks. Fake results do not prove
real adapter or server execution. No full-validation deferral is selected here.

## Coordination

Delivery order: Core public state/action contract -> TFAF common screen -> app
composition -> ESA6-07 integration acceptance -> ESA6-08 handoff documentation.
Missing cross-owner capabilities are addressed by their owner before dependent
integration; do not add temporary app implementations for later extraction.
No hash ledger, generic revision framework, public-sharing default or unrelated
storage migration is introduced by this request.

- [Other upstream plan](../../../textus-flutter-core/docs/phase/phase-2.md)
- [Design discussion](../notes/submission-settings-and-status-ui.md)
- [Decision journal](../journal/2026/10/2026-10-10-esa6-06-submission-settings-and-status-ui.md)

## Upstream dependency

Core Phase 2 supplies the accepted public state/action and fixture handoff before
runtime binding is accepted. View design may proceed against a reviewed contract,
but fake UI evidence alone cannot establish upstream runtime readiness. App Phase
6.1 owns its domain integration and end-to-end acceptance; this Phase owns reusable
UI acceptance and supplies its handoff without waiting for app Phase closure.

## Connected execution plan — 2026-10-11

Current status: active; TFAF3-01 parent intake and independent protected Step
review are complete, with its one comment-authoring blocker resolved by an
admitted M0 amendment. The owning Step is accepted; its exact commit is pending.
Post-Core consumer validation passed under tfaf3-01-consumer-validation-20261011@1. Core Phase 2 is closed at
`314b19b78fdf5eb2a5ee7922f81284a476912350`, with all 844 tests passing;
remaining owning TFAF reviews, exact commits, full validation and release remain pending.
Owner: textus-flutter-application-framework Phase 3, coordinated by the existing App Phase 6.1 task.
Update rule: retain historical App source reviews as borrowed evidence and record
this Phase's independent Step reviews, exact commits, full checks and release separately.

The human explicitly authorized Core Phase 2 and TFAF Phase 3 completion in this
chat. Use `/Users/asami/src/Project2026/nict-editing-studio-app/.codex-workflow/checkouts/textus-flutter-application-framework` on `codex/esa6-local-capture`; the original main checkout is
read-only. The original App Goal, bases, epoch and review/repair history remain.
This is adoption of existing connected implementation for owning-Phase acceptance,
not acceptance inferred from the App's source reviews. No successor starts here.

The historical connected planning inventory recorded 70 Core submission/capture-guard
paths and 39 TFAF common UI paths. The frozen owning TFAF Phase scope contains
49 paths across the original three Steps; the TFAF3-01 scope is 16 paths, with
only six documents mutable in this entry slice.
Preserve existing code, saved data, public APIs and executable specifications.
The accepted audio/capture APIs are available, but this record does not close
Core Phase 1.3 or reinterpret its historical planned status. TFAF Phase 2.1's
accepted handoff is retained. TFAF runtime acceptance waits for Core Phase 2's
public handoff, now accepted at the release above; Core closure needs consumer
evidence, not TFAF/App Phase closure. See the
[Core completion journal](../../../textus-flutter-core/docs/journal/2026/10/2026-10-11-phase-2-completion.md)
and [TFAF3-01 authoring receipt](../journal/2026/10/2026-10-11-tfaf3-01-acceptance.md).

Historical initial PLAN/authoring snapshot — 2026-10-11, before validation:
the parent PLAN was frozen and TFAF3-01 documentary adoption was in progress;
its Work Stack status was authoring-in-progress. The representative CF1 scenario,
14-suite facade/configuration/resource consumer accumulator and lib/test analysis
refresh were parent-selected and not yet executed. The dated parent receipt
below supersedes that software-validation status. Historical C1/C2 results remain scoped
borrowed inputs. Independent protected Step acceptance and its exact commit
are pending; TFAF3-02 and TFAF3-03 remain planned. Core closure establishes no
TFAF or App acceptance. The split full-validation fields above state this Phase's
existing complete local-driver obligation; they change no acceptance or deferral.

All three original Steps remain required. The private parent-owned plan selects
exact disjoint commit paths and borrowed inputs for each Step. Public export and
fixture handoff closes in the third Step. Intermediate local Step commits are
not standalone package releases. Require all owning Steps before the distinct
Phase release; do not move unreviewed dependency changes into an accepted handoff.

Reuse applicable observed host/native results after checking their relevance;
do not rerun them merely for new record formatting. Core policy tests currently
pass 37 cases; post-entry Fold authorization passed. Earlier real Drive upload
and fresh-process readback retain their 68-byte synthetic-fixture scope. Long
consent success is controlled virtual-time evidence, not a real long human wait.
NQ1–NQ4 supply their recorded native persistence/WorkManager scopes; supplied
offline inputs do not prove a physical radio toggle or an OS-stop experiment.
Unknown acknowledgement handling retains the configured idempotent transport
contract; no exactly-once remote guarantee or real server acceptance is claimed.

Required owning closure: focused behavioral evidence and one independent Step
acceptance per Step, exact Step commits, one comprehensive owning Phase review,
complete `scripts/validate-full.sh`, applicable native policy and consumer evidence,
canonical Hygiene/Development Candidate disposition, checklist/index/journal
handoff, and a distinct local Phase release commit. Full-package checks are
reserved for this Phase's release tree; App-only checks cannot substitute.
No server implementation, Phase 5, AI follow-up or automatic public sharing is included.

Canonical owning dispositions are the
[Hygiene journal](../journal/2026/10/2026-10-11-phase-3-hygiene-follow-up.md) and
[Development Candidate journal](../journal/2026/10/2026-10-11-phase-3-development-candidate-follow-up.md).
The TFAF3-01 review has no Hygiene or Development Candidate findings; later
owning reviews remain pending. Neither document asserts that the Phase is clean.
Original shared Goal, App binding, bases, epoch, R29 and global42/local40 history
remain retained. App Phase 6.1 closure and aggregate validation stay separate.

## Actual parent post-Core consumer software receipt — 2026-10-11

Receipt: tfaf3-01-consumer-validation-20261011@1. Actual parent commands after
the accepted Core handoff passed: representative CF1 1 pass, selected 14 suites
125 passes and lib/test analysis No issues found. All three commands exited 0.
The [owning receipt](../journal/2026/10/2026-10-11-tfaf3-01-acceptance.md#actual-parent-post-core-consumer-software-receipt--2026-10-11)
retains the exact host evidence scope and historical initial PLAN snapshot.

Private files/SQLite, controlled ports and native-channel mocks establish host
consumer software evidence only; this is no actual native/Drive/server/headless
or whole-package proof. Parent final static intake, independent protected
TFAF3-01 review and exact commit remain pending. TFAF3-02/03 remain planned;
comprehensive Phase review, complete scripts/validate-full.sh and the distinct
release remain required. No owning Step or Phase acceptance is claimed.

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
