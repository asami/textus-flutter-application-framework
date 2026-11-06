import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final bound in [false, true]) {
    for (final lake in [false, true]) {
      for (final entry in _labels.entries) {
        test(
          'safe ${entry.key} guidance follows intent (bound=$bound, lake=$lake)',
          () {
            // Given a genuine validated failed queue DTO with synthetic private diagnostics.
            final status = _failedStatus(
              bound: bound,
              lake: lake,
              code: entry.key,
            );
            final actions = status.actions.toSet();
            // When common resource presentation projects the saved status.
            final record = SubmissionStatusResourceRecord(
              status: status,
              configuration: _presentation(),
            );
            // Then fixed Japanese guidance exposes no raw diagnostics or new permission.
            expect(
              record.value('submissionFailure'),
              _expected(entry.key, bound),
            );
            expect(record.value('uploadFailure'), '');
            expect(record.value('name'), _itemLabel);
            expect(record.status, same(status));
            expect(record.status.actions, actions);
            expect(record.status.acknowledgement, isNull);
            expect(record.status.upload.completedCount, 0);
            expect(record.status.upload.totalCount, 0);
            _expectSafe(record.value('submissionFailure'));
          },
        );
      }
    }

    test(
      'upload failure uses the same fixed Japanese labels (bound=$bound)',
      () {
        // Given one retained original whose upload failed before submission.
        final status = _failedStatus(
          bound: bound,
          lake: false,
          code: 'credentialUnavailable',
          original: true,
        );
        // When the genuine resource record selects independent operation failures.
        final record = SubmissionStatusResourceRecord(
          status: status,
          configuration: _presentation(),
        );
        // Then only upload receives the label while submission still waits on that original.
        expect(record.value('uploadFailure'), _labels['credentialUnavailable']);
        expect(record.value('submissionFailure'), '');
        expect(status.upload.completedCount, 0);
        expect(status.upload.totalCount, 1);
        expect(
          status.submission.waitingReason,
          SubmissionTransferWaitingReason.materialUpload,
        );
        expect(status.actions, {SubmissionTransferAction.retry});
        _expectSafe(record.value('uploadFailure'));
      },
    );

    test('no failure has no invented guidance (bound=$bound)', () {
      // Given an ordinary ready record with no failure or acknowledgement.
      final request = _request(bound: bound, lake: false);
      final status = SubmissionTransferStatus.fromRecord(
        SubmissionRecord(
          request: request,
          state: SubmissionState.readyToSubmit,
          claimCount: 0,
          updatedAt: _time,
        ),
        observedAt: _time,
      );
      // When the common binding projects the empty failure fields.
      final record = SubmissionStatusResourceRecord(
        status: status,
        configuration: _presentation(),
      );
      // Then no login or error text is invented and the original request-run remains.
      expect(record.value('uploadFailure'), '');
      expect(record.value('submissionFailure'), '');
      expect(status.actions, {SubmissionTransferAction.requestRun});
    });

    for (final scenario in [
      (
        'authenticationRequired',
        RegisteredMaterialHandoffFailureKind.configuration,
      ),
      ('handoffNotSent', RegisteredMaterialHandoffFailureKind.notSent),
      ('handoffRejected', RegisteredMaterialHandoffFailureKind.rejected),
      (
        'acceptanceUnknown',
        RegisteredMaterialHandoffFailureKind.outcomeUnknown,
      ),
      (
        'unrecognizedProviderCode',
        RegisteredMaterialHandoffFailureKind.rejected,
      ),
    ]) {
      testWidgets('actual page safely displays ${scenario.$1} (bound=$bound)', (
        tester,
      ) async {
        await tester.runAsync(() async {
          // Given a real saved Registered source and independently persisted Studio failure.
          final fixture = await _PageFixture.create(
            bound: bound,
            code: scenario.$1,
            kind: scenario.$2,
          );
          final saved = await fixture.queue.find('book');
          final handoff = await fixture.queue.findHandoffForSource('book');
          try {
            tester.view.physicalSize = const Size(1200, 1500);
            tester.view.devicePixelRatio = 1;
            // When the actual status page passively loads and selects the source.
            await tester.pumpWidget(
              MaterialApp(
                home: SubmissionStatusPage(
                  workspace: fixture.workspace,
                  reconcileRegisteredMaterial: (_) async {
                    fixture.actionCalls++;
                    throw StateError('Unexpected presentation command');
                  },
                ),
              ),
            );
            await fixture.workspace.viewModel.load();
            await fixture.workspace.viewModel.select('book');
            fixture.workspace.displayModel.openDetail();
            await tester.pump();
            final record =
                fixture.workspace.viewModel.selectedResource
                    as SubmissionStatusResourceRecord;
            final label = _expected(scenario.$1, bound);
            await tester.scrollUntilVisible(
              find.text(label).last,
              200,
              scrollable: find.byType(Scrollable).last,
            );
            // Then both the resource value and real supplement use safe Japanese copy.
            expect(record.value('submissionFailure'), label);
            expect(find.text(label), findsWidgets);
            expect(find.textContaining('PRIVATE.DIAGNOSTIC'), findsNothing);
            expect(find.textContaining('PRIVATE.ACCOUNT'), findsNothing);
            expect(find.textContaining('private.invalid'), findsNothing);
            expect(find.textContaining('PRIVATE.BEARER'), findsNothing);
            expect(record.status.hasAuthenticationBinding, bound);
            expect(
              record.status.registration!.state,
              SubmissionTransferOperationState.succeeded,
            );
            expect(record.status.acknowledgement, isNull);
            expect(
              record.status.acknowledgementUncertain,
              scenario.$2 ==
                  RegisteredMaterialHandoffFailureKind.outcomeUnknown,
            );
            expect(
              SubmissionStatusSummary.fromStatuses([record.status])
                  .completedCount,
              0,
            );
            expect(record.status.actions, isEmpty);
            expect(find.text('受領済みサーバーID:'), findsNothing);
            expect(find.text('Studioの受領状況を照合'), findsOneWidget);
            expect(
              find.textContaining('Studioが未受領の場合は、この操作で送信が行われることがあります。'),
              findsOneWidget,
            );
            expect(fixture.actionCalls, 0);
            expect(fixture.base.scheduler.calls, 0);
            expect(fixture.base.storage.prepares, 0);
            expect(fixture.base.storage.uploads, 0);
            expect(fixture.base.transport.submits, 0);
            expect(await fixture.queue.find('book'), saved);
            expect(await fixture.queue.findHandoffForSource('book'), handoff);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await fixture.close();
          }
        });
      });
    }
  }
}

