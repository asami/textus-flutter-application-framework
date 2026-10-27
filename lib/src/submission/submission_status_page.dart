import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../resource/resource_data_source.dart';
import '../widgets/resource_list_detail.dart';
import 'submission_status_binding.dart';
import 'submission_status_workspace.dart';

/// Standard adaptive List/Detail; mount retains its guarded read-only load.
class SubmissionStatusPage extends StatefulWidget {
  const SubmissionStatusPage({
    required this.workspace,
    this.openSubject,
    this.handoffRegisteredMaterial,
    this.reconcileRegisteredMaterial,
    this.openSubjectLabel = 'Open item',
    super.key,
  });

  final SubmissionStatusWorkspace workspace;
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
        'Original content did not match; retained for operator review',
      'verificationUnavailable' =>
        'Provider checksum unavailable; retained for operator review',
      'integrityUpgradeRequired' =>
        'This earlier transfer needs an integrity upgrade; originals retained',
      null => null,
      _ => 'TKL needs operator reconciliation. Originals and confirmed uploads are retained.',
    };
    final mixedVerification = record.status.files
        .map((file) => file.lakeProgress?.verificationState).toSet().length > 1;
    String verificationLabel(TklOriginalVerificationState? state) => switch (state) {
      null => 'Not recorded',
      TklOriginalVerificationState.pending => 'Queued',
      TklOriginalVerificationState.verifying => 'Running',
      TklOriginalVerificationState.verified => 'Succeeded',
      TklOriginalVerificationState.failed => 'Failed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.status.usesLakeDelivery) ...[
          if (record.status.tklProgress case final progress?) ...[
            Text(
              progress.transferMethod ==
                      TklMaterialTransferMethod.googleDriveResumable
                  ? 'Transfer route: Direct to provider'
                  : 'Transfer route: Via TKL',
            ),
            if (progress.transferReason == 'providerDirectUploadUnsupported')
              const Text(
                'The provider does not support direct upload; TKL performs the transfer.',
              ),
            if (progress.transferReason == 'operatorSelectedServerTransfer')
              const Text('Server transfer was selected by the operator.'),
          ],
          if (record.status.tklProgress?.materialRef
              case final String reference)
            SelectableText('TKL Material reference: $reference'),
          if (instruction != null) Text(instruction),
        ],
        if (record.status.acknowledgement != null)
          Text('Server ID: ${record.status.acknowledgement!.serverId}'),
        if (record.status.studioHandoff?.failure != null)
          Text(record.status.studioHandoff!.failure!.message),
        if (canReconcile && pending)
          const Text(
            'Studio handoff is queued. Resume background scheduling for the same saved request.',
          ),
        if (canReconcile && !pending)
          const Text(
            'Reconciliation resends the same request and can submit it if Studio has not previously received it.',
          ),
        if (canSend || canReconcile)
          TextButton(
            onPressed: busy ? null : () => _handoff(
              workspace, record, reconcile: canReconcile,
            ),
            child: Text(canReconcile
                ? pending
                    ? 'Resume queued Studio handoff'
                    : 'Reconcile Studio receipt'
                : 'Send registered material to Studio'),
          ),
        for (final file in record.status.files) ...[
          Text(configuration.fileLabel(file)),
          Text(configuration.operationStateLabel(file.state)),
          if (record.status.usesLakeDelivery && mixedVerification)
            Text('Original integrity: ${verificationLabel(file.lakeProgress?.verificationState)}'),
          if (!record.status.usesLakeDelivery)
            Text('Original ID: ${file.original.id}'),
          Text('Media type: ${file.original.mediaType}'),
          Text('Byte length: ${file.original.byteLength}'),
          if (file.receipt != null)
            Text(
              'Stored at: ${configuration.formatTime(file.receipt!.storedAt)}',
            ),
          if (file.directReceipt != null &&
              file.lakeProgress?.state != TklOriginalTransferState.uploaded)
            const Text('Uploaded to provider; awaiting TKL confirmation.'),
        ],
        if (notice) const Text('Queued; background scheduling needs attention'),
        if (_schedulingFailedId == record.id)
          const Text('Studio handoff queued; background scheduling needs attention.'),
        if (_handoffFailedId == record.id)
          const Text('Could not perform Studio handoff action.'),
        if (_openFailed) const Text('Could not open item.'),
        if (widget.openSubject != null)
          Wrap(
            children: [
              TextButton(
                // Given current detail, When tapped, Then reserve typed navigation.
                onPressed: busy
                    ? null
                    : () => _open(workspace, record),
                child: Text(_opening ? 'Opening…' : widget.openSubjectLabel),
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
