# Phase 2 - Common Settings Foundation: Fold and Font

status=planned

planned_at=2026-09-29

predecessor=[Phase 1](phase-1.md)

reference_application=KnowledgeHubProject/nict-editing-studio-app

## Goal

Establish TFAF's common application Settings mechanism and prove it in NICT Editing Studio, beginning with Fold behavior and Font/Text settings.

Phase 2 turns settings from application-local preferences into reusable framework capability: a Settings model, persistence boundary, standard Settings UI, and application extension point.

## Architectural rules

1. TFAF owns application-level common settings and their standard UI.
2. `textus-flutter-core` owns low-level device/environment observations such as display features, fold posture, window metrics, platform capability, and system text scale.
3. Environment observations are not persisted as user settings.
4. Fold policy is expressed in terms of adaptive presentation, not device model names.
5. Font/Text settings augment rather than erase system accessibility preferences.
6. Applications may contribute application-specific settings through an explicit extension point.
7. NICT Editing Studio is the development driver and must not introduce Editing-Studio-specific concepts into TFAF.
8. The Settings model is platform-neutral; Android/iOS conventions are visual realization concerns.
9. The standard Settings shell is platform-adaptive: Android should follow the platform's Material conventions and iOS should follow the platform's native/Cupertino conventions where practical.
10. Setting availability is capability-driven. A setting that is meaningless on the current device/environment may be hidden or otherwise made unavailable according to an explicit availability policy.
11. Platform-specific rendering must not fork the semantic setting identity, stored value, validation, or application extension contract.
12. Persisted preferences, observable Settings Views, environment observations,
    and resolved presentation are separate concerns. Widgets use the Settings
    ViewModel; they do not read or write storage directly.

The contracts below resolve the Phase 2 planning review. They specify future
behavior, not implemented capability or acceptance evidence; status remains
`planned`. The reference-app counterpart is Editing Studio App Phase 3.

## Scope

### TFAF-S01 Settings model and registry

Define stable contracts for common settings, setting groups, defaults, validation, effective values, and application-contributed settings.

Initial groups:

- Appearance
- Layout / Adaptive behavior
- Accessibility-ready extension boundary
- Application extensions

The initial persisted common values are pane preference (default
`automatic`), hinge preference (default `automatic`), and text-size
multiplier (default `1.0`). Pane preference and hinge preference are independent
settings, not alternative meanings of one Fold enum.

Expose an observable Settings View through the application-session View space,
with loading, effective values, unsaved/save-error state, retry and reset
intents. The Settings service owns validation and persistence; a pure resolver
combines preferences with environment and presentation-session overrides.
Existing `ResourceListDetailDisplayModel` remains session state and is not
serialized wholesale. Setting changes must not recreate Resource Views,
replace resource selection, or issue Resource/Aggregate domain commands.

### TFAF-S02 Persistence boundary

Provide a framework-owned settings repository/service contract.

The UI and adaptive runtime must not bind directly to a concrete storage package. Persistence implementation may initially be local-device storage.

Storage is local to the application installation/browser origin, shared by its
resource tabs, and not a server profile. The storage adapter is injected at
application composition; the app does not duplicate framework persistence logic.

Required lifecycle:

- Before the initial load finishes, render using configuration/framework defaults
  and expose loading state. Settings remain editable.
- Restore validated saved values only for settings not edited/reset since that
  load began. A late load or retry must not overwrite newer user intent.
- Apply a valid edit immediately and mark it unsaved until storage acknowledges
  that revision. Serialize/coalesce writes so an older completion cannot mark a
  newer value saved or become the final stored value.
- On read failure, keep defaults/current edits, expose a nonfatal error and
  explicit retry; do not automatically overwrite unread storage with defaults.
- On save failure, retain the effective in-session value, expose unsaved/error
  state and retry the latest value. Restart restores the last successfully saved
  value; failed persistence must never be reported as durable.
