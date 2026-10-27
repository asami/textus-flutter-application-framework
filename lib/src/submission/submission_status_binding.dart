import 'dart:async';

import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/resource_list_detail_configuration.dart';
import '../resource/resource_data_source.dart';
import 'submission_facade.dart';
import 'submission_presentation_configuration.dart';

/// Wraps the exact immutable Core observation, alongside immutable display text.
final class SubmissionStatusResourceRecord extends ResourceRecord {
  SubmissionStatusResourceRecord({
    required this.status,
    required SubmissionPresentationConfiguration configuration,
  }) : super(id: status.requestId, values: _values(status, configuration));

  final SubmissionTransferStatus status;

  static Map<String, String> _values(
    SubmissionTransferStatus status,
    SubmissionPresentationConfiguration configuration,
  ) {
    final upload = configuration.operationStateLabel(status.upload.state);
    final submission = configuration.operationStateLabel(
      status.submission.state,
    );
    String waiting(SubmissionTransferOperationStatus operation) {
      final reason = operation.waitingReason;
      return reason == null ? '' : configuration.waitingReasonLabel(reason);
    }

    String stage(SubmissionTransferOperationStatus? operation) {
      if (operation == null) return 'Not recorded';
      final label = configuration.operationStateLabel(operation.state);
      final completed = operation.completedCount;
      final total = operation.totalCount;
      return completed == null || total == null
          ? label
          : '$label ($completed/$total)';
    }

    final nextAttemptAt =
        status.registration?.nextAttemptAt ??
        status.upload.nextAttemptAt ??
        status.submission.nextAttemptAt;
    final acknowledgement = status.acknowledgement;
    final lake = status.usesLakeDelivery;
    final registration = status.registration;
    final handoff = status.studioHandoff;
    return {
      'name': configuration.itemLabel(status),
      'operations': lake
          ? 'Preparation: ${stage(status.preparation)}\nUpload: ${stage(status.upload)}\nIntegrity verification: ${stage(status.verification)}\nTKL registration: ${stage(registration)}\nStudio receipt: ${acknowledgement != null ? configuration.formatTime(acknowledgement.receivedAt) : handoff == null ? 'Not received' : submission}'
          : '${configuration.uploadLabel}: $upload\n${configuration.submissionLabel}: $submission',
      'upload': upload,
      'submission': lake && handoff == null
          ? 'Not received (separate from TKL registration)'
          : submission,
      'storageDestination': lake
          ? status.tklProgress?.destinationLabel ??
                'Assigned by TKL during preparation'
          : configuration.storageDestinationLabel(status.storageConnectionId),
      'transportDestination': handoff == null
          ? configuration.transportDestinationLabel(status.transportConnectionId)
          : 'TKL source: ${configuration.transportDestinationLabel(status.transportConnectionId)}\nStudio handoff: ${configuration.transportDestinationLabel(handoff.target.id)} (${handoff.target.id})',
      'updatedAt': configuration.formatTime(status.updatedAt),
      'uploadWaiting': waiting(status.upload),
      'submissionWaiting': waiting(status.submission),
      'uploadFailure': status.upload.failure?.message ?? '',
      'submissionFailure': lake && handoff == null
          ? registration?.failure?.message ?? ''
          : handoff?.failure?.message ?? status.submission.failure?.message ?? '',
      'nextAttemptAt': nextAttemptAt == null
          ? ''
          : configuration.formatTime(nextAttemptAt),
      'acknowledgement': acknowledgement != null
          ? configuration.formatTime(acknowledgement.receivedAt)
          : status.acknowledgementUncertain
          ? 'Outcome unknown'
          : '',
    };
  }
}

