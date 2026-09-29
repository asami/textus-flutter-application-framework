# Textus Flutter Application Framework

Textus Flutter Application Framework (TFAF) is the configuration-driven application UI framework for Textus Flutter applications.

Its primary goal is to make standard application functions work from declarative configuration, while allowing selective code generation and handwritten extensions only where application-specific behavior requires them.

## Position

The intended stack is:

```text
CML / Application Model
        |
        v
Cozy UI Model
        |
        v
Framework Configuration (+ selective generated Dart)
        |
        v
Textus Flutter Application Framework
        |
        v
textus-flutter-core
        |
        v
Flutter
```

Responsibilities are separated as follows:

- **Cozy** owns UI modeling and compilation from models to framework configuration and, where necessary, generated Dart.
- **Textus Flutter Application Framework** owns reusable application-level UI behavior driven by configuration.
- **textus-flutter-core** owns lower-level Flutter/runtime capabilities such as device services, connectivity, common runtime contracts, and adaptive-device primitives.
- Application repositories provide configuration and only the application-specific extensions that cannot reasonably be expressed by the framework.

## Design principle

The default implementation priority is:

1. **Configuration**
2. **Generated code**
3. **Handwritten custom code**

A change such as adding a field to a resource detail view should normally result in a configuration change, not a newly generated screen implementation.

## Initial framework capabilities

The first capability set targets common resource-oriented application UI:

- Resource List
- Resource Detail
- Resource Editor
- Search / Filter / Sort
- Action and Navigation
- Master-detail / multi-pane composition
- Workflow and approval presentation
- Evidence / attachment presentation
- Adaptive layout including foldable devices

Each screen or presentation unit may choose an implementation policy:

- `framework` — configuration interpreted by reusable framework components
- `generated` — generated Dart/Flutter implementation
- `hybrid` — framework behavior with generated or handwritten extension points
- `custom` — application-owned implementation

`framework` is the default.

## Reference application

`nict-editing-studio-app` is the first Reference Application.

The initial target is not merely to hand-build a foldable Editing Studio application. The target is to demonstrate that the Editing Studio can be described by UI/application models and framework configuration, including adaptive/foldable behavior.

See [Phase 1](docs/phase/phase-1.md) and the [initial architecture journal](docs/journal/2026/09/2026-09-27-configuration-driven-ui-framework.md).

The [adaptive List/Detail display specification](docs/notes/adaptive-list-detail-display-model.md)
defines a shared, usable-region-driven split/detail-focus model. Compact
layouts keep sequential List/Detail navigation without exposing mode controls;
split-capable layouts default to List | Detail and permit explicit detail focus
and restoration. `ResourceListDetailDisplayModel` supplies the shared
presentation-session state; `allowDetailFocus` controls the optional capability
in JSON configuration. Physical vertical Fold transitions have been accepted;
the bounded observations and automated coverage are recorded in the
[Phase 1 checklist](docs/phase/phase-1-checklist.md).

An independent `ResourceListDetailHingePolicy` controls separator treatment:
`avoid` uses continuous panes around either separator axis, while `span` uses
ordinary left/right panes and full-body focused content. `defaultHingePolicy`
defaults to `automatic` (avoid physical gaps, span zero-thickness folds), and
`allowHingePolicySwitch` defaults to `true`. The common AppBar menu offers viable
avoid/span choices; explicit session preference survives compact sizing and
orientation without changing detail focus or semantic selection. Spanning a
physical gap carries a content-occlusion warning.

## Development status

The initial Flutter package foundation is in place. Its public entry point is
`package:textus_flutter_application_framework/textus_flutter_application_framework.dart`,
and it depends on the sibling `textus-flutter-core` package. The first public
configuration value is `PresentationRealization`, which supports stable JSON
names for `framework`, `generated`, `hybrid`, and `custom`.

An initial `ResourceDataSource` contract, serializable List/Detail
configuration, and standard Resource List/Detail Widget now run in the NICT
Editing Studio app with two distinct fake resource bindings and configurations:
collecting resources and Knowledge Candidates. The same selection is realized
as compact navigation or an expanded detail pane according to the configured width
breakpoint. Core's `SeparatedDisplayRegions` additionally supports vertical
left/right and horizontal upper/lower fold/hinge regions. Both clipped body
panes must meet the configured minimum width and height under `avoid`; that
policy excludes the separator from split, focused, and compact single-region
content, including an explicitly avoided zero-thickness fold. `span` instead
requires two minimum-width panes across the safe body and uses ordinary
left/right composition; it deliberately permits crossing a physical gap.
The optional
`minimumFoldPaneHeight` defaults to 180 logical pixels for old JSON.
Phase 1 is closed for the configuration-driven fake-resource reference path.
Horizontal hinge geometry has automated coverage; physical horizontal posture
acceptance and broader configuration coverage are not claimed.

`ApplicationNavigationConfiguration` is the serializable UI model for an
ordered set of bottom-navigation destinations. `ApplicationNavigationShell`
owns tab selection and preserves visited page state; applications supply the
destination labels, symbols, and page bindings. The reference app currently
constructs this typed model in its application composition, while its Resource
List/Detail presentations remain JSON-configured.

`ResourceListDetail` now consumes a `ResourceViewModel` rather than querying an
application data source directly. Its collection and detail Views own loading,
selection, safe error state, and action dispatch. Their read sources supply a
projection; an optional action handler translates view intents into
application-owned aggregate commands. The reference app proves this with a
fake Candidate aggregate and a review-request transition. No server Candidate
Operation is implied by that fake implementation.

Optional `detailActions` now declares an ordered detail-action allowlist and
presentation labels. The standard Widget intersects it with handler availability
and dispatches semantic IDs through the same View/command boundary. Absent/null
preserves legacy handler-driven presentation; `[]` explicitly hides buttons.
Configuration cannot grant command authority or bypass Aggregate validation.
The [configuration and Cozy handoff contract](docs/notes/configuration-cozy-handoff.md)
documents the implemented Resource, navigation, action, adaptive, and realization
schemas and the remaining typed application binding boundary. It is a compiler
target specification, not a completed Cozy generator.

`ApplicationViewModel` is the application-session view space: it owns named,
observable semantic Views independently of routes and Widgets. Reusable
`ResourceCollectionView` and `ResourceDetailView` are its first concrete View
types. `ResourceViewModel` remains a List/Detail presentation adapter so existing
Widgets can consume either standalone or application-owned Views.
`CrudResourceAdapter` can project an application-supplied CRUD client into the
same read contract while retaining typed create/update/delete inputs and
expected revisions. It defines no HTTP paths or Aggregate business rules;
the application must supply an authorized server client when one exists.

For local development, keep this repository and `textus-flutter-core` as sibling
directories, then run `flutter pub get`, `flutter analyze`, and `flutter test`.
The repository-owned `scripts/validate-full.sh` runs analysis and the full test
suite. See the [Phase index](docs/phase/README.md): Phase 1 is closed and
Phase 2 (common Settings) remains planned.
