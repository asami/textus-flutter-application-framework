# Application Settings foundation contract

TFAF owns the platform-neutral Settings catalog, immutable effective snapshots,
observable service boundary and application-session `SettingsView`. Applications
compose extension definitions, capabilities and an injected storage adapter.
Widgets read and edit through the View; they do not access storage. These are
the foundation contracts for [Phase 2](../phase/phase-2.md). Concrete persistence
lifecycle contract belongs to S02, shared Material/Cupertino controls to S03, and
presentation effects/runtime integration to [Phase 2.1](../phase/phase-2.1.md).
The fake-service tests prove observation and delegation, not storage durability.

The additive [adaptive-presentation consumer](settings-adaptive-presentation.md)
now supplies S04 pane/hinge effects through the existing Resource List/Detail
display model and a borrowed binding over all resource tabs. Its implementation
has passed focused validation and independent acceptance; its exact Step commit
remains the final S04 acceptance gate.
The accepted foundation catalog, storage/controller lifecycle and native shell
semantics below remain unchanged. S05 OS-aware text composition and S06 real
adapter/application/runtime proof are still pending.

## Catalog and finite typed choices

The ordered groups are `appearance` (Appearance), `layout` (Layout),
`accessibility` (Accessibility) and `application` (Application).

| Stable setting ID | Group | Typed choices / wire choices | Default |
| --- | --- | --- | --- |
| `textus.layout.panePreference` | layout | `SettingsPanePreference`: `automatic`, `preferSinglePane`, `preferDualPane`; wire values are these exact enum names | `automatic` |
| `textus.layout.hingePreference` | layout | `SettingsHingePreference`: `automatic`, `avoid`, `span`; wire values are these exact enum names | `automatic` |
| `textus.appearance.textSizeMultiplier` | appearance | `double`: `1.0`, `1.15`, `1.30`; numeric wire values | `1.0` |

Choice labels are user-facing and independent of wire identities. Pane and hinge
preferences are distinct global types. They do not serialize
`ResourceListDetailDisplayModel`, resource selection or session overrides. The
S04 consumer explicitly maps global hinge preference to the existing session
policy. S05 will compose the text multiplier with OS accessibility scaling.

`SettingGroup`, `SettingChoice<T>` and `SettingDefinition<T extends Object>`
contain final metadata and immutable copied catalogs. IDs, labels, group references
and supplied capability identifiers must be nonempty after trimming. Definitions
require a nonempty catalog, unique typed values and unique wire values, and a
default that belongs to the catalog. Wire values must be non-null JSON scalars:
String, bool, int or finite double. Enum objects, collections and nonfinite numbers
are rejected as wire values. This initial API admits finite choices only.

`validate(Object)` checks both Dart type and declared membership; `encode(Object)`
returns the chosen scalar or throws `ArgumentError`. `decode(Object?)` returns a
declared typed choice and falls back to the default for invalid/null/missing
payloads. Numeric JSON `1` matches stored `1.0` and returns the declared double;
`1.2` or string `"1.15"` falls back to `1.0`. Decoding one invalid known value
does not invalidate valid sibling settings. Effective snapshot input is already
typed/validated, so it rejects invalid values rather than using wire fallback.

`SettingsRegistry` preserves ordered unique groups/definitions, rejects duplicate
IDs and unresolved groups, and offers immutable iteration through `groups` and
`definitions`. `definition(id)` throws `ArgumentError` for unknown IDs.
`requireRegistered<T>(definition)` and `SettingsSnapshot.value<T>(definition)`
require the actual registered definition instance. An unregistered or forged
same-ID definition cannot substitute another type or default.

## Extension and capability composition

`CommonSettings.registry(extensionGroups: ..., extensions: ...)` adds explicit
application groups and definitions after the common catalog. Extensions may use
the existing Application or Accessibility group. Duplicate common identities
and extension collisions reject; each composition creates an isolated registry.
No production Editing Studio preference is part of the common catalog.

```dart
final flag = SettingDefinition<bool>(
  id: 'example.flag',
  groupId: 'application',
  label: 'Example flag',
  defaultValue: false,
  choices: [
    SettingChoice(value: false, label: 'Off', storedValue: false),
    SettingChoice(value: true, label: 'On', storedValue: true),
  ],
);
final registry = CommonSettings.registry(extensions: [flag]);
final defaults = SettingsSnapshot(registry: registry);
final enabled = defaults.value(flag); // false, an inherited default
```

`SettingsCapabilities(supported: {...})` copies an immutable set of ephemeral
environment capability IDs. It is never persisted or included in a snapshot.
`SettingDefinition.availability(capabilities)` and
`SettingsView.availability(id, capabilities)` compute available/disabled/hidden
from schema metadata and explicitly supplied input. Device model and platform
names do not determine availability.

