# Original audio and editable transcript interaction

- Current status: ESA6-04 connected Core/TFAF/App Step independently accepted; exact local Step commits pending. Separate repository Phases and App Phase 6.1 remain open.
- Owner: textus-flutter-application-framework maintainer.
- Update rule: append actual parent-owned validation and acceptance evidence; preserve separate repository Phase histories and historical failures.

This bounded shared interaction uses public Core audio contracts. Core owns
capture, playback, exact original storage and provider results. TFAF owns only
interaction and presentation; the connected application owns domain association
and explicit document Save. This delivery closes no TFAF Phase, App Step or Phase.
The four new public exports preserve the existing photo, settings, display and
resource package APIs. No new dependency, schema or runtime floor is introduced.

## Composition and borrowed lifetime

`AudioCaptureFacade(service: service, ownsService: false)` is inert and forwards
Core state, support, pending original, exact locale/configuration/original and
actual results/errors. `openDefaultAudioCaptureFacade(store: sharedStore)` opens
Core's inert default service with that exact caller store and owns the service.
Only the composition owner explicitly disposes an owned facade. Its caller store
remains borrowed. Controllers and panels never dispose the facade or Core service.

`AudioCaptureController(facade: facade, initialReview: restored, locale: 'ja-JP',
configuration: configuration, now: clock)` preserves restored review identity,
starts no IO, capability check, model preparation or timer, and validates exact
language tags. Each controller owns at most one original. A new original requires
a new controller. Explicit recording owns its pending/active permission request;
the UI timer starts only after successful start, ticks each second and clamps at
the requested limit without automatic stop. Explicit stop or pending import retry
returns a review only after Core's exact durable original exists. Import failure
retains Core's immutable pending bytes, actual error and retry eligibility without
recapture. Shared external Core work remains busy context owned by its caller.

Every operation reserves local ownership and settlement before notification.
Forbidden overlap and reentrant ordinary intent reject synchronously. Matching
owned recording, playback, probe/preparation or recognition may be interrupted;
saving cannot be cancelled. `detach()` synchronously ends the interaction lifetime,
stops the timer, disallows new intent, suppresses notifications and cancels only
matching owned work. It always awaits prior own commands, even if cleanup fails;
first actual cleanup error/stack remain observable. A save that settles after
detach retains its exact durable review or pending bytes/actual error for handoff.
Idempotent `dispose()` observes detach failure and releases listener resources,
including duplicate listeners and disposal from inside notification.

## Exact editor and retained provenance

Core's immutable review and ordered reports/revisions remain distinct from
`draftText`, `hasUnsavedText` and the owner's durable domain document. Explicit
`setDraftText` preserves exact Unicode, whitespace and empty clear and records
user intent even if text equals the current revision. It remains usable during
playback, preparation, recognition or unavailable model state once an original
exists. `recordCorrection()` appends dirty exact text through Core.correct;
when clean it returns the same review. `useReport(id)` explicitly selects a known
successful proposal and can intentionally replace dirty text. Neither writes disk.
Revision time is the maximum of UTC clock, original capture, last revision and
selected report completion; actual provider report timestamps are never rewritten.

Transcription appends the exact Core report to the latest concurrently edited
review. A clean buffer follows Core's first-success prefill; a dirty buffer keeps
its exact intent through first/repeated recognition, failure, cancellation,
notifications and rebuilds. Concurrent recorded corrections remain in the retained
prefix. Invalid/out-of-order restored report append or invalid source selection
fails without mutating prior history. Later recognition never silently selects a
new proposal over a manual revision. No implicit manual revision is created.

## Shared panels

`AudioCapturePanel` and `TranscriptReviewPanel` borrow the controller and only own
UI listeners/text resources. Mounting never probes, prepares, captures, recognizes
or detaches a controller. Updating or unmounting suppresses stale async review
callbacks while preserving controller results and borrowed dependencies.
Only successful stop/retry/transcription or explicit correction/proposal selection
emits the exact retained review to the start-time mounted owner. Probe, preparation,
playback, cancellation and typing do not claim a saved review.

The audio controls show actual recording seconds, pending/saving original, model
readiness/reason, preparation intent and errors. Details are initially folded.
The obvious multiline current transcript preserves dirty text/caret/composition on
unchanged-string synchronization. `Unrecorded changes` is distinct from disk Save.
The latest successful attempt supplies a separate exact recognition proposal;
actual failed/unavailable/cancelled latest attempts show diagnostics, with prior
successful proposals explicitly selectable in folded ordered transcript history.
Both panels use inherited ApplicationTextScaling and fit the caller's scrollable
at 320px and text scale two. No application domain fields are known here.

## Explicit owner save and route handoff

Use the same local capture store for recording and domain document persistence:

```dart
final facade = await openDefaultAudioCaptureFacade(store: sharedStore);
final controller = AudioCaptureController(
  facade: facade,
  initialReview: restoredReview,
);
// Mount both borrowed panels with this controller.
// Before explicit domain Save, record the user's exact draft intent.
final review = controller.recordCorrection();
await sharedStore.saveDocument('audio-workspaces', 'one',
    AudioTranscriptCodec.encode(review));
// Before leaving, wait for any outstanding durable original to settle.
await controller.detach();
final retainedForHandoff = controller.review;
// The application owner decides how to persist/handoff this final retained value.
controller.dispose();
await facade.dispose();
```

The application's actual document namespace, association and Save acknowledgement
remain application responsibilities. The sample opaque collection is domain
independent. Neither detachment nor a panel callback implicitly saves a draft.

## Authorship and acceptance evidence

Core Slice A focused source closure
`esa61-audio-core-focused-closure-1-20261009@1` is historical accepted evidence,
including the prior playback repair. Slice B additive nonterminal cancellation
has new authored CANCEL-1 through CANCEL-6 specifications. Its validation and
independent acceptance are pending.

Authored TFAF public behavior scenarios F1–F3, C1–C10, W1–W5 and T1–T6 use actual
Core service and FileCaptureStore with controlled providers. Each behavioral test
and async asserting/setup/action helper has adjacent Given/When/Then clauses and
observable matchers. The representative two-panel UI workflow explicitly records,
durably stops, recognizes saved input, records exact manual text, saves opaque
codec JSON, reopens a fresh FileCaptureStore/controller/panels, and plays identical
original bytes without acquisition/probe on reopen. Controlled provider and
channel behavior does not establish native permission, hardware or model success.

The parent runs selected software validation, mechanical preflight and independent
conformance. Connected App integration still owes actual Android plugin/MLKit
linkage, device permission/record/replay, actual model availability/explicit
preparation/saved-input recognition and complete ESA6-04 acceptance. This note
makes no hardware, model, full-Step, Phase or publication claim.

## 2026-10-10 — Parent software validation

The selected ESA6-04-B software checks passed. Core service cancellation and
existing audio behavior: 23 tests; transcript/codec/Android adapter/photo-service
consumer accumulator: 82 tests. Shared audio panel representative: 6 tests;
facade/controller/transcript editor and existing photo/text-scaling accumulator:
104 tests. Both selected static analyses reported no issues. Canonical dry
formatting covered 11 owned Dart files with zero changes; both Git diff checks
passed.

Earlier W1 runs timed out during test-fixture teardown after the user workflow
completed. Fixed observation traces located a cached detachment future created
in Flutter fake async; creating both W1 detach futures through tester.runAsync
resolved the cross-zone cleanup wait. The isolated W1 then passed, followed by
all six representative cases. Temporary diagnostic traces were removed; no
product lifecycle or behavioral assertion changed. Earlier failures remain
historical evidence.

These are parent-executed software results. Independent shared conformance,
connected App integration, Android build and plugin tests, physical-device
permission/recording/replay/model checks, complete ESA6-04 acceptance and
Phase 6.1 release remain pending.

TFAF commands: `flutter test --no-pub test/audio_capture_panel_test.dart`;
`flutter test --no-pub test/audio_capture_facade_test.dart test/audio_capture_controller_test.dart test/transcript_review_panel_test.dart test/photo_capture_facade_test.dart test/photo_capture_controller_test.dart test/photo_capture_panel_test.dart test/application_text_scaling_test.dart`;
`dart analyze lib test`.

## ESA6-04 whole-Step acceptance — 2026-10-10

Current status: ESA6-04 complete Core/TFAF/App Step accepted by independent
review `esa61-audio-whole-step-review-20261010@1` (PASS, no blockers,
new Hygiene or Development Candidates). Exact dependency-ordered local Step
commits are pending. Phase 6.1 remains open.
Owner: nict-editing-studio-app Phase 6.1 parent task.
Update rule: retain historical source/validation/failure receipts; record
actual commits separately and preserve remaining Phase validation/release gates.

This receipt supersedes earlier pending independent/native/whole-Step
acceptance descriptions for this delivery; those descriptions retain their
historical meaning. The connected review covered 65 owned paths and 92
selected contract/source/specification paths, including APP-AUDIO-OWNER-001.
Actual retained Core 23+82, TFAF 34+91, App 363 passed with one optional saved
photo replay skip, and 20 native helper tests passed. Fold native write5 and
distinct restore1 both passed: the same 656680-byte, 20.519-second original,
Japanese saved-input ASR, manual corrections/history, save/reopen and replay
were retained. The model was already available; preparation was not executed.
Japanese ASR success does not establish exact title accuracy: 窯変 was
recognized as 傭兵 and manual review remains necessary.

This is ESA6-04 Step acceptance only. It closes no separate Core/TFAF Phase.
ESA6-06 Commit/durable background submission and Core Drive/KTL integration,
ESA6-07 fake success/failure/retry/offline, ESA6-08 server handoff, the one
comprehensive Phase review, final full validation and distinct Phase release
remain required.