const _privateMessage =
    'PRIVATE.DIAGNOSTIC PRIVATE.ACCOUNT.A PRIVATE.BEARER https://private.invalid/session';
const _itemLabel = '  利用者の題名\n原文  ';
final _time = SubmissionFixture.time;

const _labels = {
  'authenticationRequired': '',
  'authRequired': '',
  'credentialUnavailable': '認証情報を読み取れません。アカウントの状態を確認してください。',
  'operationCancelled': '処理を中断しました。送信状況を確認してください。',
  'operationTimeout': '応答を確認できませんでした。送信状況を確認してください。',
  'connectionFailed': '接続できませんでした。通信環境と送信状況を確認してください。',
  'serviceUnavailable': '接続できませんでした。通信環境と送信状況を確認してください。',
  'rateLimited': '接続できませんでした。通信環境と送信状況を確認してください。',
  'permissionDenied': '送信先が処理を受け付けませんでした。アカウントと権限を確認してください。',
  'handoffRejected': '送信先が処理を受け付けませんでした。アカウントと権限を確認してください。',
  'handoffNotSent': '今回のStudioへの送信は開始できませんでした。接続とログイン状態を確認してください。',
  'acceptanceUnknown': '受領結果を確認できません。原本と送信内容は保持されています。送信状況の照合が必要です。',
  'runRetired': '受領結果を確認できません。原本と送信内容は保持されています。送信状況の照合が必要です。',
  'acknowledgementMismatch': '受領結果を確認できません。原本と送信内容は保持されています。送信状況の照合が必要です。',
  'integrityMismatch': '原本の整合性を確認できません。原本は保持されています。担当者に確認してください。',
  'verificationUnavailable': '原本の整合性を確認できません。原本は保持されています。担当者に確認してください。',
  'integrityUpgradeRequired': '原本の整合性を確認できません。原本は保持されています。担当者に確認してください。',
  'unrecognizedProviderCode': '処理を完了できませんでした。原本と送信状況を確認してください。',
};

String _expected(String code, bool bound) => switch (code) {
  'authenticationRequired' =>
    bound
        ? 'この資料の送信に対応するアカウントでログインしてください。解消しない場合は担当者に接続設定を確認してください。'
        : '以前の送信内容にはアカウント情報がありません。原本を保持して担当者に確認してください。',
  'authRequired' =>
    bound
        ? 'ログイン状態を確認してください。送信結果は送信状況で確認できます。'
        : '送信に必要な認証を確認できません。担当者に接続設定を確認してください。',
  _ => _labels[code]!,
};

void _expectSafe(String text) {
  // Given synthetic private diagnostics, When observing only failure text,
  // Then no raw message, account, bearer or endpoint appears.
  for (final marker in [
    'PRIVATE.DIAGNOSTIC',
    'PRIVATE.ACCOUNT',
    'PRIVATE.BEARER',
    'private.invalid',
  ]) {
    expect(text, isNot(contains(marker)));
  }
}

SubmissionPresentationConfiguration _presentation() =>
    SubmissionPresentationConfiguration(
      listTitle: '送信状況',
      detailTitle: '送信内容',
      uploadLabel: 'アップロード',
      submissionLabel: '送信',
      itemLabel: (_) => _itemLabel,
      storageDestinationLabel: (_) => '保存先',
      transportDestinationLabel: (_) => '送信先',
    );

