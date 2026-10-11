import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  group('SubmissionFacade public borrowed Core behavior', () {
    late SubmissionFixture fixture;
    setUp(() async {
      // Allocate isolated real IO with cleanup owned by this fixture.
      fixture = await SubmissionFixture.create();
    });
    tearDown(() async {
      // Release and drain accepted fixture work before closing owned resources.
      await fixture.dispose();
    });

    test(
      'CF1 explicit commit and distinct durable reopen preserve frozen input',
      () async {
        // Given real binary originals, immutable opaque intent and controlled wake failure.
        final queue = await fixture.openQueue();
        final service = fixture.service(queue);
        final facade = SubmissionFacade(service: service);
        final request = await fixture.request();
        fixture.scheduler.fail = true;
        expect(fixture.scheduler.calls, 0);
        // When explicitly committing and reading through every public query shape.
        final committed = await facade.commit(request);
        final byId = await facade.find(request.id);
        final bySubject = await facade.findForSubject(
          request.kind,
          request.subjectId,
        );
        final status = await facade.findTransferStatus(
          request.id,
          observedAt: fixture.clock,
          networkState: SubmissionNetworkState.offline,
        );
        final subjectStatus = await facade.findTransferStatusForSubject(
          request.kind,
          request.subjectId,
          observedAt: fixture.clock,
        );
        final statuses = await facade.listTransferStatuses(
          observedAt: fixture.clock,
        );
        final equalRequest = SubmissionCodec.requestFromJson(
          SubmissionCodec.requestToJson(request),
        );
        final repeated = await facade.commit(equalRequest);
        // Then one immutable intent preserves exact bytes/context and scheduling is separate.
        expect(committed.record.request, request);
        expect(byId, committed.record);
        expect(bySubject, committed.record);
        expect(repeated.record, committed.record);
        expect((await queue.list()).length, 1);
        expect(committed.schedulingFailure?.code, 'wakeUnavailable');
        expect(committed.record.acknowledgement, isNull);
        expect(
          status!.upload.waitingReason,
          SubmissionTransferWaitingReason.networkUnavailable,
        );
        expect(
          subjectStatus!.upload.state,
          SubmissionTransferOperationState.queued,
        );
        expect(statuses.single, subjectStatus);
        expect(
          statuses.single.files.map((file) => file.original),
          request.materials.map((material) => material.original),
        );
        expect(request.payload['transcript'], '  手入力\n原文  ');
        expect(request.extensions['executionContext'], {
          'locale': 'ja-JP',
          'opaque': '  未解釈  ',
        });
        expect(
          await fixture.materials.readMaterial(request.materials[0].original),
          SubmissionFixture.photoBytes,
        );
        expect(
          await fixture.materials.readMaterial(request.materials[1].original),
          SubmissionFixture.audioBytes,
        );
        expect(fixture.storage.prepares, 0);
        expect(fixture.storage.uploads, 0);
        expect(fixture.transport.submits, 0);
        expect(fixture.access.calls, 0);
        expect(await facade.find('absent'), isNull);
        expect(
          await facade.findTransferStatus('absent', observedAt: fixture.clock),
          isNull,
        );
        // Given accepted durable intent, close the initial service and queue owners.
        await service.close();
        await queue.close();
        // When a distinct queue and service owner reopens the durable intent.
        final reopenedQueue = await fixture.openQueue();
        final reopenedService = fixture.service(reopenedQueue);
        final reopened = SubmissionFacade(service: reopenedService);
        // Then reads retain exactly the same durable intent and start no remote work.
        expect(await reopened.find(request.id), committed.record);
        expect(
          (await reopened.listTransferStatuses(observedAt: fixture.clock))
              .single,
          subjectStatus,
        );
        expect(await reopenedService.find(request.id), committed.record);
        expect(fixture.scheduler.calls, 2);
        expect(fixture.storage.uploads, 0);
        expect(fixture.transport.submits, 0);
      },
    );

    test('CF1 exact Core errors do not replace accepted intent or close borrowed resources', () async {
      // Given durable accepted intent and a same-id conflicting immutable request.
      final queue = await fixture.openQueue();
      final service = fixture.service(queue);
      final facade = SubmissionFacade(service: service);
      final request = await fixture.request(withMaterials: false);
      final accepted = await facade.commit(request);
      final conflictJson = SubmissionCodec.requestToJson(request);
      conflictJson['payload'] = {'changed': true};
      final conflict = SubmissionCodec.requestFromJson(conflictJson);
      // When explicit conflicting Commit and absent retry/wake are attempted.
      await expectLater(facade.commit(conflict), throwsStateError);
      await expectLater(facade.retry('absent'), throwsStateError);
      await expectLater(facade.requestRun('absent'), throwsStateError);
      await expectLater(facade.find('invalid id'), throwsArgumentError);
      // Then Core errors propagate without replacement/wake and borrowed owners remain usable.
      expect(await service.find(request.id), accepted.record);
      expect(await queue.find(request.id), accepted.record);
      expect(fixture.scheduler.calls, 1);
      expect(fixture.transport.submits, 0);
    });

    test('CF2 partial upload failure retries only missing originals with exact receipts', () async {
      // Given two originals and a controlled failure of the second upload.
      final queue = await fixture.openQueue();
      final service = fixture.service(queue);
      final facade = SubmissionFacade(service: service);
      final request = await fixture.request();
      await facade.commit(request);
      fixture.storage.failKey = 'audio';
      // When the explicit fixture runner prepares/uploads and facade observes failure.
      await fixture.uploadAll(service);
      final failed = await facade.findTransferStatus(
        request.id,
        observedAt: fixture.clock,
      );
      final firstReceipt = (await queue.find(request.id))!.receipts['photo'];
      // Then actual successful and failed stages remain distinct with one supported retry.
      expect(failed!.upload.state, SubmissionTransferOperationState.failed);
      expect(failed.upload.completedCount, 1);
      expect(failed.upload.totalCount, 2);
      expect(failed.submission.state, SubmissionTransferOperationState.waiting);
      expect(
        failed.submission.waitingReason,
        SubmissionTransferWaitingReason.materialUpload,
      );
      expect(failed.files.first.receipt, firstReceipt);
      expect(failed.files.last.receipt, isNull);
      expect(failed.actions, {SubmissionTransferAction.retry});
      expect(fixture.transport.submits, 0);
      // Given the same durable intent and recovered controlled storage.
      fixture.storage.failKey = null;
      // When the caller explicitly retries that intent.
      final retry = await facade.retry(request.id);
      // Then the immutable request and first successful receipt are retained.
      expect(retry.record.request, request);
      expect(retry.record.receipts['photo'], firstReceipt);
      // When the controlled runner resumes upload and the facade observes it.
      await service.processNext(networkAllowed: true);
      final uploaded = await facade.findTransferStatus(
        request.id,
        observedAt: fixture.clock,
      );
      // Then upload succeeds, submission is queued, and only the missing original uploads again.
      expect(
        uploaded!.upload.state,
        SubmissionTransferOperationState.succeeded,
      );
      expect(
        uploaded.submission.state,
        SubmissionTransferOperationState.queued,
      );
      expect(uploaded.acknowledgement, isNull);
      expect(uploaded.actions, {SubmissionTransferAction.requestRun});
      expect(fixture.storage.uploads, 3);
      expect(fixture.storage.prepares, 2);
      // When an explicit run request lets the controlled runner submit.
      await facade.requestRun(request.id);
      final completed = await service.processNext(networkAllowed: true);
      // Then submission uses the immutable packet, retained receipt and exact originals.
      expect(completed.outcome, SubmissionRunOutcome.submitted);
      expect(fixture.transport.packets.single.request, request);
      expect(fixture.transport.packets.single.receipts['photo'], firstReceipt);
      expect(fixture.storage.uploadedBytes, [
        SubmissionFixture.photoBytes,
        SubmissionFixture.audioBytes,
        SubmissionFixture.audioBytes,
      ]);
    });

    test('CF2 uncertain server outcome preserves upload success and same request on retry', () async {
      // Given uploaded originals and a controlled uncertain transport failure.
      final queue = await fixture.openQueue();
      final service = fixture.service(queue);
      final facade = SubmissionFacade(service: service);
      final request = await fixture.request();
      await facade.commit(request);
      await fixture.uploadAll(service);
      fixture.transport.fail = true;
      // When the fixture runner attempts submit and the facade observes its checkpoint.
      await service.processNext(networkAllowed: true);
      final failed = await facade.findTransferStatus(
        request.id,
        observedAt: fixture.clock,
      );
      final receipts = (await queue.find(request.id))!.receipts;
      // Then upload succeeds independently while acknowledgement remains uncertain.
      expect(failed!.upload.state, SubmissionTransferOperationState.succeeded);
      expect(
        failed.submission.state,
        SubmissionTransferOperationState.outcomeUnknown,
      );
      expect(failed.acknowledgementUncertain, isTrue);
      expect(failed.acknowledgement, isNull);
      expect(failed.actions, {SubmissionTransferAction.retry});
      // Given the same immutable packet and recovered controlled transport.
      fixture.transport.fail = false;
      // When explicit retry and the fixture runner submit that packet.
      await facade.retry(request.id);
      await service.processNext(networkAllowed: true);
      final completed = await facade.findTransferStatus(
        request.id,
        observedAt: fixture.clock,
      );
      // Then matching acknowledgement completes submission and uploads never repeat.
      expect(
        completed!.submission.state,
        SubmissionTransferOperationState.succeeded,
      );
      expect(completed.acknowledgementUncertain, isFalse);
      expect(completed.actions, isEmpty);
      expect(fixture.transport.packets[0], fixture.transport.packets[1]);
      expect((await queue.find(request.id))!.receipts, receipts);
      expect(fixture.storage.uploads, 2);
    });
  });
}
