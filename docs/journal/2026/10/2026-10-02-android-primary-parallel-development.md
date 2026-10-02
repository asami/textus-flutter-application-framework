# Android-primary parallel Flutter development

Date: 2026-10-02

## Decision

TFAF and its reference applications use an **Android-primary parallel development** strategy.

The primary development device is Pixel 11 Pro Fold. The foldable form factor is intentionally used as the development baseline because it exposes advanced adaptive requirements early: compact and expanded layouts, List/Detail transitions, multiple usable display regions, hinge policy, and presentation changes while preserving semantic selection.

The iPhone 18 Pro is the standard-phone reference device. iOS verification is performed in parallel at meaningful development milestones; it is not treated as a later port after the Android application is complete. The goal is one Flutter/TFAF application model whose realization is continuously checked on both platforms.

## Architectural meaning

Android-primary does **not** mean Android semantics become framework semantics. TFAF must continue to resolve presentation from capabilities and geometry rather than device or platform identity. In particular:

- semantic View and Display Model contracts remain platform-neutral;
- standard navigation and List/Detail behavior are expressed once;
- Fold-specific observations enter through textus-flutter-core display/capability primitives;
- platform checks do not become shortcuts for layout or business behavior;
- genuinely reusable Android/iOS differences discovered by real-device testing are promoted into TFAF/Core abstractions;
- irreducible platform integration remains at the platform boundary.

This reinforces the existing adaptive List/Detail rule that two-pane eligibility is based on usable display regions, not on a Fold model name or folded/open Boolean.

## Development loop

1. Implement and exercise common behavior primarily on Pixel 11 Pro Fold.
2. Use its difficult adaptive cases to strengthen TFAF rather than solve them privately in the application.
3. Run the same feature on iPhone 18 Pro during normal development milestones.
4. Classify differences as form-factor capability, reusable platform presentation, or irreducible platform integration.
5. Feed the first two categories back into TFAF/textus-flutter-core so subsequent applications inherit the solution.

The expected role is therefore **Pixel Fold = advanced adaptive-UI development driver** and **iPhone = standard-phone compatibility/UX reference**.

## Reference application

NICT Editing Studio remains the development driver. Its ordinary phone path should remain a sequential List -> Detail experience, while sufficiently capable regions may realize List | Detail without changing the underlying semantic selection. iPhone verification should confirm the ordinary phone realization; Fold verification should exercise transitions between compact and expanded realizations.

This strategy also gives a clean path to future iPad/tablet/desktop targets: add or refine capability observations and presentation rules rather than introduce a separate platform-specific application architecture.
