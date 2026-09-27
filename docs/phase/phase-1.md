# Phase 1 - Configuration-driven UI Reference Path

status=planned

planned_at=2026-09-27

reference_application=KnowledgeHubProject/nict-editing-studio-app

## Goal

Establish the first executable vertical path from declarative application UI configuration to a Flutter application, using the NICT Editing Studio as the Reference Application.

Phase 1 must prove that standard Editing Studio UI can be implemented primarily by framework configuration and reusable runtime components, including an initial adaptive/foldable presentation path.

## Architectural constraints

1. Configuration is preferred over generated source.
2. Generated source is preferred over handwritten application source where generation is appropriate.
3. Screen/presentation realization is selectable using `framework | generated | hybrid | custom`.
4. `framework` is the default policy.
5. Low-level device/fold information belongs to `textus-flutter-core`.
6. Application-level adaptive pane composition belongs to TFAF.
7. Editing-Studio-specific concepts must remain in the application/model layer.
8. Cozy is the intended producer of framework configuration; Phase 1 configuration may be authored manually where necessary to establish the contract before Cozy generation is complete.

## Phase 1 scope

### TFAF-01 Package foundation

- Create Flutter package/project scaffold.
- Define public entry point and module boundaries.
- Establish dependency on `textus-flutter-core` without duplicating Core responsibilities.

### TFAF-02 Configuration model

Define the minimum stable configuration contracts for:

- application presentation
- resource binding
- Resource List
- Resource Detail
- actions
- navigation
- pane relationships
- realization policy

Configuration must be serializable/deserializable so it can become a Cozy compiler target.

### TFAF-03 Resource List runtime

Provide a reusable Resource List implementation controlled by configuration.

Prove at minimum:

- visible item properties
- selection
- basic action binding
- navigation/detail relationship

### TFAF-04 Resource Detail runtime

Provide a reusable Resource Detail implementation controlled by configuration.

A field/presentation change must be demonstrable through configuration change without creating a new screen implementation.

### TFAF-05 Adaptive master-detail

Provide the first adaptive composition contract.

Demonstrate the same List + Detail semantics as:

- compact sequential navigation
- expanded side-by-side presentation
- foldable-aware two-pane presentation when device/display information permits it

The framework consumes device/display-feature primitives from `textus-flutter-core`.

### TFAF-06 Editing Studio Reference Application

Integrate with `nict-editing-studio-app` and demonstrate a Candidate/resource List + Detail path.

The application should consist primarily of:

- TFAF configuration
- domain/application bindings
- application assets

Application-specific Widget code should be recorded explicitly as a framework gap or intentional custom extension.

### TFAF-07 Cozy handoff contract

Document the configuration schema and mapping expectations required for Cozy to generate TFAF configuration.

The phase does not require full Cozy UI generation to be complete, but the configuration contract must be designed as a compiler target rather than as hand-maintained Flutter-only settings.

## Fold target

Fold support is part of the Phase 1 architectural proof, but the phase should avoid embedding device-specific Editing Studio behavior.

The proof is successful when the same semantic List/Detail model/configuration can be realized differently according to available display regions without duplicating the application screen implementation.

## Out of scope

- Complete Editing Studio functionality.
- Complete Capture UI.
- Complete Workflow/Approval UI.
- Full three-pane desktop presentation.
- Exhaustive responsive breakpoint system.
- Full Cozy UI compiler implementation.
- Application-specific visual polishing.

These are successors once the configuration/runtime boundary has been proven.

## Acceptance criteria

Phase 1 is complete when:

- TFAF has an executable Flutter package foundation.
- Resource List and Resource Detail work from declarative configuration.
- realization policy is represented in the configuration/model contract.
- one List + Detail scenario adapts between compact and expanded/foldable presentation using the same semantic configuration.
- `nict-editing-studio-app` exercises this path as the Reference Application.
- the boundary with `textus-flutter-core` is documented and respected.
- the TFAF configuration contract is documented sufficiently for Cozy to target it.
- specialized UI has a defined `generated/hybrid/custom` escape path without weakening the configuration-first default.


## Source and artifact separation

Phase 1 must make framework ownership and application artifact provenance visible in the source tree. Generated source, handwritten application source, configuration, and framework implementation must not be mixed.

The target separation is conceptually:

```text
textus-flutter-application-framework/
  lib/
    ...                         # reusable framework implementation only

nict-editing-studio-app/
  lib/
    app/                        # handwritten application composition/extensions
    generated/                  # generated Dart; generator-owned, not hand-edited
  config/                       # declarative TFAF application/UI configuration
  test_support/
    fake/                       # fake resources/repositories for development driving
```

Exact Flutter package conventions may refine these names, but the ownership boundaries are mandatory.

Rules:

1. TFAF contains no Editing-Studio-specific source.
2. `generated/` is generator-owned and replaceable; handwritten code must not be placed there.
3. `app/` contains only application-owned composition and intentional custom/hybrid extensions.
4. `config/` is the preferred expression of standard Resource List/Detail behavior and is the future Cozy generation target.
5. Fake data/repositories are development-driver infrastructure and must not leak into framework semantics.
6. Generated code may depend on TFAF public APIs; TFAF must never depend on generated application code.
7. Handwritten application code may extend generated/framework behavior only through explicit public extension points.
8. A standard List/Detail presentation is considered successful only when the Editing Studio does not need handwritten List/Detail Widgets.

This separation is part of the executable architecture and should be tested/linted where practical.


## Model/server/client continuity constraint

Phase 1 must design the fake Resource List/Detail path so it can be replaced by a server Operation-backed data source without changing the standard List/Detail UI implementation.

Introduce or reserve a semantic Resource data-source boundary rather than binding framework Widgets directly to fake collections, REST, JSON, or endpoint URLs.

The first fake implementation is therefore a contract proof, not a temporary shortcut.

Phase 1 design/review must verify that the path can evolve toward:

```text
CML/Operation Model -> Server Operation -> typed/generated client/binding
                    -> TFAF ResourceDataSource -> ResourceListDetail
```

A future acceptance proof should replace the fake data source with an Operation-backed implementation while retaining the same Resource List/Detail configuration and framework presentation.
