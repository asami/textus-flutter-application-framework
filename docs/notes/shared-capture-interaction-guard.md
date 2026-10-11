# Shared capture interaction guard

- Current status: TFAF3-02 is accepted after parent complete-source intake and fresh independent protected owning Step review PASS. Actual CU3 representative passed 1; combined 30-suite host refresh passed 290 with 0 failures; lib/test analysis found no issues; final dry formatting checked 21 files with 0 changed. Its exact 29-path Step commit is pending. TFAF3-01 is accepted and committed at 19998a2b188e9df2332b7389a8a523f78e1fb699. TFAF3-03 remains planned; Phase full driver/review/release and separate App/native/Drive/server/headless gates remain pending.
- Owner: TFAF shared capture presentation maintainer; the caller retains controller, policy and operation-result ownership. The PHASE-6.1 parent owns validation and acceptance.
- Update rule: Keep this note aligned with the three public widgets and actual parent receipts. Record authored scenarios separately from executed validation and retain each pending App/native/Step/Phase boundary.

`AudioCapturePanel`, `TranscriptReviewPanel` and `PhotoCapturePanel` accept the optional named argument `interactionAllowed`, with type `bool Function()?`. The callback is a borrowed pure caller admission decision. It must not perform IO or mutate state. A null callback preserves the existing controller-specific behavior. False, or an exception while evaluating the callback, denies a user operation. This common UI has no Book, Commit, Save or navigation policy of its own.

Build may evaluate the current callback to disable controls. Each user callback captures the controller identity and widget generation at render time, then checks mounted ownership and that generation immediately before any action. A callback retained across unmount, controller replacement or A→B→A cannot act on either controller. Audio and transcript entry also reject detached or disposed controllers. A same-controller rebuild retains the generation, and each invocation evaluates the current widget's policy rather than retaining its earlier Boolean result. Constructors, builds and policy flips issue no acquisition, provider, settings, storage or result commands.

Audio entry covers record, stop, cancel, retry save, play, stop playback, readiness checking, model preparation, transcription and transcription cancellation. Photo entry covers configuration selection, settings load/save retry, readiness refresh, provider preparation, capture, recovery, saved-original recognition and comparison. Rejection precedes local preparation state, controller buffers and all borrowed service effects.

Transcript text changes, Record correction, Use proposal and historical Use this report share the same entry rule. A denied event can arrive after Flutter has changed the local text buffer. For the still-current live owner only, the widget restores the exact canonical `controller.draftText` locally. It creates no dirty-state change, revision, proposal adoption or result notification. Wrong-owner and unmounted callbacks touch no current editor. Admitted edits preserve exact Unicode, whitespace and intentional empty clears. The caller can continue using the existing controller's `recordCorrection()` directly for an already accepted Save flush while user UI admission is false; the widget gate does not replace controller authority.

Admission applies only before user command dispatch. Once admitted, durable stop, recognition, capture and preparation finish under the existing start-time controller/generation/mounted completion fences. Later false does not cancel work, dispose borrowed resources, suppress a same-owner durable result, or strand preparation presentation. Original bytes, report history, actual failure presentation and operation-start result callbacks remain governed by the existing controllers and Core. Mount/replacement completion suppression remains intact.

The owned executable specifications author these scenarios using production widget callbacks, actual controllers and existing private real-filesystem fixtures:

| Scenario | Owned suite | Authored behavior |
| --- | --- | --- |
| G1 | `test/transcript_review_panel_test.dart` | Capture text/correction/latest/history actions, deny without a frame, retain exact dirty draft/review/history and IO counts, reenable exact/empty corrections and proposals, and flush through the existing owner controller API while UI is denied. |
| G2 | `test/audio_capture_panel_test.dart` | Exercise every audio action in its exposing controller state; deny a captured callback after a live flip and evaluation failure, render false as disabled, and reenable explicit same-generation intent. |
| G3 | `test/audio_capture_panel_test.dart` | Hold durable stop and ASR through actual UI; success/failure settles after admission becomes false without borrowed cleanup or result redirection. |
| G4 | `test/photo_capture_panel_test.dart` | Deny captured settings/configuration/camera/provider/saved-image callbacks, reenable explicit commands, and join accepted held capture/preparation success/failure after suspension. |
| G5 | All three owned suites | Reject render-captured commands after replacement, unmount and A→B→A before either old or current controller effects. |
| G6 | Audio and photo owned suites | Keep false-gated controls visible and scrollable at 320px and scale two, disable actual gestures, and retain exact text/intent without IO or layout errors. Existing omitted-gate W/T scenarios retain compatibility coverage. |

