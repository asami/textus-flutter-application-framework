import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Disjoint counts of current observations, with no queue or navigation authority.
/// Home owns navigation; a scheduling notice or upload receipt is not submission
/// acceptance and no downstream consumer success is inferred.
final class SubmissionStatusSummary {
  const SubmissionStatusSummary._({
    required this.totalCount,
    required this.waitingCount,
    required this.runningCount,
    required this.attentionCount,
    required this.completedCount,
  });

  factory SubmissionStatusSummary.fromStatuses(
    Iterable<SubmissionTransferStatus> statuses,
  ) {
    var total = 0;
    var waiting = 0;
    var running = 0;
    var attention = 0;
    var completed = 0;
    for (final status in statuses) {
      total++;
      final upload = status.upload.state;
      final submission = status.submission.state;
      if ((upload == SubmissionTransferOperationState.succeeded ||
              upload == SubmissionTransferOperationState.notRequired) &&
          submission == SubmissionTransferOperationState.succeeded) {
        completed++;
      } else if (status.acknowledgementUncertain ||
          upload == SubmissionTransferOperationState.failed ||
          upload == SubmissionTransferOperationState.outcomeUnknown ||
          submission == SubmissionTransferOperationState.failed ||
          submission == SubmissionTransferOperationState.outcomeUnknown) {
        attention++;
      } else if (upload == SubmissionTransferOperationState.running ||
          submission == SubmissionTransferOperationState.running) {
        running++;
      } else {
        waiting++;
      }
    }
    return SubmissionStatusSummary._(
      totalCount: total,
      waitingCount: waiting,
      runningCount: running,
      attentionCount: attention,
      completedCount: completed,
    );
  }

  final int totalCount;
  final int waitingCount;
  final int runningCount;
  final int attentionCount;
  final int completedCount;
}
