import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Immutable consumer labels for actual Core observations.
/// All callbacks must be pure presentation: they have no command, credential or
/// storage authority. Unknown progress remains unknown; no percentage is inferred.
final class SubmissionPresentationConfiguration {
  const SubmissionPresentationConfiguration({
    required this.listTitle,
    required this.detailTitle,
    required this.uploadLabel,
    required this.submissionLabel,
    required this.itemLabel,
    required this.storageDestinationLabel,
    required this.transportDestinationLabel,
    this.operationStateLabel = defaultOperationStateLabel,
    this.waitingReasonLabel = defaultWaitingReasonLabel,
    this.actionLabel = defaultActionLabel,
    this.fileLabel = defaultFileLabel,
    this.formatTime = defaultFormatTime,
  });

  final String listTitle;
  final String detailTitle;
  final String uploadLabel;
  final String submissionLabel;
  final String Function(SubmissionTransferStatus) itemLabel;
  final String Function(String?) storageDestinationLabel;
  final String Function(String) transportDestinationLabel;
  final String Function(SubmissionTransferOperationState) operationStateLabel;
  final String Function(SubmissionTransferWaitingReason) waitingReasonLabel;
  final String Function(SubmissionTransferAction) actionLabel;
  final String Function(SubmissionFileTransferStatus) fileLabel;
  final String Function(DateTime) formatTime;

  static String defaultOperationStateLabel(
    SubmissionTransferOperationState state,
  ) => switch (state) {
    SubmissionTransferOperationState.notRequired => 'Not required',
    SubmissionTransferOperationState.queued => 'Queued',
    SubmissionTransferOperationState.waiting => 'Waiting',
    SubmissionTransferOperationState.running => 'Running',
    SubmissionTransferOperationState.succeeded => 'Succeeded',
    SubmissionTransferOperationState.failed => 'Failed',
    SubmissionTransferOperationState.outcomeUnknown => 'Outcome unknown',
  };

  static String defaultWaitingReasonLabel(
    SubmissionTransferWaitingReason reason,
  ) => switch (reason) {
    SubmissionTransferWaitingReason.networkUnavailable => 'Network unavailable',
    SubmissionTransferWaitingReason.policyBlocked => 'Network policy blocked',
    SubmissionTransferWaitingReason.materialUpload => 'Waiting for upload',
    SubmissionTransferWaitingReason.referenceAccess =>
      'Waiting for reference access',
    SubmissionTransferWaitingReason.leaseRecovery =>
      'Waiting for lease recovery',
    SubmissionTransferWaitingReason.retryScheduled => 'Retry scheduled',
  };

  static String defaultActionLabel(SubmissionTransferAction action) =>
      switch (action) {
        SubmissionTransferAction.retry => 'Retry',
        SubmissionTransferAction.requestRun => 'Request run',
      };

  static String defaultFileLabel(SubmissionFileTransferStatus file) =>
      file.original.originalName ?? file.key;

  static String defaultFormatTime(DateTime time) => time.toIso8601String();
}
