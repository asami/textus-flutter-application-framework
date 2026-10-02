# Display presentation v1 — client prototype

Date: 2026-10-03
Owner: TFAF under app Phase 4 / ESA4-03 / S03-framework-display-realization
Status: authored; parent validation and independent complete-Step review pending
Authority: frozen S03 public presentation contract; candidate client behavior only

This additive public presentation boundary consumes the accepted
[Core session](../../../textus-flutter-core/docs/design/display-session-v1.md)
and [semantic source](../../../textus-flutter-core/docs/design/display-fixture-source-v1.md)
through the Core package barrel. Core owns codecs, admission, fixed flow,
request metadata, accepted focus, command history and projection freshness.
TFAF owns definition lookup, immutable semantic drafts and adaptive rendering.
App composition registers definitions and transfers one configured session;
it forwards no per-request context and makes no arm allocation decision.

Public entry points are exported by the existing TFAF barrel. The view borrows
the controller. The controller owns its Core session and adaptive model.
Implementation helpers are internal to the controller library. Snapshots and
registration data are immutable and there is no global mutable registry.

## Definition registry: fully frozen additive API

Public final value DisplayDefinitionKey requires namespace,presentationSet,armId,
definitionVersion; strings nonblank byte-preserving, version positive.
Equality/hashCode use all4 normal domain values, not workflow controls.
enum DisplayDefinitionStyle { standard, cards, sections }.
Public immutable DisplayUiDefinition requires id,version,resourceType,listScreenId,
detailScreenId,style; available defaults true. Validate identifiers/version,
preserve text; structural value equality includes every field. No widget builder,
domain resolver, callbacks, raw JSON or transport metadata belongs in definition.
Public final DisplayDefinitionRegistration requires key and definition.
Public DisplayDefinitionRegistry constructor requires Iterable registrations and
optional neutralDefinition; defensively freeze iterable/map, reject duplicate
full keys and key.definitionVersion != definition.version; same labels in
different namespace/set/version are independent. Explicit empty registry allowed.
Expose immutable registrations and neutralDefinition.
resolve({required PresentationContext context, required String resourceType,
required String listScreenId, required String detailScreenId}) returns immutable
DisplayDefinitionResolution (private state constructor) with key?,definition?,
failure? and isAvailable getter. enum DisplayDefinitionFailureKind:
missingNeutral,unknownArm,unsupportedVersion,unavailableDefinition,
incompatibleDefinition,unsupportedArmFamily,definitionChangeRequiresDiscard.
Failure is immutable kind/message, no thrown operational incompatibility.
Present textus.presentation.arm must have family version1 and typed
SuppliedArmPresentationPayload; unsupported/opaque never counts as absence.
Resolve full tuple, never assignmentReference/locale/correlation as selector.
Absent arm uses only explicit neutral definition; unknown supplied arm never
fallback. A registered triple with another requested version is unsupportedVersion.
Exact key with available false is unavailableDefinition; resourceType/List/Detail
scope mismatch is incompatibleDefinition. Failure never returns substituted definition.
Core alone owns source/component/producer/lifetime admission; registry creates no
clock/policy/assignment and transports nothing. Pure resolver invokes no ports.
Definitions for standard/cards/sections are distinguishable presentation data,
not an experiment evaluation or winner mechanism.

## Controller, immutable draft and ownership

Public DisplayPresentationController extends ChangeNotifier, constructor
requires DisplaySession session,DisplayDefinitionRegistry registry.
Transfers ownership of session; creates/owns one ResourceListDetailDisplayModel.
Constructor validates session not disposed, reads initial snapshots/resolution and
attaches listeners only; no query, clock, policy or port. Expose read-only session,
registry,displayModel,isDisposed,state. Registry is immutable; no global state.

