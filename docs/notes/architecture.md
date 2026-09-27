# Architecture Notes

## Purpose

Textus Flutter Application Framework provides application-level UI capabilities above `textus-flutter-core`.

The framework is deliberately configuration-driven. Standard application screens should be instances of reusable runtime components rather than copies of generated Widget code.

## Layer boundary

### textus-flutter-core

Owns low-level reusable Flutter/runtime facilities, including:

- device and platform services
- connectivity and offline/runtime foundations
- common service/provider contracts
- low-level adaptive/foldable device information
- configuration loading primitives
- extension/plugin foundations

It should not know Editing Studio concepts or own application-level Resource List/Detail semantics.

### textus-flutter-application-framework

Owns application UI semantics and reusable presentation behavior, including:

- resource collection/list presentation
- resource detail presentation
- resource editing
- search/filter/sort
- application actions
- navigation
- master-detail and pane composition
- workflow/approval presentation
- evidence/attachment presentation
- application-level adaptive presentation rules

### Cozy

Cozy owns the model/compiler side.

Its UI model should describe semantic UI, interaction, presentation, and adaptive layout without embedding Flutter Widget structure as the primary model.

Cozy should normally compile UI models to TFAF configuration. It may generate Dart when a presentation cannot be represented adequately by configuration.

### Application

An application such as `nict-editing-studio-app` owns:

- application configuration
- application-specific assets
- domain/application bindings
- custom Widgets/actions only where framework configuration is insufficient

## UI model layers

The working model separates:

1. **Semantic UI** — what the user is viewing or doing.
2. **Interaction** — actions, navigation, state transitions, workflow/continuation interaction.
3. **Presentation** — list, detail, editor, preview, pane relationships.
4. **Adaptive Layout** — mapping semantic presentation to available display regions.
5. **Flutter realization** — framework configuration and optional generated/custom Dart.

This separation is important for foldable devices. A model should describe, for example, `ResourceList + ResourceDetail`, rather than a special "fold screen".

The runtime can then realize the same semantics as:

- compact: List → Detail navigation
- expanded: List | Detail
- foldable: List | Detail arranged around display features/hinge where appropriate

## Generation policy

Each presentation unit has a generation/realization policy:

- `framework`: configuration only; framework runtime provides implementation.
- `generated`: Cozy generates an implementation.
- `hybrid`: framework runtime is primary and extension points supply specialized behavior.
- `custom`: application supplies implementation.

The policy is selectable per screen/presentation unit. This allows applications to remain mostly configuration-driven without blocking specialized UI.

## Configuration-first rule

Configuration is an executable application description, not merely styling metadata.

A Resource List configuration should be able to express at least:

- resource type / data source binding
- visible properties
- item presentation
- sort/filter/search behavior
- selection behavior
- available actions
- navigation/detail relationship
- adaptive pane relationship

Resource Detail and Editor configurations should follow the same principle.

The desired steady state is:

```text
Application/UI Model
        -> Cozy
        -> configuration
        -> reusable TFAF runtime
```

rather than generating a new Dart screen for every model change.