/// A route-owned resource adapter borrowing Core and pure presentation callbacks.
/// Dispose the borrowing ResourceViewModel before/with detach. Detach joins all
/// accepted work and fences its results, but never closes or cancels Core intent.
final class SubmissionStatusBinding
    implements ResourceDataSource, ResourceActionHandler {
  SubmissionStatusBinding({
    required this._facade,
    required this.presentationConfiguration,
    DateTime Function()? now,
    SubmissionNetworkState Function()? networkState,
  }) : _now = now ?? DateTime.now,
       _networkState = networkState ?? _unknownNetwork;

  final SubmissionFacade _facade;
  final SubmissionPresentationConfiguration presentationConfiguration;
  final DateTime Function() _now;
  final SubmissionNetworkState Function() _networkState;
  final Set<Future<void>> _pending = {};
  bool _detached = false;
  bool _actionBusy = false;
  Future<void>? _detachFuture;
  SubmissionCommitResult? _lastActionResult;

  bool get isDetached => _detached;
  bool get actionBusy => _actionBusy;

  /// Exact current command result; scheduling failure still means queued intent.
  SubmissionCommitResult? get lastActionResult => _lastActionResult;

  /// Uses the same action reservation and detach join as ordinary queue actions.
  /// The caller predicate fences selection and widget ownership across the read.
  Future<RegisteredMaterialHandoffCommandResult> performRegisteredMaterialAction({
    required String sourceRequestId,
    required bool reconcile,
    required bool Function() isCurrent,
    required Future<RegisteredMaterialHandoffCommandResult> Function(
      SubmissionTransferStatus status,
    ) action,
  }) {
    if (_detached || _actionBusy || !isCurrent()) {
      return Future.error(StateError('Studio handoff action is unavailable'));
    }
    _actionBusy = true;
    return _accept(() async {
      try {
        final observation = _observation();
        final fresh = await _facade.findTransferStatus(
          sourceRequestId,
          observedAt: observation.$1,
          networkState: observation.$2,
        );
        _live();
        if (!isCurrent() || fresh == null ||
            !registeredMaterialActionAvailable(fresh, reconcile: reconcile)) {
          throw StateError('Studio handoff action is no longer available');
        }
        _live();
        return await action(fresh);
      } finally {
        _actionBusy = false;
      }
    });
  }

  ResourceListDetailConfiguration get configuration => configurationFor();

  /// TKL detail uses one stage summary; generic consumers retain their fields.
  ResourceListDetailConfiguration configurationFor({bool lake = false}) =>
      ResourceListDetailConfiguration(
        listTitle: presentationConfiguration.listTitle,
        detailTitle: presentationConfiguration.detailTitle,
        primaryField: 'name',
        secondaryField: 'operations',
        detailFields: List<ResourceFieldConfiguration>.unmodifiable([
          const ResourceFieldConfiguration(key: 'name', label: 'Name'),
          const ResourceFieldConfiguration(
            key: 'operations',
            label: 'Operations',
          ),
          if (!lake) ResourceFieldConfiguration(
            key: 'upload',
            label: presentationConfiguration.uploadLabel,
          ),
          if (!lake) ResourceFieldConfiguration(
            key: 'submission',
            label: presentationConfiguration.submissionLabel,
          ),
          const ResourceFieldConfiguration(
            key: 'storageDestination',
            label: 'Storage destination',
          ),
          const ResourceFieldConfiguration(
            key: 'transportDestination',
            label: 'Submission destination',
          ),
          const ResourceFieldConfiguration(
            key: 'updatedAt',
            label: 'Updated at',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'uploadWaiting',
            label: 'Upload waiting reason',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'submissionWaiting',
            label: 'Submission waiting reason',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'uploadFailure',
            label: 'Upload failure',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'submissionFailure',
            label: 'Submission failure',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'nextAttemptAt',
            label: 'Next attempt at',
          ),
          if (!lake) const ResourceFieldConfiguration(
            key: 'acknowledgement',
            label: 'Server acknowledgement',
          ),
        ]),
      );

  static SubmissionNetworkState _unknownNetwork() =>
      SubmissionNetworkState.unknown;

  void _live() {
    if (_detached) {
      throw StateError('Submission status binding is detached');
    }
  }

  /// Register before invoking caller code so reentrant detach also joins it.
  Future<T> _accept<T>(Future<T> Function() operation) {
    if (_detached) {
      return Future<T>.error(
        StateError('Submission status binding is detached'),
      );
    }
    final settled = Completer<void>();
    _pending.add(settled.future);
    final result = Future<T>.sync(operation);
    void finish() {
      _pending.remove(settled.future);
      settled.complete();
    }

    result.then<void>(
      (_) => finish(),
      onError: (Object _, StackTrace _) => finish(),
    );
    return result;
  }

  (DateTime, SubmissionNetworkState) _observation() {
    _live();
    final time = _now();
    _live();
    final network = _networkState();
    _live();
    return (time, network);
  }

  SubmissionStatusResourceRecord _record(SubmissionTransferStatus status) {
    _live();
    final record = SubmissionStatusResourceRecord(
      status: status,
      configuration: presentationConfiguration,
    );
    _live();
    return record;
  }

  @override
  Future<List<ResourceRecord>> listResources() => _accept(() async {
    final observation = _observation();
    final statuses = await _facade.listTransferStatuses(
      observedAt: observation.$1,
      networkState: observation.$2,
    );
    _live();
    final records = <ResourceRecord>[];
    for (final status in statuses) {
      records.add(_record(status));
    }
    _live();
    return List<ResourceRecord>.unmodifiable(records);
  });

  @override
  Future<ResourceRecord?> getResource(String id) => _accept(() async {
    final observation = _observation();
    final status = await _facade.findTransferStatus(
      id,
      observedAt: observation.$1,
      networkState: observation.$2,
    );
    _live();
    return status == null ? null : _record(status);
  });

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) {
    if (_detached || record is! SubmissionStatusResourceRecord) {
      return const [];
    }
    final actions = <ResourceAction>[];
    for (final action in record.status.actions) {
      final label = presentationConfiguration.actionLabel(action);
      if (_detached) {
        return const [];
      }
      actions.add(ResourceAction(id: action.name, label: label));
    }
    return List<ResourceAction>.unmodifiable(actions);
  }

  @override
  Future<void> execute(String actionId, ResourceRecord record) {
    if (_detached || _actionBusy || record is! SubmissionStatusResourceRecord) {
      return Future<void>.error(StateError('Submission action is unavailable'));
    }
    SubmissionTransferAction? selected;
    for (final action in record.status.actions) {
      if (action.name == actionId) {
        selected = action;
      }
    }
    if (selected == null) {
      return Future<void>.error(StateError('Submission action is unsupported'));
    }
    final action = selected;
    _actionBusy = true;
    _lastActionResult = null;
    return _accept(() async {
      try {
        final observation = _observation();
        final fresh = await _facade.findTransferStatus(
          record.status.requestId,
          observedAt: observation.$1,
          networkState: observation.$2,
        );
        _live();
        if (fresh == null || !fresh.actions.contains(action)) {
          throw StateError('Submission action is no longer supported');
        }
        // No callback or await separates the live check from command dispatch.
        _live();
        final result = await switch (action) {
          SubmissionTransferAction.retry => _facade.retry(fresh.requestId),
          SubmissionTransferAction.requestRun => _facade.requestRun(
            fresh.requestId,
          ),
        };
        _live();
        _lastActionResult = result;
      } finally {
        _actionBusy = false;
      }
    });
  }

  /// Synchronously retires the owner and returns one idempotent join future.
  Future<void> detach() {
    _detached = true;
    _lastActionResult = null;
    return _detachFuture ??= Future.wait<void>(_pending.toList())
        .then<void>((_) {});
  }
}

/// Pure availability from the observed durable source and handoff lifecycle.
bool registeredMaterialActionAvailable(
  SubmissionTransferStatus status, {
  required bool reconcile,
}) {
  if (status.tklProgress?.state != TklMaterialDeliveryState.registered ||
      status.registration?.state != SubmissionTransferOperationState.succeeded) {
    return false;
  }
  final handoff = status.studioHandoff;
  if (!reconcile) return handoff == null;
  if (handoff == null) return false;
  return handoff.state == RegisteredMaterialHandoffState.pending ||
      handoff.state == RegisteredMaterialHandoffState.failed ||
      handoff.state == RegisteredMaterialHandoffState.outcomeUnknown ||
      (handoff.state == RegisteredMaterialHandoffState.sending &&
          handoff.leaseExpiresAt != null &&
          !handoff.leaseExpiresAt!.isAfter(status.observedAt));
}
