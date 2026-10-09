import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  late Directory directory;
  late _Store store;
  late _Camera camera;
  late _Provider standard;
  late _Provider enhanced;
  late PhotoCaptureFacade facade;
  late _SettingsStorage storage;
  late SettingsLifecycleController settings;
  late SettingsView view;
  late PhotoCaptureController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-panel-spec-');
    store = _Store(FileCaptureStore(directory.path));
    camera = _Camera();
    standard = _Provider();
    enhanced = _Provider(enhanced: true);
    facade = PhotoCaptureFacade(service: _service(camera, standard, enhanced, store));
    storage = _SettingsStorage();
    settings = _settings(storage);
    view = SettingsView.fromService(service: settings);
    controller = PhotoCaptureController(facade: facade, settings: view);
  });
  tearDown(() async {
    controller.dispose();
    view.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  group('PC2 operation-start comparison callback', () {
    testWidgets('same-controller rebuild retains the callback bound before held capture', (tester) async {
      // Given an initialized actual service and a held camera under the first callback.
      final first = <RecognitionComparison>[];
      final rebuilt = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      camera.gate = Completer<CapturedPhoto?>();
      await tester.pumpWidget(_host(controller, onComparison: first.add));
      await tester.runAsync(() async => tester.tap(find.byKey(const ValueKey('photo-capture-capture'))));
      await tester.pump();
      // When the same panel/controller rebuilds with a replacement callback before capture completion.
      await tester.pumpWidget(_host(controller, onComparison: rebuilt.add));
      await tester.runAsync(() async {
        camera.gate!.complete(_photo());
        await _waitIdle(controller);
      });
      await tester.pumpAndSettle();
      // Then only the original callback receives the exact once-durable completion.
      expect(first, [controller.comparison]);
      expect(rebuilt, isEmpty);
      expect(camera.captures, 1); expect(store.imports, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('W1 public interaction selects enhanced and compares one durable original', (tester) async {
    // Given explicitly initialized real Core interaction and a borrowed panel callback.
    final callbacks = <RecognitionComparison>[];
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
    // When the user selects enhanced intent, captures, then compares the same original.
    await tester.tap(find.byKey(const ValueKey('photo-capture-configuration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pixel enhanced').last);
    await tester.pumpAndSettle();
    await tester.runAsync(view.retrySave);
    await _command(tester, controller, 'capture');
    final captured = controller.comparison!;
    await _command(tester, controller, 'compare');
    final compared = controller.comparison!;
    final reopened = await tester.runAsync(() => LocalRecognitionRepository(
      store: FileCaptureStore(directory.path)).findById(compared.id));
    // Then the two rows retain raw ordered proposals, timing, shared work and durable identity.
    expect(find.byKey(const ValueKey('recognition-run-androidStandard')), findsOneWidget);
    expect(find.byKey(const ValueKey('recognition-run-pixelEnhanced')), findsOneWidget);
    expect(find.text('Actual: pixelEnhanced'), findsOneWidget);
    expect(find.text('Fallback reason: none'), findsNWidgets(2));
    expect(find.text('Candidate 0: kind "unknown kind"; value " opaque proposal "'), findsOneWidget);
    expect(find.text('Candidate 1: kind "unknown kind"; value " opaque proposal "'), findsOneWidget);
    expect(find.text('Barcode 0: " second "; format "rawFormat"'), findsNWidgets(2));
    expect(find.text('Barcode 1: "first"; format "anotherFormat"'), findsNWidgets(2));
    expect(find.text('OCR: " raw OCR "'), findsNWidgets(2));
    expect(find.text('Interpretation: " raw interpretation "'), findsOneWidget);
    for (final run in compared.runs) {
      // Given the actual Core timing of this desired route.
      // When the report is rendered.
      // Then row and attempt milliseconds are displayed without invented timing.
      expect(find.text('Row elapsed: ${run.elapsed.inMilliseconds} ms (includes shared work)'), findsWidgets);
      for (final attempt in run.attempts) {
        // Given this provider attempt's actual measured duration.
        // When its presentation is observed.
        // Then the exact elapsed milliseconds remain visible.
        expect(find.text('Attempt elapsed: ${attempt.elapsed.inMilliseconds} ms'), findsWidgets);
      }
    }
    expect(find.textContaining('shared work'), findsWidgets);
    expect(compared.material, same(captured.material));
    expect(camera.captures, 1);
    expect(store.imports, 1);
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
    expect(callbacks, [captured, compared]);
    expect(RecognitionReportCodec.encode(reopened!), RecognitionReportCodec.encode(compared));
    expect(SettingsRecord.decode(storage.record!).values[RecognitionSettings.configuration.id], 'pixelEnhanced');
    // Given the same saved original and explicit saved-image/recovery controls.
    // When recognition and recovery complete successfully through the UI.
    await _command(tester, controller, 'recognize');
    await _command(tester, controller, 'recover');
    // Then each success emits exactly one callback and recovery alone adds acquisition.
    expect(callbacks, hasLength(4));
    expect(camera.captures, 1);
    expect(camera.recoveries, 1);
    expect(store.imports, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W2 explicit model preparation renders busy status and excludes duplicate operations', (tester) async {
    // Given a downloadable provider and a held model preparation.
    enhanced.state = RecognitionProviderState.downloadable;
    enhanced.prepareGate = Completer<void>();
    final callbacks = <RecognitionComparison>[];
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
    // When the user explicitly chooses Prepare.
    await tester.tap(find.byKey(const ValueKey('photo-capture-prepare-geminiNano')));
    await tester.pump();
    await tester.runAsync(_settle);
    await tester.pump();
    // Then busy/preparing are visible and every action is disabled.
    expect(find.text('Preparing geminiNano'), findsOneWidget);
    expect(enhanced.prepares, 1);
    for (final id in ['refresh', 'capture', 'recover', 'recognize', 'compare', 'prepare-geminiNano']) {
      // Given this action during the same held preparation.
      // When its callback is inspected.
      // Then no duplicate UI operation can be started.
      expect(tester.widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$id'))).onPressed, isNull);
    }
    expect(tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('photo-capture-configuration'))).onChanged, isNull);
    // Given completion of the actual provider fixture.
    enhanced.prepareGate!.complete();
    // When the admitted operation settles.
    await tester.runAsync(() => _waitIdle(controller));
    await tester.pumpAndSettle();
    // Then model availability is visible without inference, callback or preference change.
    expect(find.text('Provider geminiNano: available'), findsOneWidget);
    expect(find.text('Model: fixture-model'), findsNWidgets(2));
    expect(enhanced.inputs, isEmpty);
    expect(callbacks, isEmpty);
    expect(controller.desiredConfigurationId, 'androidStandard');
    // Given externally preparing state without a new preparation request.
    enhanced.state = RecognitionProviderState.preparing;
    // When availability is refreshed explicitly.
    await _command(tester, controller, 'refresh');
    // Then preparing is displayed and another Prepare action is absent.
    expect(find.text('Provider geminiNano: preparing'), findsOneWidget);
    expect(find.text('Preparing geminiNano'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-capture-prepare-geminiNano')), findsNothing);
    expect(enhanced.prepares, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W2 failure retains report and cancellation emits no new callback', (tester) async {
    // Given an accepted capture displayed by the public interaction panel.
    final callbacks = <RecognitionComparison>[];
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
    await _command(tester, controller, 'capture');
    final previous = controller.comparison!;
    // When an actual report write fails through Compare.
    store.writeError = StateError('actual report write failure');
    await _command(tester, controller, 'compare');
    // Then UI catches the Future, displays the actual reason and retains the accepted report.
    expect(find.textContaining('actual report write failure'), findsOneWidget);
    expect(controller.comparison, same(previous));
    expect(callbacks, [previous]);
    expect(tester.takeException(), isNull);
    // Given a downloadable provider whose explicit preparation fails.
    store.writeError = null;
    enhanced.state = RecognitionProviderState.downloadable;
    enhanced.prepareError = StateError('actual model preparation failure');
    await _command(tester, controller, 'refresh');
    // When its visible Prepare action is used.
    await _command(tester, controller, 'prepare-geminiNano');
    // Then preparation failure is displayed without replacing the report or emitting a callback.
    expect(find.textContaining('actual model preparation failure'), findsOneWidget);
    expect(controller.comparison, same(previous));
    expect(callbacks, [previous]);
    // Given camera cancellation for both acquisition entry points.
    camera.photo = null;
    // When the user captures and recovers.
    await _command(tester, controller, 'capture');
    await _command(tester, controller, 'recover');
    // Then no new report callback is emitted and previous output stays visible.
    expect(callbacks, [previous]);
    expect(controller.comparison, same(previous));
    expect(find.text('Comparison: ${previous.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W3 settings read/save errors and retry UI preserve barrier and unsaved truth', (tester) async {
    // Given a borrowed panel whose owner has not initialized settings.
    final callbacks = <RecognitionComparison>[];
    await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
    // When construction and mount are observed.
    // Then no load starts and acquisition stays disabled.
    expect(storage.reads, 0);
    expect(find.text('Settings read: notLoaded'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('photo-capture-capture'))).onPressed, isNull);
    // Given a held read followed by an actual read failure.
    storage.readGate = Completer<String?>();
    await tester.tap(find.byKey(const ValueKey('photo-capture-retry-load')));
    await tester.pump();
    // When the read is still pending.
    // Then loading is visible independently of photo capability.
    expect(find.text('Settings read: loading'), findsOneWidget);
    expect(controller.busy, isTrue);
    // Given completion with the actual error.
    storage.readGate!.completeError(StateError('actual settings read failure'));
    storage.readGate = null;
    // When the controller's retry settles.
    await tester.runAsync(() => _waitIdle(controller));
    await tester.pumpAndSettle();
    // Then read failure remains visible and capture stays blocked.
    expect(find.text('Settings read: failed'), findsOneWidget);
    expect(find.textContaining('actual settings read failure'), findsOneWidget);
    expect(camera.captures, 0);
    // Given supported storage and a failing next write.
    storage.writeError = StateError('actual settings save failure');
    // When explicit read retry succeeds and enhanced intent is selected.
    await _command(tester, controller, 'retry-load');
    controller.selectConfiguration('pixelEnhanced');
    await tester.runAsync(_settle);
    await tester.pumpAndSettle();
    // Then the independent save failure/unsaved state is visible.
    expect(find.text('Settings read: ready'), findsOneWidget);
    expect(find.text('Settings save: failed'), findsOneWidget);
    expect(find.text('Settings unsaved'), findsOneWidget);
    expect(find.textContaining('actual settings save failure'), findsOneWidget);
    // Given the same failing storage.
    // When a UI retry Future settles normally according to Core's contract.
    await _command(tester, controller, 'retry-save');
    // Then UI still says unsaved and never claims durability.
    expect(find.text('Settings unsaved'), findsOneWidget);
    expect(find.text('Settings save: failed'), findsOneWidget);
    // Given a held successful write retry.
    storage.writeError = null;
    storage.writeGate = Completer<void>();
    await tester.ensureVisible(find.byKey(const ValueKey('photo-capture-retry-save')));
    await tester.tap(find.byKey(const ValueKey('photo-capture-retry-save')));
    await tester.pump();
    await tester.runAsync(_settle);
    await tester.pump();
    // When actual acknowledgement is pending.
    // Then saving is rendered alongside unsaved state.
    expect(find.text('Settings save: saving'), findsOneWidget);
    expect(find.text('Settings unsaved'), findsOneWidget);
    // Given actual storage acknowledgement.
    storage.writeGate!.complete();
    // When the retry settles.
    await tester.runAsync(() => _waitIdle(controller));
    await tester.pumpAndSettle();
    // Then the UI follows the acknowledged snapshot and settings commands emitted no result callbacks.
    expect(find.text('No unsaved settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-capture-retry-save')), findsNothing);
    expect(callbacks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W3 unsupported camera/settings permit existing history display and readiness refresh', (tester) async {
    // Given a real saved report before camera support is lost and settings are unsupported.
    final saved = await tester.runAsync(() => facade.capture(desiredConfigurationId: 'androidStandard'));
    camera.supported = false;
    storage.record = _preference('pixelEnhanced', version: 99);
    await tester.runAsync(controller.initialize);
    await tester.runAsync(() => controller.loadComparison(saved!.id));
    await tester.pumpWidget(_host(controller));
    // When the borrowed panel displays saved history and independent readiness.
    await _command(tester, controller, 'refresh');
    // Then saved output remains readable with acquisition and saved inference blocked by settings.
    expect(find.text('Camera acquisition unsupported'), findsOneWidget);
    expect(find.text('Settings read: unsupported'), findsOneWidget);
    expect(find.text('Comparison: ${saved!.id}'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-capture-retry-load')), findsOneWidget);
    for (final id in ['capture', 'recover', 'recognize', 'compare']) {
      // Given an acquisition/inference control while settings are unsupported.
      // When its callback is inspected.
      // Then the read barrier disables it even though saved output is displayed.
      expect(tester.widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$id'))).onPressed, isNull);
    }
    expect(tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('photo-capture-refresh'))).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W4 raw empty stages duplicates failures fallback sharing and provenance fit large text', (tester) async {
    // Given controlled completed empty stages and an enhanced output containing opaque duplicates/failure.
    standard.output = ImageRecognitionResult(text: '', barcodeCompleted: true);
    enhanced.output = ImageRecognitionResult(
      interpretation: '', candidateOrganizationCompleted: true,
      candidates: [
        RecognitionCandidate(kind: 'unknown kind', value: ' same raw '),
        RecognitionCandidate(kind: 'unknown kind', value: ' same raw '),
      ],
      failures: [ImageRecognitionFailure(
        stage: ImageRecognitionStage.cleanup, code: 'rawCode', message: 'raw failure message')],
    );
    await tester.runAsync(controller.initialize);
    final original = await tester.runAsync(controller.capture);
    final comparison = await tester.runAsync(controller.compareCurrent);
    final raw = RecognitionComparison(
      id: 'rawDisplay', material: original!.material, createdAt: _time,
      runs: comparison!.runs,
      extensions: {'opaque': [' preserve ', null, {'ordered': [2, 1]}]},
    );
    // When a pure view displays the report at a narrow width and large text scale.
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(size: Size(320, 700), textScaler: TextScaler.linear(2)),
      child: SingleChildScrollView(child: Column(children: [
        RecognitionComparisonView(comparison: raw),
        PhotoCapturePanel(controller: controller),
      ])),
    ))));
    // Then empty completed output and all raw stages remain explicit and error-free.
    expect(find.text('OCR: ""'), findsWidgets);
    expect(find.text('Barcode completed: true'), findsWidgets);
    expect(find.text('Candidate organization completed: false'), findsWidgets);
    expect(find.text('Interpretation: ""'), findsWidgets);
    expect(find.text('Candidate 0: kind "unknown kind"; value " same raw "'), findsWidgets);
    expect(find.text('Candidate 1: kind "unknown kind"; value " same raw "'), findsWidgets);
    expect(find.text('Failure: cleanup / rawCode / raw failure message'), findsWidgets);
    expect(find.textContaining('shared work'), findsWidgets);
    expect(find.textContaining('Input attempt IDs: ["recognition'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Given expandable provenance and scrollable embedding.
    // When provenance expands and the acquisition controls are brought into view.
    await tester.ensureVisible(find.text('Provenance details').first);
    await tester.tap(find.text('Provenance details').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(jsonEncode(raw.extensions)));
    await tester.ensureVisible(find.byKey(const ValueKey('photo-capture-capture')));
    // Then verbatim JSON and reachable controls coexist without Flutter layout errors.
    expect(find.text(jsonEncode(raw.extensions)), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-capture-capture')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Given completed empty candidate organization from the next enhanced invocation.
    enhanced.output = ImageRecognitionResult(interpretation: '', candidateOrganizationCompleted: true);
    // When the original is recognized as enhanced and displayed.
    controller.selectConfiguration('pixelEnhanced');
    final empty = await tester.runAsync(controller.recognizeCurrent);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RecognitionComparisonView(comparison: empty!)))));
    // Then empty completed candidates are explicitly represented.
    expect(find.text('Candidate organization completed: true'), findsOneWidget);
    expect(find.text('Candidate count: 0'), findsNWidgets(2));
    // Given enhanced unavailability on a later same-original comparison.
    enhanced.state = RecognitionProviderState.unavailable;
    // When common comparison renders the Core fallback report.
    final fallback = await tester.runAsync(controller.compareCurrent);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RecognitionComparisonView(comparison: fallback!)))));
    // Then unavailable nonexecuted work and explicit fallback reason are visible.
    expect(find.text('Actual: androidStandard'), findsNWidgets(2));
    expect(find.textContaining('Fallback reason: geminiNano:'), findsOneWidget);
    expect(find.text('Provider: geminiNano; nonexecuted'), findsOneWidget);
    expect(find.text('Availability: unavailable'), findsOneWidget);
    expect(find.textContaining('Failure: availability /'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('W5 unmounted panel suppresses held completion callback and borrows dependencies', (tester) async {
    // Given a panel with a camera acquisition held by its borrowed controller.
    final callbacks = <RecognitionComparison>[];
    await tester.runAsync(controller.initialize);
    camera.gate = Completer<CapturedPhoto?>();
    await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('photo-capture-capture')));
    });
    await tester.pump();
    // When the panel unmounts before Core finishes.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      camera.gate!.complete(_photo());
      await _waitIdle(controller);
    });
    // Then the borrowed controller accepts durable completion but no late UI callback is sent.
    expect(callbacks, isEmpty);
    expect(controller.comparison, isNotNull);
    expect(tester.takeException(), isNull);
    // Given dependencies whose lifetime remains owned by the fixture.
    camera.gate = null;
    // When settings and service are used after unmount.
    view.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
    await tester.runAsync(view.retrySave);
    final saved = await tester.runAsync(() => facade.capture(desiredConfigurationId: 'androidStandard'));
    // Then neither dependency was disposed by the widget.
    expect(saved, isNotNull);
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
  });

  testWidgets('W5 replaced controller suppresses old callbacks and detaches its listener', (tester) async {
    // Given an initialized panel holding acquisition on the first controller.
    final oldCallbacks = <RecognitionComparison>[];
    final newCallbacks = <RecognitionComparison>[];
    await tester.runAsync(controller.initialize);
    camera.gate = Completer<CapturedPhoto?>();
    await tester.pumpWidget(_host(controller, onComparison: oldCallbacks.add));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('photo-capture-capture')));
    });
    await tester.pump();
    final nextCamera = _Camera();
    final nextSettings = _settings(_SettingsStorage());
    final nextView = SettingsView.fromService(service: nextSettings);
    final next = (await tester.runAsync(() async => PhotoCaptureController(settings: nextView,
      facade: PhotoCaptureFacade(service: _service(nextCamera, _Provider(),
        _Provider(enhanced: true), store)))))!;
    await tester.runAsync(next.initialize);
    // When the same panel element replaces its borrowed controller before old completion.
    await tester.pumpWidget(_host(next, onComparison: newCallbacks.add));
    await tester.runAsync(() async {
      camera.gate!.complete(_photo());
      await _waitIdle(controller);
    });
    await tester.pump();
    // Then old durable work causes no late callback or notification error in the new panel.
    expect(oldCallbacks, isEmpty);
    expect(newCallbacks, isEmpty);
    expect(controller.comparison, isNotNull);
    expect(next.comparison, isNull);
    expect(tester.takeException(), isNull);
    // Given the new controller remains independently usable.
    // When a new UI capture succeeds and the panel is detached.
    await _command(tester, next, 'capture');
    await tester.pumpWidget(const SizedBox.shrink());
    // Then exactly its own successful report is sent and borrowed settings remain usable.
    expect(newCallbacks, [next.comparison]);
    nextView.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
    expect(next.desiredConfigurationId, 'pixelEnhanced');
    next.dispose();
    nextView.dispose();
    nextSettings.dispose();
  });
}

