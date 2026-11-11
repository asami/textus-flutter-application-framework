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

    for (final action in [
      'record',
      'check-transcription',
      'stop',
      'cancel',
      'retry-save',
      'play',
      'stop-playback',
      'transcribe',
      'prepare-model',
      'cancel-transcription',
    ]) {
      testWidgets(
        'G2 $action reevaluates live admission before any controller effect',
        (tester) async {
          // Given the exact controller state exposing this admitted production action.
          Future<void>? playback;
          Future<void>? recognition;
          if (action == 'stop' || action == 'cancel') {
            await tester.runAsync(h.controller.startRecording);
          } else if (action == 'retry-save') {
            h.store.importError = const FileSystemException(
              'held import failure',
            );
            await tester.runAsync(() async {
              // Given actual capture with a failing durable import.
              // When stop is attempted, observe the expected retained error.
              await expectLater(
                h.capture(),
                throwsA(same(h.store.importError)),
              );
              // Then pending original bytes are available for an explicit retry.
              expect(h.facade.pendingOriginal, isNotNull);
            });
            h.store.importError = null;
          } else if ([
            'play',
            'stop-playback',
            'transcribe',
            'cancel-transcription',
          ].contains(action)) {
            await tester.runAsync(h.capture);
          }
          if (action == 'prepare-model') {
            h.provider.ready = AudioProviderState.downloadable;
            await tester.runAsync(h.controller.refreshAvailability);
          } else if (action == 'stop-playback') {
            h.provider.playGate = Completer<void>();
            await tester.runAsync(() async {
              // Given exact saved bytes and held playback.
              // When the owner starts playback, observe its expected cancellation immediately.
              playback = expectLater(
                h.controller.playOriginal(),
                throwsStateError,
              );
              // Then the explicit stop below must reject the original with StateError.
              expect(h.controller.busy, isTrue);
            });
            await _pumpUntil(tester, () => h.provider.playEntered.isCompleted);
          } else if (action == 'cancel-transcription') {
            h.provider.asrGate = Completer<void>();
            await tester.runAsync(() async {
              // Given a saved original and held real inference.
              // When recognition starts, observe its expected cancellation immediately.
              recognition = expectLater(
                h.controller.transcribe(),
                throwsStateError,
              );
              // Then the explicit cancellation below must reject the original with StateError.
              expect(h.controller.canCancelTranscription, isTrue);
            });
            await _pumpUntil(tester, () => h.provider.asrEntered.isCompleted);
          }
          var allowed = true;
          var policyThrows = false;
          bool policy() {
            // Return the current caller admission or its configured evaluation failure.
            if (policyThrows) {
              throw StateError('caller admission failed');
            }
            // Successful evaluation reports user admission only.
            return allowed;
          }

          final callbacks = <AudioTranscriptReview>[];
          await tester.pumpWidget(
            _root(
              h.controller,
              onChanged: callbacks.add,
              interactionAllowed: policy,
            ),
          );
          final finder = find.byKey(ValueKey('audio-capture-$action'));
          final captured = tester.widget<ElevatedButton>(finder).onPressed!;
          final before = _effects(h);
          final review = h.controller.review;
          final state = h.controller.state;
          final error = h.controller.error;
          // When the policy flips without pumping, the captured callback is denied.
          allowed = false;
          captured();
          // Then no controller, readiness, capture, playback, cancellation or storage effect occurs.
          expect(_effects(h), before);
          expect(h.controller.review, same(review));
          expect(h.controller.state, state);
          expect(h.controller.error, same(error));
          expect(callbacks, isEmpty);
          // When the policy throws, that same callback fails closed before action.
          allowed = true;
          policyThrows = true;
          captured();
          // Then a failed evaluation still produces no effect or outward exception.
          expect(_effects(h), before);
          expect(tester.takeException(), isNull);
          // When built under false, its visible action is disabled without starting IO.
          policyThrows = false;
          allowed = false;
          await tester.pumpWidget(
            _root(
              h.controller,
              onChanged: callbacks.add,
              interactionAllowed: policy,
            ),
          );
          // Then the same control stays visible and construction is inert.
          expect(tester.widget<ElevatedButton>(finder).onPressed, isNull);
          expect(_effects(h), before);
          // When reenabled without a rebuild, the original current-generation action is explicit.
          allowed = true;
          await tester.runAsync(() async {
            // Given the current owner and its original captured command.
            // When explicit intent is admitted in the real IO event zone.
            captured();
            // Then dispatch is safe before its observable asynchronous settlement.
            expect(tester.takeException(), isNull);
          });
          await _pumpUntil(
            tester,
            () => action == 'record'
                ? h.controller.recordingStarted
                : !h.controller.busy,
          );
          if (playback != null) {
            await tester.runAsync(() => playback!);
          }
          if (recognition != null) {
            await tester.runAsync(() => recognition!);
          }
          // Then a real action occurred once, and the widget never disposed the borrowed provider.
          expect(_effects(h), isNot(before));
          expect(h.provider.disposals, 0);
          if (action == 'record') {
            await tester.runAsync(h.controller.cancelRecording);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    for (final operation in ['stop', 'transcribe']) {
      for (final fails in [false, true]) {
        testWidgets(
          'G3 accepted $operation failure=$fails settles while user admission is false',
          (tester) async {
            // Given the current production panel and a held durable stop or saved-input ASR outcome.
            var allowed = true;
            final callbacks = <AudioTranscriptReview>[];
            if (operation == 'stop') {
              await tester.runAsync(h.controller.startRecording);
              h.store.saveGate = Completer<void>();
              if (fails) {
                h.store.importError = const FileSystemException(
                  'accepted import failure',
                );
              }
            } else {
              await tester.runAsync(h.capture);
              h.provider.asrGate = Completer<void>();
              if (fails) {
                h.provider.asrError = AudioProviderException(
                  'actualFailure',
                  'accepted ASR failure',
                );
              }
            }
            await tester.pumpWidget(
              _root(
                h.controller,
                onChanged: callbacks.add,
                interactionAllowed: () => allowed,
              ),
            );
            // When the real UI admits the command and then its caller suspends new user intent.
            await _tap(tester, 'audio-capture-$operation');
            await _pumpUntil(
              tester,
              () => operation == 'stop'
                  ? h.store.saveEntered.isCompleted
                  : h.provider.asrEntered.isCompleted,
            );
            allowed = false;
            await tester.pumpWidget(
              _root(
                h.controller,
                onChanged: callbacks.add,
                interactionAllowed: () => allowed,
              ),
            );
            if (operation == 'stop') {
              h.store.saveGate!.complete();
            } else {
              h.provider.asrGate!.complete();
            }
            await _pumpUntil(tester, () => !h.controller.busy);
            // Then accepted original/report/error remains actual and the current owner receives its result exactly once.
            expect(h.provider.disposals, 0);
            expect(
              h.provider.recordingCancels + h.provider.transcriptionCancels,
              0,
            );
            expect(h.controller.isDetached, isFalse);
            expect(h.store.imports, 1);
            if (operation == 'stop' && fails) {
              expect(callbacks, isEmpty);
              expect(h.facade.pendingOriginal, isNotNull);
              expect(h.controller.error, same(h.store.importError));
            } else {
              expect(callbacks, [h.controller.review]);
              expect(h.controller.review!.original.durationMilliseconds, 1000);
              if (operation == 'transcribe') {
                expect(
                  h.controller.review!.reports.single.status,
                  fails
                      ? AudioTranscriptStatus.failed
                      : AudioTranscriptStatus.success,
                );
              }
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }

    for (final retirement in ['replace', 'round-trip', 'unmount']) {
      testWidgets(
        'G5 audio $retirement denies old command before microphone or readiness',
        (tester) async {
          // Given owner A and its actual rendered record/readiness callbacks.
          final other = AudioCaptureController(facade: h.facade);
          final callbacks = <AudioTranscriptReview>[];
          await tester.pumpWidget(
            _root(h.controller, onChanged: callbacks.add),
          );
          final actions = [
            for (final suffix in ['record', 'check-transcription'])
              tester
                  .widget<ElevatedButton>(
                    find.byKey(ValueKey('audio-capture-$suffix')),
                  )
                  .onPressed!,
          ];
          // When the owner is replaced, round-tripped to A or unmounted.
          if (retirement == 'unmount') {
            await tester.pumpWidget(const SizedBox.shrink());
          } else {
            await tester.pumpWidget(_root(other, onChanged: callbacks.add));
            if (retirement == 'round-trip') {
              await tester.pumpWidget(
                _root(h.controller, onChanged: callbacks.add),
              );
            }
          }
          for (final action in actions) {
            // Given the callback captured before owner retirement.
            // When it is invoked, it has no current generation authority.
            action();
            // Then the provider has not started recording or probed readiness.
            expect(h.provider.starts + h.provider.probes, 0);
          }
          // Then neither old nor new owner receives an operation or revision result.
          expect(h.controller.busy, isFalse);
          expect(other.busy, isFalse);
          expect(callbacks, isEmpty);
          expect(h.store.imports, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          other.dispose();
        },
      );
    }

    testWidgets(
      'G6 false gate keeps scaled audio and transcript controls visible without IO',
      (tester) async {
        // Given a saved original and dirty draft at 320px with inherited scale two.
        await tester.runAsync(h.capture);
        h.controller.setDraftText(' retained 📘 ');
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _Settings();
        final view = SettingsView.fromService(service: settings);
        final before = _effects(h);
        await tester.pumpWidget(
          _root(
            h.controller,
            settings: view,
            scale: 2,
            interactionAllowed: () => false,
          ),
        );
        // Enumerate the actual disabled controls in the scaled caller scrollable.
        for (final key in [
          'audio-capture-play',
          'audio-capture-transcribe',
          'audio-capture-check-transcription',
          'transcript-review-record-correction',
        ]) {
          // Given the finder for the current visible denied command.
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          // Then the visible control has no admitted gesture callback.
          expect(tester.widget<ElevatedButton>(finder).onPressed, isNull);
          // When the actual disabled control is tapped.
          await tester.tap(finder);
          await tester.pump();
          // Then it stays reachable without IO or layout failure.
          expect(finder.hitTestable(), findsOneWidget);
          expect(_effects(h), before);
          expect(tester.takeException(), isNull);
        }
        // Then exact dirty text stays readable but disabled and inherited scaling is retained.
        final field = find.byKey(const ValueKey('transcript-review-text'));
        expect(tester.widget<TextField>(field).enabled, isFalse);
        expect(
          tester.widget<TextField>(field).controller!.text,
          ' retained 📘 ',
        );
        expect(MediaQuery.textScalerOf(tester.element(field)).scale(16), 32);
        expect(h.controller.hasUnsavedText, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        view.dispose();
        settings.dispose();
      },
    );

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
        expect(find.text('録音中: 1秒'), findsOneWidget);
        h.store.saveGate = Completer<void>();
        final failure = const FileSystemException('actual storage failure');
        h.store.importError = failure;
        await _tap(tester, 'audio-capture-stop');
        await _pumpUntil(tester, () => h.store.saveEntered.isCompleted);
        expect(find.text('音声を保存しています'), findsOneWidget);
        expect(callbacks, isEmpty);
        h.store.saveGate!.complete();
        await _pumpUntil(tester, () => !h.controller.busy);
        expect(find.text('音声が未保存です'), findsOneWidget);
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
        expect(find.text('この端末では録音を利用できません'), findsOneWidget);
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
          MediaQuery.textScalerOf(tester.element(find.text('音声'))).scale(16),
          32,
        );
        expect(find.textContaining('認識処理:'), findsNothing);
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

  // Compose real private storage and controlled borrowed providers without capture or inference.
  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('tfaf-audio-');
    store = _Store(FileCaptureStore(directory.path));
    service = AudioCaptureService(
      runtime: provider,
      transcription: provider,
      store: store,
      now: () => _time,
    );
    facade = AudioCaptureFacade(service: service);
    controller = AudioCaptureController(facade: facade, now: () => _time);
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

  // Drain the fixture controller before disposing Core and removing its own directory.
  Future<void> close() async {
    try {
      await controller.detach();
    } catch (error) {
      expect(error, same(controller.cleanupError));
    }
    controller.dispose();
    await service.dispose();
    await directory.delete(recursive: true);
    expect(provider.disposals, 0);
    expect(await directory.exists(), isFalse);
    expect(controller.isDisposed, isTrue);
  }

  // Explicitly record and durably import the exact controlled WAV; check bytes and provenance.
  Future<AudioTranscriptReview> capture() async {
    expect(controller.review, isNull);
    await controller.startRecording();
    final review = await controller.stopRecording();
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
  // Count explicit microphone starts and apply the configured gate or fault.
  Future<void> startRecording(AudioRecordingConfiguration configuration) async {
    expect(configuration.maxDurationSeconds, inInclusiveRange(1, 120));
    starts++;
    receivedConfiguration = configuration;
    if (!startEntered.isCompleted) {
      startEntered.complete();
    }
    if (startGate != null) {
      await startGate!.future;
    }
    if (startError != null) {
      throw startError!;
    }
    expect(receivedConfiguration, same(configuration));
  }

  @override
  // Return the exact controlled WAV and capture time for an explicit stop.
  Future<CapturedAudio> stopRecording() async {
    expect(starts, greaterThan(0));
    stops++;
    final captured = CapturedAudio(
      bytes: _wave(),
      capturedAt: _time,
      originalName: 'source.wav',
    );
    expect(captured.bytes, orderedEquals(_wave()));
    expect(captured.capturedAt, _time);
    return captured;
  }

  @override
  // Count cancellation and release the pending start gate.
  Future<void> cancelRecording() async {
    recordingCancels++;
    if (startGate != null && !startGate!.isCompleted) {
      startGate!.complete();
    }
    expect(recordingCancels, greaterThan(0));
    expect(startGate == null || startGate!.isCompleted, isTrue);
  }

  @override
  // Snapshot supplied original bytes and hold playback only when configured.
  Future<void> play(Uint8List bytes) async {
    expect(bytes, orderedEquals(_wave()));
    played.add(Uint8List.fromList(bytes));
    if (!playEntered.isCompleted) {
      playEntered.complete();
    }
    if (playGate != null) {
      await playGate!.future;
    }
    expect(played.last, orderedEquals(bytes));
  }

  @override
  // Count playback cleanup and release its controlled gate.
  Future<void> stopPlayback() async {
    playStops++;
    if (playGate != null && !playGate!.isCompleted) {
      playGate!.complete();
    }
    expect(playStops, greaterThan(0));
    expect(playGate == null || playGate!.isCompleted, isTrue);
  }

  @override
  // Record locale/readiness observation and apply its finite controlled gate.
  Future<AudioProviderAvailability> availability(String locale) async {
    probes++;
    locales.add(locale);
    if (!probeEntered.isCompleted) {
      probeEntered.complete();
    }
    if (probeGate != null) {
      await probeGate!.future;
    }
    final value = AudioProviderAvailability(
      providerId: id,
      locale: locale,
      state: ready,
      reason: ready == AudioProviderState.available
          ? null
          : 'actual readiness reason',
    );
    expect(value.providerId, id);
    expect(value.locale, locale);
    expect(inputs.length, lessThanOrEqualTo(probes));
    return value;
  }

  @override
  // Count explicit preparation, join its gate and return controlled availability.
  Future<AudioProviderAvailability> prepare(String locale) async {
    prepares++;
    if (!prepareEntered.isCompleted) {
      prepareEntered.complete();
    }
    if (prepareGate != null) {
      await prepareGate!.future;
    }
    ready = AudioProviderState.available;
    final result = await availability(locale);
    expect(prepares, greaterThan(0));
    expect(result.state, AudioProviderState.available);
    return result;
  }

  @override
  // Retain exact saved input and return controlled text or the configured actual fault.
  Future<AudioProviderTranscript> transcribe(
    AudioTranscriptionInput input,
  ) async {
    expect(input.bytes, orderedEquals(_wave()));
    inputs.add(input);
    if (!asrEntered.isCompleted) {
      asrEntered.complete();
    }
    if (asrGate != null) {
      await asrGate!.future;
    }
    if (asrError != null) {
      throw asrError!;
    }
    final result = AudioProviderTranscript(text: text);
    expect(result.text, text);
    expect(inputs.last, same(input));
    return result;
  }

  @override
  // Count transcription cleanup and release configured gates or report the configured fault.
  Future<void> cancel() async {
    transcriptionCancels++;
    if (releaseOnCancel) {
      for (final gate in [probeGate, prepareGate, asrGate]) {
        if (gate != null && !gate.isCompleted) {
          gate.complete();
        }
      }
    }
    if (cancelError != null) {
      Error.throwWithStackTrace(
        cancelError!,
        cancelStack ?? StackTrace.current,
      );
    }
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
  // Observe terminal provider disposal; shared borrowed ownership must not duplicate it.
  Future<void> dispose() async {
    disposals++;
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
  int materialReads = 0;
  @override
  // Count/hold/fail durable import while delegating exact bytes and provenance to real storage.
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes,
    required String mediaType,
    required DateTime capturedAt,
    String? originalName,
  }) async {
    final snapshot = Uint8List.fromList(bytes);
    expect(snapshot, orderedEquals(_wave()));
    imports++;
    if (!saveEntered.isCompleted) {
      saveEntered.complete();
    }
    if (saveGate != null) {
      await saveGate!.future;
    }
    if (importError != null) {
      throw importError!;
    }
    final reference = await delegate.saveMaterial(
      bytes: snapshot,
      mediaType: mediaType,
      capturedAt: capturedAt,
      originalName: originalName,
    );
    expect(await delegate.readMaterial(reference), orderedEquals(snapshot));
    expect(reference.capturedAt, capturedAt);
    return reference;
  }

  @override
  // Count original reads and apply the read gate/fault before real filesystem delegation.
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) async {
    materialReads++;
    if (!readEntered.isCompleted) {
      readEntered.complete();
    }
    if (readGate != null) {
      await readGate!.future;
    }
    if (readError != null) {
      throw readError!;
    }
    final bytes = await delegate.readMaterial(reference);
    expect(bytes.length, reference.byteLength);
    return bytes;
  }

  @override
  // Count exact opaque document writes and check their real disk roundtrip.
  Future<void> saveDocument(
    String collection,
    String id,
    Map<String, Object?> document,
  ) async {
    documentWrites++;
    await delegate.saveDocument(collection, id, document);
    expect(await delegate.readDocument(collection, id), document);
  }

  @override
  // Read the selected opaque document and retain absence as null.
  Future<Map<String, Object?>?> readDocument(
    String collection,
    String id,
  ) async {
    final value = await delegate.readDocument(collection, id);
    expect(value, anyOf(isNull, isA<Map<String, Object?>>()));
    return value;
  }

  @override
  // Delegate durable identity listing and check its sorted output.
  Future<List<String>> listDocumentIds(String collection) async {
    final ids = await delegate.listDocumentIds(collection);
    expect(ids, orderedEquals(List<String>.of(ids)..sort()));
    return ids;
  }
}

// Compose both borrowed panels, caller admission and inherited scaling in a scrollable host.
Widget _root(
  AudioCaptureController controller, {
  ValueChanged<AudioTranscriptReview>? onChanged,
  AudioCaptureController? transcriptController,
  SettingsView? settings,
  double scale = 1,
  bool Function()? interactionAllowed,
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
              interactionAllowed: interactionAllowed,
            ),
            TranscriptReviewPanel(
              key: const ValueKey('transcript-panel'),
              controller: transcriptController ?? controller,
              onReviewChanged: onChanged,
              interactionAllowed: interactionAllowed,
            ),
          ],
        ),
      ),
    ),
  ),
);

// Reveal and tap an enabled production control in its required event zone.
Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  expect(tester.widget<ElevatedButton>(finder).onPressed, isNotNull);
  if (key == 'audio-capture-record' || key == 'audio-capture-cancel') {
    await tester.tap(finder);
  } else {
    await tester.runAsync(() => tester.tap(finder));
  }
  await tester.pump();
  expect(tester.takeException(), isNull);
}

// Join bounded real event turns/frames and check the selected observable state.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var turn = 0; turn < 80 && !condition(); turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
  expect(tester.takeException(), isNull);
}

// Snapshot separate provider and filesystem command counters for admission assertions.
List<int> _effects(_Harness h) {
  final values = [
    h.provider.starts,
    h.provider.stops,
    h.provider.recordingCancels,
    h.provider.played.length,
    h.provider.playStops,
    h.provider.probes,
    h.provider.prepares,
    h.provider.inputs.length,
    h.provider.transcriptionCancels,
    h.provider.disposals,
    h.store.imports,
    h.store.materialReads,
    h.store.documentWrites,
  ];
  expect(values.every((value) => value >= 0), isTrue);
  return values;
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
