# Settings adaptive presentation consumer

Date: 2026-10-01

Current status: TFAF-S04 implementation, focused validation and independent
acceptance have passed; the exact acceptance commit remains pending.

Owner: TFAF presentation; application composition owns borrowed lifetimes and
supplies capabilities. Core continues to own environment geometry.

Update rule: record observable implementation changes here; acceptance and runtime
evidence require their separate recorded gates. Do not infer durability from the
controllable storage fixture.

## Additive display-model API

`ResourceListDetailDisplayModel` retains its constructor and the existing
`preference`, `openDetail`, `showList`, `focusDetail`, `restoreSplit`, `resolve`,
`hingePolicyOverride`, `setHingePolicy` and `resolveHingePolicy` contracts.
`preferenceOverride` is nullable until an explicit expanded session choice.
The legacy `preference` getter returns `preferenceOverride ?? split`, so an
initial split getter is different from an explicit split override.
The first `restoreSplit()` establishes an explicit split and notifies, even
when that legacy getter already reports split. Repeating the same explicit
choice is a no-op. `focusDetail()` also requests compact detail; `openDetail()`
and `showList()` change only compact navigation.

```dart
void applySettingsPreferences({
  required SettingsPanePreference panePreference,
  ResourceListDetailHingePolicy? hingePreference,
  bool hingeApplicable = true,
  bool clearPaneOverride = false,
  bool clearHingeOverride = false,
});
```

This atomic transient apply notifies at most once when internal presentation
state changes. It clears only requested dimensions, never compact-detail intent.
Null hinge preference denotes absent/invalid saved-current hinge preference;
it does not suppress configuration. An unbound legacy model defaults to automatic
pane policy and applicable hinge policy. It owns no snapshot/service/storage or
semantic Resource View.

## Pure resolution and physical eligibility

The widget calculates safe-body geometry and policy viability before passing
`splitCapable` to `resolve`. Ineligible layouts remain sequential, regardless
of global or session preference. Selected detail is sequentially visible only
with retained compact-detail intent; otherwise the list is shown.

In eligible layouts, explicit split wins. Explicit focus wins only with valid
selection and `allowDetailFocus`; invalid focus falls back to the common pane
policy. Without a valid session choice, automatic/dual resolve split and single
resolves sequential list/detail. An eligible single default offers the existing
restore-split toolbar control with or without selection and even when focus is
disabled. Truly ineligible layouts hide split/focus controls. Compact shrink/grow
retains session choice, selection and navigation intent.

Hinge precedence is session override, explicit global hinge, caller configuration
`defaultHingePolicy`, then automatic. Saved/current explicit automatic is a real
choice; absence or an invalid restored value preserves the configuration fallback.
Automatic avoids positive physical gaps and spans zero-thickness folds.
When temporarily inapplicable, effective hinge resolution uses that same safe
automatic rule while retaining all global/session fields for capability return.
Resolution never writes fallback, notifies, or promotes avoid to span to gain
two-pane eligibility. Existing continuous-region fallback, minimum panes,
both separator axes and physical-gap warnings remain authoritative.

## Borrowed binding and intent propagation

`ResourceListDetailSettingsBinding` is exported from the package entry point:

```dart
ResourceListDetailSettingsBinding({
  required SettingsView view,
  required Iterable<ResourceListDetailDisplayModel> displayModels,
  SettingsCapabilities? capabilities,
});
```

It validates all registered common definitions and a nonempty distinct model
list before listener attachment, then retains an immutable copy. It applies the
initial snapshot without clearing pre-attachment choices and baselines the current
`lastIntent.revision` (or zero). Construction never loads, restores or writes.
Null capabilities mean the empty set, as in `SettingsShell`.

Each View notification captures its immutable snapshot and capabilities into a
synchronous FIFO queue. An intent is consumed before model fanout. Pane edit
clears only pane overrides, hinge edit clears only hinge overrides, text/extension
edit clears neither, and common reset clears both. This applies even to a same-value
edit or already-default reset. Load, save success/failure/retry and repeated
notifications without new intent do not replay clears. Nested edit/reset or
capability updates from a model listener are queued; every tab receives the earlier
dimension clear before the later event is applied.

Explicit hinge presence is read through `hasExplicitValue`, then mapped from
`SettingsHingePreference` to `ResourceListDetailHingePolicy` value by value.
Applicability is `view.availability(CommonSettings.hingePreference.id,
capabilities) == SettingAvailability.available`. Pane remains applicable while
compact. `updateCapabilities(SettingsCapabilities)` reapplies the retained snapshot
without intent or persistence. The caller supplies current separator capability
from the environment and updates both the binding and borrowed Settings shell;
the binding does not observe hardware, window metrics or widget mounting itself.
Settings availability and the existing session toolbar viability are independent.

## Composition and disposal

Bind all resource-tab display models once at the application composition boundary,
including tabs that are inactive or have never mounted. Their model identities are
presentation state, not additional semantic Views in `ApplicationViewModel`.

```dart
final settings = SettingsView.fromService(service: controller);
final collectingDisplay = ResourceListDetailDisplayModel();
final candidatesDisplay = ResourceListDetailDisplayModel();
final binding = ResourceListDetailSettingsBinding(
  view: settings,
  displayModels: [collectingDisplay, candidatesDisplay],
  capabilities: currentCapabilities,
);
// ResourceListDetail pages borrow their own displayModel and ResourceViewModel.
// Composition chooses if/when to load Settings through the existing View API.
await settings.load();
binding.updateCapabilities(nextCapabilities);
// Rebuild borrowed SettingsShell with nextCapabilities as well.
// Detach pages and Settings shells/routes before disposing their dependencies.
binding.dispose();
settings.dispose(); // fromService leaves controller lifetime with composition
controller.dispose();
collectingDisplay.dispose();
candidatesDisplay.dispose();
```

Binding disposal is idempotent, removes only its View listener, clears pending
events and halts remaining fanout if invoked reentrantly. It does not dispose
borrowed dependencies or alter snapshots. Capability updates after disposal throw
`StateError`. Keep View/models alive while bound and dispose the binding before
them. Neither binding nor layout issues resource queries/actions, recreates Views,
changes selection or pushes detail routes.

## Evidence boundary

D01–D04 resolver, B01–B06 binding and W01–W05 widget scenarios are authored in
the owned behavior specifications with native Dart/Flutter Given/When/Then clauses.
Their controllable storage evidence concerns interface behavior only. Focused
validation passed 206 selected tests; independent Step review and the focused
repair-cycle-1 review resolved both findings without new blockers. The exact
Step acceptance commit remains pending; no full Phase acceptance is implied.
S05 OS-aware text composition and S06 application integration, real adapter restart
and Android/iOS/Web runtime smoke remain open; no application completion or runtime
durability is claimed by this consumer implementation.