Immutable DisplayDraft has generation (monotonic within controller),resourceId,
definition (actual immutable value),definitionKey?,observedRevision,
bindings (copied writable bindings, original order),initialValues,values
(Map<DisplayFieldLocator,DisplayValue?> copied immutable),hasUnsavedChanges
(value comparison to initial),needsReconciliation. No Display labels converted to
semantic input. A retained draft/snapshot never changes when new snapshots publish.
Immutable DisplayPresentationState includes latest Core session snapshot,
resolution,current displayedDefinition?,draft?,immutable fieldErrors.
getters busy,canEdit,canSave,canOperate derive exact gates below.
Core still owns focus/context/errors/receipt/floors/transport; controller wraps
presentation state, never reimplements admission, codec, revision or refresh.

Public APIs:
Future<void> load(),retryList(),retryDetail(),reload();
Future<DisplayNavigationOutcome> select(String resourceId,{bool discardDraft=false});
enum DisplayNavigationOutcome { selected, discardRequired, failed };
void showList(),focusDetail(),restoreSplit();
void beginEdit(),setValue(DisplayFieldLocator locator,DisplayValue? value),
discardDraft(),discardAndEdit();
Future<void> save(),executeOperation(String operationId),createUnsupported(),
deleteUnsupported();
void updateRegistry(DisplayDefinitionRegistry registry);
void reset({required DisplaySession nextSession,required DisplayDefinitionRegistry
nextRegistry,bool discardDraft=false});
All public config and method identifiers validated nonblank as appropriate.
No app callback is required to copy context or raw requests.

One controller semantic activity at a time. Reserve acting synchronously before
notifying/crossing Core. All semantic methods and draft/registry/reset mutation
reject busy/disposed/reentrant calls with StateError and no effect. Pure pane
showList/focus/restore may operate while a port is busy; no semantic effects.
After every awaited Core method or controller notification, guard disposal and
session identity before further controller publication/pane/draft continuation.
Core operational errors remain observable and methods complete normally; local
programmer preconditions throw, not fabricated receipts.

canEdit = current compatible available resolution + Core canMutate + !busy.
beginEdit requires canEdit; existing draft is retained, never silently replaced.
Use accepted Detail resource/revision and definition identity. Copy ONLY writable
bindings in metadata order, from inputValue, not Display model values. Initial
non-Text bindings remain typed values for visible local rejection, never stringified.
setValue accepts null/any DisplayValue only for an existing writable scoped locator;
unknown/read-only locator throws ArgumentError without changing draft/ports.
Preserve Unicode/multiline/empty text exactly; scope includes screen/section/field.
On field change remove stale errors for that locator, retain other/global errors.
save requires draft and canEdit and !needsReconciliation and matching accepted
resource/definition. Validate every draft binding: null/Missing/Number/Bool/
Timestamp -> scoped invalid-type; required text is blank iff
text.replaceAll('\u0085',' ').trim().isEmpty -> required-nonblank. No trimming.
Empty description is valid. Local failure preserves draft, publishes scoped
errors, crosses no port, increments no Core command sequence.
Submit all writable fields, original binding order, exact retained observedRevision.

Freeze submitting draft generation and expected Core command.sequence+1 before
calling Core update. In Core listener, consume ONLY matching new settled UPDATE
changed/noOp receipt and clear ONLY submitted draft immediately, before pending
projection finishes; consume once before notifying. Rejection/conflict, context/
codec/delivery failure retains draft and observed revision. Do not clear for
external/nonmatching command, Operation/create/delete or safe reads.
Conflict or failed dispatched update makes needsReconciliation true; local
validation/rejected constraint leaves it editable subject to Core eligibility.
Fresh safe read never replays/merges/rebases a draft or erases historical command
failure. Only explicit discardAndEdit (requires current canEdit) clears and creates
a new generation from current accepted values/revision. discardDraft is explicit
and may clear a draft even under context/definition failure when not busy.
No later Save of an uncertain/conflicted old draft before explicit reconciliation.

select same accepted resource opens existing detail without an extra raw read,
retaining draft. Different-resource selection with any draft returns discardRequired
without port/focus/draft/pane changes unless caller explicitly passes discardDraft:true.
Check local Core busy/pending/uncertainty/context-latched switching preconditions
before discarding anything. After explicit discard, delegate one read; successful
target adoption opens detail; failed read keeps old accepted focus/pane and returns
failed. Back/showList and adaptive resize preserve selected ID/draft.
No definition change silently replaces a draft.