Given/When/Then clauses accompany new scenarios and touched admission, buffer, settlement and fixture helpers. Provider/storage/settings counters observe actual effects; no production debug hook, clock, interaction token or persistence schema is added. Fixture owners join held work and unmount panels before disposing test-owned resources.

Historical D2G initial-authoring/command-selection snapshot — 2026-10-10;
the subsequent dated actual receipts supersede its pending execution statements.

The implementation editor runs only the manifest's canonical six-file write formatter. The parent retains the G1 representative, nine-suite TFAF accumulator, three legacy App suites, analysis, dry formatting, diff verification and fresh independent producer conformance. These authoring records establish no executed validation or native/Drive/whole ESA6-06 acceptance. App D2B binding remains a later frozen consumer task. Existing [submission settings and status UI](submission-settings-and-status-ui.md) and [submission facade and transfer binding](submission-facade-and-transfer-binding.md) histories remain separate.

The [dated D2G journal](../journal/2026/10/2026-10-10-esa6-06-shared-capture-interaction-guard.md) records this authoring boundary.

## 2026-10-10 Parent software validation receipt

The parent supplied actual completed software results from `.codex-workflow/phases/PHASE-6.1/validation/submission-tfaf-d2g-20261010` in the primary App repository. Each listed command exited 0:

- G1 representative: 1 passed (`representative-final.log`).
- Focused G2 cancellation scenarios: 2 passed (`cancellation-focused-final.log`).
- TFAF accumulator: 163 passed across 9 suites (`accumulator-final.log`).
- Legacy App compatibility: 47 passed across 3 suites (`app-legacy.log`).
- Analysis: `No issues found` (`analysis-final.log`).
- Dry formatting: 6 files, 0 changed (`format-dry-final.log`).

Initial G1 failed because the test host omitted forwarding `interactionAllowed` to `TranscriptReviewPanel`. The exact M1 helper wiring correction retained the scenarios and assertions, and the representative then passed. The initial accumulator had 161 passes and 2 failures because interrupted playback and transcription originals emitted the authoritative cancellation `StateError` without immediate observers. The exact M1 repair attached `expectLater(..., throwsStateError)` to both originals and retained their joins; the focused 2 scenarios and final accumulator then passed. Both corrections changed test fixtures only; production source was unchanged by these repairs.

The parent also recorded an actual `git diff --check` exit 0 before this documentation amendment; the final documentation diff check remains parent-owned and pending. These receipts establish completed software validation only. Fresh independent producer source conformance, App D2B binding, native/Drive runtime, whole ESA6-06 Step and PHASE-6.1 acceptance remain pending. No independent acceptance or commit is claimed.

## Historical prior current-status snapshot

The following status was recorded before the owning receipt below; it is retained
as history and does not state the current Step status.

- Current status: Authored under `esa61-submission-tfaf-d2g-manifest-20261010@1` for PHASE-6.1 / ESA6-06 / ESA6-06-D2G. Parent software validation completed on 2026-10-10 with the receipts below. Independent producer source conformance, App D2B consumer binding, native/Drive runtime, whole ESA6-06 Step and PHASE-6.1 acceptance remain pending.

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

Existing G1–G6 retain null compatibility, live false/throw denial before entry,
exact local dirty text restoration, stale/unmounted/replaced/A→B→A fencing and
accepted durable settlement under operation-start completion fences. Direct
owner correction flushing for accepted Save remains available. Only guard
scenario/helper comments are adopted; accepted legacy W/T/PC2 comments remain.
The pure borrowed callback grants no controller/resource or App policy ownership.
App retains Book eligibility, current-edit flush, navigation and borrowing closure.

Original D2G authority and the dated failed/final receipts above remain historical:
1 representative, 2 cancellation cases, 163 TFAF and 47 legacy App passes do not
establish current owning Step review, native/Drive/server/headless acceptance or
promote prior App/native reviews. See the [owning Step journal](../journal/2026/10/2026-10-11-tfaf3-02-acceptance.md).

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
