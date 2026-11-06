import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';
import 'tkl_submission_status_page_test.dart' show persistIntegrityScenario;

SubmissionTransferStatus observedStatus({
  required String id,
  SubmissionState state = SubmissionState.readyToSubmit,
  int materialCount = 2,
  int receiptCount = 0,
  bool uncertain = false,
  DateTime? retryAt,
  DateTime? leaseExpiresAt,
  SubmissionNetworkState networkState = SubmissionNetworkState.unknown,
  SubmissionReferenceAccessState accessState =
      SubmissionReferenceAccessState.unknown,
}) {
  // Construct actual immutable public Core values at a fixed observation time
  // without IO or any persisted queue transition.
  final materials = <SubmissionMaterial>[];
  final reservations = <String, SubmissionStorageReservation>{};
  final receipts = <String, SubmissionMaterialReceipt>{};
  for (var index = 0; index < materialCount; index++) {
    final key = 'file$index';
    final original = CaptureMaterialReference(
      id: 'original$index',
      mediaType: 'application/octet-stream',
      byteLength: 7,
      capturedAt: SubmissionFixture.time,
      originalName: 'Original $index',
    );
    materials.add(SubmissionMaterial(key: key, original: original));
    reservations[key] = SubmissionStorageReservation(
      key: key,
      providerId: 'controlledStorage',
      data: {'remote': key},
    );
    if (index < receiptCount) {
      receipts[key] = SubmissionMaterialReceipt(
        key: key,
        providerId: 'controlledStorage',
        remoteId: 'controlled/$key',
        accessConnectionId: 'storage',
        storedAt: SubmissionFixture.time,
      );
    }
  }
  final request = SubmissionRequest(
    id: id,
    kind: 'opaqueKind',
    subjectId: id,
    createdAt: SubmissionFixture.time,
    document: {},
    payload: {},
    materials: materials,
    storageConnectionId: materialCount == 0 ? null : 'storage',
    transportConnectionId: 'transport',
  );
  final claimed = state == SubmissionState.submitting;
  final record = SubmissionRecord(
    request: request,
    state: state,
    claimCount: state == SubmissionState.readyToSubmit && !uncertain ? 0 : 1,
    updatedAt: SubmissionFixture.time,
    reservations: reservations,
    receipts: receipts,
    leaseToken: claimed ? 'controlledOwner' : null,
    leaseExpiresAt: claimed
        ? leaseExpiresAt ??
              SubmissionFixture.time.add(const Duration(minutes: 5))
        : null,
    nextAttemptAt: retryAt,
    failureHistory: [
      if (state == SubmissionState.submissionFailed)
        SubmissionFailure(
          stage: receiptCount == materialCount
              ? SubmissionFailureStage.transport
              : SubmissionFailureStage.storage,
          code: 'controlledFailure',
          message: 'Controlled safe failure.',
          retryable: retryAt != null,
          occurredAt: SubmissionFixture.time,
          claimCount: 1,
        ),
    ],
    transportCheckpoint: uncertain
        ? SubmissionTransportCheckpoint.pending(
            claimCount: 1,
            startedAt: SubmissionFixture.time,
          )
        : null,
    acknowledgement: state == SubmissionState.submitted
        ? SubmissionAcknowledgement(
            requestId: id,
            subjectId: id,
            serverId: 'controlled/$id',
            receivedAt: SubmissionFixture.time,
          )
        : null,
  );
  return SubmissionTransferStatus.fromRecord(
    record,
    observedAt: SubmissionFixture.time,
    networkState: networkState,
    referenceAccessState: accessState,
  );
}

