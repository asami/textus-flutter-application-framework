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
    this.openSubjectLabel = 'Open item',
    super.key,
  });

  final SubmissionStatusWorkspace workspace;
  final Future<void> Function(SubmissionTransferStatus status)? openSubject;
  final String openSubjectLabel;

  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> {
  bool _opening = false;
  bool _openFailed = false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final file in record.status.files) ...[
          Text(configuration.fileLabel(file)),
          Text(configuration.operationStateLabel(file.state)),
          Text('Original ID: ${file.original.id}'),
          Text('Media type: ${file.original.mediaType}'),
          Text('Byte length: ${file.original.byteLength}'),
          if (file.receipt != null)
            Text(
              'Stored at: ${configuration.formatTime(file.receipt!.storedAt)}',
            ),
        ],
        if (notice) const Text('Queued; background scheduling needs attention'),
        if (_openFailed) const Text('Could not open item.'),
        if (widget.openSubject != null)
          Wrap(
            children: [
              TextButton(
                // Given current detail, When tapped, Then reserve typed navigation.
                onPressed: _opening || workspace.isDetached
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
    configuration: widget.workspace.binding.configuration,
    viewModel: widget.workspace.viewModel,
    displayModel: widget.workspace.displayModel,
    detailSupplementBuilder: _supplement,
  );
}
