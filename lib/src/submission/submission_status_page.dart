import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../resource/resource_data_source.dart';
import '../widgets/resource_list_detail.dart';
import 'submission_failure_presentation.dart';
import 'submission_status_binding.dart';
import 'submission_status_workspace.dart';

/// Standard adaptive List/Detail; mount retains its guarded read-only load.
class SubmissionStatusPage extends StatefulWidget {
  const SubmissionStatusPage({
    required this.workspace,
    this.openSubject,
    this.handoffRegisteredMaterial,
    this.reconcileRegisteredMaterial,
    this.openSubjectLabel = '項目を開く',
    this.executionMode = SubmissionExecutionMode.unknown,
    super.key,
  });

  final SubmissionStatusWorkspace workspace;
  final SubmissionExecutionMode executionMode;
  final Future<void> Function(SubmissionTransferStatus status)? openSubject;
  final String openSubjectLabel;
  final Future<RegisteredMaterialHandoffCommandResult> Function(
    SubmissionTransferStatus status,
  )? handoffRegisteredMaterial;
  /// Pending callbacks must use the owner's idempotent enqueue/wake capability,
  /// preserving the saved target, rather than uncertainty reconciliation.
  final Future<RegisteredMaterialHandoffCommandResult> Function(
    SubmissionTransferStatus status,
  )? reconcileRegisteredMaterial;

  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> {
  bool _opening = false;
  bool _openFailed = false;
  bool _acting = false;
  String? _handoffFailedId;
  String? _schedulingFailedId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.workspace.viewModel.addListener(_changed);
  }

