import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  group('explicit generated draft ownership', () {
    for (final operation in [
      GeneratedDraftOperation.textProofreading,
      GeneratedDraftOperation.textReadability,
    ]) {
      test('explicit ${operation.name} forwards probe prepare and generation without implicit IO', () async {
        // Given an exact text selected for one explicit revision operation.
        final provider = _Provider()
          ..state = GeneratedDraftAvailabilityState.downloadable;
        final controller = _controller(provider)
          ..selectSource(_text(), operation: operation);
        addTearDown(controller.dispose);
        expect(controller.operation, operation);
        expect(provider.probes, 0);
        expect(provider.preparations, 0);
        expect(provider.requests, isEmpty);
        // When the caller explicitly probes, prepares and generates.
        final readiness = await controller.checkAvailability();
        expect(readiness.operation, operation);
        final prepared = await controller.prepare();
        final attempt = await controller.generate();
        // Then every provider probe and durable request uses the admitted operation.
        expect(prepared.operation, operation);
        expect(provider.probeOperations, isNotEmpty);
        expect(provider.probeOperations, everyElement(operation));
        expect(provider.preparations, 1);
        expect(provider.requests.single.operation, operation);
        expect(provider.requests.single.source.toJson(), _text().toJson());
        expect(attempt.operation, operation);
        expect(attempt.rawText, _raw);
      });
    }

    test('same text with changed operation cancels old inference through cleanup without relabeling', () async {
      // Given proofreading in flight with separate inference and cancellation cleanup gates.
      final provider = _Provider();
      final output = Completer<GeneratedDraftProviderOutput>();
      final cleanup = Completer<bool>();
      provider.onGenerate = (_) => output.future;
      provider.onCancel = (_) => cleanup.future;
      final source = _text();
      final controller = _controller(provider)..selectSource(source,
        operation: GeneratedDraftOperation.textProofreading);
      addTearDown(controller.dispose);
      await controller.checkAvailability();
      final generation = controller.generation;
      final running = controller.generate();
      await _turn();
      // When only the operation changes before the original raw response returns.
      controller.selectSource(source, operation: GeneratedDraftOperation.textReadability);
      expect(controller.generation, generation + 1);
      expect(controller.operation, GeneratedDraftOperation.textReadability);
      expect(controller.readiness, isNull);
      expect(controller.error, isNull);
      expect(provider.cancelIds, [provider.requests.single.id]);
      output.complete(_success(cleanup: ['retained operation cleanup']));
      await _turn();
      expect(controller.busy, isTrue);
      cleanup.complete(true);
      final attempt = await running;
      // Then only canceled old-intent evidence survives and cleanup owns busy until settlement.
      expect(attempt.status, GeneratedDraftStatus.canceled);
      expect(attempt.errorCode, anyOf('canceled', 'contextChanged'));
      expect(attempt.operation, GeneratedDraftOperation.textProofreading);
      expect(attempt.source.toJson(), source.toJson());
      expect(attempt.rawText, _raw);
      expect(attempt.cleanupFailures, ['retained operation cleanup']);
      expect(controller.workspace.pending, isEmpty);
      expect(controller.workspace.decisions, isEmpty);
      expect(controller.readiness, isNull);
      expect(controller.busy, isFalse);
      provider.onGenerate = (_) async => _success();
      final fresh = await controller.generate();
      expect(fresh.operation, GeneratedDraftOperation.textReadability);
      expect(provider.requests.map((request) => request.operation), [
        GeneratedDraftOperation.textProofreading, GeneratedDraftOperation.textReadability,
      ]);
      expect(controller.workspace.attempts.first.operation,
        GeneratedDraftOperation.textProofreading);
    });

    test('invalid explicit operation leaves selection readiness errors and provider untouched', () async {
      // Given a selected and probed proofreading source plus a recorded command error.
      final provider = _Provider();
      final controller = _controller(provider, id: () => 'text-source')
        ..selectSource(_text(), operation: GeneratedDraftOperation.textProofreading);
      addTearDown(controller.dispose);
      await controller.checkAvailability();
      await expectLater(controller.generate(), throwsStateError);
      final readiness = controller.readiness;
      final error = controller.error;
      final generation = controller.generation;
      final probes = provider.probes;
      var notifications = 0;
      controller.addListener(() => notifications++);
      // When null, image/text mismatches and illegal bytes are explicitly selected.
      expect(() => controller.selectSource(null,
        operation: GeneratedDraftOperation.textProofreading), throwsArgumentError);
      for (final operation in [GeneratedDraftOperation.textProofreading,
        GeneratedDraftOperation.textReadability, GeneratedDraftOperation.textSummary]) {
        expect(() => controller.selectSource(_image(), operation: operation,
          imageBytes: Uint8List.fromList([1])), throwsArgumentError);
      }
      expect(() => controller.selectSource(_text(),
        operation: GeneratedDraftOperation.imageDescription), throwsArgumentError);
      expect(() => controller.selectSource(_text(),
        operation: GeneratedDraftOperation.textReadability,
        imageBytes: Uint8List.fromList([1])), throwsArgumentError);
      // Then public request validation has no state, notification or provider side effects.
      expect(controller.source!.toJson(), _text().toJson());
      expect(controller.operation, GeneratedDraftOperation.textProofreading);
      expect(controller.generation, generation);
      expect(controller.readiness, same(readiness));
      expect(controller.error, same(error));
      expect(controller.busy, isFalse);
      expect(notifications, 0);
      expect(provider.probes, probes);
      expect(provider.preparations, 0);
      expect(provider.requests, isEmpty);
      expect(provider.cancelIds, isEmpty);
      expect(controller.workspace.attempts, isEmpty);
    });

    test('same source and operation is a no-op even during owned inference', () async {
      // Given an active readability request with an exact selected text and readiness.
      final provider = _Provider();
      final output = Completer<GeneratedDraftProviderOutput>();
      provider.onGenerate = (_) => output.future;
      final controller = _controller(provider)..selectSource(_text(),
        operation: GeneratedDraftOperation.textReadability);
      addTearDown(controller.dispose);
      await controller.checkAvailability();
      final readiness = controller.readiness;
      final generation = controller.generation;
      final running = controller.generate();
      await _turn();
      var notifications = 0;
      controller.addListener(() => notifications++);
      // When the caller reselects an equivalent source with the same explicit operation.
      controller.selectSource(_text(), operation: GeneratedDraftOperation.textReadability);
      // Then no generation, readiness, cancellation or notification changes occur.
      expect(controller.generation, generation);
      expect(controller.readiness, same(readiness));
      expect(notifications, 0);
      expect(provider.cancelIds, isEmpty);
      output.complete(_success());
      expect((await running).status, GeneratedDraftStatus.success);
      expect(controller.workspace.pending.single.operation,
        GeneratedDraftOperation.textReadability);
    });

    test('operation-only selection change clears old readiness and error and notifies once', () async {
      // Given probed proofreading with an ID error recorded against that selection.
      final provider = _Provider();
      final controller = _controller(provider, id: () => 'text-source')
        ..selectSource(_text(), operation: GeneratedDraftOperation.textProofreading);
      addTearDown(controller.dispose);
      await controller.checkAvailability();
      await expectLater(controller.generate(), throwsStateError);
      expect(controller.readiness, isNotNull);
      expect(controller.error, isA<StateError>());
      final generation = controller.generation;
      final probes = provider.probes;
      var notifications = 0;
      controller.addListener(() => notifications++);
      // When only the admitted operation changes to readability.
      controller.selectSource(_text(), operation: GeneratedDraftOperation.textReadability);
      // Then the selection advances once and clears old readiness/error without provider work.
      expect(controller.generation, generation + 1);
      expect(controller.readiness, isNull);
      expect(controller.error, isNull);
      expect(notifications, 1);
      expect(provider.probes, probes);
      expect(provider.requests, isEmpty);
      expect(provider.cancelIds, isEmpty);
      // When selection is explicitly cleared, its operation is cleared as well.
      controller.selectSource(null);
      // Then no operation remains attached to the absent source.
      expect(controller.source, isNull);
      expect(controller.operation, isNull);
      expect(controller.generation, generation + 2);
    });

    for (final callback in ['admission', 'source', 'context']) {
      for (final stage in ['initial', 'launch', 'publication']) {
        for (final action in ['probe', 'prepare', 'generate']) {
          test('$callback operation reselection at $stage rejects retired $action intent and recovers explicitly', () async {
            // Given proofreading and one caller callback that will select readability.
            final provider = _Provider();
            final gate = Completer<void>();
            final output = Completer<GeneratedDraftProviderOutput>();
            if (action == 'prepare') {
              provider.state = GeneratedDraftAvailabilityState.downloadable;
            }
            if (stage == 'publication') {
              if (action == 'probe') provider.probeGate = gate.future;
              if (action == 'prepare') provider.prepareGate = gate.future;
              if (action == 'generate') provider.onGenerate = (_) => output.future;
            }
            var calls = 0;
            var publishing = false;
            var replaced = false;
            late GeneratedDraftController controller;
            void onCallback() {
              calls++;
              if (!replaced && (stage == 'publication' ? publishing
                  : calls == (stage == 'initial' ? 1 : 2))) {
                replaced = true;
                controller.selectSource(_text(),
                  operation: GeneratedDraftOperation.textReadability);
              }
            }
            controller = _controller(provider,
              admitted: () {
                if (callback == 'admission') onCallback();
                return true;
              },
              current: (_) {
                if (callback == 'source') onCallback();
                return true;
              },
              revision: () {
                if (callback == 'context') onCallback();
                return 1;
              })..selectSource(_text(),
                operation: GeneratedDraftOperation.textProofreading);
            addTearDown(controller.dispose);
            Future<Object> runCommand() => switch (action) {
              'probe' => controller.checkAvailability(),
              'prepare' => controller.prepare(),
              _ => controller.generate(),
            };
            // When the callback retires that command at its selected boundary.
            final running = runCommand();
            if (stage == 'publication') {
              await _turn();
              publishing = true;
              if (action == 'generate') {
                output.complete(_success());
              } else {
                gate.complete();
              }
              final result = await running;
              // Then completed work retains old provenance without publishing old readiness.
              expect(provider.probeOperations,
                everyElement(GeneratedDraftOperation.textProofreading));
              if (result is GeneratedDraftAttempt) {
                expect(result.status, GeneratedDraftStatus.canceled);
                expect(result.errorCode, 'contextChanged');
                expect(result.operation, GeneratedDraftOperation.textProofreading);
                expect(result.rawText, _raw);
                expect(controller.workspace.pending, isEmpty);
              } else {
                expect((result as GeneratedDraftAvailability).operation,
                  GeneratedDraftOperation.textProofreading);
                expect(provider.requests, isEmpty);
              }
            } else {
              await expectLater(running, throwsStateError);
              // Then a retired command never probes, prepares, infers or appends history.
              expect(provider.probes, 0);
              expect(provider.preparations, 0);
              expect(provider.requests, isEmpty);
              expect(controller.workspace.attempts, isEmpty);
            }
            expect(replaced, isTrue);
            expect(controller.operation, GeneratedDraftOperation.textReadability);
            expect(controller.readiness, isNull);
            expect(controller.workspace.decisions, isEmpty);
            expect(controller.busy, isFalse);
            // When a new explicit command is issued for the replacement selection.
            provider.onGenerate = (_) async => _success();
            final fresh = await runCommand();
            // Then only the new intent supplies current readiness and fresh provenance.
            expect(controller.readiness!.operation,
              GeneratedDraftOperation.textReadability);
            expect(provider.probeOperations.last,
              GeneratedDraftOperation.textReadability);
            if (fresh is GeneratedDraftAttempt) {
              expect(fresh.status, GeneratedDraftStatus.success);
              expect(fresh.operation, GeneratedDraftOperation.textReadability);
              expect(provider.requests.last.operation,
                GeneratedDraftOperation.textReadability);
              expect(controller.workspace.pending.single.id, fresh.id);
            }
            expect(controller.busy, isFalse);
          });
        }
      }
    }

    for (final callback in ['admission', 'source']) {
      for (final stage in ['launch', 'publication']) {
        for (final action in ['probe', 'prepare', 'generate']) {
          test('$callback context-only mutation at $stage fences $action and permits fresh recovery', () async {
            // Given a fixed proofreading selection and callbacks sharing a human context revision.
            final provider = _Provider();
            final gate = Completer<void>();
            final output = Completer<GeneratedDraftProviderOutput>();
            if (action == 'prepare') {
              provider.state = GeneratedDraftAvailabilityState.downloadable;
            }
            if (stage == 'publication') {
              if (action == 'probe') provider.probeGate = gate.future;
              if (action == 'prepare') provider.prepareGate = gate.future;
              if (action == 'generate') provider.onGenerate = (_) => output.future;
            }
            var revision = 1;
            var calls = 0;
            var publishing = false;
            var changed = false;
            void onCallback() {
              calls++;
              if (!changed && (stage == 'publication' ? publishing : calls == 2)) {
                changed = true;
                revision++;
              }
            }
            final controller = _controller(provider,
              admitted: () {
                if (callback == 'admission') onCallback();
                return true;
              },
              current: (_) {
                if (callback == 'source') onCallback();
                return true;
              }, revision: () => revision)..selectSource(_text(),
                operation: GeneratedDraftOperation.textProofreading);
            addTearDown(controller.dispose);
            final generation = controller.generation;
            Future<Object> runCommand() => switch (action) {
              'probe' => controller.checkAvailability(),
              'prepare' => controller.prepare(),
              _ => controller.generate(),
            };
            // When admission changes only context after the command captured its intent.
            final running = runCommand();
            if (stage == 'publication') {
              await _turn();
              publishing = true;
              if (action == 'generate') {
                output.complete(_success());
              } else {
                gate.complete();
              }
              final result = await running;
              // Then old work returns evidence without current readiness or adoptable raw.
              if (result is GeneratedDraftAttempt) {
                expect(result.status, GeneratedDraftStatus.canceled);
                expect(result.errorCode, 'contextChanged');
                expect(result.rawText, _raw);
                expect(controller.workspace.pending, isEmpty);
              } else {
                expect((result as GeneratedDraftAvailability).operation,
                  GeneratedDraftOperation.textProofreading);
              }
            } else {
              await expectLater(running, throwsStateError);
              // Then no provider command starts under the former human context.
              expect(provider.probes, 0);
              expect(provider.preparations, 0);
              expect(provider.requests, isEmpty);
              expect(controller.workspace.attempts, isEmpty);
            }
            expect(changed, isTrue);
            expect(controller.generation, generation);
            expect(controller.operation, GeneratedDraftOperation.textProofreading);
            expect(controller.readiness, isNull);
            expect(controller.workspace.decisions, isEmpty);
            expect(controller.busy, isFalse);
            // When the caller explicitly retries under the new human context.
            provider.onGenerate = (_) async => _success();
            final fresh = await runCommand();
            // Then fresh readiness and successful raw remain available for the same operation.
            expect(controller.readiness!.operation,
              GeneratedDraftOperation.textProofreading);
            if (fresh is GeneratedDraftAttempt) {
              expect(fresh.status, GeneratedDraftStatus.success);
              expect(controller.workspace.pending.single.id, fresh.id);
            }
            expect(controller.busy, isFalse);
          });
        }
      }
    }

    test('operation replacement during ID allocation fences launch before provider work', () async {
      // Given a proofreading command whose ID callback selects readability on the same source.
      final provider = _Provider();
      late GeneratedDraftController controller;
      controller = _controller(provider, id: () {
        controller.selectSource(_text(), operation: GeneratedDraftOperation.textReadability);
        return 'retired-operation';
      })..selectSource(_text(), operation: GeneratedDraftOperation.textProofreading);
      addTearDown(controller.dispose);
      // When the captured proofreading command attempts to launch after ID allocation.
      await expectLater(controller.generate(), throwsStateError);
      // Then the retired intent performs no provider work and records no mislabeled attempt.
      expect(provider.probes, 0);
      expect(provider.requests, isEmpty);
      expect(provider.cancelIds, isEmpty);
      expect(controller.workspace.attempts, isEmpty);
      expect(controller.operation, GeneratedDraftOperation.textReadability);
      expect(controller.busy, isFalse);
    });

    for (final action in ['probe', 'prepare']) {
      test('operation change during $action keeps old readiness out of the new selection', () async {
        // Given a proofreading readiness command blocked inside its borrowed provider.
        final provider = _Provider();
        final gate = Completer<void>();
        if (action == 'probe') {
          provider.probeGate = gate.future;
        } else {
          provider.state = GeneratedDraftAvailabilityState.downloadable;
          provider.prepareGate = gate.future;
        }
        final controller = _controller(provider)..selectSource(_text(),
          operation: GeneratedDraftOperation.textProofreading);
        addTearDown(controller.dispose);
        final running = action == 'probe' ? controller.checkAvailability() : controller.prepare();
        await _turn();
        // When the exact same text selects readability before old readiness settles.
        controller.selectSource(_text(), operation: GeneratedDraftOperation.textReadability);
        expect(controller.busy, isTrue);
        gate.complete();
        final readiness = await running;
        // Then the result still names proofreading and never publishes readiness for readability.
        expect(readiness.operation, GeneratedDraftOperation.textProofreading);
        expect(provider.probeOperations, everyElement(GeneratedDraftOperation.textProofreading));
        expect(controller.operation, GeneratedDraftOperation.textReadability);
        expect(controller.readiness, isNull);
        expect(provider.cancelIds, isEmpty);
        expect(provider.requests, isEmpty);
        expect(controller.busy, isFalse);
      });
    }

    for (final image in [false, true]) {
      for (final intent in ['accept', 'edit', 'clear', 'discard']) {
        test('${image ? "image" : "text"} $intent retains exact evidence', () async {
          // Given a real service, a ready fake provider, and caller-owned original data.
          final provider = _Provider();
          final publications = <GeneratedDraftWorkspace>[];
          final controller = _controller(provider,
            onChanged: publications.add);
          final source = image ? _image() : _text();
          final bytes = Uint8List.fromList([10, 20, 30]);
          controller.selectSource(source, imageBytes: image ? bytes : null);
          bytes[0] = 99;
          // When explicit commands produce a pending draft and a human records one intent.
          await controller.checkAvailability();
          final attempt = await controller.generate();
          expect(controller.workspace.pending.single.id, attempt.id);
          final kind = switch (intent) {
            'accept' => GeneratedDraftDecisionKind.accept,
            'discard' => GeneratedDraftDecisionKind.discard,
            _ => GeneratedDraftDecisionKind.edit,
          };
          controller.decide(attempt.id, kind,
            expectedGeneration: controller.generation,
            expectedContextRevision: controller.currentContextRevision,
            editedText: intent == 'edit' ? '人が確認した派生下書き'
                : intent == 'clear' ? '' : null);
          await controller.detach();
          final loaded = GeneratedDraftWorkspace.fromJson(
            jsonDecode(jsonEncode(controller.workspace.toJson())));
          // Then only derived history changes, and detached JSON retains source and raw output.
          expect(loaded.toJson(), controller.workspace.toJson());
          expect(loaded.attempts.single.source.toJson(), source.toJson());
          expect(loaded.attempts.single.rawText, _raw);
          expect(loaded.pending, isEmpty);
          expect(loaded.decisions.single.kind, kind);
          expect(loaded.decisions.single.editedText,
            intent == 'clear' ? '' : intent == 'edit' ? '人が確認した派生下書き' : null);
          expect(publications.length, 2);
          expect(provider.requests.single.id, isNot(source.id));
          expect(provider.requests.single.language, 'ja');
          expect(provider.requests.single.operation, image
            ? GeneratedDraftOperation.imageDescription : GeneratedDraftOperation.textSummary);
          expect(controller.operation, image
            ? GeneratedDraftOperation.imageDescription : GeneratedDraftOperation.textSummary);
          expect(provider.requests.single.imageBytes,
            image ? orderedEquals([10, 20, 30]) : isNull);
          expect(source.text, image ? isNull : ' 原文・人の注釈はそのまま。\n');
          expect(controller.isDetached, isTrue);
          controller.dispose();
        });
      }
    }

    for (final state in GeneratedDraftAvailabilityState.values) {
      test('selection is inert and ${state.name} readiness is truthful', () async {
        // Given a provider reporting one exact readiness state and no active commands.
        final provider = _Provider()..state = state;
        final controller = _controller(provider);
        controller.selectSource(_text());
        // When the caller only constructs/selects, then explicitly probes and prepares.
        expect(provider.probes, 0);
        expect(provider.requests, isEmpty);
        expect(provider.preparations, 0);
        final readiness = await controller.checkAvailability();
        expect(controller.readiness, same(readiness));
        expect(readiness.state, state);
        expect(readiness.reason, state == GeneratedDraftAvailabilityState.available
            ? isNull : '状態：${state.name}');
        expect(provider.preparations, 0);
        await controller.prepare();
        // Then only the explicit downloadable action downloads; other reasons stay exact.
        expect(provider.preparations,
          state == GeneratedDraftAvailabilityState.downloadable ? 1 : 0);
        expect(controller.readiness!.state,
          state == GeneratedDraftAvailabilityState.downloadable
              ? GeneratedDraftAvailabilityState.available : state);
        expect(provider.requests, isEmpty);
        controller.dispose();
      });
    }

    test('selection validates, copies bytes and ignores reordered equivalent metadata', () {
      // Given an image selection with caller-owned bytes and nested metadata.
      final provider = _Provider();
      final controller = _controller(provider);
      final source = _image(metadata: {'a': 1, 'b': [2, {'x': true, 'y': null}]});
      final bytes = Uint8List.fromList([1, 2]);
      controller.selectSource(source, imageBytes: bytes);
      final token = controller.generation;
      // When caller bytes change and an equivalent deep source is selected in another key order.
      bytes[0] = 8;
      controller.selectSource(_image(metadata: {'b': [2, {'y': null, 'x': true}], 'a': 1}),
        imageBytes: Uint8List.fromList([1, 2]),
        operation: GeneratedDraftOperation.imageDescription);
      // Then the immutable snapshot is stable and invalid kind/byte combinations are rejected.
      expect(controller.imageBytes, orderedEquals([1, 2]));
      expect(() => controller.imageBytes![0] = 3, throwsUnsupportedError);
      expect(controller.generation, token);
      expect(() => controller.selectSource(null, imageBytes: bytes), throwsArgumentError);
      expect(() => controller.selectSource(_image()), throwsArgumentError);
      expect(() => controller.selectSource(_text(), imageBytes: bytes), throwsArgumentError);
      expect(provider.probes, 0);
      controller.dispose();
    });

    test('owned generation serializes every command until cancellation cleanup settles', () async {
      // Given a running inference and separately blocked cancellation cleanup.
      final provider = _Provider();
      final output = Completer<GeneratedDraftProviderOutput>();
      final cleanup = Completer<bool>();
      provider.onGenerate = (_) => output.future;
      provider.onCancel = (_) => cleanup.future;
      final controller = _controller(provider)..selectSource(_text());
      final running = controller.generate();
      await _turn();
      // When other commands compete and cancel is requested before inference returns.
      await expectLater(controller.generate(), throwsStateError);
      await expectLater(controller.checkAvailability(), throwsStateError);
      await expectLater(controller.prepare(), throwsStateError);
      final cancellation = controller.cancel();
      output.complete(_success(cleanup: ['provider release warning']));
      var settled = false;
      unawaited(running.then((_) { settled = true; }));
      await _turn();
      // Then busy lasts through cleanup and cancellation names only the owned request.
      expect(controller.busy, isTrue);
      expect(settled, isFalse);
      expect(provider.cancelIds, [provider.requests.single.id]);
      cleanup.complete(false);
      expect(await cancellation, isFalse);
      final attempt = await running;
      expect(attempt.status, GeneratedDraftStatus.canceled);
      expect(attempt.errorCode, 'canceled');
      expect(attempt.rawText, _raw);
      expect(attempt.cleanupFailures, ['provider release warning']);
      expect(controller.workspace.attempts.length, 1);
      expect(controller.workspace.pending, isEmpty);
      expect(controller.busy, isFalse);
      controller.dispose();
    });

    test('source retirement cancels owned generation and keeps new readiness clear', () async {
      // Given a selected text whose owned inference has not returned.
      final provider = _Provider();
      final output = Completer<GeneratedDraftProviderOutput>();
      provider.onGenerate = (_) => output.future;
      final controller = _controller(provider)..selectSource(_text());
      final running = controller.generate();
      await _turn();
      // When a new source is selected before the original response returns.
      controller.selectSource(_text(id: 'replacement', revision: 'r2'));
      expect(controller.busy, isTrue);
      expect(controller.readiness, isNull);
      output.complete(_success());
      final attempt = await running;
      // Then the old raw response is terminal history and cannot become the new source's draft.
      expect(provider.cancelIds, [attempt.id]);
      expect(attempt.source.id, 'text-source');
      expect(attempt.status, GeneratedDraftStatus.canceled);
      expect(attempt.rawText, _raw);
      expect(controller.source!.id, 'replacement');
      expect(controller.readiness, isNull);
      expect(controller.workspace.pending, isEmpty);
      controller.dispose();
    });

    for (final cause in ['context', 'admission', 'source']) {
      test('$cause change cancels late success without losing provenance', () async {
        // Given admitted work with captured context and a still-current source.
        var revision = 1;
        var admitted = true;
        var current = true;
        final provider = _Provider();
        final output = Completer<GeneratedDraftProviderOutput>();
        provider.onGenerate = (_) => output.future;
        final controller = _controller(provider,
          revision: () => revision, admitted: () => admitted,
          current: (_) => current)..selectSource(_text());
        final running = controller.generate();
        await _turn();
        // When human context, admission or exact-source validity changes during inference.
        if (cause == 'context') revision++;
        if (cause == 'admission') admitted = false;
        if (cause == 'source') current = false;
        output.complete(_success(cleanup: ['retained cleanup']));
        final attempt = await running;
        // Then apparent success becomes contextChanged with all actual generation evidence retained.
        expect(attempt.status, GeneratedDraftStatus.canceled);
        expect(attempt.errorCode, 'contextChanged');
        expect(attempt.errorMessage, isNotEmpty);
        expect(attempt.rawText, _raw);
        expect(attempt.prompt, contains('原文'));
        expect(attempt.modelName, 'fake-model');
        expect(attempt.providerId, provider.id);
        expect(attempt.cleanupFailures, ['retained cleanup']);
        expect(attempt.startedAt, _time);
        expect(attempt.completedAt, _time);
        expect(controller.workspace.pending, isEmpty);
        controller.dispose();
      });
    }

    test('a controller with no generation never cancels a borrowed service owner', () async {
      // Given another owner running directly on the same borrowed real service.
      final provider = _Provider();
      final output = Completer<GeneratedDraftProviderOutput>();
      provider.onGenerate = (_) => output.future;
      final service = GeneratedDraftService(provider: provider, clock: () => _time);
      final external = service.generate(GeneratedDraftRequest(id: 'external-request',
        operation: GeneratedDraftOperation.textSummary, source: _text()));
      final controller = GeneratedDraftController(service: service, ownerId: 'idle-owner');
      await _turn();
      // When the idle controller selects, cancels and detaches.
      controller.selectSource(_text(id: 'idle-source'));
      expect(await controller.cancel(), isFalse);
      await controller.detach();
      output.complete(_success());
      // Then no cancellation reaches the other owner or changes its successful result.
      expect((await external).status, GeneratedDraftStatus.success);
      expect(provider.cancelIds, isEmpty);
      expect(controller.workspace.attempts, isEmpty);
      controller.dispose();
    });

    for (final retire in ['detach', 'dispose']) {
      test('$retire during generation retains old raw without replacement callbacks', () async {
        // Given an old owner with a running inference and an independent replacement owner.
        final provider = _Provider();
        final output = Completer<GeneratedDraftProviderOutput>();
        provider.onGenerate = (_) => output.future;
        var oldCallbacks = 0;
        var oldNotifications = 0;
        var replacementCallbacks = 0;
        final old = _controller(provider, onChanged: (_) => oldCallbacks++)
          ..selectSource(_text());
        final replacement = _controller(_Provider(), owner: 'replacement',
          onChanged: (_) => replacementCallbacks++);
        final running = old.generate();
        await _turn();
        old.addListener(() => oldNotifications++);
        // When the old owner terminally retires before its actual provider response.
        if (retire == 'dispose') old.dispose();
        final detached = old.detach();
        expect(identical(detached, old.detach()), isTrue);
        var detachedSettled = false;
        unawaited(detached.then((_) { detachedSettled = true; }));
        await _turn();
        expect(detachedSettled, isFalse);
        output.complete(_success());
        await running;
        await detached;
        // Then terminal raw stays inspectable only on the retired owner, without callbacks.
        expect(old.workspace.attempts.single.rawText, _raw);
        expect(old.workspace.attempts.single.status, GeneratedDraftStatus.canceled);
        expect(oldCallbacks, 0);
        expect(oldNotifications, 0);
        expect(replacementCallbacks, 0);
        expect(replacement.workspace.attempts, isEmpty);
        expect(old.busy, isFalse);
        old.dispose();
        replacement.dispose();
      });
    }

    for (final action in ['probe', 'prepare']) {
      test('detach awaits noncancellable $action and ignores late readiness', () async {
        // Given an explicit noncancellable operation blocked inside the provider.
        final provider = _Provider();
        final gate = Completer<void>();
        if (action == 'probe') {
          provider.probeGate = gate.future;
        } else {
          provider.state = GeneratedDraftAvailabilityState.downloadable;
          provider.prepareGate = gate.future;
        }
        final controller = _controller(provider)..selectSource(_text());
        final running = action == 'probe'
            ? controller.checkAvailability() : controller.prepare();
        await _turn();
        // When detach starts while the operation still owns its asynchronous work.
        final retirement = controller.detach();
        var settled = false;
        unawaited(retirement.then((_) { settled = true; }));
        await _turn();
        expect(settled, isFalse);
        expect(controller.busy, isTrue);
        gate.complete();
        await running;
        await retirement;
        // Then no unrelated cancellation or readiness publication occurs after retirement.
        expect(provider.cancelIds, isEmpty);
        expect(controller.readiness, isNull);
        expect(controller.busy, isFalse);
        controller.dispose();
      });
    }

    test('listener disposal fences reentrant launch and later listeners safely', () async {
      // Given a listener that retires its controller as soon as a command owns busy.
      final provider = _Provider();
      final controller = _controller(provider)..selectSource(_text());
      var laterCalls = 0;
      controller.addListener(() { if (controller.busy) controller.dispose(); });
      controller.addListener(() => laterCalls++);
      // When starting generation synchronously notifies that retiring listener.
      await expectLater(controller.generate(), throwsStateError);
      await controller.detach();
      // Then no provider work launches, no later stale listener runs and the guard settles.
      expect(provider.probes, 0);
      expect(provider.requests, isEmpty);
      expect(laterCalls, 0);
      expect(controller.busy, isFalse);
      expect(controller.isDisposed, isTrue);
    });

    test('listener selection change fences launch before the first provider await', () async {
      // Given a listener replacing the selected source at the command's first notification.
      final provider = _Provider();
      final controller = _controller(provider)..selectSource(_text());
      var changed = false;
      controller.addListener(() {
        if (controller.busy && !changed) {
          changed = true;
          controller.selectSource(_text(id: 'new-selection'));
        }
      });
      // When generation attempts to launch with the retired selection token.
      await expectLater(controller.generate(), throwsStateError);
      // Then the command guard recovers without generating or canceling unrelated work.
      expect(provider.probes, 0);
      expect(provider.cancelIds, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.workspace.attempts, isEmpty);
      controller.dispose();
    });

    test('ID callback image replacement rejects retired work and recovers on the new image', () async {
      // Given exact caller-owned image evidence and an ID callback selecting another image.
      final provider = _Provider();
      final publications = <GeneratedDraftWorkspace>[];
      final original = _image();
      final originalJson = original.toJson();
      final originalBytes = Uint8List.fromList([10, 20, 30]);
      final replacement = GeneratedDraftSource(id: 'replacement-image',
        materialId: 'replacement-material', revision: 'r2',
        kind: GeneratedDraftSourceKind.image);
      final replacementBytes = Uint8List.fromList([40, 50, 60]);
      var next = 0;
      late GeneratedDraftController controller;
      controller = _controller(provider, onChanged: publications.add, id: () {
        if (next == 0) {
          controller.selectSource(replacement, imageBytes: replacementBytes);
        }
        return 'image-request-${next++}';
      })..selectSource(original, imageBytes: originalBytes);
      addTearDown(controller.dispose);
      // When an admitted generation synchronously replaces its selection while obtaining an ID.
      await expectLater(controller.generate(), throwsStateError);
      // Then no retired source reaches any provider operation, publication or history.
      expect(provider.probes, 0);
      expect(provider.preparations, 0);
      expect(provider.requests, isEmpty);
      expect(provider.cancelIds, isEmpty);
      expect(publications, isEmpty);
      expect(controller.workspace.attempts, isEmpty);
      expect(controller.workspace.decisions, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.error, isA<StateError>());
      expect(controller.source!.toJson(), replacement.toJson());
      expect(controller.imageBytes, orderedEquals([40, 50, 60]));
      expect(original.toJson(), originalJson);
      expect(originalBytes, orderedEquals([10, 20, 30]));
      // When a fresh explicit request runs for the still-live owner's new selection.
      replacementBytes[0] = 99;
      final fresh = await controller.generate();
      // Then only the new image's immutable bytes and exact provenance reach inference/history.
      expect(fresh.status, GeneratedDraftStatus.success);
      expect(fresh.source.toJson(), replacement.toJson());
      expect(provider.requests.single.id, 'image-request-1');
      expect(provider.requests.single.source.toJson(), replacement.toJson());
      expect(provider.requests.single.imageBytes, orderedEquals([40, 50, 60]));
      expect(provider.preparations, 0);
      expect(provider.cancelIds, isEmpty);
      expect(controller.workspace.attempts.single.id, fresh.id);
      expect(publications.single.attempts.single.id, fresh.id);
      expect(controller.busy, isFalse);
    });

    for (final retire in ['detach', 'dispose']) {
      test('ID callback $retire prevents all provider work and settles owner retirement', () async {
        // Given an exact image and an ID callback that terminally retires this owner.
        final provider = _Provider();
        final publications = <GeneratedDraftWorkspace>[];
        final source = _image();
        final originalJson = source.toJson();
        final bytes = Uint8List.fromList([10, 20, 30]);
        late GeneratedDraftController controller;
        controller = _controller(provider, onChanged: publications.add, id: () {
          if (retire == 'dispose') {
            controller.dispose();
          } else {
            unawaited(controller.detach());
          }
          return 'retired-request';
        })..selectSource(source, imageBytes: bytes);
        addTearDown(controller.dispose);
        // When ID allocation retires the owner before a request can launch.
        await expectLater(controller.generate(), throwsStateError);
        await controller.detach();
        // Then retirement settles without probing, preparing, inferring or canceling another owner.
        expect(provider.probes, 0);
        expect(provider.preparations, 0);
        expect(provider.requests, isEmpty);
        expect(provider.cancelIds, isEmpty);
        expect(publications, isEmpty);
        expect(controller.workspace.attempts, isEmpty);
        expect(controller.workspace.decisions, isEmpty);
        expect(controller.busy, isFalse);
        expect(controller.isDetached, isTrue);
        expect(controller.isDisposed, retire == 'dispose');
        expect(controller.source!.toJson(), originalJson);
        expect(controller.imageBytes, orderedEquals([10, 20, 30]));
        expect(source.toJson(), originalJson);
        expect(bytes, orderedEquals([10, 20, 30]));
      });
    }

    test('ID callback human context change rejects launch and permits a fresh request', () async {
      // Given exact original text and an ID callback changing the human context revision.
      final provider = _Provider();
      final publications = <GeneratedDraftWorkspace>[];
      final source = _text();
      final originalJson = source.toJson();
      var revision = 1;
      var next = 0;
      final controller = _controller(provider, revision: () => revision,
        onChanged: publications.add, id: () {
          if (next == 0) revision++;
          return 'context-request-${next++}';
        })..selectSource(source);
      addTearDown(controller.dispose);
      // When generation obtains its ID after admission under the former human context.
      await expectLater(controller.generate(), throwsStateError);
      // Then the changed context prevents every provider operation and any recorded attempt.
      expect(provider.probes, 0);
      expect(provider.preparations, 0);
      expect(provider.requests, isEmpty);
      expect(provider.cancelIds, isEmpty);
      expect(publications, isEmpty);
      expect(controller.workspace.attempts, isEmpty);
      expect(controller.workspace.decisions, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.error, isA<StateError>());
      expect(controller.source!.toJson(), originalJson);
      expect(source.toJson(), originalJson);
      expect(controller.currentContextRevision, 2);
      // When the live owner explicitly generates again under that current human context.
      final fresh = await controller.generate();
      // Then only the fresh request publishes exact original text and successful provenance.
      expect(fresh.status, GeneratedDraftStatus.success);
      expect(fresh.source.toJson(), originalJson);
      expect(provider.requests.single.id, 'context-request-1');
      expect(provider.requests.single.source.toJson(), originalJson);
      expect(provider.requests.single.imageBytes, isNull);
      expect(provider.preparations, 0);
      expect(provider.cancelIds, isEmpty);
      expect(controller.workspace.attempts.single.id, fresh.id);
      expect(publications.single.attempts.single.id, fresh.id);
      expect(controller.busy, isFalse);
    });

    test('bad service clock releases the operation guard for a fresh generation', () async {
      // Given a real service whose injected clock initially violates the UTC contract.
      final provider = _Provider();
      var bad = true;
      var nextId = 0;
      final service = GeneratedDraftService(provider: provider,
        clock: () => bad ? DateTime(2026) : _time);
      final controller = GeneratedDraftController(service: service, ownerId: 'clock-owner',
        idGenerator: () => 'clock-${nextId++}')..selectSource(_text());
      // When the failing request settles and the caller fixes its clock before a fresh request.
      await expectLater(controller.generate(), throwsStateError);
      expect(controller.error, isA<StateError>());
      expect(controller.busy, isFalse);
      bad = false;
      final fresh = await controller.generate();
      // Then no fabricated terminal time is recorded and fresh real work can succeed.
      expect(controller.workspace.attempts.single.id, fresh.id);
      expect(fresh.status, GeneratedDraftStatus.success);
      expect(controller.busy, isFalse);
      controller.dispose();
    });

    test('publication failure preserves local raw and rejects reentrant mutation', () async {
      // Given a persistence callback that attempts reentrant selection and then fails.
      final provider = _Provider();
      late GeneratedDraftController controller;
      var reentrantRejected = false;
      var callbacks = 0;
      controller = _controller(provider, onChanged: (_) {
        callbacks++;
        try { controller.selectSource(_text(id: 'forbidden')); }
        on StateError { reentrantRejected = true; }
        throw StateError('caller persistence failed');
      })..selectSource(_text());
      // When successful generation publishes into that failing caller callback.
      final attempt = await controller.generate();
      // Then raw remains local, the callback error is visible and the operation guard is released.
      expect(reentrantRejected, isTrue);
      expect(callbacks, 1);
      expect(controller.error.toString(), contains('caller persistence failed'));
      expect(controller.workspace.attempts.single.rawText, _raw);
      expect(controller.workspace.pending.single.id, attempt.id);
      expect(controller.source!.id, 'text-source');
      expect(controller.busy, isFalse);
      controller.dispose();
    });

    test('callback disposal suppresses remaining listeners without losing local raw', () async {
      // Given a live owner whose publication callback disposes that same owner.
      final provider = _Provider();
      late GeneratedDraftController controller;
      controller = _controller(provider, onChanged: (_) => controller.dispose())
        ..selectSource(_text());
      var publicationNotifications = 0;
      controller.addListener(() {
        if (controller.workspace.attempts.isNotEmpty) publicationNotifications++;
      });
      // When generation reaches the callback while its operation is still owned.
      await controller.generate();
      await controller.detach();
      // Then retirement is safe and local evidence remains inspectable without stale notifications.
      expect(publicationNotifications, 0);
      expect(controller.workspace.attempts.single.rawText, _raw);
      expect(controller.isDisposed, isTrue);
      expect(controller.busy, isFalse);
    });

    test('failed provider output and cancellation cleanup failure stay terminal history', () async {
      // Given a provider with actual failed output and a later cancellation failure.
      final provider = _Provider();
      provider.onGenerate = (_) async => GeneratedDraftProviderOutput(
        status: GeneratedDraftStatus.failed, text: '失敗時の生出力',
        modelName: 'fake-model', errorCode: 'nativeFailure',
        errorMessage: '実際の生成失敗', cleanupFailures: ['output cleanup']);
      final controller = _controller(provider)..selectSource(_text());
      // When failure completes, then another in-flight request is canceled with failed cleanup.
      final failed = await controller.generate();
      final output = Completer<GeneratedDraftProviderOutput>();
      provider.onGenerate = (_) => output.future;
      provider.onCancel = (_) async => throw StateError('native cancel failed');
      final running = controller.generate();
      await _turn();
      expect(await controller.cancel(), isFalse);
      output.complete(_success());
      final canceled = await running;
      // Then both raw outcomes and precise cleanup diagnostics survive without pending adoption.
      expect(failed.errorCode, 'nativeFailure');
      expect(failed.rawText, '失敗時の生出力');
      expect(failed.cleanupFailures, ['output cleanup']);
      expect(canceled.status, GeneratedDraftStatus.canceled);
      expect(canceled.rawText, _raw);
      expect(canceled.cleanupFailures.single, contains('native cancel failed'));
      expect(controller.workspace.attempts.length, 2);
      expect(controller.workspace.pending, isEmpty);
      controller.dispose();
    });
  });

  group('explicit terminal review', () {
    for (final callback in ['admission', 'source', 'context']) {
      for (final change in ['operation', 'context']) {
        test('second decision $callback callback changing $change rejects stale acceptance and preserves old pending adoption', () async {
          // Given an old pending proofreading proposal rendered under a still-current selection.
          var revision = 1;
          var armed = false;
          var calls = 0;
          var changed = false;
          late GeneratedDraftController controller;
          void onCallback() {
            if (!armed) return;
            calls++;
            if (!changed && calls == 2) {
              changed = true;
              if (change == 'operation') {
                controller.selectSource(_text(),
                  operation: GeneratedDraftOperation.textReadability);
              } else {
                revision++;
              }
            }
          }
          controller = _controller(_Provider(),
            admitted: () {
              if (callback == 'admission') onCallback();
              return true;
            },
            current: (_) {
              if (callback == 'source') onCallback();
              return true;
            },
            revision: () {
              if (callback == 'context') onCallback();
              return revision;
            })..selectSource(_text(),
              operation: GeneratedDraftOperation.textProofreading);
          addTearDown(controller.dispose);
          final attempt = await controller.generate();
          final generation = controller.generation;
          final context = controller.currentContextRevision;
          armed = true;
          // When the second admission check retires the rendered action just before publication.
          expect(() => controller.decide(attempt.id, GeneratedDraftDecisionKind.accept,
            expectedGeneration: generation, expectedContextRevision: context),
            throwsStateError);
          // Then stale acceptance publishes no decision and preserves the original pending raw.
          expect(changed, isTrue);
          expect(controller.workspace.decisions, isEmpty);
          expect(controller.workspace.pending.single.id, attempt.id);
          expect(controller.workspace.attempts.single.rawText, _raw);
          expect(controller.workspace.attempts.single.operation,
            GeneratedDraftOperation.textProofreading);
          expect(controller.busy, isFalse);
          // When a fresh render admits that old proposal with another source and operation selected.
          armed = false;
          controller.selectSource(_text(id: 'replacement-selection'),
            operation: GeneratedDraftOperation.textReadability);
          controller.decide(attempt.id, GeneratedDraftDecisionKind.accept,
            expectedGeneration: controller.generation,
            expectedContextRevision: controller.currentContextRevision);
          // Then the individually current old proposal is adopted without rewriting its provenance.
          expect(controller.workspace.decisions.single.attemptId, attempt.id);
          expect(controller.workspace.decisions.single.kind,
            GeneratedDraftDecisionKind.accept);
          expect(controller.workspace.pending, isEmpty);
          expect(controller.workspace.attempts.single.source.id, 'text-source');
          expect(controller.workspace.attempts.single.operation,
            GeneratedDraftOperation.textProofreading);
          expect(controller.workspace.attempts.single.rawText, _raw);
          expect(controller.source!.id, 'replacement-selection');
          expect(controller.operation, GeneratedDraftOperation.textReadability);
        });
      }
    }

    for (final change in ['generation', 'context', 'admission', 'source']) {
      test('stale $change rejects adoption, obsolete source still permits discard', () async {
        // Given an exact rendered token for a retained pending successful attempt.
        var revision = 1;
        var admitted = true;
        var current = true;
        final controller = _controller(_Provider(), revision: () => revision,
          admitted: () => admitted, current: (_) => current)..selectSource(_text());
        final attempt = await controller.generate();
        final generation = controller.generation;
        final context = controller.currentContextRevision;
        // When one part of the rendered review authority changes before a retained action fires.
        if (change == 'generation') controller.selectSource(_text(id: 'another'));
        if (change == 'context') revision++;
        if (change == 'admission') admitted = false;
        if (change == 'source') current = false;
        expect(controller.canDecide(attempt.id, GeneratedDraftDecisionKind.accept,
          expectedGeneration: generation, expectedContextRevision: context), isFalse);
        expect(() => controller.decide(attempt.id, GeneratedDraftDecisionKind.accept,
          expectedGeneration: generation, expectedContextRevision: context), throwsStateError);
        // Then stale intent changes no history; a newly admitted render may discard obsolete evidence.
        expect(controller.workspace.decisions, isEmpty);
        admitted = true;
        controller.decide(attempt.id, GeneratedDraftDecisionKind.discard,
          expectedGeneration: controller.generation,
          expectedContextRevision: controller.currentContextRevision);
        expect(controller.workspace.decisions.single.kind, GeneratedDraftDecisionKind.discard);
        expect(controller.workspace.attempts.single.rawText, _raw);
        controller.dispose();
      });
    }

    test('a pending source can be adopted individually after another source is selected', () async {
      // Given retained pending evidence whose source remains current independently of selection.
      final controller = _controller(_Provider())..selectSource(_text(),
        operation: GeneratedDraftOperation.textProofreading);
      final first = await controller.generate();
      controller.selectSource(_text(id: 'next-source'),
        operation: GeneratedDraftOperation.textReadability);
      // When the human accepts the first source using the current render token.
      controller.decide(first.id, GeneratedDraftDecisionKind.accept,
        expectedGeneration: controller.generation,
        expectedContextRevision: controller.currentContextRevision);
      // Then review acts on that retained attempt rather than substituting the selected source.
      expect(controller.workspace.decisions.single.attemptId, first.id);
      expect(controller.workspace.attempts.single.source.id, 'text-source');
      expect(controller.workspace.attempts.single.operation,
        GeneratedDraftOperation.textProofreading);
      expect(controller.workspace.attempts.single.rawText, _raw);
      expect(controller.source!.id, 'next-source');
      expect(controller.operation, GeneratedDraftOperation.textReadability);
      controller.dispose();
    });

    test('bad decision clock and duplicate IDs fail explicitly and preserve prefix', () async {
      // Given a successful pending attempt and injected identity/time functions.
      var id = 'first';
      var time = _time.subtract(const Duration(seconds: 1));
      final controller = _controller(_Provider(), id: () => id, now: () => time)
        ..selectSource(_text());
      final first = await controller.generate();
      final before = jsonEncode(controller.workspace.toJson());
      // When a bad clock attempts adoption and a used inference ID attempts another generation.
      expect(() => controller.decide(first.id, GeneratedDraftDecisionKind.edit,
        editedText: '', expectedGeneration: controller.generation,
        expectedContextRevision: controller.currentContextRevision), throwsStateError);
      await expectLater(controller.generate(), throwsStateError);
      expect(jsonEncode(controller.workspace.toJson()), before);
      time = _time.add(const Duration(seconds: 1));
      id = 'fresh';
      controller.decide(first.id, GeneratedDraftDecisionKind.edit, editedText: '',
        expectedGeneration: controller.generation,
        expectedContextRevision: controller.currentContextRevision);
      await controller.generate();
      // Then honest recovery appends an empty clear and fresh attempt without rewriting evidence.
      expect(controller.workspace.decisions.single.editedText, '');
      expect(controller.workspace.attempts.map((v) => v.id), ['first', 'fresh']);
      expect(controller.workspace.attempts.first.rawText, _raw);
      expect(controller.busy, isFalse);
      controller.dispose();
    });

    test('loaded attempt IDs and source identity cannot be reused for inference', () async {
      // Given retained history loaded into a new controller with a controlled ID generator.
      final original = _controller(_Provider())..selectSource(_text());
      final retained = await original.generate();
      var id = retained.id;
      final provider = _Provider();
      final controller = _controller(provider, initial: original.workspace, id: () => id)
        ..selectSource(_text());
      // When generation is attempted with a retained attempt ID and then its source ID.
      await expectLater(controller.generate(), throwsStateError);
      id = retained.source.id;
      await expectLater(controller.generate(), throwsStateError);
      // Then no provider invocation or duplicate terminal record is created.
      expect(provider.requests, isEmpty);
      expect(controller.workspace.attempts.single.id, retained.id);
      expect(controller.busy, isFalse);
      original.dispose();
      controller.dispose();
    });
  });
}

