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

## Scope

### TFAF-S01 Settings model and registry

Define stable contracts for common settings, setting groups, defaults, validation, effective values, and application-contributed settings.

Initial groups:

- Appearance
- Layout / Adaptive behavior
- Accessibility-ready extension boundary
- Application extensions

### TFAF-S02 Persistence boundary

Provide a framework-owned settings repository/service contract.

The UI and adaptive runtime must not bind directly to a concrete storage package. Persistence implementation may initially be local-device storage.

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

### TFAF-S05 Font/Text behavior

Introduce a common application text preference.

The design must preserve the system accessibility text scale. The effective text presentation is derived from system preference plus the TFAF/application preference rather than replacing the system setting.

Do not prematurely require arbitrary font-family selection; establish the common text-size/font policy boundary first.

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
