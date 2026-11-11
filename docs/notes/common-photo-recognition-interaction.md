# Common photo recognition interaction

The public TFAF barrel exports `PhotoCaptureFacade`, `PhotoCaptureController`,
`PhotoCapturePanel` and `RecognitionComparisonView`. Core remains the authority
for original storage, recognition routes, provider preparation and durable reports.
The facade forwards Core arguments, results and failures without re-saving reports.
The controller and panel borrow their dependencies.

## Compose one store and an explicit settings owner

```dart
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

Future<PhotoCaptureController> composePhotoInteraction({
  required LocalCaptureStore sharedStore,
  required SettingsStorage settingsStorage,
  required ImageRecognitionProvider bookConfiguredNanoProvider,
}) async {
  final settingsService = SettingsLifecycleController(
    registry: RecognitionSettings.registry(),
    storage: settingsStorage,
    resetDefinitions: RecognitionSettings.definitions,
  );
  final settingsView = SettingsView.fromService(service: settingsService);
  final photos = await openDefaultPhotoCaptureFacade(
    store: sharedStore,
    additionalProviders: [bookConfiguredNanoProvider],
  );
  final controller = PhotoCaptureController(
    facade: photos,
    settings: settingsView,
  );
  await controller.initialize();
  return controller;
}
```

The application should retain the settings service/view alongside the returned
controller so its owner can dispose them after detaching the UI. The owner disposes
the controller first, then the view and settings service according to its own
composition lifetime. The shared store and provider lifetime remain caller-owned.
For existing settings composition, register the exact
`RecognitionSettings.configuration` definition in the same registry; the controller
validates that registered identity and every choice's presence in the Core catalog.
A `CaptureStorageFacade(store: sharedStore)` can use the same original storage.

The factory starts no capability probe, download, camera operation or inference.
The constructor attaches one settings observer and starts no I/O.
`initialize()` explicitly loads settings and probes availability.
Mount `PhotoCapturePanel(controller: controller, onComparison: acceptReport)` in a
caller-owned scrollable layout. The panel is a Column, owns no navigation or
Scaffold, and neither initializes nor disposes the controller. Applications may
place it under their existing `ApplicationTextScaling` boundary.

## Desired intent, provider availability and actual execution

`selectConfiguration(id)` writes desired intent through SettingsView. It neither
runs providers nor guarantees durability. Enhanced intent remains selectable and
persisted when the provider is unavailable. Settings read readiness gates capture,
recovery and saved-image recognition/comparison. The settings snapshot separately
reports loading, failed/unsupported reads, saving, failed saves and unsaved edits.
A settled `retrySettingsLoad()` or `retrySettingsSave()` Future is not a durability
acknowledgement: inspect that snapshot.

`refreshAvailability()` probes only. `prepareProvider(providerId)` is an explicit
preparation request. The UI offers Prepare only for a downloadable provider and
shows preparing/available/model/reason snapshots. Availability is historical
capability evidence; the desired choice is user intent. The report records the
actual route and fallback reason independently.

Each capture/recovery/recognition snapshots desired intent at operation start.
An external settings edit changes the next operation's desired ID. The controller
admits one operation at a time, including probes, loads and settings retries.

## Work on the unchanged saved original

```dart
final captured = await controller.capture();
if (captured != null) {
  final comparison = await controller.compareCurrent();
  // Both registered desired routes use comparison.material, the saved original.
  await controller.recognizeCurrent();
  await controller.loadComparison(comparison.id);
}
```

`recover()` handles Core camera recovery. Camera cancellation returns null,
retains the previous report and emits no result callback.
`compareCurrent()` passes the registered choice IDs in order without another
acquisition. `recognizeCurrent()` reuses exactly the current report's original.
`loadComparison(id)` reads history without inference and can display it while
settings restoration or camera support is unavailable. An absent report throws
StateError; corrupt storage and actual storage errors remain observable.

