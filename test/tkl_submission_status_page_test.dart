import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

/// Seeds public native queue facts, never a parallel queue or runner.
Future<SubmissionRequest> persistIntegrityScenario(
  SubmissionFixture fixture,
  SqliteSubmissionQueueStore queue, {
  required String id,
  TklMaterialDeliveryState? state,
  List<TklOriginalVerificationState?> proof = const [null, null],
  int prepared = 2,
  String? failure,
}) async {
  final original = await fixture.request(id: id, subjectId: id);
  final request = SubmissionRequest(
    id: id, kind: original.kind, subjectId: original.subjectId,
    createdAt: original.createdAt, document: original.document,
    payload: original.payload, materials: original.materials,
    transportConnectionId: original.transportConnectionId,
    tklDelivery: TklMaterialDeliveryRequest(
      requestId: id, contribution: {'opaque': 'https://secret.invalid/session'},
    ),
  );
  await queue.enqueue(request);
  await queue.claimNext(now: fixture.clock, leaseToken: id,
      leaseDuration: const Duration(minutes: 1));
  final digest = TklContentDigest(algorithm: 'sha256', value: 'a' * 64);
  for (final material in request.materials.take(prepared)) {
    await queue.saveTklContentDigest(id: id, leaseToken: id,
        key: material.key, digest: digest, now: fixture.clock);
  }
  if (state != null) {
    await queue.saveTklProgress(id: id, leaseToken: id, now: fixture.clock,
      progress: TklMaterialDeliverySnapshot(
        deliveryRef: 'private-delivery', requestId: id, revision: 1,
        destinationId: 'private-destination', destinationLabel: 'Library materials',
        state: state, actionRequired: failure,
        materialRef: state == TklMaterialDeliveryState.registered
            ? 'urn:textus:klake:test:material:$id' : null,
        resources: [
          for (var index = 0; index < request.materials.length; index++)
            TklOriginalTransferProgress(
              resourceId: request.materials[index].key,
              mediaType: request.materials[index].original.mediaType,
              byteLength: request.materials[index].original.byteLength,
              state: TklOriginalTransferState.uploaded,
              contentDigest: proof[index] == null ? null : digest,
              verificationState: proof[index],
              verificationAttempts: proof[index] == null ? null
                  : proof[index] == TklOriginalVerificationState.pending ? 0
                  : failure == 'verificationUnavailable' ? 3 : 1,
              verificationReason: proof[index] == TklOriginalVerificationState.failed
                  ? failure : null,
            ),
        ],
      ),
    );
  }
  if (state == TklMaterialDeliveryState.registered) {
    await queue.completeMaterialRegistration(id: id, leaseToken: id, now: fixture.clock);
  } else if (failure != null) {
    await queue.fail(id: id, leaseToken: id, now: fixture.clock,
      failure: SubmissionFailure(stage: SubmissionFailureStage.storage,
        code: failure, message: 'Safe retained failure.', retryable: false,
        occurredAt: fixture.clock, claimCount: 1));
  }
  return request;
}