Widget _host(PhotoCaptureController controller, {ValueChanged<RecognitionComparison>? onComparison}) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: PhotoCapturePanel(controller: controller, onComparison: onComparison))));

Future<void> _waitIdle(PhotoCaptureController controller) async {
  final watch = Stopwatch()..start();
  while (controller.busy) {
    if (watch.elapsed > const Duration(seconds: 10)) throw StateError('Held fixture did not settle');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<void> _command(WidgetTester tester, PhotoCaptureController controller, String id) async {
  final control = find.byKey(ValueKey('photo-capture-$id'));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(control);
    await _waitIdle(controller);
  });
  await tester.pumpAndSettle();
}

final _time = DateTime.utc(2026, 10, 6);
CapturedPhoto _photo() => CapturedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]), mediaType: 'image/jpeg',
  capturedAt: _time, originalName: 'original.jpg',
);

final class _Camera implements CameraProvider {
  bool supported = true;
  CapturedPhoto? photo = _photo();
  Object? error;
  Completer<CapturedPhoto?>? gate;
  int captures = 0;
  int recoveries = 0;
  @override
  bool get isSupported => supported;
  @override
  Future<CapturedPhoto?> capturePhoto() async {
    captures++;
    if (error != null) throw error!;
    return gate == null ? photo : gate!.future;
  }
  @override
  Future<CapturedPhoto?> recoverLostPhoto() async {
    recoveries++;
    if (error != null) throw error!;
    return photo;
  }
}

