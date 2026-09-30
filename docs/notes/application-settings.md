# Application Settings foundation contract

TFAF owns the platform-neutral Settings catalog, immutable effective snapshots,
observable service boundary and application-session `SettingsView`. Applications
compose extension definitions, capabilities and an injected storage adapter.
Widgets read and edit through the View; they do not access storage. These are
the foundation contracts for [Phase 2](../phase/phase-2.md). Concrete persistence
lifecycle proof belongs to S02, shared Material/Cupertino controls to S03, and
presentation effects/runtime integration to [Phase 2.1](../phase/phase-2.1.md).
The fake-service tests prove observation and delegation, not storage durability.

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
successor explicitly maps global hinge preference to the existing session policy
and composes the text multiplier with OS accessibility scaling.

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
post-disposal state changes/notifications. The concrete controller is S02.

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

## Storage and S02 record/lifecycle obligations

`SettingsStorage` is the injected local-installation/browser-origin boundary:
`Future<String?> read()` and `Future<void> write(String record)`. Null means
absence. Write completion means acknowledged durable whole-record replacement;
failure means not acknowledged. Adapters must not report success early. The
framework serializes writes; no CAS/server-profile requirement is introduced.
S01 supplies no real adapter, storage package or concrete codec/controller.

S02 must implement this versioned JSON envelope:

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

Missing known values inherit defaults and are not explicit. Invalid known values
use their per-setting default and are not explicit. Valid explicit defaults
remain explicit. Ordinary writes preserve uninterpreted unknown setting values
and unknown top-level JSON fields. Registered extension data follows its own
typed schema; common reset preserves application and unknown extension data.

An unsupported integer `version != 1` is protected from automatic rewriting
until explicit reset. Malformed JSON or envelope is a nonfatal read failure with
explicit retry, not permission to overwrite unread data. Explicit reset writes
explicit common defaults while preserving application/unknown extension data,
including recovery from a future envelope.

Before load completes, defaults/current edits are usable and loading is visible.
Late load/retry restores only values not edited/reset since that read began. A
valid edit applies immediately and remains unsaved until its revision is
acknowledged. Writes must be serialized/coalesced so an older completion cannot
mark newer intent saved or become the final stored value. Read failure retains
defaults/current edits and requires explicit retry. Write failure retains session
values and exposes unsaved/error state; retry saves the latest values. Restart
restores the last acknowledged values rather than failed saves. Reset participates
in the same revision/error rules and preserves extension data.

These record and lifecycle obligations await S02's concrete controller, queue/read
merge algorithm and controllable-storage executable proof. S01 fake snapshots
and service transitions make no claim that any record has actually been stored.