void main() {
  group('DU03 five factual delivery stages', () {
    for (final size in [const Size(390, 844), const Size(1200, 900)]) {
      for (final scenario in ['preparing', 'uploaded', 'verified', 'registered',
        'legacy', 'integrityMismatch', 'verificationUnavailable', 'integrityUpgradeRequired']) {
        testWidgets('$scenario remains passive and factual at $size', (tester) async {
          await tester.runAsync(() async {
            // Given real originals and a native SQLite delivery at the selected boundary.
            final fixture = await SubmissionFixture.create();
            final queue = await fixture.openQueue();
            final failed = scenario == 'integrityMismatch' || scenario == 'verificationUnavailable';
            final legacy = scenario == 'legacy' || scenario == 'integrityUpgradeRequired';
            final registered = scenario == 'registered' || scenario == 'legacy';
            final request = await persistIntegrityScenario(fixture, queue,
              id: scenario,
              prepared: scenario == 'preparing' ? 1 : legacy ? 0 : 2,
              state: scenario == 'preparing' ? null : registered
                  ? TklMaterialDeliveryState.registered : failed
                  ? TklMaterialDeliveryState.verificationFailed
                  : scenario == 'integrityUpgradeRequired'
                  ? TklMaterialDeliveryState.reconciliationRequired
                  : scenario == 'verified' ? TklMaterialDeliveryState.readyToRegister
                  : TklMaterialDeliveryState.verifying,
              proof: scenario == 'preparing' || legacy ? const [null, null]
                  : failed ? const [TklOriginalVerificationState.verified, TklOriginalVerificationState.failed]
                  : scenario == 'uploaded' ? const [TklOriginalVerificationState.verifying, TklOriginalVerificationState.pending]
                  : const [TklOriginalVerificationState.verified, TklOriginalVerificationState.verified],
              failure: failed || scenario == 'integrityUpgradeRequired' ? scenario : null,
            );
            final workspace = SubmissionStatusWorkspace(
              facade: SubmissionFacade(service: fixture.service(queue)),
              presentationConfiguration: submissionPresentation(), now: fixture.now,
            );
            try {
              // When the existing adaptive page loads and opens the persisted item.
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              await tester.pumpWidget(MaterialApp(home: SubmissionStatusPage(workspace: workspace)));
              await workspace.viewModel.load();
              await workspace.viewModel.select(request.id);
              workspace.displayModel.openDetail();
              await tester.pump();
              final record = workspace.viewModel.selectedResource as SubmissionStatusResourceRecord;
              final operations = record.value('operations');
              // Then five named stages count only recorded checkpoints and proof.
              expect(operations.split('\n').map((line) => line.split(':').first),
                ['Preparation', 'Upload', 'Integrity verification', 'TKL registration', 'Studio receipt']);
              expect(operations, contains(scenario == 'preparing'
                ? 'Preparation: Running (1/2)' : legacy
                ? 'Preparation: ${scenario == 'legacy' ? 'Queued' : 'Outcome unknown'} (0/2)'
                : 'Preparation: Succeeded (2/2)'));
              expect(operations, contains(scenario == 'preparing'
                ? 'Upload: Running (0/2)' : 'Upload: Succeeded (2/2)'));
              expect(operations, contains(legacy || scenario == 'preparing'
                ? 'Integrity verification: Not recorded' : failed
                ? 'Integrity verification: Failed (1/2)' : scenario == 'uploaded'
                ? 'Integrity verification: Running (0/2)'
                : 'Integrity verification: Succeeded (2/2)'));
              expect(operations, endsWith('Studio receipt: Not received'));
              expect(record.status.acknowledgement, isNull);
              expect(SubmissionStatusSummary.fromStatuses([record.status]).completedCount, 0);
              expect(record.values.values.join(), isNot(contains('secret.invalid')));
              expect(record.values.values.join(), isNot(contains('a' * 64)));
              expect(workspace.binding.configurationFor(lake: true).detailFields
                .where((field) => field.key == 'operations').length, 1);
              if (failed || scenario == 'integrityUpgradeRequired') {
                expect(workspace.viewModel.selectedActions, isEmpty);
              }
              // Given the selected compact or split detail.
              // When scrolling to the retained route and instructions.
              await tester.scrollUntilVisible(find.text(scenario == 'preparing' ? 'Media type: image/jpeg' : 'Transfer route: Via TKL'), 250,
                scrollable: find.byType(Scrollable).last);
              await tester.pump();
              // Then actual registration alone exposes its reference and safe operator text.
              expect(find.textContaining('TKL Material reference:'), registered ? findsOneWidget : findsNothing);
              expect(find.textContaining('Server ID:'), findsNothing);
              final instruction = switch (scenario) {
                'integrityMismatch' => 'Original content did not match; retained for operator review',
                'verificationUnavailable' => 'Provider checksum unavailable; retained for operator review',
                'integrityUpgradeRequired' => 'This earlier transfer needs an integrity upgrade; originals retained',
                _ => null,
              };
              if (instruction != null) expect(find.text(instruction), findsOneWidget);
              if (failed) {
                expect(find.text('Original integrity: Succeeded'), findsOneWidget);
                expect(find.text('Original integrity: Failed'), findsOneWidget);
              }
              // Given unchanged queue intent.
              // When explicitly refreshing its observations.
              await workspace.viewModel.load();
              await workspace.viewModel.select(request.id);
              await tester.pump();
              // Then selection survives and no transfer, submission or wake is dispatched.
              expect(workspace.viewModel.selectedId, request.id);
              expect(fixture.scheduler.calls, 0);
              expect(fixture.storage.prepares, 0);
              expect(fixture.storage.uploads, 0);
              expect(fixture.transport.submits, 0);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await workspace.detach();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              await fixture.dispose();
            }
          });
        });
      }
    }
  });
  for (final direct in [false, true]) {
    testWidgets(
      'TKL registration displays its confirmed reference and actual route separately from an absent Studio receipt (direct=$direct)',
      (tester) async {
        await tester.runAsync(() async {
          // Given a real persisted queue with a confirmed TKL registration and no Studio ACK.
          final fixture = await SubmissionFixture.create();
          final queue = await fixture.openQueue();
          final service = fixture.service(queue);
          final legacy = await fixture.request(withMaterials: false);
          final request = SubmissionRequest(
            id: legacy.id,
            subjectId: legacy.subjectId,
            kind: legacy.kind,
            createdAt: legacy.createdAt,
            document: legacy.document,
            payload: legacy.payload,
            materials: const [],
            transportConnectionId: legacy.transportConnectionId,
            tklDelivery: TklMaterialDeliveryRequest(
              requestId: legacy.id,
              contribution: {'opaque': null},
            ),
          );
          await queue.enqueue(request);
          await queue.claimNext(
            now: fixture.clock,
            leaseToken: 'test-owner',
            leaseDuration: const Duration(minutes: 1),
          );
          const reference = 'urn:textus:klake:test:material:registered1';
          await queue.saveTklProgress(
            id: request.id,
            leaseToken: 'test-owner',
            now: fixture.clock,
            progress: TklMaterialDeliverySnapshot(
              deliveryRef: 'delivery1',
              requestId: request.id,
              revision: 3,
              destinationId: 'configured',
              destinationLabel: 'Library materials',
              state: TklMaterialDeliveryState.registered,
              resources: const [],
              materialRef: reference,
              transferMethod: direct
                  ? TklMaterialTransferMethod.googleDriveResumable
                  : TklMaterialTransferMethod.tklMultipart,
              transferReason: direct ? null : 'providerDirectUploadUnsupported',
            ),
          );
          await queue.completeMaterialRegistration(
            id: request.id,
            leaseToken: 'test-owner',
            now: fixture.clock,
          );
          final workspace = SubmissionStatusWorkspace(
            facade: SubmissionFacade(service: service),
            presentationConfiguration: submissionPresentation(),
            now: fixture.now,
          );
          try {
            // When the standard status page queries and displays the selected record.
            tester.view.physicalSize = const Size(900, 1600);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              MaterialApp(home: SubmissionStatusPage(workspace: workspace)),
            );
            await workspace.viewModel.load();
            await workspace.viewModel.select(request.id);
            workspace.displayModel.openDetail();
            await tester.pump();
            await tester.scrollUntilVisible(
              find.text('TKL Material reference: $reference'),
              250,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump();
            // Then only the confirmed Lake reference appears, without manufacturing server acceptance.
            expect(
              find.text('TKL Material reference: $reference'),
              findsOneWidget,
            );
            expect(find.textContaining('Server ID:'), findsNothing);
            expect(
              find.text(
                direct
                    ? 'Transfer route: Direct to provider'
                    : 'Transfer route: Via TKL',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                'The provider does not support direct upload; TKL performs the transfer.',
              ),
              direct ? findsNothing : findsOneWidget,
            );
            final record =
                workspace.viewModel.selectedResource
                    as SubmissionStatusResourceRecord;
            expect(record.value('storageDestination'), 'Library materials');
            expect(
              record.value('operations'),
              contains('TKL registration: Succeeded'),
            );
            expect(
              record.value('operations'),
              contains('Studio receipt: Not received'),
            );
            expect(record.status.acknowledgement, isNull);
            expect(
              record.status.registration!.state,
              SubmissionTransferOperationState.succeeded,
            );
            expect(fixture.storage.uploads, 0);
            expect(fixture.transport.submits, 0);
            expect(fixture.scheduler.calls, 0);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await workspace.detach();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await fixture.dispose();
          }
        });
      },
    );
  }
}
