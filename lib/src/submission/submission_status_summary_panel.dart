import 'package:flutter/material.dart';

import 'submission_status_overview_controller.dart';

/// Explicit refresh and navigation over a borrowed current overview.
class SubmissionStatusSummaryPanel extends StatefulWidget {
  const SubmissionStatusSummaryPanel({
    required this.controller,
    this.openStatuses,
    this.title = 'Submission status',
    this.openStatusesLabel = 'View submissions',
    super.key,
  });

  final SubmissionStatusOverviewController controller;
  final VoidCallback? openStatuses;
  final String title;
  final String openStatusesLabel;

  @override
  State<SubmissionStatusSummaryPanel> createState() =>
      _SubmissionStatusSummaryPanelState();
}

class _SubmissionStatusSummaryPanelState
    extends State<SubmissionStatusSummaryPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SubmissionStatusSummaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // Given a current owner event, When mounted, Then display its observation.
    if (mounted) setState(() {});
  }

  void _refresh(SubmissionStatusOverviewController controller) {
    // Given an explicit tap, When its owner is current and idle, Then read freshly.
    if (mounted &&
        identical(controller, widget.controller) &&
        !controller.isDetached &&
        !controller.loading) {
      controller.load();
    }
  }

  void _open(SubmissionStatusOverviewController controller) {
    // Given owner-provided navigation, When explicitly tapped while current,
    // Then invoke it without queue, load or scheduler authority.
    if (mounted &&
        identical(controller, widget.controller) &&
        !controller.isDetached) {
      widget.openStatuses?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final summary = controller.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            if (controller.loading)
              const Text('Loading submission status…')
            else if (controller.failed)
              const Text('Could not load submission status.')
            else if (summary == null)
              const Text('Submission status not loaded.')
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Total: ${summary.totalCount}'),
                  Text('Waiting: ${summary.waitingCount}'),
                  Text('Running: ${summary.runningCount}'),
                  Text('Attention: ${summary.attentionCount}'),
                  Text('Completed: ${summary.completedCount}'),
                ],
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  // Given this rendered owner, When tapped, Then recheck refresh.
                  onPressed: controller.loading || controller.isDetached
                      ? null
                      : () => _refresh(controller),
                  child: const Text('Refresh'),
                ),
                if (widget.openStatuses != null)
                  TextButton(
                    // Given explicit navigation, When tapped, Then recheck owner.
                    onPressed: controller.isDetached
                        ? null
                        : () => _open(controller),
                    child: Text(widget.openStatusesLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