updateRegistry takes explicit new immutable registration data, no ports:
failure (unknown/unavailable/version/scope) is visible, keeps last displayed
definition, accepted focus and draft, editing disabled. A compatible but structurally
different definition with a retained draft yields definitionChangeRequiresDiscard
and keeps old displayed definition/draft; store proposed registry. Once explicit
discardDraft occurs, resolve/adopt proposed compatible definition. Compatible equal
definition may update immediately, retaining draft. No implicit neutral fallback.
Core contextFailure always blocks editing even if registry still resolves old
admitted arm; last accepted projection/draft remains visible.

reset requires nonidentical pristine not-disposed nextSession (idle List/Detail,
no focus/command/pending/uncertainty/activity) and no current activity.
Draft requires explicit discardDraft:true; otherwise StateError, old/new sessions
untouched. Detach old listeners, dispose old owned session, adopt new registry/session,
clear draft/errors/old displayed definition/command-match state, showList and resolve
new fixed context; next session remains idle until explicit load or view autoLoad.
No client context rewriting, flow generation or inherited resource/context.
Common presentation preferences may remain in the same model; compact navigation
is reset and global Common Settings remain owner data, not context inheritance.

executeOperation requires Core canMutate, compatible available definition, no draft,
descriptor with exact ID/enabled in accepted Detail. Pass accepted Detail revision
and operationId to Core; NO automatic reload, no handler/domain transition in TFAF.
createUnsupported requires compatible Core canCreate,no draft; sends empty fields.
deleteUnsupported requires compatible Core canMutate,no draft; sends Detail revision.
Their settled unsupported/failure histories remain visible, never successful UI.
Descriptors still do not grant server authority.

Disposal idempotently marks isDisposed immediately, detaches both listeners and
disposes owned Core session immediately (its existing reentrant-safe contract).
Schedule exactly one microtask to release owned displayModel and controller
ChangeNotifier after active notification stacks unwind. No timer or polling.
No late notification/port/pane/draft change, no rollback/cancellation claim.
Public calls after disposal fail before effects; retained snapshots stay readable.

## Standard widget and Common Settings/adaptive realization

Public DisplaySessionView StatefulWidget requires controller, optional
compactBreakpoint=700 and autoLoad=true, key. Positive finite breakpoint.
Widget borrows controller and never disposes it; detach on controller replacement/
unmount. AutoLoad schedules exactly one post-frame load for each pristine new
session identity while autoLoad true; recheck mounted/controller/session/idle/not
busy/notdisposed before dispatch. Never auto-retry failure, eager-read Detail or
replay command. Core/controller reset supplies a new identity; only its first idle
query is autoLoaded. autoLoad:false is fully manual.

Use LayoutBuilder and current safe usable width for compact/expanded capability;
reuse controller.displayModel.resolve and its focus/restore/showList choices.
400x850 -> sequential List/Detail;1200x850 -> split unless Common pane preference/
explicit focus requests otherwise. Selection/draft/TextEditingControllers survive
resize and back/list/detail transitions. This prototype requires ordinary Web
widths; no new physical-fold/hinge/device posture claim. Existing legacy fold
implementation/config remains untouched.
ApplicationTextScaling and applicationTextAppBar integrate inherited Common text
multiplier; ResourceListDetailSettingsBinding can borrow controller.displayModel
alongside existing tabs. New view creates no Settings service/storage and does not
apply multiplier twice. SafeArea, scrollable panes/editor, accessible labels and
normal Material widgets; no clipping/overflow at tested size/multiplier.