Core returns recognition reports only after durable storage success. Failed work
keeps the previously accepted comparison/availability and records the same actual
operation error. UI commands await and catch controller failures; successful
nonnull capture/recovery/recognition/comparison each emits one callback while the
panel is still mounted with the same controller. Probe/preparation/settings retries
emit no result callback. Unmount/replacement suppresses late callbacks. Controller
disposal detaches settings observation, preserves borrowed lifetimes and lets
already admitted Core work settle without late state publication.

`RecognitionComparisonView` displays original/comparison identities and metadata,
desired/actual routes, fallback, every attempt, actual duration, ordered input
links, shared work and all failure stage/code/message values. Raw OCR, barcode
values/formats, interpretation, completed empty stages and duplicate opaque
candidate kind/value proposals remain intact. Expand 出典の詳細 to see
the verbatim JSON extensions. A caller can render an original preview through
its storage facade in later application composition.

The current display uses Japanese labels, with aliases for the two exact
built-in configuration ID/label pairs only; caller-supplied labels remain
unchanged. Operation exceptions use fixed Japanese UI messages while the
controller or settings snapshot retains the actual error. Serialized comparison
failures and all other provenance values remain unchanged and fully visible.
The expandable section is labeled 出典の詳細.

Book-specific provider instructions and parsing are caller responsibilities.
Passing a book-configured Nano provider replaces the Core default Nano registration;
this common layer introduces no ISBN validation, title inference, correction UI or
bibliographic authority. Injected provider/camera specifications establish the
interaction contract and do not demonstrate native inference.

## Original-only facade authored — 2026-10-06 / ESA6-03-A

`PhotoCaptureFacade.captureOriginal()` and `recoverOriginal()` directly return
Core's `Future<CaptureMaterialReference?>`. Original-only acquisition can be
composed without a settings view, controller initialization or readiness probe:

```dart
final photos = await openDefaultPhotoCaptureFacade(store: sharedStore);
final original = await photos.captureOriginal();
// Or: final original = await photos.recoverOriginal();
if (original != null) {
  final bytes = await photos.readOriginal(original);
  // App attaches the durable original to its page; recognition is explicit.
  final comparison = await photos.compare(original);
}
```

The shared store remains caller-owned. Core imports exact original bytes/media
type/UTC capture time/name once before returning the actual durable reference.
The facade performs no second import, catch, result transformation, settings
selection, capability probe, model preparation, inference or report write. Null
camera cancellation/empty recovery and actual permission, camera, unsupported and
import failures remain observable unchanged. Core's one shared operation guard
excludes originals and existing recognition/readiness operations in both
directions, including while import is held; it releases on completion, error or
cancellation. Accepted material ownership is retained without rollback/deletion.
Later explicit recognition/comparison uses the same original and durable raw
report lineage through the existing methods.

App ESA6-03-B owns page attachment, annotation text and Draft composition. The
controller/panel retain their existing settings-backed recognition behavior.
The [original-facade journal](../journal/2026/10/2026-10-06-esa6-original-photo-facade.md)
records authored A1–A5 scenarios. Focused parent validation, complete-Step
independent review/acceptance and physical device acceptance remain pending;
injected camera/provider cases do not prove physical acquisition or inference.
No prior native result, failure or release obligation is replaced by this entry.

## Parent preflight and approval-review stop — 2026-10-06 / ESA6-03-A

Parent exact10paths preflight, all three repository `git diff --check` results,
owned-file whitespace/final-newline checks and48 relative-link checks passed.
The first selected Core `flutter analyze` request used `require_escalated`, but
CreateProcess rejected it before execution because automatic approval review
could not complete: the selected review model was at capacity. The platform
identified this as a review failure, not a determination that the action was
unsafe, and directed that the approval check must not be bypassed.

No selected analysis or test process started; no exit status, pass, test count
or runtime session exists. The remaining four selected jobs were not submitted.
No automatic retry, alternate route or repair was consumed. Parent retained the
raw request/result under the App root at
`.codex-workflow/phases/PHASE-6/platform-review-failure-esa6-03-a-core-analyze-20261006.json`.
The observed pre-existing private constructor parameter spelling remains pending
compiler verification; no compatibility pass, repair or design change is admitted.
Earlier passing receipts retain their historical scope. Focused validation,
independent complete-Step review/acceptance, physical acceptance and full release
obligations remain pending.