const _raw = '\n  生成された下書き😀。 \n';
final _time = DateTime.utc(2026, 10, 30, 1);
Future<void> _turn() => Future<void>.delayed(Duration.zero);

GeneratedDraftController _controller(_Provider provider, {
  String owner = 'owner', GeneratedDraftWorkspace? initial,
  void Function(GeneratedDraftWorkspace)? onChanged,
  bool Function()? admitted,
  bool Function(GeneratedDraftSource)? current,
  Object? Function()? revision, DateTime Function()? now, String Function()? id,
}) {
  var next = 0;
  return GeneratedDraftController(
    service: GeneratedDraftService(provider: provider, clock: () => _time),
    ownerId: owner, initialWorkspace: initial, onWorkspaceChanged: onChanged,
    interactionAllowed: admitted, sourceIsCurrent: current, contextRevision: revision,
    now: now ?? () => _time.add(const Duration(seconds: 1)),
    idGenerator: id ?? () => 'request-${next++}');
}

GeneratedDraftSource _text({String id = 'text-source', String revision = 'r1'}) =>
    GeneratedDraftSource(id: id, materialId: 'original', revision: revision,
      kind: GeneratedDraftSourceKind.text, text: ' 原文・人の注釈はそのまま。\n',
      metadata: {'transcriptRevision': 2});

