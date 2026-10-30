import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Common proposal review. Parent owns persistence and domain value validation.
class StructuredCandidateReviewPanel extends StatefulWidget {
  const StructuredCandidateReviewPanel({
    required this.ownerId,
    required this.workspace,
    required this.fieldLabels,
    required this.currentValues,
    required this.onDecision,
    this.enabled = true,
    this.interactionAllowed,
    this.providerNotice,
    super.key,
  });
  final String ownerId;
  final StructuredCandidateWorkspace workspace;
  final Map<String, String> fieldLabels;
  final Map<String, String?> currentValues;
  final void Function(StructuredFieldProposal, StructuredDecisionKind, String?)
  onDecision;
  final bool enabled;
  final bool Function()? interactionAllowed;
  final String? providerNotice;
  @override
  State<StructuredCandidateReviewPanel> createState() =>
      _StructuredCandidateReviewPanelState();
}

class _StructuredCandidateReviewPanelState
    extends State<StructuredCandidateReviewPanel> {
  int _generation = 0;
  bool _editing = false;
  @override
  void didUpdateWidget(covariant StructuredCandidateReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) _generation++;
  }

  bool _allowed() {
    if (!mounted || !widget.enabled) return false;
    try {
      return widget.interactionAllowed?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  bool _pending(StructuredFieldProposal p) => widget.workspace.pending.any(
    (next) => jsonEncode(next.toJson()) == jsonEncode(p.toJson()),
  );
  bool _renderCurrent(
    StructuredFieldProposal p,
    int generation,
    String source,
  ) =>
      generation == _generation &&
      _allowed() &&
      _pending(p) &&
      jsonEncode(widget.workspace.sourceFor(p).toJson()) == source;

  void _decide(
    StructuredFieldProposal p,
    StructuredDecisionKind kind,
    int generation,
    String source,
    void Function(StructuredFieldProposal, StructuredDecisionKind, String?)
    onDecision,
  ) {
    if (_editing || !_renderCurrent(p, generation, source)) return;
    onDecision(p, kind, null);
  }

  Future<void> _edit(
    StructuredFieldProposal p,
    int generation,
    String source,
    void Function(StructuredFieldProposal, StructuredDecisionKind, String?)
    onDecision,
  ) async {
    if (_editing || !_renderCurrent(p, generation, source)) return;
    var edited = p.value;
    setState(() => _editing = true);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${widget.fieldLabels[p.fieldId] ?? p.fieldId}を編集して採用'),
          content: TextFormField(
            initialValue: p.value,
            onChanged: (value) => edited = value,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '採用する値（空欄で消去）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, edited),
              child: const Text('採用'),
            ),
          ],
        ),
      );
      if (result != null && _renderCurrent(p, generation, source)) {
        onDecision(p, StructuredDecisionKind.edit, result);
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.workspace.pending.toList();
    final fields = pending.map((p) => p.fieldId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.providerNotice != null) Text(widget.providerNotice!),
        if (pending.isEmpty) const Text('未確認の候補はありません。'),
        for (final field in fields)
          _field(
            context,
            field,
            pending.where((p) => p.fieldId == field).toList(),
          ),
        if (widget.workspace.decisions.isNotEmpty)
          Text('確認済み ${widget.workspace.decisions.length}件（履歴を保持）'),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    String field,
    List<StructuredFieldProposal> proposals,
  ) {
    final generation = _generation;
    final onDecision = widget.onDecision;
    final sourceSnapshots = {
      for (final p in proposals)
        p.id: jsonEncode(widget.workspace.sourceFor(p).toJson()),
    };
    final current = widget.currentValues[field];
    final conflict =
        proposals.map((p) => p.value).toSet().length > 1 ||
        (current != null && proposals.any((p) => p.value != current));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.fieldLabels[field] ?? field,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              current == null
                  ? '現在値：未設定'
                  : current.isEmpty
                  ? '現在値：消去済み'
                  : '現在値：$current',
            ),
            if (conflict) const Text('異なる値があります。出典を確認して選んでください。'),
            for (final p in proposals) ...[
              const Divider(),
              SelectableText(p.value),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('出典を見る'),
                subtitle: Text(_sourceLabel(widget.workspace.sourceFor(p))),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      widget.workspace
                          .sourceFor(p)
                          .text
                          .substring(p.start, p.end),
                    ),
                  ),
                  Text('処理：${p.providerId} / ${p.method}'),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: ValueKey('structured-accept-${p.id}'),
                    onPressed: widget.enabled && !_editing
                        ? () => _decide(
                            p,
                            StructuredDecisionKind.accept,
                            generation,
                            sourceSnapshots[p.id]!,
                            onDecision,
                          )
                        : null,
                    child: const Text('採用'),
                  ),
                  TextButton(
                    key: ValueKey('structured-edit-${p.id}'),
                    onPressed: widget.enabled && !_editing
                        ? () => _edit(
                            p,
                            generation,
                            sourceSnapshots[p.id]!,
                            onDecision,
                          )
                        : null,
                    child: const Text('編集して採用'),
                  ),
                  TextButton(
                    key: ValueKey('structured-discard-${p.id}'),
                    onPressed: widget.enabled && !_editing
                        ? () => _decide(
                            p,
                            StructuredDecisionKind.discard,
                            generation,
                            sourceSnapshots[p.id]!,
                            onDecision,
                          )
                        : null,
                    child: const Text('破棄'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _sourceLabel(StructuredTextSource s) =>
      (s.kind == StructuredSourceKind.ocr
          ? '画像 ${s.materialId}・OCR ${s.reportId} / ${s.attemptId}'
          : '音声 ${s.materialId}・文字起こし ${s.transcriptRevisionIndex ?? s.reportId}') +
      (s.regionId == null
          ? ''
          : '・領域 ${s.regionId} revision ${s.regionRevision}');
}
