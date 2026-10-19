import 'package:flutter/material.dart';

import 'submission_commit_controller.dart';

/// A borrowed explicit Commit control; the App supplies current eligibility.
class SubmissionCommitButton extends StatefulWidget {
  const SubmissionCommitButton({
    required this.controller,
    required this.eligible,
    this.label = 'Commit',
    this.disabledReason,
    super.key,
  });

  final SubmissionCommitController controller;
  final bool eligible;
  final String label;
  final String? disabledReason;

  @override
  State<SubmissionCommitButton> createState() => _SubmissionCommitButtonState();
}

class _SubmissionCommitButtonState extends State<SubmissionCommitButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SubmissionCommitButton oldWidget) {
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
    // Given a borrowed controller event, When mounted, Then rebuild current state.
    if (mounted) setState(() {});
  }

  void _commit(SubmissionCommitController controller) {
    // Given an explicit tap, When still eligible/current/idle, Then request Commit.
    if (!mounted ||
        !identical(controller, widget.controller) ||
        !widget.eligible ||
        controller.busy ||
        controller.isDetached) {
      return;
    }
    controller.commit();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final result = controller.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          children: [
            FilledButton(
              // Given this rendered controller, When tapped, Then recheck ownership.
              onPressed:
                  widget.eligible && !controller.busy && !controller.isDetached
                  ? () => _commit(controller)
                  : null,
              child: Text(controller.busy ? 'Queuing…' : widget.label),
            ),
          ],
        ),
        if (!widget.eligible && widget.disabledReason != null)
          Text(widget.disabledReason!),
        if (controller.failed) Text(controller.failureMessage!),
        if (result != null) ...[
          Text('Queued for background submission: ${result.record.request.id}'),
          if (result.schedulingFailure != null)
            const Text('Queued; background scheduling needs attention'),
        ],
      ],
    );
  }
}