final class _Provider implements ImageRecognitionProvider, ImageRecognitionProviderProvenance {
  _Provider({this.enhanced = false});
  final bool enhanced;
  RecognitionProviderState state = RecognitionProviderState.available;
  Object? prepareError;
  Object? provenanceError;
  Completer<void>? prepareGate;
  int probes = 0;
  int prepares = 0;
  final inputs = <ImageRecognitionInput>[];
  ImageRecognitionResult? output;
  @override
  RecognitionProviderDescriptor get descriptor => RecognitionProviderDescriptor(
    id: enhanced ? 'geminiNano' : 'mlkitStandard', label: enhanced ? 'Enhanced' : 'Standard',
    capabilities: enhanced
      ? {RecognitionCapability.imageInterpretation, RecognitionCapability.candidateOrganization}
      : {RecognitionCapability.ocr, RecognitionCapability.barcodes},
  );
  @override
  Map<String, Object?> get provenance {
    if (provenanceError != null) throw provenanceError!;
    return {'model': 'fixture-model', 'opaque': [true, null, ' raw ']};
  }
  @override
  Future<RecognitionProviderAvailability> availability() async {
    probes++;
    return RecognitionProviderAvailability(
      providerId: descriptor.id, state: state, capabilities: descriptor.capabilities,
      modelName: 'fixture-model',
      reason: state == RecognitionProviderState.unavailable ? 'not supported here' : null,
    );
  }
  @override
  Future<void> prepare() async {
    prepares++;
    if (prepareGate != null) await prepareGate!.future;
    if (prepareError != null) throw prepareError!;
    state = RecognitionProviderState.available;
  }
  @override
  Future<ImageRecognitionResult> recognize(ImageRecognitionInput input) async {
    inputs.add(input);
    return output ?? (enhanced
      ? ImageRecognitionResult(
          interpretation: ' raw interpretation ', candidateOrganizationCompleted: true,
          candidates: [
            RecognitionCandidate(kind: 'unknown kind', value: ' opaque proposal '),
            RecognitionCandidate(kind: 'unknown kind', value: ' opaque proposal '),
            RecognitionCandidate(kind: 'isbn', value: 'not validated'),
          ],
        )
      : ImageRecognitionResult(text: ' raw OCR ', barcodeCompleted: true, barcodes: [
          RecognizedImageBarcode(value: ' second ', format: 'rawFormat'),
          RecognizedImageBarcode(value: 'first', format: 'anotherFormat'),
        ]));
  }
}

