# 2026-10-09 — ESA6-04-B shared audio interaction and transcript review

- Current status: ESA6-04 connected Core/TFAF/App Step independently accepted; exact local Step commits pending. Separate repository Phases and App Phase 6.1 remain open.
- Owner: textus-flutter-application-framework maintainer.
- Update rule: append actual parent-owned validation/acceptance evidence; retain separate repository Phase histories and historical failures.

Implemented the frozen connected App Phase 6.1 / ESA6-04 / ESA6-04-B participant
scope. The facade forwards existing public Core contracts and adds no runtime,
storage or domain policy. The Listenable controller borrows dependencies, owns
only its explicit interaction, accepts one durable original, retains exact
append-only review and a separate dirty editable buffer, and rejects competing
intent before provider work. Recording UI seconds start only after successful
permission/capture and never automatically stop/import at the duration limit.

Nonterminal Core cancellation exposes existing provider cancellation for
readiness/preparation/saved-input recognition and always waits prior settlement.
Controller detach cancels only its own matching live work, awaits outstanding
commands even on cleanup failure, keeps saving success/pending bytes for handoff,
and suppresses later listeners. Widgets own only UI resources and suppress
callbacks after replacement/unmount. Duplicate listeners and disposal inside a
notification preserve borrowed Core/service/store lifetime.

Manual correction and successful proposal selection are explicit append-only
revisions; exact Unicode/whitespace/intentional empty clears survive concurrent
ASR. Results append to latest review, dirty buffer is never implicitly committed,
and actual report timestamps are never normalized to repair restored history.
Revision clocks floor to actual capture/revision/source time. Owners explicitly
record draft before domain Save, await route detach and read retained final review
before disposing their own composition. The full public interaction/ownership
contract and same-store usage are in the
[shared audio note](../../../notes/original-audio-and-transcript-review.md).

Authored executable specifications F1–F3, C1–C10, W1–W5 and T1–T6 include actual
FileCaptureStore/codec save and fresh-store reopen, exact original playback,
provider failure/readiness, guarded cancellation, held durable save success/failure,
concurrent dirty/recorded edits, lifecycle isolation and narrow inherited text
scaling. Behavioral and async helper Given/When/Then clauses sit adjacent to setup,
action and observable assertions. No worker validation or native runtime was run.

Core Slice A source focused closure
`esa61-audio-core-focused-closure-1-20261009@1` remains accepted historical evidence
for that slice, including its prior playback repair. It does not accept the new B
cancellation or interaction delta. Parent software checks and independent shared
conformance remain pending. Actual Android/MLKit linkage, device permission,
record/replay, actual model readiness/explicit preparation/saved-input recognition,
connected App integration and complete Step/Phase acceptance remain owed. No
separate TFAF/Core Phase closure, commit or publication is claimed.

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