Pane and text settings are always available. Hinge requires `hinge` and uses
`disableWhenUnsupported`; its preference remains intact on unsupported
environments. Extensions may use `hideWhenUnsupported`. A definition with no
required capability or with the `always` policy is available. Capability changes
neither edit values nor issue persistence/intent revisions.

## Snapshot, presence and user intent

`SettingsSnapshot` holds its registry, a complete immutable effective value map,
`explicitValueIds`, `unsavedIds`, `revision`, `savedRevision`, read/save states,
read/save errors and optional `lastIntent`. It copies maps/sets, fills missing
effective values with registered defaults and rejects unknown IDs/invalid typed
values. Explicit/unsaved IDs must be registered. Revisions are nonnegative and
`savedRevision <= revision`.

The initial snapshot has inherited defaults, empty explicit/unsaved sets,
revision/savedRevision zero, `notLoaded`/`idle`, no errors and no intent.
`hasExplicitValue(id)` distinguishes absent inherited automatic from validated
restored automatic or a current explicit automatic edit/reset. This presence is
semantic intent; it is not a durability claim. `hasUnsavedChanges` derives from
`unsavedIds`. Save failure preserves effective session values and unsaved state;
errors must never imply acknowledged saved values.

Read states are `notLoaded`, `loading`, `ready`, `failed`, `unsupported`; save
states are `idle`, `saving`, `failed`. Consumers inspect all of these through the
same snapshot rather than inferring completion from defaults.

`SettingsIntent` has a positive revision, `edit` or `resetCommon` kind, and an
edit setting ID (null for reset). Snapshot intent is no newer than its revision;
edit IDs must be registered. A valid explicit edit emits intent even for the
current value, and reset always emits intent. Loading and capability events do
not increment user-intent revision. Phase 2.1 observes intent revisions to clear
corresponding session overrides without touching resource selection.

## Service and View ownership

`SettingsService implements Listenable` supplies registry/snapshot and explicit
`load`, `retryLoad`, `retrySave`, `setValue` and `resetCommon`. It owns validation,
state transitions, persistence and intent sequence. Getters expose immutable
state. Invalid edits throw `ArgumentError`. Calls after disposal throw
`StateError`, disposal is idempotent, and async continuations must suppress
post-disposal state changes/notifications. `SettingsController` supplies the
concrete S02 lifecycle through this unchanged service boundary.

`SettingsView extends ChangeNotifier implements ApplicationView` attaches exactly
one service listener and delegates registry/snapshot/typed reading, availability,
load/retry/edit/reset. It validates edit ID/type/catalog before forwarding and
holds no independent snapshot or storage reference. Service notifications notify
the View. Neither constructor loads automatically; composition calls load.

`SettingsView.owned(service: service)` owns service disposal;
`SettingsView.fromService(service: service)` borrows a separately owned service.
Disposal detaches the listener once, disposes only an owned service, suppresses
late callbacks and rejects subsequent View intents. A borrowed service remains
usable after View disposal.

Application composition registers the view beside existing resource/other views
under an application-chosen stable ID:

```dart
final settings = SettingsView.owned(service: service);
final views = ApplicationViewModel({
  'settings': settings,
  'resources': collectionView,
  'detail': detailView,
});
await settings.load(); // explicit composition step
```

`ApplicationViewModel` remains the owner of its registered views. Ordinary
Settings notifications must not recreate resource views, replace selection,
issue domain commands or serialize resource/session state. These integration
boundaries are exercised with the unchanged resource views in View tests.

## Storage, retained records and explicit controller composition

`SettingsStorage` is the injected local-installation/browser-origin boundary:
`Future<String?> read()` and `Future<void> write(String record)`. Null means
absence. Write completion means acknowledged durable whole-record replacement;
failure means not acknowledged. Adapters must not report success early. The
framework serializes writes; no CAS/server-profile requirement is introduced.
S01 defines the service/storage boundary. S02 adds `SettingsRecord` and
`SettingsController`; applications still supply their own adapter, without a
framework dependency on a storage package or platform persistence implementation.

`SettingsRecord` retains this versioned JSON envelope:

```json
{
  "version": 1,
  "values": {
    "textus.layout.panePreference": "automatic",
    "textus.layout.hingePreference": "avoid",
    "textus.appearance.textSizeMultiplier": 1.15
  }
}
```

