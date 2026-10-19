import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('one-original audio controller', () {
    late _Harness h;
    setUp(() async {
      // Given inert controlled providers and a fresh actual durable store.
      h = _Harness();
      // When the public borrowed controller is composed.
      await h.open();
      // Then initial state has no provider operations or review.
      expect(h.controller.review, isNull);
      expect(h.controller.busy, isFalse);
    });
    tearDown(() async {
      // Given this test's explicitly owned fixture.
      // When its settled interaction and Core resources are closed.
      await h.close();
      // Then borrowed provider lifetime was preserved.
      expect(h.provider.disposals, 0);
    });

    test(
      'C1 inert restored review and exact explicit locale/configuration',
      () async {
        // Given an original restored into a new controller with an explicit locale/configuration.
        final initial = (await h.capture()).correct(
          ' exact 日本語 ',
          recordedAt: _time,
        );
        h.controller.dispose();
        final configuration = AudioRecordingConfiguration(
          maxDurationSeconds: 2,
        );
        h.controller = AudioCaptureController(
          facade: h.facade,
          initialReview: initial,
          locale: 'en-US',
          configuration: configuration,
        );
        final probes = h.provider.probes;
        // When malformed construction is rejected and the restored controller explicitly probes.
        expect(
          () => AudioCaptureController(facade: h.facade, locale: ' ja-JP'),
          throwsArgumentError,
        );
        expect(h.controller.review, same(initial));
        expect(h.controller.draftText, ' exact 日本語 ');
        expect(h.provider.probes, probes);
        final ready = await h.controller.refreshAvailability();
        // Then no implicit IO occurs and exact locale, original and configuration are preserved.
        expect(ready.locale, 'en-US');
        expect(h.controller.configuration, same(configuration));
        expect(h.controller.canStartRecording, isFalse);
        expect(h.controller.hasUnsavedText, isFalse);
        expect(h.store.imports, 1);
        expect(h.provider.inputs, isEmpty);
      },
    );

    testWidgets(
      'C2 successful start persists timer until explicit held durable stop',
      (tester) async {
        // Given an empty controller with a two-second native limit.
        h.controller.dispose();
        h.controller = AudioCaptureController(
          facade: h.facade,
          configuration: AudioRecordingConfiguration(maxDurationSeconds: 2),
        );
        // When explicit start settles, UI seconds advance and durable stop is held.
        await h.controller.startRecording();
        await tester.pump(const Duration(seconds: 3));
        expect(h.controller.recordingStarted, isTrue);
        expect(h.controller.elapsedSeconds, 2);
        expect(h.facade.state, AudioCaptureState.recording);
        expect(h.provider.stops, 0);
        h.store.saveGate = Completer<void>();
        late Future<AudioTranscriptReview> saving;
        await tester.runAsync(() async {
          // Given this fake-clock recording and a real durable save held by storage.
          // When explicit stop launches IO in the real event zone.
          saving = h.controller.stopRecording();
          // Then Core has reserved the actual saving transition before further UI intent.
          expect(h.facade.state, AudioCaptureState.saving);
        });
        await h.store.saveEntered.future;
        expect(h.controller.review, isNull);
        expect(h.controller.canCancelRecording, isFalse);
        expect(() => h.controller.startRecording(), throwsStateError);
        h.store.saveGate!.complete();
        final review = await tester.runAsync(() => saving);
        // Then only durable success creates an original and second acquisition is forbidden.
        expect(h.controller.review, same(review));
        expect(h.controller.recordingStarted, isFalse);
        expect(h.controller.canStartRecording, isFalse);
        expect(h.provider.starts, 1);
        expect(h.provider.stops, 1);
        expect(h.store.imports, 1);
      },
    );

    test(
      'C3 failed import immutable retry and exact original read failures',
      () async {
        // Given a started recording and actual storage failure.
        final failure = const FileSystemException('cannot import');
        await h.controller.startRecording();
        h.store.importError = failure;
        // When stop fails, pending bytes are retried and saved input later fails to read.
        await expectLater(h.controller.stopRecording(), throwsA(same(failure)));
        final pending = h.facade.pendingOriginal!;
        final detached = pending.bytes;
        detached[44] = 255;
        expect(h.controller.error, same(failure));
        expect(h.controller.canRetryPendingOriginal, isTrue);
        h.store.importError = null;
        final review = await h.controller.retryPendingOriginal();
        final readFailure = const FileSystemException('saved input missing');
        h.store.readError = readFailure;
        await expectLater(
          h.controller.transcribe(),
          throwsA(same(readFailure)),
        );
        // Then exact review/pending original survive failures without recapture or reports.
        expect(detached[44], 255);
        expect(pending.bytes, orderedEquals(_wave()));
        expect(h.controller.review, same(review));
        expect(h.controller.error, same(readFailure));
        expect(review.reports, isEmpty);
        expect(h.provider.inputs, isEmpty);
        expect(h.provider.starts, 1);
        expect(h.store.imports, 2);
      },
    );

    test('C4 pending start cancellation permission failure and all reentrant ordinary guards', () async {
      // Given pending permission and a notification attempting competing commands.
      h.provider.startGate = Completer<void>();
      var blocked = 0;
      void competitor() {
        if (!h.controller.busy) return;
        // Given a reserved command visible to a synchronous listener.
        // When ordinary commands try to enter before provider work launches.
        expect(() => h.controller.startRecording(), throwsStateError);
        expect(() => h.controller.refreshAvailability(), throwsStateError);
        expect(() => h.controller.prepareTranscription(), throwsStateError);
        expect(() => h.controller.retryPendingOriginal(), throwsStateError);
        expect(() => h.controller.playOriginal(), throwsStateError);
        expect(() => h.controller.transcribe(), throwsStateError);
        // Then every forbidden ordinary route rejects synchronously.
        blocked++;
      }

      h.controller.addListener(competitor);
      // When start is explicitly cancelled before permission settles, then permission fails.
      final start = h.controller.startRecording();
      final rejected = expectLater(start, throwsStateError);
      expect(h.controller.canStopRecording, isFalse);
      expect(h.controller.canCancelRecording, isTrue);
      await h.controller.cancelRecording();
      await rejected;
      h.controller.removeListener(competitor);
      final denial = AudioProviderException(
        'permissionDenied',
        'actual denial',
      );
      h.provider.startError = denial;
      await expectLater(h.controller.startRecording(), throwsA(same(denial)));
      // Then no capture was saved and all guarded intent/actual errors remain observable.
      expect(blocked, greaterThan(0));
      expect(h.provider.recordingCancels, 1);
      expect(h.store.imports, 0);
      expect(h.controller.error, same(denial));
      expect(h.controller.busy, isFalse);
    });

    test('C4 disposal from first start listener aborts before provider launch', () async {
      // Given a listener that terminally disposes during synchronous reservation.
      var laterCalls = 0;
      h.controller.addListener(h.controller.dispose);
      void later() {
        laterCalls++;
      }

      h.controller.addListener(later);
      // When start notifies before native work and detachment awaits its registered task.
      await expectLater(h.controller.startRecording(), throwsStateError);
      await h.controller.detach();
      // Then no native operation or later listener escapes the disposed owner.
      expect(h.provider.starts, 0);
      expect(h.provider.recordingCancels, 0);
      expect(laterCalls, 0);
      expect(h.controller.isDetached, isTrue);
      expect(h.facade.state, AudioCaptureState.idle);
    });

    test('C5 first exact prefill manual correction clear and explicit report selection', () async {
      // Given an exact durable original and a clean empty editor.
      await h.capture();
      // When first recognition prefills, corrections/clear are recorded, and recognition repeats.
      final first = await h.controller.transcribe();
      expect(h.controller.draftText, ' 日本語 \n');
      h.controller.setDraftText(' 手入力 \n');
      final corrected = h.controller.recordCorrection();
      h.provider.text = 'second';
      final second = await h.controller.transcribe();
      expect(second.currentText, ' 手入力 \n');
      h.controller.setDraftText('');
      final cleared = h.controller.recordCorrection();
      h.provider.text = 'third';
      final third = await h.controller.transcribe();
      final selected = h.controller.useReport(first.reports.single.id);
      // Then histories retain exact prefixes and explicit selection alone replaces manual intent.
      expect(corrected.revisions.last.source, TranscriptRevisionSource.manual);
      expect(cleared.currentText, '');
      expect(third.currentText, '');
      expect(selected.currentText, ' 日本語 \n');
      expect(selected.revisions.last.reportId, first.reports.single.id);
      expect(
        selected.revisions.last.source,
        TranscriptRevisionSource.generated,
      );
      AudioTranscriptReview.requireRetainedPrefix(third, selected);
      expect(selected.reports.length, 3);
      expect(h.store.imports, 1);
      expect(h.store.documentWrites, 0);
    });

    test('C6 dirty edits clear and concurrent committed correction survive held ASR', () async {
      // Given a saved original and held first ASR with exact editor intent.
      await h.capture();
      h.provider.asrGate = Completer<void>();
      final asr = h.controller.transcribe();
      await h.provider.asrEntered.future;
      // When an intentional empty clear precedes first success, then a concurrent correction precedes repeat success.
      h.controller.setDraftText('');
      h.provider.asrGate!.complete();
      final first = await asr;
      expect(first.currentText, ' 日本語 \n');
      expect(h.controller.draftText, '');
      expect(h.controller.hasUnsavedText, isTrue);
      expect(first.revisions.length, 1);
      h.provider.asrGate = Completer<void>();
      h.provider.asrEntered = Completer<void>();
      final repeat = h.controller.transcribe();
      await h.provider.asrEntered.future;
      h.controller.setDraftText(' 同時編集 \n');
      final manual = h.controller.recordCorrection();
      h.provider.asrGate!.complete();
      final next = await repeat;
      h.controller.setDraftText(' dirty remains ');
      h.provider.asrError = AudioProviderException('actualFailure', 'failure');
      final failed = await h.controller.transcribe();
      h.provider.ready = AudioProviderState.unavailable;
      final unavailable = await h.controller.transcribe();
      // Then latest review retains concurrent manual history while dirty input survives every outcome.
      AudioTranscriptReview.requireRetainedPrefix(manual, next);
      expect(next.currentText, ' 同時編集 \n');
      expect(failed.reports.last.status, AudioTranscriptStatus.failed);
      expect(
        unavailable.reports.last.status,
        AudioTranscriptStatus.unavailable,
      );
      expect(h.controller.draftText, ' dirty remains ');
      expect(h.controller.hasUnsavedText, isTrue);
      expect(unavailable.revisions.length, 2);
    });

    test('C7 backwards edit clock floors capture revision/source without repairing reports', () async {
      // Given a restored future-clock report and its generated revision.
      final original = (await h.capture()).original;
      final future = _time.add(const Duration(days: 10));
      final report = AudioTranscriptReport(
        id: 'future-report',
        original: original,
        providerId: h.provider.id,
        locale: 'ja-JP',
        startedAt: future,
        completedAt: future,
        elapsedMilliseconds: 0,
        status: AudioTranscriptStatus.success,
        text: 'future',
      );
      final restored = AudioTranscriptReview(original: original)
          .appendReport(report);
      h.controller.dispose();
      h.controller = AudioCaptureController(
        facade: h.facade,
        initialReview: restored,
        now: () => _time.subtract(const Duration(days: 1)),
      );
      // When explicit manual text/selection use a backwards clock and old provider reports arrive.
      h.controller.setDraftText('manual');
      final manual = h.controller.recordCorrection();
      final selected = h.controller.useReport(report.id);
      expect(() => h.controller.useReport('missing'), throwsArgumentError);
      await expectLater(h.controller.transcribe(), throwsArgumentError);
      // Then revisions floor to actual source and failed append leaves all retained history untouched.
      expect(manual.revisions.last.recordedAt, future);
      expect(selected.revisions.last.recordedAt, future);
      expect(h.controller.review, same(selected));
      expect(h.controller.draftText, 'future');
      expect(h.controller.review!.reports.single, same(report));
      expect(h.controller.error, isArgumentError);
    });

    for (final kind in [
      'recording',
      'playing',
      'probe',
      'preparing',
      'transcribing',
    ]) {
      test(
        'C8 detach owned $kind cancels only matching work and reuses borrowed service',
        () async {
          // Given one interaction owning the selected pending runtime/provider operation.
          if (kind != 'recording') await h.capture();
          Future<Object?> pending;
          if (kind == 'recording') {
            h.provider.startGate = Completer<void>();
            pending = h.controller.startRecording();
          } else if (kind == 'playing') {
            h.provider.playGate = Completer<void>();
            pending = h.controller.playOriginal();
          } else if (kind == 'probe') {
            h.provider.probeGate = Completer<void>();
            pending = h.controller.refreshAvailability();
          } else if (kind == 'preparing') {
            h.provider.prepareGate = Completer<void>();
            pending = h.controller.prepareTranscription();
          } else {
            h.provider.asrGate = Completer<void>();
            pending = h.controller.transcribe();
          }
          final rejected = expectLater(pending, throwsStateError);
          if (kind == 'playing') await h.provider.playEntered.future;
          if (kind == 'transcribing') await h.provider.asrEntered.future;
          var notifications = 0;
          void listener() {
            notifications++;
          }

          h.controller.addListener(listener);
          // When terminal interaction detach settles only its matching owned work.
          final first = h.controller.detach();
          final second = h.controller.detach();
          await first;
          await rejected;
          final ready = await h.facade.availability();
          // Then detach is idempotent, silent, nonterminal to Core and preserves storage.
          expect(first, same(second));
          expect(notifications, 0);
          expect(ready.state, AudioProviderState.available);
          expect(h.provider.recordingCancels, kind == 'recording' ? 1 : 0);
          expect(h.provider.playStops, kind == 'playing' ? 1 : 0);
          expect(
            h.provider.transcriptionCancels,
            ['probe', 'preparing', 'transcribing'].contains(kind) ? 1 : 0,
          );
          expect(h.provider.disposals, 0);
          expect(h.facade.state, AudioCaptureState.idle);
          expect(() => h.controller.setDraftText('late'), throwsStateError);
        },
      );
    }

    for (final fail in [false, true]) {
      test(
        'C9 detach during durable save retains ${fail ? 'pending failure' : 'original success'}',
        () async {
          // Given an owned recording and a held durable stop/import.
          await h.controller.startRecording();
          h.store.saveGate = Completer<void>();
          final failure = const FileSystemException('actual held save failure');
          if (fail) h.store.importError = failure;
          final saving = h.controller.stopRecording();
          final observed = saving.then<Object?>(
            (value) => value,
            onError: (Object error) => error,
          );
          await h.store.saveEntered.future;
          var detached = false;
          // When detach awaits saving without cancelling or disposing the borrowed service.
          final detach = h.controller.detach().then((_) => detached = true);
          await Future<void>.delayed(Duration.zero);
          expect(detached, isFalse);
          h.store.saveGate!.complete();
          final result = await observed;
          await detach;
          // Then exact durable success or original failure/pending bytes survive the owner handoff.
          expect(detached, isTrue);
          expect(h.provider.recordingCancels, 0);
          expect(h.provider.disposals, 0);
          if (fail) {
            expect(result, same(failure));
            expect(h.controller.error, same(failure));
            expect(h.controller.review, isNull);
            expect(h.facade.pendingOriginal!.bytes, orderedEquals(_wave()));
          } else {
            expect(h.controller.review, same(result));
            expect(
              await h.store.delegate.readMaterial(
                h.controller.review!.original.material,
              ),
              orderedEquals(_wave()),
            );
            expect(h.facade.pendingOriginal, isNull);
          }
        },
      );
    }

    test(
      'C9 detach during held retry retains the exact durable original',
      () async {
        // Given a failed original import whose immutable captured bytes await explicit retry.
        await h.controller.startRecording();
        final failure = const FileSystemException('first import failed');
        h.store.importError = failure;
        await expectLater(h.controller.stopRecording(), throwsA(same(failure)));
        h.store.importError = null;
        h.store.saveGate = Completer<void>();
        // When explicit retry is held by storage and the route detaches before durability.
        final retry = h.controller.retryPendingOriginal();
        var detached = false;
        final detaching = h.controller.detach().then((_) => detached = true);
        await Future<void>.delayed(Duration.zero);
        expect(detached, isFalse);
        expect(h.controller.review, isNull);
        h.store.saveGate!.complete();
        final retained = await retry;
        await detaching;
        // Then exact durable retry success is retained without recapture or cancellation.
        expect(h.controller.review, same(retained));
        expect(
          await h.store.delegate.readMaterial(retained.original.material),
          orderedEquals(_wave()),
        );
        expect(h.provider.starts, 1);
        expect(h.provider.stops, 1);
        expect(h.provider.recordingCancels, 0);
        expect(h.store.imports, 2);
        expect(h.facade.pendingOriginal, isNull);
        expect(h.controller.error, isNull);
      },
    );

    test('C9 cleanup failure still awaits prior task and retains actual stack', () async {
      // Given a held probe whose cleanup fails without releasing provider work.
      h.provider.probeGate = Completer<void>();
      h.provider.releaseOnCancel = false;
      final failure = StateError('cleanup failure');
      final stack = StackTrace.fromString('actual cleanup stack');
      h.provider.cancelError = failure;
      h.provider.cancelStack = stack;
      final pending = h.controller.refreshAvailability();
      final rejected = expectLater(pending, throwsStateError);
      var settled = false;
      Object? actual;
      StackTrace? actualStack;
      // When detach sees cleanup failure but still waits for the original command.
      final detaching = h.controller.detach().then<void>(
        (_) => settled = true,
        onError: (Object error, StackTrace trace) {
          actual = error;
          actualStack = trace;
          settled = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      h.provider.probeGate!.complete();
      await detaching;
      await rejected;
      h.provider.cancelError = null;
      // Then failure identity/stack and completed settlement are visible to the owner.
      expect(actual, same(failure));
      expect(actualStack.toString(), stack.toString());
      expect(h.controller.cleanupError, same(failure));
      expect(h.provider.disposals, 0);
    });

    test('C10 duplicate listeners remove one registration at a time', () async {
      // Given an idle saved original and two registrations of the same callback.
      await h.capture();
      var calls = 0;
      void listener() {
        calls++;
      }

      h.controller.addListener(listener);
      h.controller.addListener(listener);
      // When exact edits notify and each explicit removal drops one registration.
      h.controller.setDraftText('first');
      expect(calls, 2);
      h.controller.removeListener(listener);
      h.controller.setDraftText('second');
      expect(calls, 3);
      h.controller.removeListener(listener);
      h.controller.setDraftText('third');
      h.controller.dispose();
      h.controller.removeListener(listener);
      await h.controller.detach();
      // Then remaining duplicate registrations never leak callbacks or provider disposal.
      expect(calls, 3);
      expect(h.controller.draftText, 'third');
      expect(h.controller.hasUnsavedText, isTrue);
      expect(h.provider.disposals, 0);
    });

    test('C10 foreign work idle detach and duplicate listener removal remain isolated', () async {
      // Given a controller owning no work while a foreign caller owns a held probe.
      h.provider.probeGate = Completer<void>();
      final foreign = h.facade.availability();
      var calls = 0;
      void listener() {
        calls++;
      }

      h.controller.addListener(listener);
      h.controller.addListener(listener);
      h.controller.removeListener(listener);
      // When the idle controller detaches/disposes and the foreign probe finishes normally.
      await h.controller.detach();
      h.controller.dispose();
      h.controller.dispose();
      h.controller.removeListener(listener);
      h.provider.probeGate!.complete();
      final ready = await foreign;
      // Then foreign work is untouched and no duplicate listener leaks or callbacks occur.
      expect(ready.state, AudioProviderState.available);
      expect(h.provider.transcriptionCancels, 0);
      expect(calls, 0);
      expect(h.facade.state, AudioCaptureState.idle);
      expect(h.provider.disposals, 0);
    });

    for (final dispose in [false, true]) {
      for (final kind in [
        'recording',
        'playing',
        'probe',
        'preparing',
        'transcribing',
      ]) {
        test(
          'C11 ${dispose ? 'dispose' : 'detach'} at $kind interruption reservation cancels launched work once',
          () async {
            // Given actually launched owned work held at its exact provider gate.
            final initial = kind == 'recording' ? null : await h.capture();
            Future<Object?> pending;
            Future<void> entered;
            if (kind == 'recording') {
              h.provider.startGate = Completer<void>();
              pending = h.controller.startRecording();
              entered = h.provider.startEntered.future;
            } else if (kind == 'playing') {
              h.provider.playGate = Completer<void>();
              pending = h.controller.playOriginal();
              entered = h.provider.playEntered.future;
            } else if (kind == 'probe') {
              h.provider.probeGate = Completer<void>();
              pending = h.controller.refreshAvailability();
              entered = h.provider.probeEntered.future;
            } else if (kind == 'preparing') {
              h.provider.ready = AudioProviderState.downloadable;
              await h.controller.refreshAvailability();
              h.provider.prepareGate = Completer<void>();
              pending = h.controller.prepareTranscription();
              entered = h.provider.prepareEntered.future;
            } else {
              h.provider.asrGate = Completer<void>();
              pending = h.controller.transcribe();
              entered = h.provider.asrEntered.future;
            }
            final rejected = expectLater(
              pending.timeout(const Duration(seconds: 3)),
              throwsStateError,
            );
            Future<void>? detaching;
            var reservationCalls = 0;
            var laterCalls = 0;
            void reservationListener() {
              // Given the first notification of an interrupt reservation.
              if (reservationCalls != 0) return;
              reservationCalls++;
              // When the owner terminally detaches or disposes before dispatch.
              if (dispose) h.controller.dispose();
              detaching = h.controller.detach();
              // Then repeated detach exposes the same registered settlement.
              expect(h.controller.detach(), same(detaching));
            }

            void laterListener() {
              laterCalls++;
            }

            try {
              await entered.timeout(const Duration(seconds: 3));
              h.controller.addListener(reservationListener);
              h.controller.addListener(laterListener);
              // When matching interruption notifies the synchronous terminal listener.
              final Future<void> interruption;
              if (kind == 'recording') {
                interruption = h.controller.cancelRecording();
              } else if (kind == 'playing') {
                interruption = h.controller.stopPlayback();
              } else {
                interruption = h.controller.cancelTranscription();
              }
              final interruptRejected = expectLater(
                interruption.timeout(const Duration(seconds: 3)),
                throwsStateError,
              );
              await interruptRejected;
              await detaching!.timeout(const Duration(seconds: 3));
              await rejected;
              final ready = await h.facade.availability().timeout(
                const Duration(seconds: 3),
              );
              // Then launched ownership is cleaned once while the reserved interrupt never launches.
              expect(reservationCalls, 1);
              expect(laterCalls, 0);
              expect(h.controller.isDetached, isTrue);
              expect(h.controller.isDisposed, dispose);
              expect(h.controller.busy, isFalse);
              expect(h.provider.recordingCancels, kind == 'recording' ? 1 : 0);
              expect(h.provider.playStops, kind == 'playing' ? 1 : 0);
              expect(
                h.provider.transcriptionCancels,
                ['probe', 'preparing', 'transcribing'].contains(kind) ? 1 : 0,
              );
              expect(h.provider.disposals, 0);
              expect(h.provider.stops, kind == 'recording' ? 0 : 1);
              expect(h.store.imports, kind == 'recording' ? 0 : 1);
              expect(h.store.documentWrites, 0);
              expect(h.controller.review, same(initial));
              if (initial != null) expect(initial.reports, isEmpty);
              expect(h.facade.pendingOriginal, isNull);
              expect(h.facade.state, AudioCaptureState.idle);
              expect(ready.state, AudioProviderState.available);
              expect(h.controller.cleanupError, isNull);
            } finally {
              for (final gate in [
                h.provider.startGate,
                h.provider.playGate,
                h.provider.probeGate,
                h.provider.prepareGate,
                h.provider.asrGate,
              ]) {
                if (gate != null && !gate.isCompleted) gate.complete();
              }
            }
          },
        );
      }
    }

    for (final dispose in [false, true]) {
      test(
        'C11 ${dispose ? 'dispose' : 'detach'} at cancellation reservation retains cleanup failure and held settlement',
        () async {
          // Given a launched held probe whose cleanup fails without releasing its gate.
          h.provider.probeGate = Completer<void>();
          h.provider.releaseOnCancel = false;
          final failure = StateError('reservation cleanup failure');
          final stack = StackTrace.fromString(
            'actual reservation cleanup stack',
          );
          h.provider.cancelError = failure;
          h.provider.cancelStack = stack;
          final pending = h.controller.refreshAvailability();
          final rejected = expectLater(
            pending.timeout(const Duration(seconds: 3)),
            throwsStateError,
          );
          Future<void>? detaching;
          Future<void>? observedDetach;
          var settled = false;
          var reservationCalls = 0;
          Object? actual;
          StackTrace? actualStack;
          void reservationListener() {
            // Given the first synchronous cancellation reservation notification.
            if (reservationCalls != 0) return;
            reservationCalls++;
            // When the owner terminates before interrupt dispatch and observes cleanup immediately.
            if (dispose) h.controller.dispose();
            detaching = h.controller.detach();
            observedDetach = detaching!.then<void>(
              (_) => settled = true,
              onError: (Object error, StackTrace trace) {
                actual = error;
                actualStack = trace;
                settled = true;
              },
            );
            // Then detach exposes one cached cleanup settlement.
            expect(h.controller.detach(), same(detaching));
          }

          try {
            await h.provider.probeEntered.future.timeout(
              const Duration(seconds: 3),
            );
            h.controller.addListener(reservationListener);
            // When cancellation aborts at reservation and actual cleanup has entered its failure path.
            final interruptRejected = expectLater(
              h.controller.cancelTranscription().timeout(
                const Duration(seconds: 3),
              ),
              throwsStateError,
            );
            await h.provider.cancelEntered.future.timeout(
              const Duration(seconds: 3),
            );
            await interruptRejected;
            // Then even failed cleanup cannot finish detach before the owned original settles.
            expect(settled, isFalse);
            expect(h.provider.probeGate!.isCompleted, isFalse);
            expect(h.provider.transcriptionCancels, 1);
            // When the original provider gate is explicitly released after cleanup failure.
            h.provider.probeGate!.complete();
            await observedDetach!.timeout(const Duration(seconds: 3));
            await rejected;
            h.provider.cancelError = null;
            final ready = await h.facade.availability().timeout(
              const Duration(seconds: 3),
            );
            // Then the first actual error/stack survives settlement and the borrowed service remains reusable.
            expect(settled, isTrue);
            expect(reservationCalls, 1);
            expect(actual, same(failure));
            expect(actualStack.toString(), stack.toString());
            expect(h.controller.cleanupError, same(failure));
            expect(h.provider.transcriptionCancels, 1);
            expect(h.provider.recordingCancels, 0);
            expect(h.provider.playStops, 0);
            expect(h.provider.disposals, 0);
            expect(h.controller.isDisposed, dispose);
            expect(h.controller.busy, isFalse);
            expect(h.controller.review, isNull);
            expect(h.store.imports, 0);
            expect(h.facade.state, AudioCaptureState.idle);
            expect(ready.state, AudioProviderState.available);
          } finally {
            h.provider.cancelError = null;
            if (!h.provider.probeGate!.isCompleted) {
              h.provider.probeGate!.complete();
            }
          }
        },
      );
    }

    test('C11 detach joins dispatched held interruption without duplicate provider cancellation', () async {
      // Given a launched held probe and independently held actual provider cleanup.
      h.provider.probeGate = Completer<void>();
      h.provider.cancelGate = Completer<void>();
      h.provider.releaseOnCancel = false;
      final pending = h.controller.refreshAvailability();
      final rejected = expectLater(
        pending.timeout(const Duration(seconds: 3)),
        throwsStateError,
      );
      var interruptSettled = false;
      var detached = false;
      var notifications = 0;
      void listener() {
        notifications++;
      }

      try {
        await h.provider.probeEntered.future.timeout(
          const Duration(seconds: 3),
        );
        // When interruption actually dispatches before the owner detaches.
        final interruption = h.controller.cancelTranscription();
        final observedInterrupt = expectLater(
          interruption
              .then<void>((_) => interruptSettled = true)
              .timeout(const Duration(seconds: 3)),
          completes,
        );
        await h.provider.cancelEntered.future.timeout(
          const Duration(seconds: 3),
        );
        h.controller.addListener(listener);
        final detaching = h.controller.detach();
        final observedDetach = expectLater(
          detaching
              .then<void>((_) => detached = true)
              .timeout(const Duration(seconds: 3)),
          completes,
        );
        // Then detach joins both held settlements without a second cancellation.
        expect(h.controller.detach(), same(detaching));
        expect(h.provider.transcriptionCancels, 1);
        expect(interruptSettled, isFalse);
        expect(detached, isFalse);
        expect(h.provider.cancelGate!.isCompleted, isFalse);
        expect(h.provider.probeGate!.isCompleted, isFalse);
        // When actual cleanup and the original provider operation are separately released.
        h.provider.cancelGate!.complete();
        h.provider.probeGate!.complete();
        await observedInterrupt;
        await observedDetach;
        await rejected;
        final ready = await h.facade.availability().timeout(
          const Duration(seconds: 3),
        );
        // Then both futures settle, cleanup stays once-only and the borrowed service is idle and reusable.
        expect(interruptSettled, isTrue);
        expect(detached, isTrue);
        expect(notifications, 0);
        expect(h.provider.transcriptionCancels, 1);
        expect(h.provider.recordingCancels, 0);
        expect(h.provider.playStops, 0);
        expect(h.provider.disposals, 0);
        expect(h.controller.busy, isFalse);
        expect(h.controller.cleanupError, isNull);
        expect(h.controller.review, isNull);
        expect(h.store.imports, 0);
        expect(h.facade.state, AudioCaptureState.idle);
        expect(ready.state, AudioProviderState.available);
      } finally {
        for (final gate in [h.provider.cancelGate, h.provider.probeGate]) {
          if (gate != null && !gate.isCompleted) gate.complete();
        }
      }
    });

    for (final dispose in [false, true]) {
      test(
        'C12 ${dispose ? 'dispose' : 'detach'} at stop reservation cancels recording before saving can launch',
        () async {
          // Given an observer for the first live recording timer tick and no saved original.
          final tick = Completer<void>();
          void timerListener() {
            // Given the first elapsed tick has not yet been observed.
            if (h.controller.elapsedSeconds != 1 || tick.isCompleted) return;
            // When the live timer reports its first tick, complete the observation.
            tick.complete();
            // Then the test can await that exact notification once.
            expect(tick.isCompleted, isTrue);
          }

          h.controller.addListener(timerListener);
          // When recording starts with its observer registered in the same real zone.
          await h.controller.startRecording();
          // Then the owned recording can stop and Core is recording.
          expect(h.controller.recordingStarted, isTrue);
          expect(h.controller.canStopRecording, isTrue);
          expect(h.facade.state, AudioCaptureState.recording);
          // When the successful recording owns one elapsed timer tick.
          await tick.future.timeout(const Duration(seconds: 3));
          h.controller.removeListener(timerListener);
          // Then the timer is active before the stop reservation listener is attached.
          expect(h.controller.elapsedSeconds, 1);
          Future<void>? detaching;
          var reservationCalls = 0;
          var laterCalls = 0;
          void reservationListener() {
            // Given the first stop reservation before Core enters saving.
            if (reservationCalls != 0) return;
            reservationCalls++;
            // When the owner terminates synchronously at that notification.
            if (dispose) h.controller.dispose();
            detaching = h.controller.detach();
            // Then repeated detach returns the same owned cleanup future.
            expect(h.controller.detach(), same(detaching));
          }

          void laterListener() {
            laterCalls++;
          }

          h.controller.addListener(reservationListener);
          h.controller.addListener(laterListener);
          late AudioProviderAvailability ready;
          // When stop is reserved but the listener detaches before its saving action dispatches.
          final rejected = expectLater(
            h.controller.stopRecording().timeout(const Duration(seconds: 3)),
            throwsStateError,
          );
          // Then the rejected stop and cached detach settle before checking borrowed availability.
          await rejected;
          await detaching!.timeout(const Duration(seconds: 3));
          ready = await h.facade.availability().timeout(
            const Duration(seconds: 3),
          );
          // When two further timer intervals pass after cleanup settles.
          await Future<void>.delayed(const Duration(seconds: 2));
          // Then recording is cancelled once, no stop/import occurs and the timer/listeners are terminal.
          expect(reservationCalls, 1);
          expect(laterCalls, 0);
          expect(h.controller.recordingStarted, isFalse);
          expect(h.controller.elapsedSeconds, 1);
          expect(h.controller.isDetached, isTrue);
          expect(h.controller.isDisposed, dispose);
          expect(h.controller.busy, isFalse);
          expect(h.provider.starts, 1);
          expect(h.provider.recordingCancels, 1);
          expect(h.provider.stops, 0);
          expect(h.provider.playStops, 0);
          expect(h.provider.transcriptionCancels, 0);
          expect(h.provider.disposals, 0);
          expect(h.store.imports, 0);
          expect(h.store.documentWrites, 0);
          expect(h.controller.review, isNull);
          expect(h.facade.pendingOriginal, isNull);
          expect(h.facade.state, AudioCaptureState.idle);
          expect(ready.state, AudioProviderState.available);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
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
  Completer<void>? cancelGate;
  Completer<void> startEntered = Completer<void>();
  Completer<void> playEntered = Completer<void>();
  Completer<void> probeEntered = Completer<void>();
  Completer<void> prepareEntered = Completer<void>();
  Completer<void> asrEntered = Completer<void>();
  Completer<void> cancelEntered = Completer<void>();
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
    // Given owned readiness/preparation/ASR, optional held cleanup and real cleanup failure.
    // When cancellation is counted and its actual dispatch gate is signalled before any hold.
    transcriptionCancels++;
    if (!cancelEntered.isCompleted) cancelEntered.complete();
    if (cancelGate != null) await cancelGate!.future;
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
    // Then cleanup is observable, its own hold has settled and configured release settles matching work.
    expect(transcriptionCancels, greaterThan(0));
    expect(cancelGate == null || cancelGate!.isCompleted, isTrue);
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