final class _Store implements LocalCaptureStore {
  _Store(this.delegate);
  final LocalCaptureStore delegate;
  Object? writeError;
  Object? readError;
  int writes = 0;
  int imports = 0;
  @override
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes, required String mediaType,
    required DateTime capturedAt, String? originalName,
  }) {
    imports++;
    return delegate.saveMaterial(bytes: bytes, mediaType: mediaType,
      capturedAt: capturedAt, originalName: originalName);
  }
  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) => delegate.readMaterial(reference);
  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) async {
    writes++;
    if (writeError != null) throw writeError!;
    await delegate.saveDocument(collection, id, document);
  }
  @override
  Future<Map<String, Object?>?> readDocument(String collection, String id) async {
    if (readError != null) throw readError!;
    return delegate.readDocument(collection, id);
  }
  @override
  Future<List<String>> listDocumentIds(String collection) => delegate.listDocumentIds(collection);
}

var _serviceIdentities = 0;
PhotoCaptureService _service(_Camera camera, _Provider standard, _Provider enhanced, LocalCaptureStore store) {
  final serviceIdentity = _serviceIdentities++;
  var tick = 0;
  var identity = 0;
  return PhotoCaptureService(
    camera: CameraService(provider: camera),
    recognition: ImageRecognitionService(
      registry: RecognitionProviderRegistry(providers: [standard, enhanced]),
      clock: () => _time.add(Duration(milliseconds: tick++ * 7)),
      idGenerator: () => 'recognition${serviceIdentity}_${identity++}',
    ),
    store: store,
  );
}

final class _SettingsStorage implements SettingsStorage {
  String? record;
  Object? readError;
  Object? writeError;
  Completer<String?>? readGate;
  Completer<void>? writeGate;
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> read() async {
    reads++;
    if (readError != null) throw readError!;
    return readGate == null ? record : readGate!.future;
  }
  @override
  Future<void> write(String value) async {
    writes++;
    if (writeGate != null) await writeGate!.future;
    if (writeError != null) throw writeError!;
    record = value;
  }
}

SettingsLifecycleController _settings(_SettingsStorage storage) => SettingsLifecycleController(
  registry: RecognitionSettings.registry(), storage: storage,
  resetDefinitions: RecognitionSettings.definitions,
);

String _preference(String desired, {int version = 1}) => SettingsRecord.empty()
    .withUpdates({RecognitionSettings.configuration.id: desired}).encode()
    .replaceFirst('"version":1', '"version":$version');

Future<void> _settle() => Future<void>.delayed(Duration.zero);
