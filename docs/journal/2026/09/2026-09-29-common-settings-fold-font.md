# Common Settings: Fold and Font Development Driver

Date: 2026-09-29
Status: architectural decision

TFAF should provide a common Settings capability shared by applications. The first executable settings are Fold behavior and Font/Text presentation, with NICT Editing Studio acting as the development driver.

This follows directly from the Phase 1 Resource List/Detail and adaptive/foldable work. Rather than implementing a settings screen independently in each Flutter application, TFAF will own the common Settings model, persistence boundary, standard Settings UI, and an extension point for application-specific settings.

A key distinction is between user preference and runtime environment. Fold posture, hinge/display features, window size, system text scale, and platform capability are observations supplied by `textus-flutter-core`; they are not application settings. TFAF combines those observations with persisted application preferences to choose an effective presentation.

The initial Fold policy is intentionally small: `automatic`, `preferSinglePane`, and `preferDualPane`. `automatic` remains the default and lets TFAF choose the List/Detail composition from current display conditions. The preference is therefore an adaptive-layout policy, not a Pixel/Fold/device-name switch.

Font/Text is also common framework behavior. The application preference must compose with the operating system's accessibility text scale rather than replace it. Phase 2 establishes this policy boundary before expanding into richer typography choices.

NICT Editing Studio is the executable proof: its existing List/Detail path must react to Fold preference and its common UI must react to Font/Text preference. Both must persist across restart. Common Settings UI should require no Editing-Studio-specific Widgets.

A further design decision is that Android and iOS differences belong to visual realization, not to the logical Settings model. Android can realize the shared model using Material-style Settings conventions while iOS can realize it using native/Cupertino-style grouped navigation and controls. The stored setting identity and semantics remain common.

Settings are also capability-aware. A Fold preference should not be treated as universally meaningful merely because it exists in the registry. Its availability can depend on Core-provided device/environment capabilities. This gives TFAF a general `availability` concept for settings and avoids hard-coding device names or maintaining separate Android/iOS setting schemas.

The resulting pipeline is: logical Settings -> capability filtering/effective policy -> platform-adaptive visual realization.

See [Phase 2](../../phase/phase-2.md).