void main() {
  test('DU03 native retained TKL stages contribute disjoint attention running and waiting counts', () async {
    // Given independent native records for hashing, verification failure, registration and uncertainty.
    final fixture = await SubmissionFixture.create();
    final queue = await fixture.openQueue();
    try {
      await persistIntegrityScenario(fixture, queue, id: 'hashing', prepared: 1);
      await persistIntegrityScenario(fixture, queue, id: 'mismatch',
        state: TklMaterialDeliveryState.verificationFailed,
        proof: const [TklOriginalVerificationState.verified, TklOriginalVerificationState.failed],
        failure: 'integrityMismatch');
      await persistIntegrityScenario(fixture, queue, id: 'registered',
        state: TklMaterialDeliveryState.registered,
        proof: const [TklOriginalVerificationState.verified, TklOriginalVerificationState.verified]);
      await persistIntegrityScenario(fixture, queue, id: 'unknown', prepared: 0,
        state: TklMaterialDeliveryState.reconciliationRequired,
        failure: 'integrityUpgradeRequired');
      final facade = SubmissionFacade(service: fixture.service(queue));
      // When querying actual Core observations and deriving the pure overview.
      final statuses = await facade.listTransferStatuses(observedAt: fixture.clock);
      final summary = SubmissionStatusSummary.fromStatuses(statuses);
      // Then a registration without Studio acknowledgement stays waiting, not complete.
      expect(summary.totalCount, 4);
      expect(summary.runningCount, 1);
      expect(summary.attentionCount, 2);
      expect(summary.waitingCount, 1);
      expect(summary.completedCount, 0);
      expect(summary.runningCount + summary.attentionCount +
        summary.waitingCount + summary.completedCount, summary.totalCount);
      expect(fixture.scheduler.calls, 0);
      expect(fixture.storage.uploads, 0);
      expect(fixture.transport.submits, 0);
    } finally {
      await fixture.dispose();
    }
  });
  group('Current observation summary and pure presentation', () {
    test('CF7 disjoint buckets distinguish no upload waits partial failure uncertainty and success', () {
      // Given genuine immutable Core projections with independent operation facts.
      final statuses = [
        observedStatus(id: 'noUpload', materialCount: 0),
        observedStatus(
          id: 'offline',
          networkState: SubmissionNetworkState.offline,
        ),
        observedStatus(id: 'referenceWait', receiptCount: 2),
        observedStatus(
          id: 'running',
          state: SubmissionState.submitting,
          receiptCount: 1,
        ),
        observedStatus(
          id: 'partialFailure',
          state: SubmissionState.submissionFailed,
          receiptCount: 1,
        ),
        observedStatus(
          id: 'uncertain',
          state: SubmissionState.submissionFailed,
          receiptCount: 2,
          uncertain: true,
        ),
        observedStatus(
          id: 'noUploadComplete',
          state: SubmissionState.submitted,
          materialCount: 0,
        ),
        observedStatus(
          id: 'complete',
          state: SubmissionState.submitted,
          receiptCount: 2,
        ),
      ];
      // When deriving repeated pure counts from the same actual observations.
      final summary = SubmissionStatusSummary.fromStatuses(statuses);
      final repeated = SubmissionStatusSummary.fromStatuses(statuses);
      // Then each item contributes exactly one bucket without downstream success inference.
      expect(summary.totalCount, 8);
      expect(summary.waitingCount, 3);
      expect(summary.runningCount, 1);
      expect(summary.attentionCount, 2);
      expect(summary.completedCount, 2);
      expect(
        summary.waitingCount +
            summary.runningCount +
            summary.attentionCount +
            summary.completedCount,
        summary.totalCount,
      );
      expect(repeated.waitingCount, summary.waitingCount);
      expect(repeated.runningCount, summary.runningCount);
      expect(repeated.attentionCount, summary.attentionCount);
      expect(repeated.completedCount, summary.completedCount);
      expect(
        statuses[0].upload.state,
        SubmissionTransferOperationState.notRequired,
      );
      expect(
        statuses[0].submission.state,
        SubmissionTransferOperationState.queued,
      );
      expect(
        statuses[2].upload.state,
        SubmissionTransferOperationState.succeeded,
      );
      expect(
        statuses[2].submission.waitingReason,
        SubmissionTransferWaitingReason.referenceAccess,
      );
      expect(statuses[4].upload.completedCount, 1);
      expect(
        statuses[4].submission.state,
        SubmissionTransferOperationState.waiting,
      );
      expect(
        statuses[5].submission.state,
        SubmissionTransferOperationState.outcomeUnknown,
      );
      expect(statuses[5].acknowledgement, isNull);
    });

    test(
      'CF7 attention precedes running and all observed waits remain waiting',
      () {
        // Given unconfirmed active dispatch, policy block and an expired durable claim.
        final uncertainRunning = observedStatus(
          id: 'uncertainRunning',
          state: SubmissionState.submitting,
          receiptCount: 2,
          uncertain: true,
        );
        final blocked = observedStatus(
          id: 'blocked',
          networkState: SubmissionNetworkState.policyBlocked,
        );
        final expired = observedStatus(
          id: 'expired',
          state: SubmissionState.submitting,
          leaseExpiresAt: SubmissionFixture.time,
        );
        // When classifying these current observations and an empty input.
        final summary = SubmissionStatusSummary.fromStatuses([
          uncertainRunning,
          blocked,
          expired,
        ]);
        final empty = SubmissionStatusSummary.fromStatuses([]);
        // Then uncertainty needs attention regardless of a lease and waits never imply progress.
        expect(summary.totalCount, 3);
        expect(summary.attentionCount, 1);
        expect(summary.runningCount, 0);
        expect(summary.waitingCount, 2);
        expect(summary.completedCount, 0);
        expect(
          blocked.upload.waitingReason,
          SubmissionTransferWaitingReason.policyBlocked,
        );
        expect(
          expired.upload.waitingReason,
          SubmissionTransferWaitingReason.leaseRecovery,
        );
        expect(empty.totalCount, 0);
        expect(
          empty.waitingCount +
              empty.runningCount +
              empty.attentionCount +
              empty.completedCount,
          0,
        );
      },
    );

    test(
      'CF7 default labels cover Core enums and format only actual facts',
      () {
        // Given actual partial failure with a persisted retry time and safe file values.
        final retryAt = SubmissionFixture.time.add(const Duration(seconds: 30));
        final status = observedStatus(
          id: 'retry',
          state: SubmissionState.submissionFailed,
          receiptCount: 1,
          retryAt: retryAt,
        );
        final presentation = submissionPresentation();
        // When formatting through pure configured callbacks and immutable resource values.
        final record = SubmissionStatusResourceRecord(
          status: status,
          configuration: presentation,
        );
        // Then every default enum meaning is covered without percentage or inferred timestamp.
        expect(
          SubmissionTransferOperationState.values.map(
            presentation.operationStateLabel,
          ),
          [
            'Not required',
            'Queued',
            'Waiting',
            'Running',
            'Succeeded',
            'Failed',
            'Outcome unknown',
          ],
        );
        expect(
          SubmissionTransferWaitingReason.values.map(
            presentation.waitingReasonLabel,
          ),
          [
            'Network unavailable',
            'Network policy blocked',
            'Waiting for upload',
            'Waiting for reference access',
            'Waiting for lease recovery',
            'Retry scheduled',
          ],
        );
        expect(SubmissionTransferAction.values.map(presentation.actionLabel), [
          'Retry',
          'Request run',
        ]);
        expect(presentation.fileLabel(status.files.first), 'Original 0');
        expect(record.status, same(status));
        expect(
          record.value('operations'),
          'Original upload: Failed\nServer submission: Waiting',
        );
        expect(
          record.value('uploadFailure'),
          '処理を完了できませんでした。原本と送信状況を確認してください。',
        );
        // Then displayed failure presentation does not reveal the controlled raw message.
        expect(
          record.value('uploadFailure'),
          isNot(contains('Controlled safe failure.')),
        );
        expect(record.value('submissionFailure'), isEmpty);
        expect(record.value('uploadWaiting'), 'Retry scheduled');
        expect(record.value('submissionWaiting'), 'Waiting for upload');
        expect(
          record.value('updatedAt'),
          SubmissionFixture.time.toIso8601String(),
        );
        expect(record.value('nextAttemptAt'), retryAt.toIso8601String());
        expect(record.value('acknowledgement'), isEmpty);
        expect(
          record.values.values.any((value) => value.contains('%')),
          isFalse,
        );
        expect(status.upload.completedCount, 1);
        expect(status.upload.totalCount, 2);
        expect(status.submission.completedCount, isNull);
        expect(status.submission.totalCount, isNull);
        final queued = SubmissionStatusResourceRecord(
          status: observedStatus(id: 'queued'),
          configuration: presentation,
        );
        expect(queued.value('nextAttemptAt'), isEmpty);
        expect(queued.value('acknowledgement'), isEmpty);
        expect(queued.status.upload.completedAt, isNull);
        final acceptedStatus = observedStatus(
          id: 'accepted',
          state: SubmissionState.submitted,
          receiptCount: 2,
        );
        final accepted = SubmissionStatusResourceRecord(
          status: acceptedStatus,
          configuration: presentation,
        );
        expect(
          accepted.value('acknowledgement'),
          acceptedStatus.acknowledgement!.receivedAt.toIso8601String(),
        );
      },
    );

    test(
      'CF7 caller labels retain exact status file and destination identities',
      () {
        // Given generic consumer callbacks over a no-upload Core status.
        final status = observedStatus(id: 'opaque', materialCount: 0);
        SubmissionTransferStatus? seen;
        String? seenStorage = 'unset';
        String? seenTransport;
        String itemLabel(SubmissionTransferStatus value) {
          // Retain the exact status identity received by this formatting callback.
          seen = value;
          return 'Consumer item';
        }

        String storageLabel(String? id) {
          // Retain the exact nullable destination, including its absence.
          seenStorage = id;
          return 'No original destination';
        }

        String transportLabel(String id) {
          // Retain the exact transport identity received by this callback.
          seenTransport = id;
          return 'Consumer server';
        }

        String operationLabel(SubmissionTransferOperationState state) {
          // Format only the actual operation state supplied to this callback.
          return state.name;
        }

        final presentation = SubmissionPresentationConfiguration(
          listTitle: 'Consumer list',
          detailTitle: 'Consumer detail',
          uploadLabel: 'Stage A',
          submissionLabel: 'Stage B',
          itemLabel: itemLabel,
          storageDestinationLabel: storageLabel,
          transportDestinationLabel: transportLabel,
          operationStateLabel: operationLabel,
        );
        // When mapping the exact observed value through the configured callbacks.
        final record = SubmissionStatusResourceRecord(
          status: status,
          configuration: presentation,
        );
        // Then exact status and destination identities produce the generic consumer labels.
        expect(seen, same(status));
        expect(seenStorage, isNull);
        expect(seenTransport, 'transport');
        expect(record.value('name'), 'Consumer item');
        expect(
          record.value('operations'),
          'Stage A: notRequired\nStage B: queued',
        );
        expect(record.value('storageDestination'), 'No original destination');
        expect(record.value('transportDestination'), 'Consumer server');
      },
    );
  });
}
