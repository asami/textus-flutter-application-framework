import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

Future<Finder> _visibleHandoffAction(WidgetTester tester, String label) async {
  // Given a real action, When scrolling its detail, Then its button center is hittable.
  final button = find.ancestor(of: find.text(label), matching: find.byType(TextButton));
  final scrollable = find.ancestor(of: button, matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(button, 250, scrollable: scrollable);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle(const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  for (var attempt = 0; attempt < 8; attempt++) {
    final viewport = tester.getRect(scrollable);
    final center = tester.getCenter(button);
    if (viewport.contains(center) && button.hitTestable().evaluate().length == 1) break;
    await tester.drag(scrollable,
      Offset(0, (viewport.center.dy - center.dy).clamp(-200.0, 200.0).toDouble()));
    await tester.pumpAndSettle(const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  }
  expect(tester.getRect(scrollable).contains(tester.getCenter(button)), isTrue);
  expect(button.hitTestable(), findsOneWidget);
  return button.hitTestable();
}

final class _StudioTransport implements RegisteredMaterialSubmissionTransport {
  @override
  final connection = HttpSubmissionConnection(id: 'studio',
    endpoint: Uri.parse('https://studio.example.test/book-materials'));
  int calls = 0;
  String outcome = 'accepted';
  @override
  Future<SubmissionAcknowledgement> submitRegisteredMaterial(
    RegisteredMaterialSubmissionPacket packet,
  ) async {
    calls++;
    if (outcome != 'accepted') {
      throw SubmissionAdapterException(stage: SubmissionFailureStage.transport,
        code: 'fixtureFailure', message: 'Fixture handoff failure.', retryable: false,
        transportFailureOutcome: outcome == 'failed'
            ? SubmissionTransportFailureOutcome.rejected
            : SubmissionTransportFailureOutcome.unknown);
    }
    return SubmissionAcknowledgement(requestId: packet.sourceRequest.id,
      subjectId: packet.sourceRequest.subjectId, serverId: 'actual-fixture-studio',
      receivedAt: SubmissionFixture.time);
  }
}

final class _RegisteredUiFixture {
  _RegisteredUiFixture._(this.base, this.queue);
  final SubmissionFixture base;
  final SqliteSubmissionQueueStore queue;
  final transport = _StudioTransport();
  late RegisteredMaterialHandoffService handoffs;
  late SubmissionService service;
  late SubmissionFacade facade;
  late SubmissionStatusWorkspace workspace;
  late SubmissionRequest source;

  static Future<_RegisteredUiFixture> create({
    bool originals = false, String state = 'registered',
  }) async {
    // Given real file originals and a native SQLite queue, seeded only publicly.
    final base = await SubmissionFixture.create();
    final queue = await base.openQueue();
    final f = _RegisteredUiFixture._(base, queue);
    final original = await base.request(id: 'book', subjectId: 'book',
      withMaterials: originals);
    f.source = SubmissionRequest(id: 'book', kind: 'bookMaterial', subjectId: 'book',
      createdAt: original.createdAt, document: original.document,
      payload: {'schemaVersion': 1, 'type': 'bookMaterial',
        'material': {'schemaVersion': 2, 'id': 'book'},
        'recognitionReports': <String, Object?>{}},
      materials: original.materials, transportConnectionId: 'transport',
      extensions: original.extensions,
      tklDelivery: TklMaterialDeliveryRequest(requestId: 'book', contribution: {}));
    await queue.enqueue(f.source);
    await queue.claimNext(now: base.clock, leaseToken: 'seed',
      leaseDuration: const Duration(minutes: 5));
    final digest = TklContentDigest(algorithm: 'sha256', value: 'c' * 64);
    for (final material in f.source.materials) {
      await queue.saveTklContentDigest(id: 'book', leaseToken: 'seed',
        key: material.key, digest: digest, now: base.clock);
    }
    await queue.saveTklProgress(id: 'book', leaseToken: 'seed', now: base.clock,
      progress: TklMaterialDeliverySnapshot(deliveryRef: 'fixtureDelivery',
        requestId: 'book', revision: 1, destinationId: 'fixtureLibrary',
        destinationLabel: 'Registered library',
        state: TklMaterialDeliveryState.registered,
        materialRef: 'urn:textus:klake:test:material:ui',
        resources: [for (final material in f.source.materials)
          TklOriginalTransferProgress(resourceId: material.key,
            mediaType: material.original.mediaType,
            byteLength: material.original.byteLength,
            state: TklOriginalTransferState.uploaded, contentDigest: digest,
            verificationState: TklOriginalVerificationState.verified,
            verificationAttempts: 1)],
      ));
    await queue.completeMaterialRegistration(id: 'book', leaseToken: 'seed', now: base.clock);
    f.handoffs = RegisteredMaterialHandoffService(queue: queue, store: queue,
      transports: {'studio': f.transport}, scheduler: base.scheduler, now: base.now);
    f.service = SubmissionService(queue: queue, materials: base.materials,
      storageAdapters: {'storage': base.storage}, transports: {'transport': base.transport},
      scheduler: base.scheduler, registeredMaterialHandoffs: f.handoffs, now: base.now);
    f.facade = SubmissionFacade(service: f.service);
    if (state != 'registered') {
      await f.facade.enqueueRegisteredMaterialHandoff('book', f.transport.connection);
      if (state == 'sending' || state == 'expired') {
        await queue.claimNextHandoff(now: base.clock, leaseToken: 'held',
          leaseDuration: const Duration(minutes: 5));
        if (state == 'expired') base.clock = base.clock.add(const Duration(minutes: 6));
      } else if (state != 'pending') {
        f.transport.outcome = state;
        await f.handoffs.processNext(networkAllowed: true);
      }
    }
    f.workspace = f.newWorkspace();
    return f;
  }

  SubmissionStatusWorkspace newWorkspace() => SubmissionStatusWorkspace(
    facade: facade, presentationConfiguration: submissionPresentation(), now: base.now);

  Future<RegisteredMaterialHandoffCommandResult> send(SubmissionTransferStatus status) =>
      facade.enqueueRegisteredMaterialHandoff(status.requestId, transport.connection);
  Future<RegisteredMaterialHandoffCommandResult> reconcile(SubmissionTransferStatus status) =>
      status.studioHandoff?.state == RegisteredMaterialHandoffState.pending
          ? facade.enqueueRegisteredMaterialHandoff(
              status.requestId, status.studioHandoff!.target)
          : facade.reconcileRegisteredMaterialHandoff(status.requestId);

  Future<void> select() async {
    await workspace.viewModel.load();
    await workspace.viewModel.select('book');
    workspace.displayModel.openDetail();
  }
  Future<void> close() async {
    await workspace.detach();
    await service.close();
    await handoffs.close();
    await base.dispose();
  }
}

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    for (final originals in [false, true]) {
      for (final state in ['registered', 'pending', 'sending', 'unknown', 'failed', 'expired', 'accepted']) {
        testWidgets('should passively display $state with one source and factual receipt at $size (originals=$originals)', (tester) async {
          await tester.runAsync(() async {
            // Given a genuine persisted registration and optional separately stored handoff.
            final f = await _RegisteredUiFixture.create(originals: originals, state: state);
            final wakes = f.base.scheduler.calls;
            final calls = f.transport.calls;
            try {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              // When the common page mounts, selects and explicitly refreshes observations.
              await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
                workspace: f.workspace, handoffRegisteredMaterial: f.send,
                reconcileRegisteredMaterial: f.reconcile)));
              await f.select();
              await tester.pump();
              await f.workspace.viewModel.load();
              await tester.pump();
              final record = f.workspace.viewModel.selectedResource as SubmissionStatusResourceRecord;
              final statuses = await f.facade.listTransferStatuses(observedAt: f.base.clock);
              // Then the original appears once and only real accepted ACK completes it.
              expect(statuses.length, 1);
              final summary = SubmissionStatusSummary.fromStatuses(statuses);
              expect(summary.totalCount, 1);
              expect(summary.completedCount, state == 'accepted' ? 1 : 0);
              expect(record.status.files.length, originals ? 2 : 0);
              expect(record.status.files.every((file) => file.receipt == null), isTrue);
              expect((await f.queue.find('book'))!.acknowledgement, isNull);
              expect(record.value('operations'), contains(state == 'registered'
                ? 'Studio受領: 未受領' : state == 'pending'
                ? 'Studio受領: Queued' : state == 'sending'
                ? 'Studio受領: Running' : state == 'failed'
                ? 'Studio受領: Failed' : state == 'accepted'
                ? 'Studio受領:' : 'Studio受領: Outcome unknown'));
              if (state != 'registered') {
                expect(record.value('transportDestination'), contains('TKL転送元:'));
                expect(record.value('transportDestination'), contains('Studioへの送信: Transport studio (studio)'));
              }
              final label = state == 'registered' ? '登録済み資料をStudioへ送信'
                : state == 'pending' ? '待機中のStudio送信を再開'
                : ['unknown', 'failed', 'expired'].contains(state) ? 'Studioの受領状況を照合' : null;
              if (label != null) {
                await tester.scrollUntilVisible(find.text(label), 250,
                  scrollable: find.byType(Scrollable).last);
                expect(find.text(label), findsOneWidget);
              } else {
                expect(find.text('登録済み資料をStudioへ送信'), findsNothing);
                expect(find.text('待機中のStudio送信を再開'), findsNothing);
                expect(find.text('Studioの受領状況を照合'), findsNothing);
              }
              expect(find.textContaining('保存日時:'), findsNothing);
              expect(find.textContaining('受領済みサーバーID:'), state == 'accepted' ? findsOneWidget : findsNothing);
              if (label == 'Studioの受領状況を照合') {
                expect(find.textContaining('Studioが未受領の場合は、この操作で送信が行われることがあります。'), findsOneWidget);
              } else if (state == 'pending') {
                expect(find.textContaining('同じ保存済みリクエストでバックグラウンド処理の手配を再開します。'), findsOneWidget);
                expect(find.textContaining('照合では同じリクエストを再送します。Studioが未受領の場合は、この操作で送信が行われることがあります。'), findsNothing);
                expect(find.text('Studioの受領状況を照合'), findsNothing);
              }
              expect(f.base.scheduler.calls, wakes);
              expect(f.transport.calls, calls);
              expect(f.base.storage.uploads + f.base.transport.submits, 0);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await f.close();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          });
        });
      }
      testWidgets('should reject a stale pending resume and refresh unknown guidance at $size (originals=$originals)', (tester) async {
        await tester.runAsync(() async {
          // Given selected pending detail that still presents scheduling-only guidance.
          final f = await _RegisteredUiFixture.create(originals: originals, state: 'pending');
          var callbacks = 0;
          try {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
              workspace: f.workspace, reconcileRegisteredMaterial: (status) {
                callbacks++;
                return f.reconcile(status);
              })));
            await f.select();
            await tester.pump();
            final saved = (await f.queue.findHandoffForSource('book'))!;
            final source = (await f.queue.find('book'))!;
            final button = await _visibleHandoffAction(tester, '待機中のStudio送信を再開');
            final wakes = f.base.scheduler.calls;
            // When real background processing records uncertainty before the stale button is tapped.
            f.transport.outcome = 'unknown';
            await f.handoffs.processNext(networkAllowed: true).timeout(const Duration(seconds: 5));
            final unknown = (await f.queue.findHandoffForSource('book'))!;
            expect(unknown.state, RegisteredMaterialHandoffState.outcomeUnknown);
            await tester.tap(button);
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (f.workspace.binding.actionBusy ||
                (f.workspace.viewModel.selectedResource as SubmissionStatusResourceRecord?)
                    ?.status.studioHandoff?.state != RegisteredMaterialHandoffState.outcomeUnknown) {
              if (DateTime.now().isAfter(deadline)) throw StateError('Expected unknown detail refresh.');
              await Future<void>.delayed(const Duration(milliseconds: 10));
              await tester.pump();
            }
            await tester.pump();
            // Then no caller or second wake runs and actual selected detail shows reconciliation guidance.
            expect(callbacks, 0);
            expect(await f.queue.findHandoffForSource('book'), unknown);
            expect(unknown.id, saved.id);
            expect(unknown.packet, saved.packet);
            expect(unknown.target.toJson(), saved.target.toJson());
            expect(unknown.sourceRequest, source.request);
            expect(unknown.acknowledgement, isNull);
            expect(f.base.scheduler.calls, wakes);
            expect((await f.handoffs.processNext(networkAllowed: true)).outcome,
              RegisteredMaterialHandoffRunOutcome.noWork);
            expect(f.transport.calls, 1);
            expect(await f.queue.find('book'), source);
            expect((await f.queue.find('book'))!.acknowledgement, isNull);
            expect(f.base.storage.uploads + f.base.transport.submits, 0);
            expect(find.text('待機中のStudio送信を再開'), findsNothing);
            expect(find.text('Studioの受領状況を照合'), findsOneWidget);
            expect(find.textContaining('照合では同じリクエストを再送します。Studioが未受領の場合は、この操作で送信が行われることがあります。'), findsOneWidget);
            expect(find.textContaining('受領済みサーバーID:'), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await f.close();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        });
      });

      testWidgets('should resume a saved pending handoff once after wake failure at $size (originals=$originals)', (tester) async {
        await tester.runAsync(() async {
          // Given a durable pending handoff whose initial background wake failed.
          final f = await _RegisteredUiFixture.create(originals: originals);
          final gate = SubmissionGate();
          try {
            f.base.scheduler.fail = true;
            final initial = await f.send((await f.facade.findTransferStatus('book', observedAt: f.base.clock))!);
            expect(initial.schedulingFailed, isTrue);
            final saved = initial.record;
            final wakes = f.base.scheduler.calls;
            f.base.scheduler.fail = false;
            f.base.scheduler.gate = gate;
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
              workspace: f.workspace, reconcileRegisteredMaterial: f.reconcile)));
            await f.select();
            await tester.pump();
            expect(f.base.scheduler.calls, wakes);
            expect(find.textContaining('照合では同じリクエストを再送します。Studioが未受領の場合は、この操作で送信が行われることがあります。'), findsNothing);
            // When the actual pending resume action is tapped repeatedly before wake settles.
            final button = await _visibleHandoffAction(tester, '待機中のStudio送信を再開');
            await tester.tap(button);
            await tester.tap(button);
            await gate.entered.future.timeout(const Duration(seconds: 5));
            expect(f.base.scheduler.calls, wakes + 1);
            gate.release();
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (f.workspace.binding.actionBusy) {
              if (DateTime.now().isAfter(deadline)) throw StateError('Expected pending resume settlement.');
              await Future<void>.delayed(const Duration(milliseconds: 10));
              await tester.pump();
            }
            // Then only one wake occurs and the whole frozen intent and original source survive.
            final resumed = (await f.facade.findRegisteredMaterialHandoff('book'))!;
            expect(resumed, saved);
            expect(resumed.id, saved.id);
            expect(resumed.packet, saved.packet);
            expect(resumed.target.toJson(), saved.target.toJson());
            expect(resumed.sourceRequest, f.source);
            expect(resumed.acknowledgement, isNull);
            expect((await f.queue.find('book'))!.request, f.source);
            expect((await f.queue.find('book'))!.acknowledgement, isNull);
            expect(f.base.scheduler.calls, wakes + 1);
            expect(f.transport.calls, 0);
            expect(f.base.storage.uploads + f.base.transport.submits, 0);
            expect(tester.takeException(), isNull);
          } finally {
            gate.release();
            await tester.pumpWidget(const SizedBox.shrink());
            await f.close();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        });
      });
    }
  }

  testWidgets('should refresh selected detail after explicit handoff without claiming acceptance', (tester) async {
    await tester.runAsync(() async {
      // Given a selected Registered source with no Studio handoff or receipt.
      final f = await _RegisteredUiFixture.create();
      try {
        await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
          workspace: f.workspace, handoffRegisteredMaterial: f.send)));
        await f.select();
        await tester.pump();
        final original = f.workspace.viewModel.selectedResource;
        // When the operator taps the real action and its guarded refresh settles.
        final button = await _visibleHandoffAction(tester, '登録済み資料をStudioへ送信');
        await tester.tap(button);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while ((f.workspace.viewModel.selectedResource as SubmissionStatusResourceRecord?)
            ?.status.studioHandoff?.state != RegisteredMaterialHandoffState.pending) {
          if (DateTime.now().isAfter(deadline)) throw StateError('Expected pending selected detail.');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        await tester.pump();
        // Then the same selected source has a fresh pending detail with no ACK or remote call.
        final record = f.workspace.viewModel.selectedResource as SubmissionStatusResourceRecord;
        expect(f.workspace.viewModel.selectedId, 'book');
        expect(identical(record, original), isFalse);
        expect(record.status.studioHandoff!.state, RegisteredMaterialHandoffState.pending);
        expect(record.status.acknowledgement, isNull);
        expect((await f.queue.find('book'))!.acknowledgement, isNull);
        expect(find.textContaining('受領済みサーバーID:'), findsNothing);
        expect(find.text('登録済み資料をStudioへ送信'), findsNothing);
        expect(f.base.scheduler.calls, 1);
        expect(f.transport.calls, 0);
        expect(f.base.storage.uploads + f.base.transport.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await f.close();
      }
    });
  });

  testWidgets('should single-flight explicit handoff and join an issued callback on retirement', (tester) async {
    await tester.runAsync(() async {
      // Given a real Registered source with an explicitly held domain callback.
      final f = await _RegisteredUiFixture.create();
      final gate = SubmissionGate();
      var callbacks = 0;
      Future<RegisteredMaterialHandoffCommandResult> send(SubmissionTransferStatus status) async {
        callbacks++;
        final result = await f.send(status);
        await gate.wait();
        return result;
      }
      try {
        await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
          workspace: f.workspace, handoffRegisteredMaterial: send)));
        await f.select();
        await tester.pump();
        final button = await _visibleHandoffAction(tester, '登録済み資料をStudioへ送信');
        // When repeated taps precede callback settlement and the route retires.
        await tester.tap(button);
        await tester.tap(button);
        await gate.entered.future.timeout(const Duration(seconds: 5));
        expect(callbacks, 1);
        var detached = false;
        final join = f.workspace.detach().then((_) => detached = true);
        await tester.pumpWidget(const SizedBox.shrink());
        await Future<void>.delayed(Duration.zero);
        // Then detach waits accepted callback work and late result cannot publish.
        expect(detached, isFalse);
        gate.release();
        await join.timeout(const Duration(seconds: 5));
        expect(detached, isTrue);
        expect(f.base.scheduler.calls, 1);
        expect(f.transport.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        gate.release();
        await tester.pumpWidget(const SizedBox.shrink());
        await f.close();
      }
    });
  });

  test('should reject changed selection before dispatch and never borrow missing capability', () async {
    // Given actual native queue status and an accepted fresh-status read.
    final f = await _RegisteredUiFixture.create();
    addTearDown(f.close);
    await f.select();
    final selected = f.workspace.viewModel.selectedResource;
    var calls = 0;
    final action = f.workspace.binding.performRegisteredMaterialAction(
      sourceRequestId: 'book', reconcile: false,
      isCurrent: () => f.workspace.viewModel.selectedId == 'book' &&
          identical(f.workspace.viewModel.selectedResource, selected),
      action: (status) { calls++; return f.send(status); });
    // When selection authority retires before the awaited lookup resumes.
    final selection = f.workspace.viewModel.select('absent');
    await expectLater(action, throwsStateError);
    await selection;
    // Then no domain callback or wake runs, and legacy compositions reject explicitly.
    expect(calls, 0);
    expect(f.base.scheduler.calls, 0);
    final legacy = SubmissionFacade(service: f.base.service(f.queue));
    expect(legacy.supportsRegisteredMaterialHandoff, isFalse);
    expect(() => legacy.findRegisteredMaterialHandoff('book'), throwsStateError);
  });

  testWidgets('should suppress a late failed handoff result after workspace replacement', (tester) async {
    await tester.runAsync(() async {
      // Given a current page whose explicit callback is in flight.
      final f = await _RegisteredUiFixture.create();
      final gate = SubmissionGate();
      final replacement = f.newWorkspace();
      try {
        await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
          workspace: f.workspace, handoffRegisteredMaterial: (status) async {
            await gate.wait();
            throw StateError('private callback detail');
          })));
        await f.select();
        await tester.pump();
        final button = await _visibleHandoffAction(tester, '登録済み資料をStudioへ送信');
        await tester.tap(button);
        await gate.entered.future.timeout(const Duration(seconds: 5));
        // When the same page state receives another workspace before settlement.
        await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(workspace: replacement)));
        gate.release();
        await f.workspace.detach();
        await tester.pump();
        // Then neither the raw error nor a stale failure notice reaches replacement UI.
        expect(find.textContaining('private callback detail'), findsNothing);
        expect(find.text('Studioへの送信操作を実行できませんでした。'), findsNothing);
        expect(f.base.scheduler.calls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        gate.release();
        await tester.pumpWidget(const SizedBox.shrink());
        await replacement.detach();
        await f.close();
      }
    });
  });

  testWidgets('should reconcile only on explicit warning action using the same source', (tester) async {
    await tester.runAsync(() async {
      // Given an unknown handoff and the original frozen packet.
      final f = await _RegisteredUiFixture.create(state: 'unknown');
      final saved = (await f.facade.findRegisteredMaterialHandoff('book'))!;
      final done = Completer<void>();
      try {
        await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
          workspace: f.workspace, reconcileRegisteredMaterial: (status) async {
            expect(status.requestId, 'book');
            final result = await f.reconcile(status);
            done.complete();
            return result;
          })));
        await f.select();
        await tester.pump();
        final wakes = f.base.scheduler.calls;
        // When the operator explicitly taps the action adjacent to the warning.
        final button = await _visibleHandoffAction(tester, 'Studioの受領状況を照合');
        expect(find.textContaining('照合では同じリクエストを再送します。Studioが未受領の場合は、この操作で送信が行われることがあります。'), findsOneWidget);
        await tester.tap(button);
        await done.future.timeout(const Duration(seconds: 5));
        // Then only the same source packet is replayed and no transport is invoked by UI.
        expect((await f.facade.findRegisteredMaterialHandoff('book'))!.packet, saved.packet);
        expect(f.base.scheduler.calls, wakes + 1);
        expect(f.transport.calls, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await f.close();
      }
    });
  });

  for (final schedulingFailure in [false, true]) {
    testWidgets('should show safe explicit action outcome without claiming acceptance (schedulingFailure=$schedulingFailure)', (tester) async {
      await tester.runAsync(() async {
        // Given a Registered source and a domain failure or a durable wake failure.
        final f = await _RegisteredUiFixture.create();
        f.base.scheduler.fail = schedulingFailure;
        try {
          await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(
            workspace: f.workspace, handoffRegisteredMaterial: (status) {
              if (!schedulingFailure) throw StateError('private domain error');
              return f.send(status);
            })));
          await f.select();
          await tester.pump();
          // When the real explicit action settles and the current page refreshes once.
          final button = await _visibleHandoffAction(tester, '登録済み資料をStudioへ送信');
          await tester.tap(button);
          final notice = schedulingFailure
              ? 'Studioへの送信は登録済みです。バックグラウンド処理の手配を確認してください。'
              : 'Studioへの送信操作を実行できませんでした。';
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (find.text(notice).evaluate().isEmpty) {
            if (DateTime.now().isAfter(deadline)) throw StateError('Expected safe action notice.');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
          // Then safe current UI separates queued intent from acknowledgement.
          expect(find.text(notice), findsOneWidget);
          expect(find.textContaining('private domain error'), findsNothing);
          expect(find.textContaining('受領済みサーバーID:'), findsNothing);
          expect(f.base.scheduler.calls, schedulingFailure ? 1 : 0);
          expect((await f.handoffs.list()).length, schedulingFailure ? 1 : 0);
          expect(f.transport.calls, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await f.close();
        }
      });
    });
  }
}
