# Capture storage facade

Current status: Independently accepted for ESA6-01; local Step commit pending.
Owner: Textus Flutter Application Framework; App PHASE-6 / ESA6-01 / ESA6-01-B.
Update rule: Change public delegation contracts through the parent plan; record focused validation and independent acceptance separately.

The original body below records the authoring checkpoint. Its pending-validation
statements are historical; the dated acceptance addendum records the current status.

## Public entry point

`CaptureStorageFacade` and `openDefaultCaptureStorageFacade` are exported from
the public framework barrel. The facade is the common capture interaction's
storage entry point above textus-flutter-core's public `LocalCaptureStore`.

```dart
import 'dart:typed_data';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

Future<CaptureMaterialReference> importOriginal(
  LocalCaptureStore store,
  Uint8List bytes,
) async {
  final facade = CaptureStorageFacade(store: store);
  final reference = await facade.importMaterial(
    bytes: bytes,
    mediaType: 'image/jpeg',
    capturedAt: DateTime.now(),
    originalName: 'page.jpg',
  );
  await facade.saveDocument('drafts', 'one', {
    'material': reference.toJson(),
    'extensions': <String, Object?>{},
  });
  return reference;
}
```

Callers explicitly import Core for material/store value types. The facade
adds no Annotation terminology or re-export of unrelated Core APIs.

| Facade method | Exactly one Core delegation |
| --- | --- |
| importMaterial | saveMaterial with the same bytes/media/time/name arguments. |
| readMaterial | readMaterial with the exact reference. |
| saveDocument | saveDocument with the same collection/id/document. |
| readDocument | readDocument with the same collection/id. |
| listDocumentIds | listDocumentIds with the same collection. |

Returned references, bytes, documents and id lists retain exact Core values.
Errors and absent-read/list semantics pass through unchanged. The default
factory awaits `openDefaultCaptureStore` and wraps its result; provider and
unsupported-platform failures remain observable without a success fallback.

## Ownership and limits

Core owns immutable material references, unchanged original bytes, ordered
generic writes, strict JSON validation, filesystem durability, platform support
and errors. TFAF owns this public capture integration boundary, without caching,
queues, schema, error wrapping, file IO, service disposal or application policy.
The NICT Editing Studio App owns its candidate model/schema, provenance, local
identity and Draft repository semantics. Generic documents are opaque to TFAF.

The existing [architecture](architecture.md) responsibility boundary remains
the basis for future acquisition/presentation integration. This facade does
not establish camera/device lifecycle, recognition, UI wiring, audio,
transcription, remote references, upload or submission. Explicit application
JSON extensions may carry future data under that application's contract; TFAF
does not interpret or migrate those keys.

## Connected setup and authored evidence

Use a Core checkout containing the connected capture material/store API. TFAF's
existing sibling path dependency selects `../textus-flutter-core`; check that
the sibling is the intended capture delivery. In the App consumer, configure
package-local `pubspec_overrides.yaml` with the actual Core/TFAF paths, then run
`flutter pub get` and targeted checks. The normal public dependency declarations
are retained, with accepted source branch/commit handoffs recorded separately
after acceptance. Older upstream main is not assumed to contain this API.

`test/capture_storage_facade_test.dart` authors public filesystem restart,
exact five-method forwarding, unchanged error identity/recovery and real Core
invalid-input preservation scenarios. Parent-selected checks are `flutter pub
get`, `flutter analyze`, the facade tests and existing CRUD/View consumer tests;
none was run by this implementation worker. Independent Step acceptance remains
pending. Complete upstream validation remains a Phase release obligation.

Later App Phase 6 capture work extends the common interaction above this entry
point; Phase 6.1 requires its own admitted handoff for audio/submission. No
Step/Phase completion, full-suite pass, physical-device observation or upstream
own Phase closure is recorded by this implementation note.

## 2026-10-06 — ESA6-01 acceptance

Parent-recorded TFAF validation completed with the following results:

| Command | Result |
| --- | --- |
| `flutter pub get` | Success. |
| `flutter analyze` | Final analysis: no issues; the initial formal lint was corrected and retained in parent evidence. |
| `flutter test test/capture_storage_facade_test.dart` | 4 passed. |
| `flutter test test/crud_resource_adapter_test.dart test/application_view_model_test.dart` | 3 passed. |
| `git diff --check` | Passed. |

Independent protected-focused complete A+B acceptance returned PASS, reference
`esa6-01-acceptance-20261006` revision1, reviewer
`/root/esa6_01_acceptance_review`, with zero CPB/HYG/DEV.

The parent local Step commit is still pending; its actual commit identity will
be recorded after execution. This addendum asserts no current commit or
whole-Phase closure. Core/TFAF full suites remain pending Phase6 release; the
App aggregate driver is deferred-not-run to Phase6.1. This Step establishes no
physical-device or default-directory acceptance, nor camera, recognition, UI,
audio or submission acceptance.
