import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('borrowed audio facade', () {
    late _Harness h;
    setUp(() async {
      // Given a fresh inert real-storage fixture.
      h = _Harness();
      // When composition opens the public facade.
      await h.open();
      // Then Core remains idle without construction IO.
      expect(h.facade.state, AudioCaptureState.idle);
    });
    tearDown(() async {
      // Given the fixture's explicitly owned controller/service/directory.
      // When composition completes cleanup.
      await h.close();
      // Then borrowed provider disposal remains zero.
      expect(h.provider.disposals, 0);
    });

    test('F1 construction default store locale configuration and explicit ownership', () async {
      // Given an inert borrowed facade and exact supplied storage.
      expect(h.facade.ownsService, isFalse);
      final configuration = AudioRecordingConfiguration(maxDurationSeconds: 3);
      // When explicit forwarding and default factory composition occur.
      await h.facade.dispose();
      await h.facade.startRecording(configuration: configuration);
      expect(h.facade.state, AudioCaptureState.recording);
      await h.facade.cancelRecording();
      final ready = await h.facade.availability(locale: 'en-US');
      final defaultFacade = await openDefaultAudioCaptureFacade(store: h.store);
      await defaultFacade.dispose();
      await defaultFacade.dispose();
      // Then construction is inert, forwarding exact and only default ownership is terminal.
      expect(h.provider.receivedConfiguration, same(configuration));
      expect(ready.locale, 'en-US');
      expect(h.provider.locales, ['en-US']);
      expect(h.facade.isSupported, isTrue);
      expect(h.facade.state, AudioCaptureState.idle);
      expect(defaultFacade.ownsService, isTrue);
      expect(defaultFacade.state, AudioCaptureState.disposed);
      expect(h.store.imports + h.store.documentWrites, 0);
      final ownedService = AudioCaptureService(
        runtime: h.provider,
        transcription: h.provider,
        store: h.store,
      );
      final owned = AudioCaptureFacade(
        service: ownedService,
        ownsService: true,
      );
      final first = owned.dispose();
      final second = owned.dispose();
      await first;
      await second;
      expect(first, same(second));
      expect(owned.state, AudioCaptureState.disposed);
      expect(h.provider.disposals, 0);
    });

    test('F1 default factory keeps exact caller store through real adapter forwarding', () async {
      // Given the actual default adapter with explicit Android target and a controlled native channel.
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('org.textus.flutter.core/audio');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        // Given an actual encoded default-adapter request with a safe session identity.
        final arguments = call.arguments as Map;
        expect(
          arguments['sessionId'],
          matches(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$'),
        );
        // When this fixture records an explicit native recording/stop/dispose request.
        calls.add(call.method);
        Object? result;
        if (call.method == 'stopRecording') {
          result = {
            'bytes': _wave(),
            'capturedAt': _time.toIso8601String(),
            'originalName': 'source.wav',
          };
        } else if (call.method != 'startRecording' &&
            call.method != 'dispose') {
          throw StateError('Unexpected implicit native work: ${call.method}');
        }
        // Then only explicitly admitted methods cross the native boundary.
        expect(calls.last, call.method);
        expect(arguments.keys.toSet(), {
          'sessionId',
          if (call.method == 'startRecording') 'maxDurationSeconds',
        });
        return result;
      });
      AudioCaptureFacade? defaults;
      try {
        // When the inert default factory is opened with the exact store and explicit recording saves.
        defaults = await openDefaultAudioCaptureFacade(store: h.store);
        expect(calls, isEmpty);
        expect(h.store.imports, 0);
        await defaults.startRecording();
        final original = await defaults.stopRecording();
        await defaults.dispose();
        await defaults.dispose();
        // Then only that caller store receives exact durable bytes, with no factory permission/probe.
        expect(h.store.imports, 1);
        expect(
          await h.store.delegate.readMaterial(original.material),
          orderedEquals(_wave()),
        );
        expect(calls, ['startRecording', 'stopRecording', 'dispose']);
        expect(defaults.state, AudioCaptureState.disposed);
        expect(h.store.documentWrites, 0);
      } finally {
        await defaults?.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    test('F2 exact durable original survives restart and failed import retry', () async {
      // Given exact canonical runtime bytes and a real storage failure object.
      final failure = const FileSystemException('actual import error');
      h.store.importError = failure;
      await h.facade.startRecording();
      // When stop fails, retained bytes are retried without another acquisition.
      await expectLater(h.facade.stopRecording(), throwsA(same(failure)));
      final pending = h.facade.pendingOriginal!;
      final detached = pending.bytes;
      detached[44] = 255;
      h.store.importError = null;
      final original = await h.facade.retryPendingOriginal();
      final reopened = FileCaptureStore(h.directory.path);
      // Then exact immutable WAV is durable and retry preserves capture/provenance.
      expect(
        await reopened.readMaterial(original.material),
        orderedEquals(_wave()),
      );
      expect(detached[44], 255);
      expect(pending.bytes, orderedEquals(_wave()));
      expect(h.facade.pendingOriginal, isNull);
      expect(h.provider.starts, 1);
      expect(h.provider.stops, 1);
      expect(h.store.imports, 2);
      expect(h.store.documentWrites, 0);
    });

    test('F3 saved playback ASR probe preparation and cancellation forward exactly', () async {
      // Given one saved original through the real Core service.
      final original = (await h.capture()).original;
      h.provider.playGate = Completer<void>();
      // When playback and held ASR are explicitly interrupted, then readiness is prepared.
      final playback = h.facade.playOriginal(original);
      final playRejected = expectLater(playback, throwsStateError);
      await h.provider.playEntered.future;
      expect(() => h.facade.availability(), throwsStateError);
      await h.facade.stopPlayback();
      await playRejected;
      h.provider.asrGate = Completer<void>();
      final asr = h.facade.transcribe(original, locale: 'en-US');
      final asrRejected = expectLater(asr, throwsStateError);
      await h.provider.asrEntered.future;
      await h.facade.cancelTranscription();
      await asrRejected;
      h.provider.ready = AudioProviderState.downloadable;
      final before = await h.facade.availability(locale: 'en-US');
      final prepared = await h.facade.prepareTranscription(locale: 'en-US');
      final report = await h.facade.transcribe(original, locale: 'en-US');
      // Then exact saved input/provenance and all actual provider effects are retained.
      expect(before.state, AudioProviderState.downloadable);
      expect(prepared.state, AudioProviderState.available);
      expect(report.original, same(original));
      expect(report.locale, 'en-US');
      expect(report.text, ' 日本語 \n');
      expect(
        h.provider.inputs.every(
          (input) =>
              identical(input.original, original) && input.locale == 'en-US',
        ),
        isTrue,
      );
      expect(h.provider.played.single, orderedEquals(_wave()));
      expect(h.provider.transcriptionCancels, 1);
      expect(h.provider.playStops, 1);
      expect(h.provider.prepares, 1);
      expect(h.store.imports, 1);
      expect(h.store.documentWrites, 0);
    });
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
