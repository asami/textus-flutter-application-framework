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
    super.key,
  });

  /// Caller-owned interaction and immutable review.
  final AudioCaptureController controller;

  /// Explicit correction or proposal-selection result, never a disk-save claim.
  final ValueChanged<AudioTranscriptReview>? onReviewChanged;

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
    if (!mounted) return;
    final value = widget.controller.draftText;
    if (_text.text != value) {
      _text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {});
  }

  void _record(AudioTranscriptReview Function() action) {
    final controller = widget.controller;
    final callback = widget.onReviewChanged;
    final generation = _generation;
    AudioTranscriptReview result;
    try {
      result = action();
    } catch (_) {
      return;
    }
    if (mounted &&
        generation == _generation &&
        identical(controller, widget.controller) &&
        !controller.isDetached &&
        !controller.isDisposed) {
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
      onPressed: controller.canEditTranscript
          ? () => _record(() => controller.useReport(report.id))
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
            enabled: controller.canEditTranscript,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Current transcript'),
            onChanged: controller.setDraftText,
          ),
          if (controller.hasUnsavedText) const Text('Unrecorded changes'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                key: const ValueKey('transcript-review-record-correction'),
                onPressed: controller.canRecordCorrection
                    ? () => _record(controller.recordCorrection)
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
