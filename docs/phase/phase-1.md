# Phase 1 - Configuration-driven UI Reference Path

status=in_progress

planned_at=2026-09-27

reference_application=KnowledgeHubProject/nict-editing-studio-app

## Goal

Establish the first executable vertical path from declarative application UI configuration to a Flutter application, using the NICT Editing Studio as the Reference Application.

Phase 1 must prove that standard Editing Studio UI can be implemented primarily by framework configuration and reusable runtime components, including an initial adaptive/foldable presentation path.

An initial implementation now provides serializable List/Detail configuration,
an asynchronous ResourceDataSource boundary, and width-based compact/expanded
standard presentation exercised by the NICT app with fake data. Core now
interprets vertical/horizontal fold/hinge geometry for the adaptive pane layout. Physical
foldable acceptance, broader configuration coverage, independent
review, and Phase acceptance remain open.

The application now also exercises a serializable TFAF bottom-navigation model
and framework-owned tab shell. Editing Studio supplies three destination
bindings; TFAF owns selection and visited-page state. JSON decoding is
available in the framework contract, though the reference app currently builds
the typed navigation configuration synchronously at its composition boundary.

The Resource List/Detail Widget now consumes a runtime `ResourceViewModel`.
Queries populate its read projection; view actions dispatch through a separate
handler to application-owned commands. The fake Candidate path demonstrates an
aggregate-validated review transition and projection refresh without placing
mutation logic in the Widget or View Model. Production Workbench Operations and
full CRUD/lifecycle semantics remain future contract work.

The 2026-09-29 configuration-action successor adds serializable `detailActions`
with ordered semantic IDs and presentation labels. Absent/null retains legacy
handler-driven presentation; an empty list hides actions. The standard detail
Widget intersects configuration with runtime availability and still dispatches
through Views to application Aggregate commands. The reference Candidate JSON
declares its review intent while Collecting explicitly declares no detail actions.
The [configuration/Cozy handoff](../notes/configuration-cozy-handoff.md) documents
the implemented schemas, compiler mapping, typed resource/view/page bindings,
compatibility, and realization escape boundary. JSON registry loading, broader
action surfaces, full Cozy generation, physical posture acceptance, and
independent Phase acceptance are not claimed by this successor.
Final successor verification passed all 73 TFAF and 39 reference-app Flutter
tests. TFAF analysis is clean; the app retains only its two preexisting
nonfatal Book Capture infos. Fourteen new framework cases include executable
Cozy documentation examples and action availability/serialization; five new
app cases cover actual JSON-to-Aggregate execution at compact/split widths
and configuration asset/bundle replacement. Fresh parent source review found
no current slice blocker; it is not independent full Phase acceptance.

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

The agreed [adaptive List/Detail display model](../notes/adaptive-list-detail-display-model.md)
also requires a shared split/detail-focused presentation contract. Eligibility
depends on usable display regions, not Fold posture. Compact navigation does
not expose mode controls or implicitly request detail focus; growing a compact
detail screen must show List | Detail with the same selection by default.
Explicit detail focus and restore-split actions are available only when split
presentation is viable. `ResourceListDetailDisplayModel` now supplies the shared
presentation-session state, and Editing Studio provides a separate instance for
each resource tab. The framework reconciles size changes within one adaptive
Scaffold rather than leaving a compact detail route over the expanded layout.
Focused executable verification and physical-device transition acceptance are
tracked separately; this implementation does not close Phase 1.

The initial 2026-09-29 focused verification passed 34 framework tests and 22
reference app tests for width changes and the original vertical-region primitive.
The successor horizontal-region slice adds Core rectangles/gaps, actual body
viewport clipping, height-aware stacked panes, and continuous-region compact
fallback. Its focused verification is recorded separately in the display-model
note; physical fold/unfold visual acceptance remains pending. Multiple/partial
feature partitioning and chrome relocation are not claimed by this slice.
The successor final Flutter test runs passed Core 25, TFAF 47, and reference
app 31 tests; Core/TFAF analysis was clean. The app retained its two existing
nonfatal Book Capture deprecation infos. Phase 1 remains in progress.

The selectable-policy successor separates hinge avoidance/spanning from detail
focus. Configuration adds compatible `defaultHingePolicy=automatic` and
`allowHingePolicySwitch=true` defaults; the common menu selects `avoid` or
`span` when viable. Automatic avoids physical gaps and spans non-occluding
folds. Explicit policy survives resizing, rotation, and focus/restore, including
avoiding a zero-thickness crease or deliberately spanning a positive gap with
an occlusion warning. Each reference-app resource tab keeps its own preference.
This remains TFAF-05 work, not a new app Phase 2 or Phase 1 acceptance claim.
Final selectable-policy full Flutter runs passed Core 25, TFAF 59, and reference
app 34 tests; Core/TFAF analysis is clean and the app retains only its two
existing nonfatal Book Capture infos. Fresh parent source review completed;
physical-device posture acceptance and independent Phase acceptance remain open.

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
- selecting a detail while compact and then gaining sufficient space realizes List | Detail with the same selection; explicit detail focus/restore works in split-capable layout and its controls stay absent while compact.
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