  @override
  void didUpdateWidget(SubmissionStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workspace, widget.workspace)) {
      oldWidget.workspace.viewModel.removeListener(_changed);
      widget.workspace.viewModel.addListener(_changed);
      _generation++;
      _opening = false;
      _openFailed = false;
      _acting = false;
      _handoffFailedId = null;
      _schedulingFailedId = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.workspace.viewModel.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // Given a borrowed projection event, When mounted, Then rebuild current detail.
    if (mounted) setState(() {});
  }

  Future<void> _open(
    SubmissionStatusWorkspace workspace,
    SubmissionStatusResourceRecord record,
  ) async {
    // Given selected immutable status, When explicitly opened, Then reserve once
    // and fence navigation across owner/selection changes and late completion.
    final callback = widget.openSubject;
    if (!mounted ||
        _opening ||
        _acting ||
        workspace.binding.actionBusy ||
        workspace.viewModel.actionRunning ||
        callback == null ||
        !identical(workspace, widget.workspace) ||
        workspace.isDetached ||
        workspace.viewModel.selectedId != record.id ||
        !identical(workspace.viewModel.selectedResource, record)) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    try {
      if (!mounted ||
          generation != _generation ||
          !identical(workspace, widget.workspace) ||
          workspace.isDetached ||
          workspace.viewModel.selectedId != record.id ||
          !identical(workspace.viewModel.selectedResource, record)) {
        return;
      }
      await callback(record.status);
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          identical(workspace, widget.workspace) &&
          !workspace.isDetached &&
          workspace.viewModel.selectedId == record.id) {
        _openFailed = true;
      }
    } finally {
      if (mounted &&
          generation == _generation &&
          identical(workspace, widget.workspace) &&
          !workspace.isDetached) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _handoff(
    SubmissionStatusWorkspace workspace,
    SubmissionStatusResourceRecord record, {
    required bool reconcile,
  }) async {
    final pendingResume = reconcile &&
        record.status.studioHandoff?.state == RegisteredMaterialHandoffState.pending;
    final callback = reconcile
        ? widget.reconcileRegisteredMaterial
        : widget.handoffRegisteredMaterial;
    bool ownsSelection() => mounted &&
        identical(workspace, widget.workspace) &&
        !workspace.isDetached &&
        workspace.viewModel.selectedId == record.id &&
        identical(workspace.viewModel.selectedResource, record);
    if (!ownsSelection() || _acting || _opening || callback == null ||
        workspace.binding.actionBusy || workspace.viewModel.actionRunning) {
      return;
    }
    final generation = ++_generation;
    bool current() => generation == _generation && ownsSelection();
    setState(() {
      _acting = true;
      _handoffFailedId = null;
      _schedulingFailedId = null;
    });
    try {
      // Given explicit intent, revalidate fresh persisted state before dispatch.
      // When ownership changes during that read, the binding rejects the action.
      final result = await workspace.binding.performRegisteredMaterialAction(
        sourceRequestId: record.id,
        reconcile: reconcile,
        isCurrent: current,
        action: (status) {
          if (pendingResume &&
              status.studioHandoff?.state != RegisteredMaterialHandoffState.pending) {
            throw StateError('Queued Studio handoff is no longer pending.');
          }
          return callback(status);
        },
      );
      if (!current()) return;
      if (result.schedulingFailed) _schedulingFailedId = record.id;
      // Then refresh only the still-current explicit action's observation.
      await workspace.viewModel.load();
      if (!current()) return;
      await workspace.viewModel.detailView.refresh();
    } catch (_) {
      if (current()) {
        _handoffFailedId = record.id;
        if (pendingResume) {
          await workspace.viewModel.load();
          if (current()) await workspace.viewModel.detailView.refresh();
        }
      }
    } finally {
      if (mounted && generation == _generation &&
          identical(workspace, widget.workspace) && !workspace.isDetached) {
        setState(() => _acting = false);
      }
    }
  }

  Widget _supplement(BuildContext context, ResourceRecord record) {
    // Given only the current typed projection, When building detail,
    // Then expose safe actual file facts and request-specific scheduling notice.
    if (record is! SubmissionStatusResourceRecord) {
      return const SizedBox.shrink();
    }
    final workspace = widget.workspace;
    final configuration = workspace.binding.presentationConfiguration;
    final actionResult = workspace.binding.lastActionResult;
    final notice =
        !workspace.viewModel.actionRunning &&
        !workspace.binding.actionBusy &&
        actionResult?.record.request.id == record.id &&
        actionResult?.schedulingFailure != null;
    final progress = record.status.tklProgress;
    final canSend = widget.handoffRegisteredMaterial != null &&
        registeredMaterialActionAvailable(record.status, reconcile: false);
    final canReconcile = widget.reconcileRegisteredMaterial != null &&
        registeredMaterialActionAvailable(record.status, reconcile: true);
    final pending = record.status.studioHandoff?.state ==
        RegisteredMaterialHandoffState.pending;
    final busy = _acting || _opening || workspace.isDetached ||
        workspace.binding.actionBusy || workspace.viewModel.actionRunning;
    final reason = progress?.actionRequired ??
        record.status.verification?.failure?.code ??
        record.status.registration?.failure?.code;
    final instruction = switch (reason) {
      'integrityMismatch' =>
        '原本の内容が一致しません。原本は保持されています。担当者による確認が必要です。',
      'verificationUnavailable' =>
        'プロバイダーでチェックサムを確認できません。原本は保持されています。担当者による確認が必要です。',
      'integrityUpgradeRequired' =>
        '以前の転送には整合性確認の更新が必要です。原本は保持されています。',
      null => null,
      _ => 'TKL側で担当者による照合が必要です。原本と確認済みのアップロードは保持されています。',
    };
    final mixedVerification = record.status.files
        .map((file) => file.lakeProgress?.verificationState).toSet().length > 1;
    String verificationLabel(TklOriginalVerificationState? state) => switch (state) {
      null => '未記録',
      TklOriginalVerificationState.pending => '確認待ち',
      TklOriginalVerificationState.verifying => '確認中',
      TklOriginalVerificationState.verified => '確認済み',
      TklOriginalVerificationState.failed => '確認失敗',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.executionMode == SubmissionExecutionMode.foreground)
          const Text(
            'アプリを開いている間に送信します。閉じても送信待ちの内容は保持されます。',
          ),
        if (record.status.usesLakeDelivery) ...[
          if (record.status.tklProgress case final progress?) ...[
            Text(
              progress.transferMethod ==
                      TklMaterialTransferMethod.googleDriveResumable
                  ? '転送経路: 保存先へ直接'
                  : '転送経路: TKL経由',
            ),
            if (progress.transferReason == 'providerDirectUploadUnsupported')
              const Text(
                '保存先は直接アップロードに対応していないため、TKL経由で転送します。',
              ),
            if (progress.transferReason == 'operatorSelectedServerTransfer')
              const Text('担当者の指定によりサーバー経由で転送します。'),
          ],
          if (record.status.tklProgress?.materialRef
              case final String reference)
            SelectableText('TKL資料参照: $reference'),
          if (instruction != null) Text(instruction),
        ],
        if (record.status.acknowledgement != null)
          Text('受領済みサーバーID: ${record.status.acknowledgement!.serverId}'),
        if (record.status.studioHandoff?.failure != null)
          Text(submissionFailureLabel(
            record.status.studioHandoff!.failure!.code,
            hasAuthenticationBinding: record.status.hasAuthenticationBinding,
          )),
        if (canReconcile && pending)
          const Text(
            'Studioへの送信は待機中です。同じ保存済みリクエストで送信処理の手配を再開します。',
          ),
        if (canReconcile && !pending)
          const Text(
            '照合では同じリクエストを再送します。Studioが未受領の場合は、この操作で送信が行われることがあります。',
          ),
        if (canSend || canReconcile)
          TextButton(
            onPressed: busy ? null : () => _handoff(
              workspace, record, reconcile: canReconcile,
            ),
            child: Text(canReconcile
                ? pending
                    ? '待機中のStudio送信を再開'
                    : 'Studioの受領状況を照合'
                : '登録済み資料をStudioへ送信'),
          ),
        for (final file in record.status.files) ...[
          Text(configuration.fileLabel(file)),
          Text(configuration.operationStateLabel(file.state)),
          if (record.status.usesLakeDelivery && mixedVerification)
            Text('原本の整合性: ${verificationLabel(file.lakeProgress?.verificationState)}'),
          if (!record.status.usesLakeDelivery)
            Text('原本ID: ${file.original.id}'),
          Text('メディア形式: ${file.original.mediaType}'),
          Text('サイズ（バイト）: ${file.original.byteLength}'),
          if (file.receipt != null)
            Text(
              '保存日時: ${configuration.formatTime(file.receipt!.storedAt)}',
            ),
          if (file.directReceipt != null &&
              file.lakeProgress?.state != TklOriginalTransferState.uploaded)
            const Text('保存先へのアップロードは完了しています。TKLの確認待ちです。'),
        ],
        if (notice) const Text('送信待ちに登録済みです。送信処理の手配を確認してください。'),
        if (_schedulingFailedId == record.id)
          const Text('Studioへの送信は登録済みです。送信処理の手配を確認してください。'),
        if (_handoffFailedId == record.id)
          const Text('Studioへの送信操作を実行できませんでした。'),
        if (_openFailed) const Text('項目を開けませんでした。'),
        if (widget.openSubject != null)
          Wrap(
            children: [
              TextButton(
                // Given current detail, When tapped, Then reserve typed navigation.
                onPressed: busy
                    ? null
                    : () => _open(workspace, record),
                child: Text(_opening ? '開いています…' : widget.openSubjectLabel),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ResourceListDetail(
    configuration: widget.workspace.binding.configurationFor(
      lake: (widget.workspace.viewModel.selectedResource
          as SubmissionStatusResourceRecord?)?.status.usesLakeDelivery ?? false,
    ),
    viewModel: widget.workspace.viewModel,
    displayModel: widget.workspace.displayModel,
    detailSupplementBuilder: _supplement,
  );
}
