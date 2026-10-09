import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  group('shared audio capture panel', () {
    late _Harness h;
    setUp(() async {
      // Given a fresh real-storage test fixture.
      h = _Harness();
      // When the inert controller is opened without UI work.
      await h.open();
      // Then microphone, model and storage are untouched.
      expect(h.provider.starts + h.provider.probes + h.store.imports, 0);
    });
    tearDown(() async {
      // Given explicitly owned settled test resources.
      // When fixture cleanup closes only those resources.
      await h.close();
      // Then borrowed provider ownership remains with composition.
      expect(h.provider.disposals, 0);
    });

    testWidgets(
      'W1 actual two-panel record transcribe correction save reopen replay',
      (tester) async {
        // Given mounted borrowed shared panels and no automatic microphone/model work.
        final callbacks = <AudioTranscriptReview>[];
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        expect(h.provider.starts + h.provider.probes + h.provider.prepares, 0);
        // When explicit UI intent records/stops durably and recognizes exact saved input.
        await _tap(tester, 'audio-capture-record');
        await _pumpUntil(tester, () => h.controller.recordingStarted);
        await _tap(tester, 'audio-capture-stop');
        await _pumpUntil(tester, () => callbacks.length == 1);
        final original = callbacks.single.original;
        await _tap(tester, 'audio-capture-transcribe');
        await _pumpUntil(tester, () => callbacks.length == 2);
        final generated = callbacks.last;
        final editor = find.byKey(const ValueKey('transcript-review-text'));
        await tester.ensureVisible(editor);
        await tester.enterText(editor, ' 手入力📘\n  exact ');
        await tester.pump();
        expect(callbacks.length, 2);
        await _tap(tester, 'transcript-review-record-correction');
        final retained = callbacks.last;
        await tester.runAsync(
          () => h.store.saveDocument(
            'audio-workspaces',
            'one',
            AudioTranscriptCodec.encode(retained),
          ),
        );
        // Create cached detachment in the real zone for later group cleanup.
        await tester.runAsync(h.controller.detach);
        h.controller.dispose();
        final fresh = FileCaptureStore(h.directory.path);
        final encoded = await tester.runAsync(
          () => fresh.readDocument('audio-workspaces', 'one'),
        );
        final decoded = AudioTranscriptCodec.decode(encoded!);
        final freshService = AudioCaptureService(
          runtime: h.provider,
          transcription: h.provider,
          store: fresh,
          now: () => _time,
        );
        final freshFacade = AudioCaptureFacade(service: freshService);
        h.controller = AudioCaptureController(
          facade: freshFacade,
          initialReview: decoded,
          now: () => _time,
        );
        final starts = h.provider.starts;
        final probes = h.provider.probes;
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        await tester.pump();
        // Then reopen preserves exact original/generated/manual history and causes no acquisition or probe.
        expect(h.controller.review, decoded);
        expect(decoded.original, original);
        expect(decoded.reports, generated.reports);
        expect(decoded.revisions.length, 2);
        expect(decoded.revisions.first, generated.revisions.single);
        expect(decoded.revisions.last.text, ' 手入力📘\n  exact ');
        expect(decoded.revisions.last.source, TranscriptRevisionSource.manual);
        expect(decoded.revisions.last.reportId, generated.reports.single.id);
        expect(
          tester.widget<TextField>(editor).controller!.text,
          decoded.currentText,
        );
        expect(h.provider.starts, starts);
        expect(h.provider.probes, probes);
        expect(h.store.imports, 1);
        expect(h.store.documentWrites, 1);
        // When the reopened UI explicitly plays its retained original.
        await _tap(tester, 'audio-capture-play');
        await _pumpUntil(
          tester,
          () => h.provider.played.isNotEmpty && !h.controller.busy,
        );
        // Then playback uses identical original bytes and emits no review or Save callback.
        expect(h.provider.played.single, orderedEquals(_wave()));
        expect(callbacks.length, 3);
        expect(
          await tester.runAsync(() => fresh.readMaterial(original.material)),
          orderedEquals(_wave()),
        );
        expect(h.provider.starts, 1);
        expect(h.provider.inputs.single.original, original);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(h.controller.detach);
        await freshService.dispose();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'W2 pending permission timer cancel durable saving import failure retry',
      (tester) async {
        // Given pending permission and a panel with no saved source.
        final callbacks = <AudioTranscriptReview>[];
        h.provider.startGate = Completer<void>();
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        // When pending start is cancelled, another recording runs, and import fails then retries.
        await _tap(tester, 'audio-capture-record');
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('audio-capture-stop')),
              )
              .onPressed,
          isNull,
        );
        await _tap(tester, 'audio-capture-cancel');
        await _pumpUntil(tester, () => !h.controller.busy);
        expect(callbacks, isEmpty);
        await _tap(tester, 'audio-capture-record');
        await _pumpUntil(tester, () => h.controller.recordingStarted);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Recording: 1 seconds'), findsOneWidget);
        h.store.saveGate = Completer<void>();
        final failure = const FileSystemException('actual storage failure');
        h.store.importError = failure;
        await _tap(tester, 'audio-capture-stop');
        await _pumpUntil(tester, () => h.store.saveEntered.isCompleted);
        expect(find.text('Saving audio'), findsOneWidget);
        expect(callbacks, isEmpty);
        h.store.saveGate!.complete();
        await _pumpUntil(tester, () => !h.controller.busy);
        expect(find.text('Audio not saved'), findsOneWidget);
        expect(find.textContaining('actual storage failure'), findsOneWidget);
        h.store.importError = null;
        await _tap(tester, 'audio-capture-retry-save');
        await _pumpUntil(tester, () => callbacks.length == 1);
        // Then only durable retry emits success and exact capture bytes were retained without recapture.
        expect(h.provider.recordingCancels, 1);
        expect(h.provider.starts, 2);
        expect(h.provider.stops, 1);
        expect(h.store.imports, 2);
        expect(callbacks.single.original.durationMilliseconds, 1000);
        expect(h.facade.pendingOriginal, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'W3 unsupported runtime actual readiness explicit preparation and errors',
      (tester) async {
        // Given an unsupported runtime and initially inert UI.
        h.provider.supported = false;
        await tester.pumpWidget(_root(h.controller));
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('audio-capture-record')),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Audio recording unavailable'), findsOneWidget);
        h.provider.supported = true;
        await tester.runAsync(h.capture);
        final callbacks = <AudioTranscriptReview>[];
        h.provider.ready = AudioProviderState.unavailable;
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        // When unavailable/downloading/downloadable readiness is checked and only explicit intent prepares.
        await _tap(tester, 'audio-capture-check-transcription');
        await _pumpUntil(
          tester,
          () =>
              h.controller.availability?.state ==
              AudioProviderState.unavailable,
        );
        expect(find.text('actual readiness reason'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('transcript-review-text')),
          'manual while unavailable',
        );
        await tester.pump();
        h.provider.ready = AudioProviderState.downloading;
        await _tap(tester, 'audio-capture-check-transcription');
        await _pumpUntil(
          tester,
          () =>
              h.controller.availability?.state ==
              AudioProviderState.downloading,
        );
        expect(
          find.byKey(const ValueKey('audio-capture-prepare-model')),
          findsNothing,
        );
        h.provider.ready = AudioProviderState.downloadable;
        await _tap(tester, 'audio-capture-check-transcription');
        await _pumpUntil(tester, () => h.controller.canPrepareTranscription);
        expect(h.provider.prepares, 0);
        h.provider.prepareGate = Completer<void>();
        await _tap(tester, 'audio-capture-prepare-model');
        expect(
          find.byKey(const ValueKey('audio-capture-cancel-transcription')),
          findsOneWidget,
        );
        await _tap(tester, 'audio-capture-cancel-transcription');
        await _pumpUntil(tester, () => !h.controller.busy);
        h.store.readError = const FileSystemException(
          'actual saved input error',
        );
        await _tap(tester, 'audio-capture-transcribe');
        await _pumpUntil(
          tester,
          () => h.controller.error != null && !h.controller.busy,
        );
        // Then model work was explicit, failure truthful and manual editor intent survives without review success.
        expect(h.provider.prepares, 1);
        expect(h.provider.transcriptionCancels, 1);
        expect(h.controller.draftText, 'manual while unavailable');
        expect(h.controller.hasUnsavedText, isTrue);
        expect(callbacks, isEmpty);
        expect(find.textContaining('actual saved input error'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final replacement in [false, true]) {
      testWidgets(
        'W4 held save ${replacement ? 'controller replacement' : 'unmount'} suppresses callback and retains result',
        (tester) async {
          // Given a recording whose durable stop is held and an owner callback.
          final callbacks = <AudioTranscriptReview>[];
          await tester.pumpWidget(
            _root(h.controller, onChanged: callbacks.add),
          );
          await _tap(tester, 'audio-capture-record');
          await _pumpUntil(tester, () => h.controller.recordingStarted);
          h.store.saveGate = Completer<void>();
          await _tap(tester, 'audio-capture-stop');
          await _pumpUntil(tester, () => h.store.saveEntered.isCompleted);
          final old = h.controller;
          final other = AudioCaptureController(facade: h.facade);
          // When presentation unmounts or borrows a new controller before durable completion.
          await tester.pumpWidget(
            replacement
                ? _root(other, onChanged: callbacks.add)
                : const SizedBox.shrink(),
          );
          h.store.saveGate!.complete();
          await _pumpUntil(tester, () => old.review != null && !old.busy);
          // Then no callback reaches either UI owner and the original controller retains the actual durable result.
          expect(callbacks, isEmpty);
          expect(old.review!.original.durationMilliseconds, 1000);
          expect(old.isDetached, isFalse);
          expect(other.review, isNull);
          expect(h.provider.disposals, 0);
          expect(h.store.imports, 1);
          expect(h.facade.state, AudioCaptureState.idle);
          await tester.pumpWidget(const SizedBox.shrink());
          other.dispose();
        },
      );
    }

    testWidgets(
      'W5 narrow inherited application text scaling keeps controls reachable and details folded',
      (tester) async {
        // Given a 320px viewport, inherited application scaling and OS text scale two.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1600);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _Settings();
        final view = SettingsView.fromService(service: settings);
        await tester.pumpWidget(_root(h.controller, settings: view, scale: 2));
        // When the scaled primary record/check controls are used inside the caller scrollable.
        await _tap(tester, 'audio-capture-check-transcription');
        await _pumpUntil(tester, () => h.controller.availability != null);
        await _tap(tester, 'audio-capture-record');
        await _pumpUntil(tester, () => h.controller.recordingStarted);
        await _tap(tester, 'audio-capture-cancel');
        await _pumpUntil(tester, () => !h.controller.busy);
        // Then actual inherited scale remains two, no overflow occurs, and diagnostics remain collapsed.
        expect(
          MediaQuery.textScalerOf(tester.element(find.text('Audio'))).scale(16),
          32,
        );
        expect(find.textContaining('Provider:'), findsNothing);
        expect(
          find.byKey(const ValueKey('audio-capture-details')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(h.provider.prepares, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        view.dispose();
        settings.dispose();
      },
    );
  });
}

final _time = DateTime.utc(2026, 10, 9);
Uint8List _wave() => PcmWaveAudio.encode(
  Uint8List.fromList(List.generate(32000, (index) => index % 256)),
);

final class _Harness {
  late Directory directory;
  late _Store store;
  final provider = _Provider();
  late AudioCaptureService service;
  late AudioCaptureFacade facade;
  late AudioCaptureController controller;

  Future<void> open() async {
    // Given a fresh test-owned directory and inert controlled provider.
    directory = await Directory.systemTemp.createTemp('tfaf-audio-');
    // When real FileCaptureStore, Core service and borrowed interaction are composed.
    store = _Store(FileCaptureStore(directory.path));
    service = AudioCaptureService(
      runtime: provider,
      transcription: provider,
      store: store,
      now: () => _time,
    );
    facade = AudioCaptureFacade(service: service);
    controller = AudioCaptureController(facade: facade, now: () => _time);
    // Then construction has no capture, inference, preparation or durable-write effects.
    expect(
      provider.starts +
          provider.probes +
          provider.prepares +
          provider.inputs.length,
      0,
    );
    expect(store.imports + store.documentWrites, 0);
    expect(await directory.exists(), isTrue);
  }

  Future<void> close() async {
    // Given the test-owned controller/service and directory with settled gates.
    // When composition explicitly detaches, disposes Core and removes its files.
    try {
      await controller.detach();
    } catch (error) {
      expect(error, same(controller.cleanupError));
    }
    controller.dispose();
    await service.dispose();
    await directory.delete(recursive: true);
    // Then provider ownership was never transferred and the fixture is terminal.
    expect(provider.disposals, 0);
    expect(await directory.exists(), isFalse);
    expect(controller.isDisposed, isTrue);
  }

  Future<AudioTranscriptReview> capture() async {
    // Given an idle empty interaction and exact one-second controlled WAV.
    expect(controller.review, isNull);
    // When capture starts and explicitly stops through real durable import.
    await controller.startRecording();
    final review = await controller.stopRecording();
    // Then exact bytes and original provenance exist before review success.
    expect(
      await store.delegate.readMaterial(review.original.material),
      orderedEquals(_wave()),
    );
    expect(controller.review, same(review));
    expect(review.original.durationMilliseconds, 1000);
    return review;
  }
}

final class _Provider
    implements AudioRuntimeProvider, AudioTranscriptionProvider {
  bool supported = true;
  AudioProviderState ready = AudioProviderState.available;
  String text = ' 日本語 \n';
  Object? startError;
  Object? asrError;
  Object? cancelError;
  StackTrace? cancelStack;
  bool releaseOnCancel = true;
  Completer<void>? startGate;
  Completer<void>? playGate;
  Completer<void>? probeGate;
  Completer<void>? prepareGate;
  Completer<void>? asrGate;
  Completer<void> startEntered = Completer<void>();
  Completer<void> playEntered = Completer<void>();
  Completer<void> probeEntered = Completer<void>();
  Completer<void> prepareEntered = Completer<void>();
  Completer<void> asrEntered = Completer<void>();
  final inputs = <AudioTranscriptionInput>[];
  final played = <Uint8List>[];
  final locales = <String>[];
  int starts = 0;
  int stops = 0;
  int recordingCancels = 0;
  int playStops = 0;
  int probes = 0;
  int prepares = 0;
  int transcriptionCancels = 0;
  int disposals = 0;
  AudioRecordingConfiguration? receivedConfiguration;
  @override
  String get id => 'controlled-provider';
  @override
  bool get isSupported => supported;

  @override
  Future<void> startRecording(AudioRecordingConfiguration configuration) async {
    // Given an explicit caller-owned duration configuration.
    expect(configuration.maxDurationSeconds, inInclusiveRange(1, 120));
    // When controlled start is counted, held or actually denied.
    starts++;
    receivedConfiguration = configuration;
    if (!startEntered.isCompleted) startEntered.complete();
    if (startGate != null) await startGate!.future;
    if (startError != null) throw startError!;
    // Then successful permission/capture start preserves the exact configuration instance.
    expect(receivedConfiguration, same(configuration));
  }

  @override
  Future<CapturedAudio> stopRecording() async {
    // Given a previously explicit microphone start.
    expect(starts, greaterThan(0));
    // When explicit stop returns canonical original bytes.
    stops++;
    final captured = CapturedAudio(
      bytes: _wave(),
      capturedAt: _time,
      originalName: 'source.wav',
    );
    // Then stop returns the exact WAV and timestamp without a second start.
    expect(captured.bytes, orderedEquals(_wave()));
    expect(captured.capturedAt, _time);
    return captured;
  }

  @override
  Future<void> cancelRecording() async {
    // Given owned unsaved recording or a pending permission start.
    // When explicit cleanup unblocks that start and records cancellation.
    recordingCancels++;
    if (startGate != null && !startGate!.isCompleted) startGate!.complete();
    // Then the caller can observe cleanup and no new capture is launched.
    expect(recordingCancels, greaterThan(0));
    expect(startGate == null || startGate!.isCompleted, isTrue);
  }

  @override
  Future<void> play(Uint8List bytes) async {
    // Given exact saved original bytes delivered by real Core IO.
    expect(bytes, orderedEquals(_wave()));
    // When controlled playback snapshots input and optionally holds completion.
    played.add(Uint8List.fromList(bytes));
    if (!playEntered.isCompleted) playEntered.complete();
    if (playGate != null) await playGate!.future;
    // Then playback retains exact supplied bytes without import/capture work.
    expect(played.last, orderedEquals(bytes));
  }

  @override
  Future<void> stopPlayback() async {
    // Given an owned playback cleanup request, possibly during its original read.
    // When explicit cleanup unblocks pending runtime playback.
    playStops++;
    if (playGate != null && !playGate!.isCompleted) playGate!.complete();
    // Then cleanup is observable and held playback can settle.
    expect(playStops, greaterThan(0));
    expect(playGate == null || playGate!.isCompleted, isTrue);
  }

  @override
  Future<AudioProviderAvailability> availability(String locale) async {
    // Given actual controlled readiness for the exact requested locale.
    // When explicit readiness work is counted and optionally held.
    probes++;
    locales.add(locale);
    if (!probeEntered.isCompleted) probeEntered.complete();
    if (probeGate != null) await probeGate!.future;
    final value = AudioProviderAvailability(
      providerId: id,
      locale: locale,
      state: ready,
      reason: ready == AudioProviderState.available
          ? null
          : 'actual readiness reason',
    );
    // Then readiness retains exact provider/locale and cannot synthesize inference text.
    expect(value.providerId, id);
    expect(value.locale, locale);
    expect(inputs.length, lessThanOrEqualTo(probes));
    return value;
  }

  @override
  Future<AudioProviderAvailability> prepare(String locale) async {
    // Given explicit model preparation and its exact locale.
    // When preparation is counted and a controlled delay completes.
    prepares++;
    if (!prepareEntered.isCompleted) prepareEntered.complete();
    if (prepareGate != null) await prepareGate!.future;
    ready = AudioProviderState.available;
    final result = await availability(locale);
    // Then only explicit preparation establishes available model state.
    expect(prepares, greaterThan(0));
    expect(result.state, AudioProviderState.available);
    return result;
  }

  @override
  Future<AudioProviderTranscript> transcribe(
    AudioTranscriptionInput input,
  ) async {
    // Given exact saved input with immutable original provenance.
    expect(input.bytes, orderedEquals(_wave()));
    // When recognition retains input and optionally waits or reports an actual failure.
    inputs.add(input);
    if (!asrEntered.isCompleted) asrEntered.complete();
    if (asrGate != null) await asrGate!.future;
    if (asrError != null) throw asrError!;
    final result = AudioProviderTranscript(text: text);
    // Then exact Unicode/whitespace reaches the report unchanged.
    expect(result.text, text);
    expect(inputs.last, same(input));
    return result;
  }

  @override
  Future<void> cancel() async {
    // Given owned readiness/preparation/ASR and optional real cleanup failure.
    // When cancellation is counted and controlled native gates are released as configured.
    transcriptionCancels++;
    if (releaseOnCancel) {
      for (final gate in [probeGate, prepareGate, asrGate]) {
        if (gate != null && !gate.isCompleted) gate.complete();
      }
    }
    if (cancelError != null) {
      Error.throwWithStackTrace(
        cancelError!,
        cancelStack ?? StackTrace.current,
      );
    }
    // Then cleanup is observable and release settles all matching controlled provider gates.
    expect(transcriptionCancels, greaterThan(0));
    if (releaseOnCancel) {
      expect(
        [
          probeGate,
          prepareGate,
          asrGate,
        ].every((gate) => gate == null || gate.isCompleted),
        isTrue,
      );
    }
  }

  @override
  Future<void> dispose() async {
    // Given explicit provider ownership by a composition owner.
    // When its one terminal disposal is counted.
    disposals++;
    // Then shared runtime/transcriber ownership disposes the same instance once.
    expect(disposals, 1);
  }
}

final class _Store implements LocalCaptureStore {
  _Store(this.delegate);
  final LocalCaptureStore delegate;
  Object? importError;
  Object? readError;
  Completer<void>? saveGate;
  Completer<void>? readGate;
  final saveEntered = Completer<void>();
  final readEntered = Completer<void>();
  int imports = 0;
  int documentWrites = 0;
  @override
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes,
    required String mediaType,
    required DateTime capturedAt,
    String? originalName,
  }) async {
    // Given exact WAV and existing actual FileCaptureStore.
    final snapshot = Uint8List.fromList(bytes);
    expect(snapshot, orderedEquals(_wave()));
    // When import is counted, optionally held/failed and durably delegated.
    imports++;
    if (!saveEntered.isCompleted) saveEntered.complete();
    if (saveGate != null) await saveGate!.future;
    if (importError != null) throw importError!;
    final reference = await delegate.saveMaterial(
      bytes: snapshot,
      mediaType: mediaType,
      capturedAt: capturedAt,
      originalName: originalName,
    );
    // Then returned provenance refers to exact durable bytes before publication.
    expect(await delegate.readMaterial(reference), orderedEquals(snapshot));
    expect(reference.capturedAt, capturedAt);
    return reference;
  }

  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) async {
    // Given one unchanged saved original and optional actual read failure.
    // When IO is optionally held and delegated without an import.
    if (!readEntered.isCompleted) readEntered.complete();
    if (readGate != null) await readGate!.future;
    if (readError != null) throw readError!;
    final bytes = await delegate.readMaterial(reference);
    // Then real original bytes satisfy the immutable reference length.
    expect(bytes.length, reference.byteLength);
    return bytes;
  }

  @override
  Future<void> saveDocument(
    String collection,
    String id,
    Map<String, Object?> document,
  ) async {
    // Given an owner's explicit domain-independent opaque document Save.
    // When the existing store durably writes the exact document.
    documentWrites++;
    await delegate.saveDocument(collection, id, document);
    // Then actual disk roundtrip retains the complete caller payload.
    expect(await delegate.readDocument(collection, id), document);
  }

  @override
  Future<Map<String, Object?>?> readDocument(
    String collection,
    String id,
  ) async {
    // Given a caller-selected logical document identity.
    // When the existing store reads that opaque document.
    final value = await delegate.readDocument(collection, id);
    // Then absence is null and an existing document preserves string JSON keys.
    expect(value, anyOf(isNull, isA<Map<String, Object?>>()));
    return value;
  }

  @override
  Future<List<String>> listDocumentIds(String collection) async {
    // Given a caller-selected opaque collection.
    // When the existing store lists durable identities.
    final ids = await delegate.listDocumentIds(collection);
    // Then IDs are sorted and no fixture-specific storage contract is introduced.
    expect(ids, orderedEquals(List<String>.of(ids)..sort()));
    return ids;
  }
}

Widget _root(
  AudioCaptureController controller, {
  ValueChanged<AudioTranscriptReview>? onChanged,
  AudioCaptureController? transcriptController,
  SettingsView? settings,
  double scale = 1,
}) => MaterialApp(
  builder: (context, child) {
    final content = MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
    return settings == null
        ? content
        : MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: ApplicationTextScaling(view: settings, child: child),
          );
  },
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            AudioCapturePanel(
              key: const ValueKey('audio-panel'),
              controller: controller,
              onReviewChanged: onChanged,
            ),
            TranscriptReviewPanel(
              key: const ValueKey('transcript-panel'),
              controller: transcriptController ?? controller,
              onReviewChanged: onChanged,
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String key) async {
  // Given a visible keyed actual primary control in the mounted shared panels.
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  // When explicit user intent taps that enabled button and rebuilds presentation.
  expect(tester.widget<ElevatedButton>(finder).onPressed, isNotNull);
  if (key == 'audio-capture-record' || key == 'audio-capture-cancel') {
    await tester.tap(finder);
  } else {
    await tester.runAsync(() => tester.tap(finder));
  }
  await tester.pump();
  // Then the real widget action completes its synchronous dispatch without a UI exception.
  expect(tester.takeException(), isNull);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  // Given a finite awaited observable state change whose IO uses real FileCaptureStore.
  // When bounded real-event turns and Flutter frames let the actual operation settle.
  for (var turn = 0; turn < 80 && !condition(); turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  // Then the selected operation actually reached its required observable state.
  expect(condition(), isTrue);
  expect(tester.takeException(), isNull);
}

final class _Settings extends ChangeNotifier implements SettingsService {
  @override
  final SettingsRegistry registry = CommonSettings.registry();
  @override
  SettingsSnapshot get snapshot => SettingsSnapshot(registry: registry);
  @override
  Future<void> load() =>
      Future<void>.error(StateError('Unexpected settings IO'));
  @override
  Future<void> retryLoad() => load();
  @override
  Future<void> retrySave() => load();
  @override
  void setValue(String id, Object value) =>
      throw StateError('Unexpected settings edit');
  @override
  void resetCommon() => throw StateError('Unexpected settings reset');
}