## Shared original-read forwarding authored — 2026-10-06 / ESA6-03-B-R

For F-ESA6-03-B-01, `PhotoCaptureFacade.readOriginal(material)` returns Core's
`Future<Uint8List>` using the same borrowed service and exact reference. Core's
existing guard owns actual store reading through success/error settlement; the
facade adds no guard, readiness gate, storage authority, result transform or
lifetime ownership. Reads require neither camera support nor model availability
and start no acquisition, import, provider work or report write. The existing
common controller reaches that same guard for capture/recovery/readiness.

Capture/import and read remain successive operations; a competitor between them
can produce a visible shared-busy read failure. App retains the original for an
explicit retry. Independent CaptureStorageFacade reads retain their low-level
contract. R1 exact saved forwarding/reopen/mutation, R2 observed held facade read
excluding every facade/direct Core operation and exact material-read error
release, and R3 reciprocal held Core operations are authored in the existing
facade spec. Material-read fixtures are separate from document `readError`.
Adjacent Given/When/Then describe actual setup/action/observable assertions.

Actual parent validation and fresh M2 complete-Step03 protected focused
conformance remain pending. The retained platform capacity failure and separate
unverified constructor spelling are unchanged; authoring claims no pass,
runtime closure, device result or acceptance.

## Generic operation context forwarding authored — 2026-10-08 / PHOTO-B1

Identity: PHASE-6 / ESA6-02 / ESA6-02-PHOTO-B1,
`implementation-esa6-photo-b1-20261008` revision1. Owner: TFAF maintainer for
common interaction; Core owns the generic value and raw report namespace, and
App owns source roles, requested candidate kinds and domain instructions.
Update rule: preserve historical receipts and append actual parent validation
and acceptance separately from authored API/specification changes.

Facade `capture`, `recover`, `recognize`, `compare` accept optional named
`RecognitionOperationContext? operationContext`. Controller `capture`, `recover`,
`recognizeCurrent`, `recognizeOriginal`, `compareCurrent` accept the same value.
Default null preserves existing callers and omitted-argument tear-offs. This
immutable value is forwarded only for the accepted operation; roles/kinds are
opaque and there is no facade/controller context state or source filtering.

The controller retains start-time desired selection, explicit-route behavior,
ready-settings barrier, shared busy/reentrant exclusion, error propagation,
durable-report acceptance and disposal publication rules. Explicit saved-original
recognition does not change desired settings or import the source again.
Original-only acquisition/recovery/read, history load, preparation and settings
APIs retain their contracts. Construction performs no IO or model work.

Core stores a present requested context in its strict optional
`extensions.recognitionOperationContext` schemaVersion1 namespace alongside
static providerProvenance; the version1 report root is unchanged. An omitted
context remains absent, including after previous contextual operations.
Requested metadata is not a promise of extraction or actual model execution.
The facade returns Core's exact durable result, cancellation or actual failure.

OC5 scenarios in `photo_capture_facade_test.dart` author all four contextual
commands, distinct contexts, fresh real-file reopen, opaque/duplicate raw output,
cancellation, write-error identity and the next omitted-context request. OC6 in
`photo_capture_controller_test.dart` authors all five commands, start-time intent,
reentrant listener, held provider/write ownership, durability failures and
dispose-before-success/failure settlement. The finite write gate augments the
existing actual forwarding fixture. Adjacent Given/When/Then describe setup,
action and expect matchers. Existing G1–G5 and all earlier cases are retained.

Parent selected validation, independent complete-Step acceptance and updated
physical evidence are pending; this append claims no new PASS. App PHOTO-B2
must freeze its own integrated review schema and five-field domain policy before
editing. See the [forwarding journal](../journal/2026/10/2026-10-08-esa6-recognition-operation-context-forwarding.md).

## PHOTO-B1 parent validation result — 2026-10-08