SubmissionRequest _request({
  required bool bound,
  required bool lake,
  bool original = false,
}) => SubmissionRequest(
  id: 'book',
  kind: 'bookMaterial',
  subjectId: 'book',
  createdAt: _time,
  document: const {'title': _itemLabel},
  payload: const {
    'schemaVersion': 1,
    'type': 'bookMaterial',
    'material': {'schemaVersion': 2, 'id': 'book'},
    'recognitionReports': <String, Object?>{},
  },
  materials: [
    if (original)
      SubmissionMaterial(
        key: 'photo',
        original: CaptureMaterialReference(
          id: 'original',
          mediaType: 'image/jpeg',
          byteLength: 3,
          capturedAt: _time,
        ),
      ),
  ],
  storageConnectionId: !lake && original ? 'storage' : null,
  transportConnectionId: 'transport',
  tklDelivery: lake
      ? TklMaterialDeliveryRequest(requestId: 'book', contribution: const {})
      : null,
  authenticationBinding: bound
      ? SubmissionAuthenticationBinding(
          authority: UserAccountHttpProfile.fromString(
            profileId: 'studio-user',
            serviceBaseUri: 'https://studio.example.test',
          ),
          userAccountId: 'PRIVATE.ACCOUNT.A',
        )
      : null,
);

SubmissionTransferStatus _failedStatus({
  required bool bound,
  required bool lake,
  required String code,
  bool original = false,
}) => SubmissionTransferStatus.fromRecord(
  SubmissionRecord(
    request: _request(bound: bound, lake: lake, original: original),
    state: SubmissionState.submissionFailed,
    claimCount: 1,
    updatedAt: _time,
    failureHistory: [
      SubmissionFailure(
        stage: SubmissionFailureStage.configuration,
        code: code,
        message: _privateMessage,
        retryable: false,
        occurredAt: _time,
        claimCount: 1,
      ),
    ],
  ),
  observedAt: _time,
);

final class _PageFixture {
  _PageFixture._(this.base, this.queue, this.handoffs, this.service)
    : workspace = SubmissionStatusWorkspace(
        facade: SubmissionFacade(service: service),
        presentationConfiguration: _presentation(),
        now: base.now,
      );
  final SubmissionFixture base;
  final SqliteSubmissionQueueStore queue;
  final RegisteredMaterialHandoffService handoffs;
  final SubmissionService service;
  final SubmissionStatusWorkspace workspace;
  int actionCalls = 0;

  static Future<_PageFixture> create({
    required bool bound,
    required String code,
    required RegisteredMaterialHandoffFailureKind kind,
  }) async {
    final base = await SubmissionFixture.create();
    final queue = await base.openQueue();
    final request = _request(bound: bound, lake: true);
    await queue.enqueue(request);
    await queue.claimNext(
      now: _time,
      leaseToken: 'registration',
      leaseDuration: const Duration(minutes: 1),
    );
    final snapshot = TklMaterialDeliverySnapshot(
      deliveryRef: 'saved-delivery',
      requestId: 'book',
      revision: 1,
      destinationId: 'fixtureLibrary',
      destinationLabel: 'Registered library',
      state: TklMaterialDeliveryState.registered,
      materialRef: 'urn:textus:klake:test:material:book',
      resources: const [],
    );
    await queue.saveTklProgress(
      id: 'book',
      leaseToken: 'registration',
      now: _time,
      progress: snapshot,
    );
    final source = await queue.completeMaterialRegistration(
      id: 'book',
      leaseToken: 'registration',
      now: _time,
    );
    final target = HttpSubmissionConnection(
      id: 'studio',
      endpoint: Uri.parse('https://studio.example.test/book-materials'),
    );
    final packet = RegisteredMaterialSubmissionPacket(
      sourceRequest: request,
      target: target,
      association: RegisteredMaterialAssociation(
        materialRef: snapshot.materialRef!,
        resources: const [],
      ),
    );
    await queue.createHandoff(
      id: 'handoff',
      source: source,
      target: target,
      packet: packet,
      now: _time,
    );
    await queue.claimNextHandoff(
      now: _time,
      leaseToken: 'handoff-claim',
      leaseDuration: const Duration(minutes: 1),
    );
    await queue.finishHandoff(
      id: 'handoff',
      leaseToken: 'handoff-claim',
      now: _time,
      state: kind == RegisteredMaterialHandoffFailureKind.outcomeUnknown
          ? RegisteredMaterialHandoffState.outcomeUnknown
          : RegisteredMaterialHandoffState.failed,
      failure: RegisteredMaterialHandoffFailure(
        kind: kind,
        code: code,
        message: _privateMessage,
      ),
    );
    final handoffs = RegisteredMaterialHandoffService(
      queue: queue,
      store: queue,
      transports: const {},
      scheduler: base.scheduler,
      now: base.now,
    );
    final service = SubmissionService(
      queue: queue,
      materials: base.materials,
      storageAdapters: {'storage': base.storage},
      transports: {'transport': base.transport},
      scheduler: base.scheduler,
      registeredMaterialHandoffs: handoffs,
      now: base.now,
    );
    return _PageFixture._(base, queue, handoffs, service);
  }

  Future<void> close() async {
    await workspace.detach();
    await service.close();
    await handoffs.close();
    await base.dispose();
  }
}