Render typed List data in order and Detail sections/fields in their model order,
all roles/scoped identities/provenance retained; no resource-specific constants.
standard -> ordered ListTiles + Detail ListTiles;
cards -> ordered Cards for summaries and section Cards;
sections -> ordered ExpansionTiles for summaries and named Detail section groups.
All three styles visibly distinct; expansion does not change resource/flow.
No available definition -> visible incompatibility while retained projection
uses last displayed definition when present; no default substitution.
No arm/experiment conditionals outside registry. Widget selects by definition.style.
Model title/label/Display text remains supplied; renderer formats Number.toString,
Bool true/false, UTC Timestamp.toIso8601String and Missing em dash for READ only.
Text semantic editors exclusively use draft input-ready Text values.

Use stable scoped field keys and draft generation/resource identity for editor
state. On rebuild, mirror draft Text only when text actually differs; typing does
not reset cursor/copy labels/trim values. Read-only/unbound fields (including stage)
are visible but never TextFields. Unsupported binding input type shows local error,
never automatic Text conversion. Fields disabled while busy/pending/incompatible/
needsReconciliation, values retained. Scoped local/server field errors remain beside
correct field, global errors separate. Save/Cancel/Discard and edit current are
explicit; no rebase on reload.
Show loading/failure with safe Retry list/detail, Refresh and separate command
receipt/commit/current revision, pending projection/unknown outcome messages.
A committed update plus failed refresh is displayed as committed with refresh
failure; uncertain command says outcome unknown and offers safe reads, never
failed/rolled-back success. Buttons disabled by exact eligibility, no duplicated Save.
Operation buttons reflect admitted Detail descriptors and call separate controller
Operation; show receipt then explicit Reload button, never auto-refresh.
Unsupported create/delete controls visibly report unsupported result and no success.
Show optional context omission diagnostics as presentation info without runtime
security/capabilities. Locale chrome uses admitted locale family: ja locale -> Japanese
standard labels; all other/absent locale -> English. Do not translate semantic model
labels/values or require arm. No experiment metrics.

Stable public widget Keys for tests/accessibility:
display-list,display-detail,display-editor,display-save,display-cancel,
display-reconcile,display-reload,display-retry-list,display-retry-detail,
display-create,display-delete,display-back,display-focus,display-split,
display-definition-failure,display-projection-pending,display-command-uncertain.
Resource rows ValueKey(('display-resource',resourceId)); editable fields
ValueKey(('display-field',screenId,sectionId,fieldId)); Operation controls
ValueKey(('display-operation',operationId)); style containers
ValueKey(('display-style',definition.style.name)). Avoid duplicate keys across
simultaneously visible panes; text/semantic observations supplement Keys.

## Authored executable specifications and current acceptance projection

[Registry specs](../../test/display/display_definition_registry_test.dart) author
23 expanded RG01–RG12 cases. [Editor specs](../../test/display/display_editor_test.dart)
author 48 expanded ED01–ED25 cases. [Widget specs](../../test/display/display_session_view_test.dart)
author 32 expanded VW01–VW20 cases, using the independent
[neutral fixture and controllable ports](../../test/support/display_presentation_fixture.dart).
The app owns four AF01–AF04 public consumers of its unchanged actual asset.
Every primary and secondary action has adjacent real Given/When/Then and
observable state/port/source expectations. No test execution result is asserted here.

S02 is independently accepted with 237 actual selected successes, clean selected
analyzers/format and review `esa4-03-s02-review-20261003-root-01` revision 1 PASS,
review ledger revision 10. Its exact 41 captured inputs remain the accepted source
boundary. S03 is authored pending actual parent SDK validation and fresh independent
complete-Step review. ESA4-03 and all SC01–SC20 stay OPEN. No Step, package, Phase,
Web, production wire or real-server acceptance follows from authoring.

Parent owns selected SDK checks, diff verification, authoring matrix evidence,
independent review, Step transitions and commit. ESA4-04 product composition and
SC01–SC20, ESA4-05 Web400/1200, feedback, final full validation, one comprehensive
Phase review and distinct release remain mandatory. Existing Settings/adaptive/action
sources, Core code/specifications, configuration/assets and app product screens
retain their accepted authority. Step repairs 3/3 remain consumed and closed;
Phase repairs 0/3 remain separate. The closed S02 constructor batch creates no S03
repair allowance. Findings are empty; design promotion is empty.