Current status: B1 common API authoring complete; parent selected validation
found one App consumer-specification failure. Core representative106 and
8-suite accumulator188 passed; TFAF representative57 and6-suite accumulator87
passed. App21-suite accumulator:250 passed,1 failed. All3 static analyses and
all3 repository diff checks passed. These are software results, not native or
Step/Phase acceptance.
Owner: Phase6 parent for validation and next scope; each repository maintainer
for its existing responsibilities. Update rule: append actual repair/validation
results; preserve dated authoring, old receipts, original/raw/manual/workspace
histories and all7 acceptance viewpoints.

The failed existing F8 in `test/book_identification_flow_test.dart` calls save
after failed explicit reloads left the controller uninitialized. The observed
error is `Bad state: Book review is not initialized`; the saved-raw corruption
validation assertion was not reached. A normal successful reinitialization
is missing from that specification. Its path is outside B1 owned edits and
requires exact parent PLAN admission before correction; the production
read-only safety contract remains required. No repair or PASS is claimed here.

B2 still requires all5 book fields (title, author, section/volume, ISBN and
publication information), role/target snapshots, standard-first same-original
processing, available local AI only for unresolved targets, merged candidates
with conflicts/equal multiple sources, and manual/select/apply/save with strict
separate integrated-review persistence. Legacy mapping1/2 remains unchanged.
Updated Fold/Sony, camera-denial negative route, complete Step/affected-boundary
independent review, separate acceptance commits and Phase closure/release
remain pending. Phase6.1 is unstarted.

## PHOTO-REQUEST-REVISION App historical contract — 2026-10-08

Identity: PHASE-6 / ESA6-02 / PHOTO-REQUEST-REVISION,
implementation-esa6-photo-request-revision-20261008 revision1.
Current status: App source/specification authoring; parent software validation,
revised native effectiveness and independent acceptance pending. Owner: this
repository's maintainer for generic responsibilities, App maintainer for book
meaning/history, Phase6 parent for validation and closure. Update rule: append
actual results separately and retain prior B1/B2 authoring, failures, receipts,
original/raw/provider/manual/workspace histories and acceptance boxes.

TFAF continues to forward the exact immutable per-call context through existing facade/controller commands and display actual common capture/recognition state. Its API, busy/readiness/durability/error/lifetime behavior and generic image presentation remain unchanged. It neither selects App request versions nor stores sticky context or validates book bibliography.

App reserves session.extensions.bookRecognitionContract for exactly integer
schemaVersion1 and requestRevision1/2. Absence means historical1 and remains
absent on Save; malformed present metadata rejects in the App codec and aggregate.
App's bookRecognitionRequest keeps exactly schemaVersion,bookMaterialId,
sessionId,stage with payload version1/2 matching the frozen session revision.
New App runs freeze explicit2 before busy; standard and enhanced calls forward
that same intent. App preserves old exact trusted instructions and appends its
exact revised kind/value/visible-bibliography guidance for2. App reconstructs
whole historical raw contexts, rejects unknown/mixed versions or forged text,
and preserves old raw/candidate/human/workspace prefixes. No upstream program
or generic historical report migration is introduced.

The actual Fold saved session has six originals, five selected sources, one
role correction and one selection change; Save and same-install COLD retention
were observed. Four of five actual Nano candidate outputs were invalid.
App RR1–RR5 author real-file compatibility/strictness and actual Dart Nano
MethodChannel framing/valid versus malformed output. Those controlled channels
prove software behavior only, never native model effectiveness. Implementation
worker executed no validation, build, device work, independent review or commit.

Existing Core188/TFAF87 B1 selected software receipts retain their unchanged
program scope; this append adds no new PASS. Parent owes App representative/
28-suite/analysis and three-root diff checks, saved-session-first revision2
Fold rerun/fresh Save/COLD evidence, Sony standard-only/fallback and original
camera-denial negative, whole ESA6-02 plus affected01/03/05 protected review,
separate repository journals/acceptance commits, upstream final validation,
unused epoch1 full Phase review and Phase6 release. All five book fields/seven
viewpoints and canonical Hygiene/Development Candidate paths, IDs and statuses
remain; no Phase6.1 execution or counter/epoch reset.