- Use a versioned record and stable setting IDs. Missing values inherit defaults;
  invalid known values fall back per setting without discarding valid siblings.
  Unknown keys are not interpreted or silently deleted by ordinary edits.
  Unsupported future record versions are not automatically rewritten; report
  unsupported storage and allow an explicit reset.
- Reset restores all common defaults, clears common presentation overrides in
  every resource tab, and persists that intent through the same revision/error
  rules. It does not clear selected resources or application-owned extension data.

Test with a controllable fake storage adapter: delayed reads, out-of-order
completion, read/write failure, invalid/missing values, unknown keys, unsupported
versions, reset, and restart after successful/failed saves.

### TFAF-S03 Standard Settings shell

Provide reusable Settings navigation and presentation so applications can expose common settings without handwritten settings screens.

Initial conceptual structure:

```text
Settings
├─ Appearance
│  └─ Text size / Font
├─ Layout
│  └─ Fold behavior
└─ <Application Settings>
```

### TFAF-S04 Fold behavior

Introduce an application-level adaptive policy with at least:

- `automatic`
- `preferSinglePane`
- `preferDualPane`

`automatic` uses current device/display environment supplied by Core. Explicit preferences influence TFAF composition but do not replace environment facts.

The Phase 1 List/Detail reference path is the primary executable proof.

#### Resolution and precedence

First calculate physical layout eligibility using the existing safe regions,
minimum pane dimensions and selected hinge policy. A preference never makes an
ineligible two-pane layout eligible. Preserve Phase 1 selection and compact
navigation state across every settings, window-size and posture transition.

For eligible layouts, an explicit per-tab session choice (split or detail focus)
overrides the persisted pane preference. Otherwise:

| Pane preference | Effective default |
| --- | --- |
| `automatic` | Existing Phase 1 adaptive behavior: split when eligible, sequential otherwise. |
| `preferSinglePane` | Sequential List/Detail even with sufficient space; show detail only when compact-detail intent and a valid selection exist. |
| `preferDualPane` | Split when eligible; ordinary sequential fallback when not eligible. |

Temporary lack of space hides split/focus controls but does not erase the
session choice; restoring space restores that choice. Even under
`preferSinglePane`, an eligible layout offers an explicit switch to split,
so the global default does not trap the user in a single-pane presentation.
Detail focus still requires a valid selection and `allowDetailFocus`.
Session choices are independent per resource tab and are not persisted.

Hinge resolution is independently: per-tab session override -> explicitly saved
global hinge preference -> configuration `defaultHingePolicy` -> framework
`automatic`. Missing pane settings inherit configuration defaults where
provided, otherwise `automatic`; an explicitly saved `automatic` is a real
choice, not a missing value. Preserve the Phase 1 avoid/span viability rules,
continuous-region fallback and physical-gap occlusion warning. A dual-pane
preference must not silently change avoid to span to make a layout fit.

An explicit common pane-setting edit clears only pane session overrides in all
tabs; a hinge-setting edit clears only hinge overrides. This makes a common
setting change immediately observable without changing the other dimension.
Automatic restoration, resizing and capability changes clear neither.
Text-size edits clear neither. Reset clears both as specified above.

#### Availability and retention

Availability is based on layout capability, not Fold hardware or an Android/iOS
name: tablets, desktop and resizable windows can benefit from pane preference.
Keep the pane setting accessible even while compact so the next expanded layout
can be configured. A hinge setting without an applicable separator is disabled
with an explanation rather than deleting its stored value.
When a setting becomes temporarily inapplicable, use a safe effective fallback
without writing that fallback to storage. Re-enable and re-resolve the retained
choice when capability returns. Session toolbar controls keep the Phase 1
eligibility rules; Settings availability is not the same as toolbar visibility.

### TFAF-S05 Font/Text behavior

Introduce a common application text preference.

The design must preserve the system accessibility text scale. The effective text presentation is derived from system preference plus the TFAF/application preference rather than replacing the system setting.

