import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';
import 'tkl_submission_status_page_test.dart' show persistIntegrityScenario;

void main() {
  test('DU03 absent verification remains unreported across native reopen and passive queries', () async {
    // Given placed originals in the native queue with preparation but no server proof.
    final fixture = await SubmissionFixture.create();
    final queue = await fixture.openQueue();
    await persistIntegrityScenario(fixture, queue, id: 'unreported',
      state: TklMaterialDeliveryState.transferring);
    final reopened = await fixture.openQueue();
    final binding = SubmissionStatusBinding(
      facade: SubmissionFacade(service: fixture.service(reopened)),
      presentationConfiguration: submissionPresentation(), now: fixture.now,
    );
    try {
      // When querying list and detail through the borrowing binding after reopening.
      final listed = (await binding.listResources()).single;
      final detail = await binding.getResource('unreported') as SubmissionStatusResourceRecord;
      // Then byte placement is complete but absent independent proof has no success label.
      expect(detail.value('operations'),
        '準備: Succeeded (2/2)\nアップロード: Succeeded (2/2)\n'
        '原本の整合性確認: 未記録\nTKL登録: Running\nStudio受領: 未受領');
      expect(listed.value('operations'), detail.value('operations'));
      expect(detail.status.tklProgress!.materialRef, isNull);
      expect(binding.actionsFor(detail), isEmpty);
      expect(detail.values.values.join(), isNot(contains('secret.invalid')));
      expect(fixture.scheduler.calls, 0);
      expect(fixture.storage.uploads, 0);
      expect(fixture.transport.submits, 0);
    } finally {
      await binding.detach();
      await fixture.dispose();
    }
  });
  test('DU03 queued preparation exposes only the actual explicit request-run action', () async {
    // Given partial durable hashing released back to its existing queue.
    final fixture = await SubmissionFixture.create();
    final queue = await fixture.openQueue();
    await persistIntegrityScenario(fixture, queue, id: 'partial', prepared: 1);
    await queue.release(id: 'partial', leaseToken: 'partial', now: fixture.clock);
    final binding = SubmissionStatusBinding(
      facade: SubmissionFacade(service: fixture.service(queue)),
      presentationConfiguration: submissionPresentation(), now: fixture.now,
    );
    try {
      // When reading the actual available commands.
      final record = await binding.getResource('partial') as SubmissionStatusResourceRecord;
      // Then no reset, reprepare or speculative retry action is invented.
      expect(binding.actionsFor(record).map((action) => action.id), ['requestRun']);
      expect(fixture.scheduler.calls, 0);
      // Given the supported explicit command, When the operator requests a run.
      await binding.execute('requestRun', record);
      // Then only the existing scheduler is notified; UI does not dispatch bytes.
      expect(fixture.scheduler.calls, 1);
      expect(fixture.storage.prepares, 0);
      expect(fixture.storage.uploads, 0);
      expect(fixture.transport.submits, 0);
    } finally {
      await binding.detach();
      await fixture.dispose();
    }
  });
  group('Fresh transfer resource queries and explicit actions', () {
    late SubmissionFixture fixture;
    late SqliteSubmissionQueueStore queue;
    late SubmissionService service;
    late SubmissionFacade facade;
    late SubmissionRequest request;
    late SubmissionStatusBinding binding;

    setUp(() async {
      // Construct borrowed adapters over real IO and controlled ports without
      // starting a runner, scheduler or network operation.
      fixture = await SubmissionFixture.create();
      queue = await fixture.openQueue();
      service = fixture.service(queue);
      facade = SubmissionFacade(service: service);
      request = await fixture.request();
      binding = SubmissionStatusBinding(
        facade: facade,
        presentationConfiguration: submissionPresentation(),
        now: fixture.now,
      );
    });
    tearDown(() async {
      // Release every controlled gate and join accepted binding work before
      // cleaning up service, queue and artifact owners.
      fixture.access.gate?.release();
      fixture.scheduler.gate?.release();
      fixture.storage.gate?.release();
      fixture.transport.gate?.release();
      try {
        await binding.detach();
      } finally {
        await fixture.dispose();
      }
    });

    test(
      'CF3 fresh typed immutable list/detail retain both operations',
      () async {
        // Given a constructed binding and explicit immutable Commit.
        expect(fixture.scheduler.calls, 0);
        expect(await binding.listResources(), isEmpty);
        await facade.commit(request);
        // When querying both resource shapes over the exact Core observation.
        final resources = await binding.listResources();
        final listed = resources.single as SubmissionStatusResourceRecord;
        final detail = await binding.getResource(
          request.id,
        ) as SubmissionStatusResourceRecord;
        final actual = await facade.findTransferStatus(
          request.id,
          observedAt: fixture.clock,
        );
        // Then immutable Core values and configured text expose separate operations.
        expect(listed.status, actual);
        expect(detail.status, actual);
        expect(listed.id, request.id);
        expect(listed.value('name'), 'Item subject1');
        expect(
          listed.value('operations'),
          'Original upload: Queued\nServer submission: Waiting',
        );
        expect(listed.value('storageDestination'), 'Storage storage');
        expect(listed.value('transportDestination'), 'Transport transport');
        expect(listed.value('submissionWaiting'), 'Waiting for upload');
        expect(listed.value('nextAttemptAt'), isEmpty);
        expect(listed.value('acknowledgement'), isEmpty);
        expect(() => resources.clear(), throwsUnsupportedError);
        expect(() => listed.values.clear(), throwsUnsupportedError);
        expect(binding.configuration.primaryField, 'name');
        expect(binding.configuration.secondaryField, 'operations');
        expect(binding.configuration.detailFields.map((field) => field.key), [
          'name',
          'operations',
          'upload',
          'submission',
          'storageDestination',
          'transportDestination',
          'updatedAt',
          'uploadWaiting',
          'submissionWaiting',
          'uploadFailure',
          'submissionFailure',
          'nextAttemptAt',
          'acknowledgement',
        ]);
        expect(await binding.getResource('absent'), isNull);
        expect(fixture.scheduler.calls, 1);
        expect(fixture.storage.uploads, 0);
        expect(fixture.transport.submits, 0);
        // Given explicitly changed durable receipts.
        await fixture.uploadAll(service);
        // When observing the resource afresh.
        final changed = await binding.getResource(
          request.id,
        ) as SubmissionStatusResourceRecord;
        // Then no stale cache survives and the prior observation remains immutable.
        expect(
          changed.status.upload.state,
          SubmissionTransferOperationState.succeeded,
        );
        expect(
          changed.value('operations'),
          'Original upload: Succeeded\nServer submission: Queued',
        );
        expect(
          listed.status.upload.state,
          SubmissionTransferOperationState.queued,
        );
        expect((await queue.list()).length, 1);
        expect(binding.actionsFor(changed).single.id, 'requestRun');
        expect(binding.actionsFor(changed).single.label, 'Request run');
      },
    );

    test('CF3 actual policy and queue faults remain errors or resource failure flags', () async {
      // Given uploaded intent and a genuine controlled Core policy fault.
      await facade.commit(request);
      await fixture.uploadAll(service);
      fixture.access.fail = true;
      final model = ResourceViewModel(
        dataSource: binding,
        actionHandler: binding,
      );
      try {
        // When direct queries and existing semantic views encounter the fault.
        await expectLater(
          binding.listResources(),
          throwsA(
            isA<SubmissionConfigurationException>().having(
              (error) => error.code,
              'query failure',
              'configurationUnavailable',
            ),
          ),
        );
        await expectLater(
          binding.getResource(request.id),
          throwsA(isA<SubmissionConfigurationException>()),
        );
        await model.load();
        await model.select(request.id);
        // Then errors never publish empty success or acceptance.
        expect(model.listFailed, isTrue);
        expect(model.detailFailed, isTrue);
        expect(model.resources, isNull);
        expect(model.selectedResource, isNull);
        expect(binding.lastActionResult, isNull);
        // When the controlled policy recovers and the model reloads.
        fixture.access.fail = false;
        await model.load();
        // Then the current live list recovers.
        expect(model.listFailed, isFalse);
        expect(model.resources!.single.id, request.id);
        // When the real queue closes and subsequent query and loading fail.
        await queue.close();
        await expectLater(binding.getResource('absent'), throwsStateError);
        await model.load();
        // Then the list fails without a new wake or transport operation.
        expect(model.listFailed, isTrue);
        expect(fixture.scheduler.calls, 1);
        expect(fixture.transport.submits, 0);
      } finally {
        // Dispose borrowed semantic views as their owner retires.
        model.dispose();
      }
    });

    test('CF4 foreign unknown and stale observed actions reject before dispatch', () async {
      // Given a displayed retry after controlled storage failure.
      await facade.commit(request);
      fixture.storage.failKey = 'audio';
      await fixture.uploadAll(service);
      final displayed = await binding.getResource(
        request.id,
      ) as SubmissionStatusResourceRecord;
      final foreign = ResourceRecord(id: request.id, values: {});
      final wakes = fixture.scheduler.calls;
      // When foreign/unknown actions and a retry made stale by a durable transition execute.
      expect(binding.actionsFor(foreign), isEmpty);
      await expectLater(binding.execute('retry', foreign), throwsStateError);
      await expectLater(
        binding.execute('unknown', displayed),
        throwsStateError,
      );
      await queue.retry(id: request.id, now: fixture.clock);
      await expectLater(binding.execute('retry', displayed), throwsStateError);
      // Then fresh validation prevents any command wake or fabricated requeue.
      expect(fixture.scheduler.calls, wakes);
      expect(binding.actionBusy, isFalse);
      expect(binding.lastActionResult, isNull);
      expect(
        (await queue.find(request.id))!.state,
        SubmissionState.readyToSubmit,
      );
      expect(fixture.storage.uploads, 2);
      expect(fixture.transport.submits, 0);
    });

    test('CF4 missing fresh intent rejects and one live command retains exact result', () async {
      // Given an actual immutable Core observation whose request is absent from this queue.
      final absentRequest = await fixture.request(
        id: 'absent',
        subjectId: 'absentSubject',
        withMaterials: false,
      );
      final absentStatus = SubmissionTransferStatus.fromRecord(
        SubmissionRecord(
          request: absentRequest,
          state: SubmissionState.readyToSubmit,
          claimCount: 0,
          updatedAt: fixture.clock,
        ),
        observedAt: fixture.clock,
      );
      final absent = SubmissionStatusResourceRecord(
        status: absentStatus,
        configuration: submissionPresentation(),
      );
      // When the absent observed action executes.
      await expectLater(
        binding.execute('requestRun', absent),
        throwsStateError,
      );
      // Then the missing fresh query invents no durable intent or wake.
      expect(fixture.scheduler.calls, 0);
      expect(await queue.find('absent'), isNull);
      // Given a real ready row and a held wake gate.
      await facade.commit(request);
      final displayed = await binding.getResource(
        request.id,
      ) as SubmissionStatusResourceRecord;
      final gate = SubmissionGate();
      fixture.scheduler.gate = gate;
      // When the first caller and a concurrent caller request a run.
      final action = binding.execute('requestRun', displayed);
      await gate.entered.future.timeout(const Duration(seconds: 5));
      await expectLater(
        binding.execute('requestRun', displayed),
        throwsStateError,
      );
      // Then the single synchronous reservation remains busy.
      expect(binding.actionBusy, isTrue);
      // When the accepted wake releases and its command joins.
      gate.release();
      await action;
      final result = binding.lastActionResult!;
      // Then the exact command result is retained without acknowledgement or transport.
      expect(result, same(binding.lastActionResult));
      expect(result.record, await queue.find(request.id));
      expect(result.record.acknowledgement, isNull);
      expect(result.schedulingFailure, isNull);
      expect(binding.actionBusy, isFalse);
      expect(fixture.scheduler.calls, 2);
      expect(fixture.transport.submits, 0);
    });

    test('CF4 detach before held query joins every accepted read and prevents command', () async {
      // Given uploaded intent displaying a supported requestRun action.
      await facade.commit(request);
      await fixture.uploadAll(service);
      final displayed = await binding.getResource(
        request.id,
      ) as SubmissionStatusResourceRecord;
      final gate = SubmissionGate();
      fixture.access.gate = gate;
      final wakes = fixture.scheduler.calls;
      // When an action holds a fresh query and a concurrent click repeats.
      final action = binding.execute('requestRun', displayed);
      final actionExpectation = expectLater(action, throwsStateError);
      // Then the held query keeps its accepted action busy.
      expect(binding.actionBusy, isTrue);
      await expectLater(
        binding.execute('requestRun', displayed),
        throwsStateError,
      );
      await gate.entered.future.timeout(const Duration(seconds: 5));
      final readExpectation = expectLater(
        binding.listResources(),
        throwsStateError,
      );
      final detached = binding.detach();
      var joined = false;
      void markJoined() {
        // Record completion of the detach join for this test.
        joined = true;
      }

      detached.then((_) => markJoined());
      await Future<void>.value();
      // Then retirement is synchronous and the idempotent join waits for all accepted work.
      expect(binding.isDetached, isTrue);
      expect(binding.detach(), same(detached));
      expect(joined, isFalse);
      expect(binding.actionsFor(displayed), isEmpty);
      await expectLater(binding.getResource(request.id), throwsStateError);
      await expectLater(
        binding.execute('requestRun', displayed),
        throwsStateError,
      );
      // When the held query releases and all accepted work joins.
      gate.release();
      await actionExpectation;
      await readExpectation;
      await detached;
      // Then retirement joins without publishing an action result or dispatching a command.
      expect(joined, isTrue);
      expect(binding.lastActionResult, isNull);
      expect(binding.actionBusy, isFalse);
      expect(fixture.scheduler.calls, wakes);
      expect((await service.find(request.id))!.request, request);
      expect(
        (await queue.find(request.id))!.state,
        SubmissionState.readyToSubmit,
      );
    });

    test(
      'CF4 detach after command entry permits durable finish and fences result',
      () async {
        // Given ready intent with a controlled held wake command.
        await facade.commit(request);
        final displayed = await binding.getResource(
          request.id,
        ) as SubmissionStatusResourceRecord;
        final gate = SubmissionGate();
        fixture.scheduler.gate = gate;
        // When Core command entry precedes synchronous route retirement.
        final actionExpectation = expectLater(
          binding.execute('requestRun', displayed),
          throwsStateError,
        );
        await gate.entered.future.timeout(const Duration(seconds: 5));
        final detached = binding.detach();
        var joined = false;
        void markJoined() {
          // Record completion of accepted Core work for this test.
          joined = true;
        }

        detached.then((_) => markJoined());
        await Future<void>.value();
        // Then retirement waits for the held command and retains its busy reservation.
        expect(joined, isFalse);
        expect(binding.actionBusy, isTrue);
        await expectLater(
          binding.execute('requestRun', displayed),
          throwsStateError,
        );
        // When the held wake releases and the accepted command joins.
        gate.release();
        await actionExpectation;
        await detached;
        // Then exactly one initiated command finishes without any late published result.
        expect(joined, isTrue);
        expect(fixture.scheduler.calls, 2);
        expect(binding.lastActionResult, isNull);
        expect(binding.actionBusy, isFalse);
        expect((await service.find(request.id))!.request, request);
        expect(
          (await queue.find(request.id))!.state,
          SubmissionState.readyToSubmit,
        );
        expect(fixture.transport.submits, 0);
      },
    );

    test('CF4 reentrant observation callbacks cannot dispatch after detach', () async {
      // Given actual ready intent and a caller clock that retires its binding.
      await facade.commit(request);
      final status = (await facade.findTransferStatus(
        request.id,
        observedAt: fixture.clock,
      ))!;
      final record = SubmissionStatusResourceRecord(
        status: status,
        configuration: submissionPresentation(),
      );
      await binding.detach();
      DateTime retiringClock() {
        // Retire the binding during observation and return only the clock fact.
        binding.detach();
        return fixture.clock;
      }

      binding = SubmissionStatusBinding(
        facade: facade,
        presentationConfiguration: submissionPresentation(),
        now: retiringClock,
      );
      // When executing an action invokes the reentrant clock.
      await expectLater(
        binding.execute('requestRun', record),
        throwsStateError,
      );
      await binding.detach();
      // Then no Core wake follows detach.
      expect(fixture.scheduler.calls, 1);
      SubmissionNetworkState retiringNetwork() {
        // Retire during observation; the returned connectivity fact grants no command authority.
        binding.detach();
        return SubmissionNetworkState.allowed;
      }

      binding = SubmissionStatusBinding(
        facade: facade,
        presentationConfiguration: submissionPresentation(),
        now: fixture.now,
        networkState: retiringNetwork,
      );
      // When a network-bound read invokes the retiring callback.
      await expectLater(binding.listResources(), throwsStateError);
      await binding.detach();
      // Then no policy query, wake or transport follows detach.
      expect(fixture.access.calls, 0);
      expect(fixture.scheduler.calls, 1);
      expect(fixture.transport.submits, 0);
    });

    test(
      'CF4 reentrant presentation cannot publish records or offered actions',
      () async {
        // Given a real observed ready record and ordinary pure presentation callbacks.
        await facade.commit(request);
        final status = (await facade.findTransferStatus(
          request.id,
          observedAt: fixture.clock,
        ))!;
        final ordinary = submissionPresentation();
        final record = SubmissionStatusResourceRecord(
          status: status,
          configuration: ordinary,
        );
        await binding.detach();
        String retiringItem(SubmissionTransferStatus status) {
          // Retire during item formatting; returned text cannot revive its owner.
          binding.detach();
          return status.subjectId;
        }

        final presentation = SubmissionPresentationConfiguration(
          listTitle: ordinary.listTitle,
          detailTitle: ordinary.detailTitle,
          uploadLabel: ordinary.uploadLabel,
          submissionLabel: ordinary.submissionLabel,
          itemLabel: retiringItem,
          storageDestinationLabel: ordinary.storageDestinationLabel,
          transportDestinationLabel: ordinary.transportDestinationLabel,
        );
        binding = SubmissionStatusBinding(
          facade: facade,
          presentationConfiguration: presentation,
          now: fixture.now,
        );
        await expectLater(
          // When record formatting invokes retirement during the accepted read.
          binding.getResource(request.id),
          // Then the read rejects publication with StateError.
          throwsStateError
        );
        await binding.detach();
        String retiringAction(SubmissionTransferAction action) {
          // Retire during action formatting before any offered action escapes.
          binding.detach();
          return action.name;
        }

        final actionPresentation = SubmissionPresentationConfiguration(
          listTitle: ordinary.listTitle,
          detailTitle: ordinary.detailTitle,
          uploadLabel: ordinary.uploadLabel,
          submissionLabel: ordinary.submissionLabel,
          itemLabel: ordinary.itemLabel,
          storageDestinationLabel: ordinary.storageDestinationLabel,
          transportDestinationLabel: ordinary.transportDestinationLabel,
          actionLabel: retiringAction,
        );
        binding = SubmissionStatusBinding(
          facade: facade,
          presentationConfiguration: actionPresentation,
          now: fixture.now,
        );
        expect(
          // When offering actions invokes the retiring action label.
          binding.actionsFor(record),
          // Then the offered action set is empty.
          isEmpty
        );
        await binding.detach();
        expect(fixture.scheduler.calls, 1);
        expect(fixture.transport.submits, 0);
      },
    );

    test(
      'CF8 existing views expose scheduling notice and retain failed actions',
      () async {
        // Given existing semantic views borrowing the binding over real queued intent.
        await facade.commit(request);
        final model = ResourceViewModel(
          dataSource: binding,
          actionHandler: binding,
        );
        try {
          // When loading/selecting and requesting run with a controlled wake failure.
          await model.load();
          await model.select(request.id);
          fixture.scheduler.fail = true;
          await model.performAction('requestRun');
          // Then durable command success yields a notice without submission acceptance.
          expect(model.listFailed, isFalse);
          expect(model.detailFailed, isFalse);
          expect(model.actionFailed, isFalse);
          expect(
            binding.lastActionResult!.schedulingFailure?.code,
            'wakeUnavailable',
          );
          expect(binding.lastActionResult!.record.acknowledgement, isNull);
          expect(
            (model.selectedResource as SubmissionStatusResourceRecord)
                .status
                .submission
                .state,
            SubmissionTransferOperationState.waiting,
          );
          expect(model.selectedActions.single.id, 'requestRun');
          expect(fixture.scheduler.calls, 2);
          // Given another owner claims the displayed action's Core row.
          await queue.claimNext(
            now: fixture.clock,
            leaseToken: 'otherOwner',
            leaseDuration: const Duration(minutes: 5),
          );
          // When the stale view action executes.
          await model.performAction('requestRun');
          // Then fresh rejection becomes view action failure without another wake.
          expect(model.actionFailed, isTrue);
          expect(binding.lastActionResult, isNull);
          expect(fixture.scheduler.calls, 2);
          expect(fixture.transport.submits, 0);
        } finally {
          // Dispose route-owned views before joining detach.
          model.dispose();
          await binding.detach();
        }
        expect((await service.find(request.id))!.request, request);
      },
    );

    test(
      'CF8 disposed views never refresh after a late accepted action',
      () async {
        // Given selected collection/detail views and a held explicit wake.
        await facade.commit(request);
        final model = ResourceViewModel(
          dataSource: binding,
          actionHandler: binding,
        );
        await model.load();
        await model.select(request.id);
        var notifications = 0;
        void observe() {
          // Count current updates delivered to the live semantic observer.
          notifications++;
        }

        model.addListener(observe);
        final gate = SubmissionGate();
        fixture.scheduler.gate = gate;
        // When action enters Core and its views retire before completion.
        final action = model.performAction('requestRun');
        await gate.entered.future.timeout(const Duration(seconds: 5));
        model.dispose();
        final retiredNotifications = notifications;
        final detached = binding.detach();
        final policyCalls = fixture.access.calls;
        gate.release();
        await action;
        await detached;
        // Then neither retired notifications nor refresh nor result publication survive.
        expect(notifications, retiredNotifications);
        expect(fixture.access.calls, policyCalls);
        expect(binding.lastActionResult, isNull);
        expect(fixture.scheduler.calls, 2);
        expect((await queue.find(request.id))!.acknowledgement, isNull);
        expect((await service.find(request.id))!.request, request);
      },
    );

    testWidgets('CF8 standard ListDetail retires a held automatic read', (
      tester,
    ) async {
      // Run real file and SQLite IO in real async to avoid fake-clock stalls.
      await tester.runAsync(() async {
        // Given existing resource/display models and uploaded intent with a held policy read.
        await facade.commit(request);
        await fixture.uploadAll(service);
        final model = ResourceViewModel(
          dataSource: binding,
          actionHandler: binding,
        );
        final display = ResourceListDetailDisplayModel();
        final gate = SubmissionGate();
        fixture.access.gate = gate;
        var notifications = 0;
        void observe() {
          // Count current updates delivered to the mounted view observer.
          notifications++;
        }

        model.addListener(observe);
        try {
          // When standard ResourceListDetail mounts, its existing lifecycle starts a read.
          await tester.pumpWidget(
            MaterialApp(
              home: ResourceListDetail(
                viewModel: model,
                configuration: binding.configuration,
                displayModel: display,
              ),
            ),
          );
          // Given the automatic policy read is held at its gate.
          await gate.entered.future.timeout(const Duration(seconds: 5));
          // When route removal and model disposal precede detach and the read joins.
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          final retiredNotifications = notifications;
          final detached = binding.detach();
          gate.release();
          await detached;
          await tester.pump();
          // Then lifecycle guards prevent late publication and extra transport.
          expect(notifications, retiredNotifications);
          expect(model.resources, isNull);
          expect(binding.lastActionResult, isNull);
          expect(fixture.scheduler.calls, 1);
          expect(fixture.transport.submits, 0);
          expect((await service.find(request.id))!.request, request);
        } finally {
          // Unblock incomplete work and retire each owner during cleanup.
          gate.release();
          model.dispose();
          display.dispose();
          await binding.detach();
        }
      });
    });
  });
}
