import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/audio_capture_controller.dart';
import 'application_text_scaling.dart';

/// Exact current editor, separate provider proposals and folded retained history.
class TranscriptReviewPanel extends StatefulWidget {
  /// Borrows the controller; only local text/listener resources are owned.
  const TranscriptReviewPanel({
    required this.controller,
    this.onReviewChanged,
    this.interactionAllowed,
    super.key,
  });

  /// Caller-owned interaction and immutable review.
  final AudioCaptureController controller;

  /// Explicit correction or proposal-selection result, never a disk-save claim.
  final ValueChanged<AudioTranscriptReview>? onReviewChanged;

  /// Borrowed pure caller admission, reevaluated before each user edit/command.
  /// Null preserves controller rules; false or a thrown evaluation denies entry.
  /// Owner calls to the borrowed controller remain independent of this UI gate.
  final bool Function()? interactionAllowed;

  @override
  State<TranscriptReviewPanel> createState() => _TranscriptReviewPanelState();
}

class _TranscriptReviewPanelState extends State<TranscriptReviewPanel> {
  late final TextEditingController _text;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.draftText);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TranscriptReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      _generation++;
      _text.value = TextEditingValue(text: widget.controller.draftText);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    final value = widget.controller.draftText;
    if (_text.text != value) {
      _text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {});
  }

  bool _owns(AudioCaptureController controller, int generation) =>
      mounted &&
      generation == _generation &&
      identical(controller, widget.controller) &&
      !controller.isDetached &&
      !controller.isDisposed;

  bool _allows(AudioCaptureController controller, int generation) {
    // Given the render-time owner, stale callbacks have no current authority.
    // When admission is requested, ownership precedes current policy evaluation.
    if (!_owns(controller, generation)) {
      return false;
    }
    try {
      // Then null preserves compatibility and a live pure policy decides entry.
      return widget.interactionAllowed?.call() ?? true;
    } catch (_) {
      // Then a policy failure is denied without draft or history mutation.
      return false;
    }
  }

  void _edit(AudioCaptureController controller, int generation, String text) {
    // Given a TextField may already have updated its local buffer.
    // When current policy denies the edit, restore only this same owner's buffer.
    if (!_allows(controller, generation)) {
      if (_owns(controller, generation) && _text.text != controller.draftText) {
        final canonical = controller.draftText;
        _text.value = TextEditingValue(
          text: canonical,
          selection: TextSelection.collapsed(offset: canonical.length),
        );
      }
      // Then denied edits never change common dirty state or notify a revision.
      return;
    }
    // Then an admitted edit retains exact Unicode, whitespace and empty intent.
    controller.setDraftText(text);
  }

  void _record(
    AudioCaptureController controller,
    int generation,
    AudioTranscriptReview Function() action,
  ) {
    // Given a correction/proposal action captured by the rendered owner.
    // When it is invoked, reject before touching its controller's review.
    if (!_allows(controller, generation)) {
      return;
    }
    final callback = widget.onReviewChanged;
    AudioTranscriptReview result;
    try {
      result = action();
    } catch (_) {
      return;
    }
    // Then only the same live owner receives the accepted explicit revision.
    if (_owns(controller, generation)) {
      callback?.call(result);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    // Given this render's exact borrowed owner and local editor.
    final generation = _generation;
    // When pure admission determines enabled controls, no controller work starts.
    final interactionAllowed = _allows(controller, generation);
    final review = controller.review;
    final latest = review == null || review.reports.isEmpty
        ? null
        : review.reports.last;
    Widget useButton(
      AudioTranscriptReport report,
      String suffix,
      String label,
    ) => ElevatedButton(
      key: ValueKey('transcript-review-$suffix'),
      // Then bind this owner/generation to _record, which rechecks current
      // admission when the user invokes the callback before mutation.
      onPressed: controller.canEditTranscript && interactionAllowed
          ? () => _record(
              controller,
              generation,
              () => controller.useReport(report.id),
            )
          : null,
      child: Text(label),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (review == null)
          const Text('Record audio first')
        else ...[
          TextField(
            key: const ValueKey('transcript-review-text'),
            controller: _text,
            enabled: controller.canEditTranscript && interactionAllowed,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Current transcript'),
            onChanged: (text) => _edit(controller, generation, text),
          ),
          if (controller.hasUnsavedText) const Text('Unrecorded changes'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                key: const ValueKey('transcript-review-record-correction'),
                onPressed: controller.canRecordCorrection && interactionAllowed
                    ? () => _record(
                        controller,
                        generation,
                        controller.recordCorrection,
                      )
                    : null,
                child: const Text('Record correction'),
              ),
            ],
          ),
          if (latest != null && latest.status == AudioTranscriptStatus.success)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Recognition proposal'),
                    Text(latest.text!),
                    Wrap(
                      children: [
                        useButton(latest, 'use-proposal', 'Use proposal'),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (latest != null) ...[
            Text('Recognition: ${latest.status.name}'),
            if (latest.errorMessage != null) Text(latest.errorMessage!),
            if (latest.errorCode != null)
              Text('Recognition error: ${latest.errorCode}'),
          ],
          ExpansionTile(
            key: const ValueKey('transcript-review-history'),
            title: const Text('Transcript history'),
            children: [
              for (final report in review.reports)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Report ${report.id}: ${report.status.name} at ${report.completedAt.toIso8601String()}',
                      ),
                      if (report.text != null) Text(report.text!),
                      if (report.errorCode != null) Text(report.errorCode!),
                      if (report.errorMessage != null)
                        Text(report.errorMessage!),
                      if (report.status == AudioTranscriptStatus.success)
                        Wrap(
                          children: [
                            useButton(
                              report,
                              'use-${report.id}',
                              'Use this report',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              for (final revision in review.revisions)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${revision.source.name} at ${revision.recordedAt.toIso8601String()}; source: ${revision.reportId ?? 'manual'}',
                      ),
                      Text(revision.text),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
    return scaler == null
        ? content
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: content,
          );
  }
}