The codec is independent of registry, Widgets and storage. `empty()` supplies
version 1 and empty values/extras. `decode(String)` requires an object with an
integer `version` and object `values`; malformed JSON or required shapes throw
`FormatException`. `values` and `extraFields` recursively copy and freeze maps
and lists, including null and unknown nested data. `encode()` roundtrips semantic
JSON, without promising whitespace or key order. `withUpdates(...)` replaces
only named values and rejects non-JSON objects, nonfinite numbers, nonstring map
keys and cyclic structures with `ArgumentError`.

Every integer version other than 1, including zero/negative/future versions, is
well-formed but unsupported. The codec retains its envelope and refuses ordinary
updates with `StateError`; `withUpdates(..., resetVersion: true)` explicitly
changes its version while preserving unrelated data.

Application composition injects storage and registers a concrete service-backed
View. A custom registry must contain the actual three common definition instances:

```dart
final registry = CommonSettings.registry(extensions: [flag]);
final controller = SettingsController(
  registry: registry,
  storage: applicationStorage, // supplied and owned by application composition
);
final settings = SettingsView.owned(service: controller);
await settings.load(); // explicit; neither constructor starts I/O
```

Missing/invalid known values inherit their per-definition defaults and are not
explicit. Valid explicit defaults remain explicit, including numeric JSON `1`
restored as the declared multiplier `1.0`. Valid siblings restore independently.
The controller retains the raw envelope even for invalid registered fields:
an unrelated edit does not canonicalize or erase them. Unknown value keys and
top-level fields survive ordinary writes. Loading never writes defaults merely
because they are effective values.

## Read barriers, recovery and local intent

Defaults and current edits are usable before load completes. Each valid edit,
including the same value, applies synchronously, adds explicit/unsaved presence
and creates a distinct revision/intent. `resetCommon()` creates one revision,
makes all three common defaults explicit/unsaved, and preserves extension
values, presence and pending edits.

A read captures per-setting local revisions and IDs already unsaved at its start.
It restores only fields that were not already unsaved and have had no local
intent since that capture. This protects edits before the first load, during a
load, after a failed read, before retry and during retry. Common reset protects
every common field while allowing untouched registered extensions to restore.
Restoration creates no user intent or revision.

There is one read at a time. Overlapping `load()`/`retryLoad()` calls share its
Future. `load()` only starts from `notLoaded`; it does not retry failures.
`retryLoad()` starts from `notLoaded`, `failed` or an unsupported state whose
writes remain blocked. Ready state and an authorized version-reset recovery do
not reload. Read Futures complete normally after the resulting state is published
and an eligible write pump is scheduled; they do not await persistence.

Writes are blocked until a supported/null read establishes a baseline. Read I/O
failure or malformed data exposes nonfatal `failed`/`readError` while preserving
current values and unsaved intent. Edits, common reset and `retrySave()` cannot
overwrite unread/failed storage; only explicit successful `retryLoad()` opens
that barrier.

An unsupported record is retained and reported as `unsupported` with a
`StateError` identifying its version. Stored known values are not interpreted,
and ordinary edits/save retry do not rewrite it. Explicit common reset, including
a still-pending reset before/during its read, authorizes recovery. Recovery makes
common defaults explicit, restores valid untouched registered extensions,
preserves invalid/unknown extension raw data and top-level extras, merges local
extension edits and submits version 1. Read state remains `unsupported` until
that recovery write succeeds; failure preserves unsupported/unsaved/save-error
state and requires `retrySave()`.

## Serialized saves, acknowledgement and lifetime

The permitted write pump starts in a microtask, coalescing synchronous edits
before its first capture. Only one adapter write is active. Each capture overlays
the latest unsaved values onto the retained acknowledged envelope and records
their per-ID revisions and global revision. Edits during an active write remain
immediate/dirty and coalesce into the next serialized capture.

Success replaces the acknowledged baseline with that exact submitted record and
sets `savedRevision` to its captured revision. An ID clears from `unsavedIds` only
if its current local revision still matches the capture. Unchanged captured IDs
can acknowledge independently of newer dirty IDs. A same-value edit or A/B/A
sequence remains new intent even when its effective value equals the old record.
`saving` lasts while writes are active/pending; `idle` means the pump drained.

Write/encoding failure, including synchronous adapter throws, preserves effective
session values, dirty IDs, the last acknowledged image and `savedRevision`.
It publishes `failed`/`saveError` and stops the pump. Ordinary subsequent edits or
resets retain that error and do not retry. Explicit `retrySave()` clears the save
failure latch and queues all newest pending values when the read barrier permits;
when blocked it starts no I/O and retains the read error. Calls during an existing
scheduled/active pump share its Future, which completes normally after the pump
drains or stops, including edits added while it runs. Completion alone does not
guarantee durability: inspect the snapshot. Restart reads only the adapter's last
acknowledged whole-record image, never failed in-session edits.

