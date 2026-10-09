import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  group('shared transcript review panel', () {
    late _Harness h;
    setUp(() async {
      // Given fresh controlled providers and real local storage.
      h = _Harness();
      // When the inert borrowed composition opens.
      await h.open();
      // Then no provider/model/original work has started.
      expect(h.provider.starts + h.provider.probes + h.store.imports, 0);
    });
    tearDown(() async {
      // Given explicitly owned settled test resources.
      // When the test fixture closes its composition and exact directory.
      await h.close();
      // Then borrowed provider lifetime is preserved.
      expect(h.provider.disposals, 0);
    });

    testWidgets(
      'T1 exact visible Unicode whitespace and intentional empty clear need explicit revision',
      (tester) async {
        // Given a saved original and a clean editor with no transcript history.
        await tester.runAsync(h.capture);
        final callbacks = <AudioTranscriptReview>[];
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        final field = find.byKey(const ValueKey('transcript-review-text'));
        // When exact Unicode/whitespace is typed, explicitly recorded, then intentionally cleared.
        await tester.enterText(field, ' 日本語📘\n  exact ');
        await tester.pump();
        expect(find.text('Unrecorded changes'), findsOneWidget);
        expect(callbacks, isEmpty);
        expect(h.controller.review!.revisions, isEmpty);
        await _tap(tester, 'transcript-review-record-correction');
        expect(callbacks.single.currentText, ' 日本語📘\n  exact ');
        await tester.enterText(field, '');
        await tester.pump();
        expect(find.text('Unrecorded changes'), findsOneWidget);
        await _tap(tester, 'transcript-review-record-correction');
        // Then exact revisions include the empty clear and no disk-save claim/write is fabricated.
        expect(callbacks.length, 2);
        expect(
          h.controller.review!.revisions.map((revision) => revision.text),
          [' 日本語📘\n  exact ', ''],
        );
        expect(
          h.controller.review!.revisions.every(
            (revision) => revision.source == TranscriptRevisionSource.manual,
          ),
          isTrue,
        );
        expect(find.text('Unrecorded changes'), findsNothing);
        expect(h.store.documentWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'T2 held ASR notifications preserve exact draft caret and concurrent manual history',
      (tester) async {
        // Given a saved original and held recognition through the actual controller/Core boundary.
        await tester.runAsync(h.capture);
        await tester.pumpWidget(_root(h.controller));
        h.provider.asrGate = Completer<void>();
        late Future<AudioTranscriptReview> recognizing;
        await tester.runAsync(() async {
          // Given a mounted saved-input editor and held provider inference.
          // When recognition starts in the real IO event zone.
          recognizing = h.controller.transcribe();
          // Then the reserved interaction is busy before typing can overlap it.
          expect(h.controller.busy, isTrue);
        });
        await _pumpUntil(tester, () => h.provider.asrEntered.isCompleted);
        final field = find.byKey(const ValueKey('transcript-review-text'));
        // When typing during ASR establishes exact dirty text and a nonterminal caret.
        await tester.enterText(field, ' edited 日本語 ');
        final text = tester.widget<TextField>(field).controller!;
        text.selection = const TextSelection.collapsed(offset: 3);
        text.value = text.value.copyWith(
          composing: const TextRange(start: 1, end: 3),
        );
        final value = text.value;
        await tester.pumpWidget(_root(h.controller));
        h.controller.setDraftText(h.controller.draftText);
        await tester.pump();
        // Then unchanged-string synchronization preserves caret/composition and creates no manual revision.
        expect(text.value, value);
        expect(h.controller.review!.revisions, isEmpty);
        h.provider.asrGate!.complete();
        await tester.runAsync(() => recognizing);
        await tester.pump();
        expect(text.value, value);
        expect(h.controller.hasUnsavedText, isTrue);
        expect(h.controller.review!.revisions.length, 1);
        // When another held ASR overlaps an explicitly committed correction.
        h.provider.asrGate = Completer<void>();
        h.provider.asrEntered = Completer<void>();
        late Future<AudioTranscriptReview> repeated;
        await tester.runAsync(() async {
          // Given a saved original with an existing generated revision.
          // When repeated recognition launches actual original reads in the real event zone.
          repeated = h.controller.transcribe();
          // Then recognition remains busy while explicit manual correction is allowed.
          expect(h.controller.busy, isTrue);
          expect(h.controller.canRecordCorrection, isTrue);
        });
        await _pumpUntil(tester, () => h.provider.asrEntered.isCompleted);
        await _tap(tester, 'transcript-review-record-correction');
        final manual = h.controller.review!;
        h.provider.asrGate!.complete();
        await tester.runAsync(() => repeated);
        await tester.pump();
        // Then the result appends to latest manual history without overwriting the exact buffer.
        AudioTranscriptReview.requireRetainedPrefix(
          manual,
          h.controller.review!,
        );
        expect(h.controller.review!.currentText, ' edited 日本語 ');
        expect(h.controller.review!.revisions.length, 2);
        expect(text.text, ' edited 日本語 ');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'T3 latest proposal separate explicit selection and folded older report history',
      (tester) async {
        // Given first recognition and an explicitly recorded manual correction.
        await tester.runAsync(h.capture);
        final first = await tester.runAsync(h.controller.transcribe);
        h.controller.setDraftText('manual');
        h.controller.recordCorrection();
        h.provider.text = 'second proposal';
        final second = await tester.runAsync(h.controller.transcribe);
        final callbacks = <AudioTranscriptReview>[];
        await tester.pumpWidget(_root(h.controller, onChanged: callbacks.add));
        final field = find.byKey(const ValueKey('transcript-review-text'));
        // Then the latest proposal is separate and older history remains initially folded.
        expect(tester.widget<TextField>(field).controller!.text, 'manual');
        expect(find.text('Recognition proposal'), findsOneWidget);
        expect(find.text('second proposal'), findsOneWidget);
        expect(
          find.byKey(
            ValueKey('transcript-review-use-${first!.reports.single.id}'),
          ),
          findsNothing,
        );
        // When explicit latest selection and then a folded older-report selection are requested.
        await _tap(tester, 'transcript-review-use-proposal');
        final latestSelected = h.controller.review!;
        final history = find.byKey(const ValueKey('transcript-review-history'));
        await tester.ensureVisible(history);
        await tester.tap(find.text('Transcript history'));
        await tester.pumpAndSettle();
        await _tap(tester, 'transcript-review-use-${first.reports.single.id}');
        // Then exact ordered reports/revisions and selected source links are retained.
        expect(callbacks.length, 2);
        expect(latestSelected.currentText, 'second proposal');
        expect(latestSelected.revisions.last.reportId, second!.reports.last.id);
        expect(h.controller.review!.currentText, ' 日本語 \n');
        expect(
          h.controller.review!.revisions.last.reportId,
          first.reports.single.id,
        );
        AudioTranscriptReview.requireRetainedPrefix(
          latestSelected,
          h.controller.review!,
        );
        expect(
          h.controller.review!.reports.map((report) => report.id),
          second.reports.map((report) => report.id),
        );
        expect(h.store.documentWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final status in [
      AudioTranscriptStatus.failed,
      AudioTranscriptStatus.unavailable,
      AudioTranscriptStatus.cancelled,
    ]) {
      testWidgets(
        'T4 ${status.name} report preserves editable text and older successful proposal',
        (tester) async {
          // Given one exact successful report, manual text and a real provider nonsuccess outcome.
          await tester.runAsync(h.capture);
          final success = await tester.runAsync(h.controller.transcribe);
          h.controller.setDraftText(' retained manual ');
          h.controller.recordCorrection();
          if (status == AudioTranscriptStatus.unavailable) {
            h.provider.ready = AudioProviderState.unavailable;
          } else {
            h.provider.asrError = AudioProviderException(
              status == AudioTranscriptStatus.cancelled
                  ? 'cancelled'
                  : 'actualFailure',
              'actual ${status.name}',
            );
          }
          await tester.runAsync(h.controller.transcribe);
          await tester.pumpWidget(_root(h.controller));
          // When actual attempt diagnostics are displayed and older proposals are explicitly expanded.
          expect(find.text('Recognition: ${status.name}'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('transcript-review-use-proposal')),
            findsNothing,
          );
          final field = find.byKey(const ValueKey('transcript-review-text'));
          await tester.enterText(field, ' still editable ');
          await tester.pump();
          await tester.ensureVisible(find.text('Transcript history'));
          await tester.tap(find.text('Transcript history'));
          await tester.pumpAndSettle();
          // Then failure supplies no fake proposal and prior exact success remains selectable in history.
          expect(h.controller.draftText, ' still editable ');
          expect(h.controller.hasUnsavedText, isTrue);
          expect(h.controller.review!.reports.last.status, status);
          expect(h.controller.review!.reports.last.text, isNull);
          expect(
            find.byKey(
              ValueKey('transcript-review-use-${success!.reports.single.id}'),
            ),
            findsOneWidget,
          );
          expect(h.controller.review!.currentText, ' retained manual ');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'T5 controller replacement and unmount rebind only local editor listeners',
      (tester) async {
        // Given a dirty first controller and a second borrowed controller with separate draft intent.
        final saved = await tester.runAsync(h.capture);
        final old = h.controller;
        old.setDraftText('old draft');
        final other = AudioCaptureController(
          facade: h.facade,
          initialReview: saved,
        );
        other.setDraftText('new draft');
        var oldCallbacks = 0;
        var newCallbacks = 0;
        void oldCallback(AudioTranscriptReview review) {
          oldCallbacks++;
        }

        void newCallback(AudioTranscriptReview review) {
          newCallbacks++;
        }

        await tester.pumpWidget(_root(old, onChanged: oldCallback));
        final field = find.byKey(const ValueKey('transcript-review-text'));
        final text = tester.widget<TextField>(field).controller!;
        // When the same widget borrows a new controller and the former owner changes afterward.
        await tester.pumpWidget(_root(other, onChanged: newCallback));
        old.setDraftText('old later');
        await tester.pump();
        expect(tester.widget<TextField>(field).controller, same(text));
        expect(text.text, 'new draft');
        await _tap(tester, 'transcript-review-record-correction');
        await tester.pumpWidget(const SizedBox.shrink());
        other.setDraftText('after unmount');
        old.setDraftText('old after unmount');
        // Then only the current UI owner receives one explicit result, both controllers stay usable.
        expect(oldCallbacks, 0);
        expect(newCallbacks, 1);
        expect(old.review!.revisions, isEmpty);
        expect(other.review!.currentText, 'new draft');
        expect(other.isDisposed, isFalse);
        expect(old.isDisposed, isFalse);
        expect(h.provider.disposals, 0);
        other.dispose();
      },
    );

    testWidgets(
      'T6 narrow scaled editor buttons folded history and inert no-original state',
      (tester) async {
        // Given a narrow 320px app with OS scale two and no saved original.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1600);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _Settings();
        final view = SettingsView.fromService(service: settings);
        await tester.pumpWidget(_root(h.controller, settings: view, scale: 2));
        expect(find.text('Record audio first'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('transcript-review-text')),
          findsNothing,
        );
        expect(h.provider.starts + h.provider.probes, 0);
        await tester.runAsync(h.capture);
        await tester.pumpWidget(_root(h.controller, settings: view, scale: 2));
        final field = find.byKey(const ValueKey('transcript-review-text'));
        // When exact unsaved text is entered and scaled primary correction is explicitly used.
        await tester.ensureVisible(field);
        await tester.enterText(field, ' unsaved 日本語 ');
        await tester.pump();
        expect(find.text('Unrecorded changes'), findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(field)).scale(16), 32);
        await _tap(tester, 'transcript-review-record-correction');
        // Then controls/history remain reachable, history folded and no implicit provider or disk save occurs.
        expect(h.controller.review!.currentText, ' unsaved 日本語 ');
        expect(find.textContaining('manual at'), findsNothing);
        expect(
          find.byKey(const ValueKey('transcript-review-history')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(
          h.provider.probes + h.provider.inputs.length + h.provider.prepares,
          0,
        );
        expect(h.store.documentWrites, 0);
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