Do not prematurely require arbitrary font-family selection; establish the common text-size/font policy boundary first.

This Phase implements text size only: `1.0` (standard), `1.15`, and `1.30`,
with `1.0` as default. Other persisted multipliers are invalid and fall back to
`1.0`; font-family, weight and line-height customization are out of scope.

For an unscaled logical font size `s`, let `S(s)` be the current OS-provided
scaling function and `m` the selected app multiplier. Effective size is
`m * S(s)`, applied once at the common presentation boundary. Preserve the
OS function rather than replacing it with a fixed scalar; `m = 1.0` must
produce exactly the OS result. Changing system scale recomputes presentation
without changing saved app preferences.

Apply this to app text, navigation, standard Resource List/Detail and Settings,
including its own controls and dialogs. Do not scale icons, images or geometry
by this multiplier, apply it twice in nested screens, or cap away OS enlargement.
At the largest app value combined with enlarged system text, text remains
readable and controls reachable through wrapping/scrolling or safe layout
fallback. Settings must remain usable to return to standard size.

Acceptance includes default-system scaling and enlarged-system scaling for each
app value, a non-linear fake OS scaling function to prove composition order,
live OS changes, and compact/split/Settings navigation without clipping or
unreachable controls. Example: if `S(16) = 24`, `m = 1.30` yields `31.2`.

### TFAF-S06 NICT Editing Studio development driver

Use `nict-editing-studio-app` to prove:

- opening the common Settings UI;
- changing Fold behavior;
- observing the existing List/Detail presentation respond;
- changing text size/font preference;
- observing the application update consistently;
- persistence across application restart;
- no Editing-Studio-specific Widget implementation for the common settings.

Application-specific settings may be added as an extension proof if useful, but are not required for Phase closure.

## Settings versus environment

Keep these concepts separate:

```text
ApplicationSettings
  AppearanceSettings
  AdaptiveSettings
  <application extensions>

DeviceEnvironment
  window/display regions
  display features / hinge
  fold posture
  system text scale
  platform capabilities
```

TFAF resolves effective presentation from both inputs.

## Acceptance criteria

Phase 2 is complete when:

- TFAF exposes a common Settings model and standard Settings shell.
- settings are persisted through an abstract persistence boundary.
- Fold behavior supports automatic/single-pane/dual-pane preference.
- the automatic path continues to consume Core environment primitives.
- Font/Text preference works without suppressing system accessibility scaling.
- NICT Editing Studio demonstrates both settings against the Phase 1 List/Detail path.
- application settings can be extended without modifying TFAF internals.
- tests distinguish persisted user preference from runtime device environment.
- tests prove pane/session/hinge precedence, global-setting edits, reset,
  insufficient-space fallback and retention across capability loss/return;
- persistence tests cover the lifecycle and failure cases above, including
  latest-intent preservation and restart after an acknowledged save;
- text-size tests prove the defined composition, single application of scaling,
  live OS changes and accessible controls at enlarged sizes;
- Android Material and iOS Cupertino Settings realizations pass widget/interaction
  tests using the same setting IDs, values, validation and storage contract;
- the reference app supplies an Android device/emulator and iOS simulator/device
  smoke record for opening Settings, changing both setting groups, navigating
  back, and restoring acknowledged values after restart. Platform, environment
  and limits are recorded; unavailable runtime evidence stays pending, not passed;
- reference-app tests cover compact/expanded and both hinge-axis fixtures,
  disabled-to-enabled hinge settings and unchanged selected resource across tabs.

The same acceptance matrix applies to Editing Studio App Phase 3; evidence may
be shared with clear ownership rather than requiring duplicate executions.
Existing Web startup remains supported, with a browser smoke check for Settings
and local preference restore. Server synchronization, production server
integration, arbitrary typography and persistent Resource selection remain out
of scope. A synthetic application setting is sufficient to test the extension
contract; no production application setting is required.
