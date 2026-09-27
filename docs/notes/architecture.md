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


## Artifact ownership and provenance

The architecture distinguishes four kinds of implementation artifacts:

| Artifact | Owner | Edit policy | Purpose |
| --- | --- | --- | --- |
| Framework source | TFAF | handwritten framework development | reusable executable UI behavior |
| Application configuration | application / later Cozy | declarative; preferably generated from model | standard application/UI definition |
| Generated application source | Cozy/generator | replaceable; never hand-edited | code required beyond configuration |
| Handwritten application source | application | handwritten | composition and intentional custom/hybrid extensions |

A fifth category, fake/test-support data, exists only to drive development and executable examples.

These categories must remain physically recognizable in repository/package layout. The boundary is not documentation-only: it is intended to make it obvious whether a change belongs in the framework, the model/configuration, generated output, or an application-specific extension.

The desired dependency direction is:

```text
application handwritten source ----+
application generated source ------+--> TFAF public API --> textus-flutter-core
application configuration ---------+
```

TFAF does not depend on application artifacts. Generated artifacts do not become framework source merely because the first generator or Reference Application needs them.


## Dependency topology

The preferred application-UI dependency path is:

```text
nict-editing-studio-app
        -> textus-flutter-application-framework
        -> textus-flutter-core
```

TFAF depends on Core for lower-level runtime/device capabilities. Applications consume TFAF for standard application UI behavior.

This is a preferred path, not a prohibition on all direct Core use. An application may depend directly on `textus-flutter-core` when it uses a Core-level capability whose semantics do not belong to TFAF, such as Capture/runtime facilities.

Therefore the practical topology may be:

```text
nict-editing-studio-app -----> TFAF -----> Core
          \-----------------------------> Core
                    (explicit Core capabilities)
```

Rules:

- standard application UI must use TFAF rather than bypassing it;
- direct Core use must correspond to an explicit Core-level capability, not convenience;
- TFAF must not wrap/re-export every Core API merely to force a strict dependency chain;
- Core remains independent of TFAF and applications.


## Model-to-server-to-client continuity

TFAF is designed from the beginning as the client runtime endpoint of a continuous model-driven contract, not as a UI framework with networking added later.

Target continuity:

```text
CML / Application Model
  |-- Resource / View semantics
  |-- Operation semantics
  |     |-- Query: collection/detail
  |     |-- Command: action
  |     |-- Job: asynchronous execution/status
  |     `-- Workflow/Continuation
  `-- UI Model
          |
          v
Server Operation contract
          |
          v
generated/typed client + operation binding
          |
          v
TFAF Resource Data Source / Action binding
          |
          v
ResourceListDetail / application UI
```

TFAF must not make Resource List/Detail depend directly on REST, JSON, endpoint URLs, or a particular transport. Standard UI consumes semantic client-side contracts such as a Resource collection/detail data source and action bindings.

The same contract must support both development and production implementations:

```text
ResourceDataSource
  |-- FakeResourceDataSource
  `-- OperationResourceDataSource
```

Switching from fake data to server Operations must not require rewriting the standard UI.

The intended semantic mapping is:

- Query returning a collection -> Resource List data source
- Query returning one resource/view -> Resource Detail data source
- Command -> UI Action
- asynchronous Job -> execution/progress/status presentation
- Workflow / Continuation -> workflow/human-interaction presentation

Transport/client generation belongs below this semantic boundary. Cozy/CML/CNCF integration may generate typed clients and bindings, but TFAF configuration should refer to operation/resource semantics rather than hand-coded HTTP calls.