Snapshots and queue/read/intent state are established before notifying observers,
including reentrant edits, resets, retries and disposal. Controller disposal is
immediate and idempotent, detaches listeners and prevents new I/O/notifications
or continuation state changes. Disposal from notification dispatch defers the
underlying notifier teardown until dispatch unwinds. New intent/load/retry or
`addListener` calls then throw `StateError`; `removeListener` remains harmless,
and registry/last snapshot stay readable for diagnostics.

The interface cannot cancel an already active adapter operation: it may still
acknowledge external storage. Its completion settles awaiting callers normally,
catches late failure and never mutates/notifies a disposed controller or starts
follow-up writes. The controller never disposes the externally owned storage
adapter or calls a resource/domain operation. Owned/borrowed View semantics remain
as defined above.

The S02 record/controller suites use reusable test-only
`ControllableSettingsStorage` with delayed read/write completion, durable images,
failure and concurrency counts; no real adapter or runtime is involved. Their
scenarios cover the record/lifecycle contract and concrete View consumers. S02
focused validation and independent acceptance remain separate workflow gates;
S03 shell controls are specified below; Phase 2.1 presentation/runtime integration
remains deferred.
S01 fake service tests alone make no persistence or durability claim.

## Borrowed native Settings shell and navigation

`SettingsShell(view: ..., capabilities: ..., presentation: ...)` observes the
current View snapshot directly and renders registered groups and definitions in
order. Empty/all-hidden groups are omitted. `SettingsPresentation.adaptive` uses
`Theme.of(context).platform`: iOS selects Cupertino, other targets Material.
Explicit `material`/`cupertino` overrides affect visuals only. Null capabilities
mean an empty ephemeral set; direct callers update capabilities by rebuilding.
No mount, rebuild or platform/capability update loads, edits or resets settings.

```dart
// Application composition owns the controller/View and explicit restoration.
final settings = SettingsView.owned(
  service: SettingsController(registry: registry, storage: applicationStorage),
);
await settings.load();
// An application-owned Settings destination can render the borrowed View:
final screen = SettingsShell(view: settings, capabilities: capabilities);
// Or an action in an existing screen opens Settings on its nearest Navigator:
await showSettings(context, view: settings, capabilities: capabilities);
// Route completion means pop, not durable save. Inspect settings.snapshot.
// Dispose the owner only after all observing shells/routes have detached.
```

`showSettings` pushes a matching `MaterialPageRoute<void>` or
`CupertinoPageRoute<void>`, capturing its initial capabilities and resolved style.
The route borrows the same View and does not load/dispose it or its service/storage.
Pop/reopen preserves current values. Cupertino presentation also works inside a
`CupertinoApp` without a Material ancestor. Every choice/reset modal uses the
nearest Navigator and its own builder context to pop.

Exactly two typed bool choices `{false, true}` render as a native switch regardless
of catalog order/wire values. All other finite catalogs use a native labelled
chooser showing the current choice. Selection forwards the stable registered ID
and typed value; selecting the current value still creates one intent. Disabled
controls remain visible with null callbacks and “Unavailable in this environment”;
hidden controls are omitted. Capability updates preserve values and revisions.
Cupertino switch rows do not toggle on row tap. Wrapped labels and descriptions
retain OS text scaling; S03 does not apply the user text multiplier.

Choice/reset completion captures the original View and ignores stale completion
after replacement/unmount. Choices additionally require the same registered
definition instance and current available capability. Cancel/back/dismiss creates
no intent. Replacement detaches old observation; neither shell nor route owns
View disposal. The owner must detach widgets before disposing Views.

Read and save status are independent snapshot projections. Not-loaded, loading,
read-failed and unsupported states never report saved defaults. Explicit Load,
Retry loading and Retry saving actions delegate to the View. Unsaved IDs display
“Unsaved changes”; “Changes saved” requires ready/idle and no unsaved IDs. Errors
are readable messages without raw adapter details or Future-based success banners.
Controls stay editable according to capabilities while the controller enforces its
read barriers, coalescing, retry and acknowledgement rules.

“Reset common settings” is always visible and opens a native confirmation:
“Restore common defaults. Application settings are kept.” Confirmation creates
exactly one common-reset intent, including already-default or loading states;
Cancel creates none. Extension/unknown retained data and unsupported-version
recovery remain controller-owned. Shell/navigation executable specifications use
the unchanged controllable adapter; acceptance, Phase closure and runtime proof
remain separate workflow gates.
