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

## Development status

The initial Flutter package foundation is in place. Its public entry point is
`package:textus_flutter_application_framework/textus_flutter_application_framework.dart`,
and it depends on the sibling `textus-flutter-core` package. The first public
configuration value is `PresentationRealization`, which supports stable JSON
names for `framework`, `generated`, `hybrid`, and `custom`.

The Resource List/Detail runtime and adaptive pane behavior in Phase 1 are not
implemented yet. The NICT Editing Studio app currently exercises the package
dependency and import path, not those UI capabilities.

For local development, keep this repository and `textus-flutter-core` as sibling
directories, then run `flutter pub get`, `flutter analyze`, and `flutter test`.
