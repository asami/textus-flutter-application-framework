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

### Shared adaptive List/Detail display model

TFAF distinguishes selected-resource View state, usable-region layout
capability, and an explicit presentation preference. Split-capable layouts
default to List on the left and Detail on the right (or above/below around a
horizontal separator), with an optional
detail-focus/restore-split interaction. Compact layouts expose only sequential
List -> Detail navigation and hide those mode controls. Opening compact Detail
is not an explicit detail-focus choice: gaining enough space reveals the list
and the same selected detail by default.

This is a reusable presentation model for Fold, tablet, desktop, and window
size changes, not a device-posture branch or a Resource/Aggregate mutation.
See the [adaptive List/Detail display specification](adaptive-list-detail-display-model.md)
for the public display-model contract, state transitions, ownership, and
acceptance evidence.

Core supplies full-view display rectangles and gaps; TFAF clips them to its
measured safe body after chrome/ancestor layout. Pane eligibility uses both
width and height. Positive physical gaps require continuous-region content
under the automatic default, including compact screens and focused Detail.
`ResourceListDetailHingePolicy` is an independent presentation-session policy:
`avoid` uses continuous regions even for a zero-thickness crease; `span` uses
ordinary left/right composition or full-body focused/compact content. The
automatic default spans non-occluding folds, while explicit user preference
wins through resize and rotation. The common menu checks the effective policy,
disables nonviable options, and warns about content hidden by a positive gap
when spanning. It is absent without an intersecting separator or any viable
two-pane policy, independent of focus/restore visibility. These are presentation
policies, not additional domain Views or device-specific application offsets.

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


## Common Settings architecture

TFAF owns reusable application-level Settings behavior. The framework provides four cooperating pieces:

1. a common Settings model/registry;
2. a persistence abstraction;
3. a standard Settings UI shell;
4. an extension point for application-specific settings.

The first common settings are Fold behavior and Font/Text presentation. NICT Editing Studio is the development driver.

Settings must remain distinct from runtime environment observations:

```text
persisted user/application preference       runtime environment
-------------------------------------       -------------------
font/text preference                        system text scale
fold/adaptive preference                    window/display regions
application-specific preference             hinge/display features
                                            fold posture
                                            platform capabilities
                 \                         /
                  +--> TFAF effective presentation
```

Low-level environment observations belong to `textus-flutter-core`. TFAF owns the application-level policy that combines them with settings.

Fold behavior is an adaptive presentation preference, not a device-specific switch. The initial policy vocabulary is `automatic | preferSinglePane | preferDualPane`; `automatic` uses Core environment primitives.

Font/Text preference must preserve system accessibility behavior. TFAF may apply an application preference on top of the system text scale, but must not silently replace or neutralize the system preference.

Applications can contribute their own Settings groups/items without modifying the common Settings shell or TFAF internals. Common settings remain framework-owned; domain-specific settings remain application-owned.

### Platform-adaptive Settings realization

The Settings model is platform-neutral. Android and iOS may use different presentation conventions without creating different application settings models.

Conceptually:

```text
Logical Settings / Settings Registry
              |
              v
       TFAF Settings shell
          /          \
 Android realization  iOS realization
 Material conventions native/Cupertino conventions
```

The renderer may vary section styling, row/navigation affordances, selection controls, spacing, and other platform presentation details. Semantic setting identity, type, default, validation, persistence, and application extension contracts remain shared.

Setting visibility/availability is capability-driven. For example, a Fold behavior setting is useful only when the current environment exposes a relevant foldable/adaptive capability. TFAF should support an explicit availability condition derived from `DeviceEnvironment` / platform capabilities rather than forcing every registered setting onto every device.

This yields three separate concerns:

- **Settings Model** — platform-neutral preference semantics.
- **DeviceEnvironment / Capability** — runtime facts supplied by Core.
- **Settings Visual Realization** — platform-adaptive TFAF presentation.

The same separation principle used for Resource List/Detail visual realization therefore also applies to Settings.

See [Phase 2](../phase/phase-2.md) for the executable Fold/Font development phase.