GeneratedDraftSource _image({Map<String, Object?> metadata = const {}}) =>
    GeneratedDraftSource(id: 'image-source', materialId: 'image-material',
      revision: 'r1', kind: GeneratedDraftSourceKind.image, metadata: metadata);

GeneratedDraftProviderOutput _success({Iterable<String> cleanup = const []}) =>
    GeneratedDraftProviderOutput(status: GeneratedDraftStatus.success,
      text: _raw, modelName: 'fake-model', cleanupFailures: cleanup);

final class _Provider implements GeneratedDraftProvider {
  @override
  String get id => 'fake-provider';
  @override
  String get promptTemplate => 'fake-template-v1';
  GeneratedDraftAvailabilityState state = GeneratedDraftAvailabilityState.available;
  int probes = 0;
  int preparations = 0;
  Future<void>? probeGate;
  Future<void>? prepareGate;
  Future<GeneratedDraftProviderOutput> Function(GeneratedDraftRequest)? onGenerate;
  Future<bool> Function(String)? onCancel;
  final List<GeneratedDraftRequest> requests = [];
  final List<GeneratedDraftOperation> probeOperations = [];
  final List<String> cancelIds = [];

  @override
  Future<GeneratedDraftAvailability> availability({
    required GeneratedDraftOperation operation, required String language,
  }) async {
    probes++;
    probeOperations.add(operation);
    await probeGate;
    return GeneratedDraftAvailability(providerId: id, operation: operation,
      language: language, state: state,
      modelName: state == GeneratedDraftAvailabilityState.available ? 'fake-model' : null,
      reason: state == GeneratedDraftAvailabilityState.available ? null : '状態：${state.name}');
  }

  @override
  Future<void> prepare() async {
    preparations++;
    await prepareGate;
    state = GeneratedDraftAvailabilityState.available;
  }

  @override
  String promptFor(GeneratedDraftRequest request) =>
      '生成指示：${request.source.text ?? request.source.id}';

  @override
  Future<GeneratedDraftProviderOutput> generate(GeneratedDraftRequest request, {
    required String prompt, String? expectedModelName,
  }) {
    requests.add(request);
    return onGenerate?.call(request) ?? Future.value(_success());
  }

  @override
  Future<bool> cancel(String requestId) {
    cancelIds.add(requestId);
    return onCancel?.call(requestId) ?? Future.value(true);
  }
}
