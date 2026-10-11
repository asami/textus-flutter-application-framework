import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Borrows the exact Core service without starting work or owning its lifetime.
/// The application freezes current edits and constructs requests before Commit.
final class SubmissionFacade {
  const SubmissionFacade({required this._service});

  final SubmissionService _service;

  Future<SubmissionCommitResult> commit(SubmissionRequest request) =>
      _service.commit(request);

  Future<SubmissionCommitResult> retry(String id) => _service.retry(id);

  Future<SubmissionCommitResult> requestRun(String id) =>
      _service.requestRun(id);

  Future<SubmissionRecord?> find(String id) => _service.find(id);

  Future<SubmissionRecord?> findForSubject(String kind, String subjectId) =>
      _service.findForSubject(kind, subjectId);

  Future<SubmissionTransferStatus?> findTransferStatus(
    String id, {
    required DateTime observedAt,
    SubmissionNetworkState networkState = SubmissionNetworkState.unknown,
  }) => _service.findTransferStatus(
    id,
    observedAt: observedAt,
    networkState: networkState,
  );

  Future<SubmissionTransferStatus?> findTransferStatusForSubject(
    String kind,
    String subjectId, {
    required DateTime observedAt,
    SubmissionNetworkState networkState = SubmissionNetworkState.unknown,
  }) => _service.findTransferStatusForSubject(
    kind,
    subjectId,
    observedAt: observedAt,
    networkState: networkState,
  );

  Future<List<SubmissionTransferStatus>> listTransferStatuses({
    required DateTime observedAt,
    SubmissionNetworkState networkState = SubmissionNetworkState.unknown,
  }) => _service.listTransferStatuses(
    observedAt: observedAt,
    networkState: networkState,
  );
}
