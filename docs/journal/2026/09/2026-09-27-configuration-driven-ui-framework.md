# Configuration-driven Flutter Application Framework

Date: 2026-09-27

Status: active initial architecture

## Context

The first substantial Flutter application is the NICT Editing Studio application. It is expected to support foldable devices, including distinct closed/open presentation patterns.

Implementing this application ad hoc would prove the application but not the modeling/generation approach. The Editing Studio should instead become the first Reference Application for the UI-model-to-Flutter path.

At the same time, generating complete Dart/Flutter source for every ordinary screen would create unnecessary generated code and make small model changes expensive.

## Decision

Create **Textus Flutter Application Framework** (`textus-flutter-application-framework`) as an application-level framework above `textus-flutter-core`.

The framework follows this priority:

> Configuration first, generated code second, custom code last.

Ordinary UI such as resource lists and resource details is implemented once by the framework and customized by configuration.

Cozy compiles Application/UI Models primarily into this configuration. Dart generation remains available for presentations that cannot be represented adequately by the framework.

## Screen-level realization policy

Generation is controlled per screen or presentation unit.

- **framework**: use reusable framework implementation with configuration.
- **generated**: generate Dart/Flutter implementation.
- **hybrid**: use framework implementation with generated or handwritten extensions.
- **custom**: delegate implementation to the application.

The default is `framework`.

This makes generation selective rather than all-or-nothing.

## Foldable and adaptive UI

Fold support is treated as a general adaptive-layout concern, not as an Editing Studio special case.

The UI model describes semantic presentation units and their relationships. For example:

```text
CandidateList + CandidateEditor + EvidencePreview
```

may be realized as sequential navigation on a compact display, two panes on an opened foldable, or a larger multi-pane presentation on tablet/desktop.

The framework and `textus-flutter-core` divide responsibility so that low-level device/display-feature information belongs to Core, while application-level pane composition belongs to TFAF.

Applications should therefore not need independent fold-specific implementations for ordinary framework-supported screens.

## Editing Studio as Reference Application

`nict-editing-studio-app` is the first Reference Application.

The important goal is not:

> Build a Flutter Editing Studio application with fold support.

The stronger goal is:

> Demonstrate that the Editing Studio application, including fold/adaptive presentation, can be constructed primarily from UI models and framework configuration.

Expected reference scenarios include:

1. Candidate/resource list.
2. Candidate/resource detail.
3. Candidate editing.
4. Evidence/attachment preview.
5. Actions and navigation.
6. Workflow/approval interaction.
7. Compact-to-expanded/foldable presentation changes.
8. A specialized capture UI that tests generated/hybrid/custom escape paths.

## Relationship with Cozy

The intended compilation path is:

```text
CML / Application Model
        -> Cozy Semantic UI Model
        -> Interaction / Presentation / Adaptive Layout
        -> TFAF Configuration
        -> TFAF Runtime
        -> Flutter
```

When configuration is insufficient:

```text
Cozy UI Model
        -> Flutter IR
        -> generated Dart
        -> TFAF extension point
```

This keeps Cozy independent of one application's hand-built Widget structure while still permitting Flutter-specific realization.

## Architectural consequence

TFAF is not merely a widget library. It is the runtime counterpart of the declarative application/UI model.

This also establishes a useful boundary:

- Core provides Flutter/runtime mechanisms.
- TFAF provides application UI semantics.
- Cozy provides modeling and compilation.
- Editing Studio validates the complete path.

The boundary may evolve as the first Reference Application is implemented, but application-specific concepts must not be pushed into Core or TFAF merely to make the first application easier.
