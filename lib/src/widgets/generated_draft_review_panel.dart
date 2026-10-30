import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/generated_draft_controller.dart';

/// Compact derived-draft review. The caller retains controller ownership.
class GeneratedDraftReviewPanel extends StatefulWidget {
  const GeneratedDraftReviewPanel({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final GeneratedDraftController controller;
  final bool enabled;

  @override
  State<GeneratedDraftReviewPanel> createState() =>
      _GeneratedDraftReviewPanelState();
}

class _GeneratedDraftReviewPanelState extends State<GeneratedDraftReviewPanel> {
  int _epoch = 0;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.controller);
  }

  void _subscribe(GeneratedDraftController controller) {
    if (!controller.isDetached && !controller.isDisposed) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant GeneratedDraftReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      _epoch++;
      _subscribe(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  _RenderedDraft? _capture() {
    final controller = widget.controller;
    try {
      return _RenderedDraft(controller, controller.ownerId, _epoch,
        controller.generation, controller.currentContextRevision);
    } catch (_) {
      return null;
    }
  }

  bool _current(_RenderedDraft render, {bool requireEnabled = true}) {
    try {
      return mounted && (!requireEnabled || widget.enabled) &&
          identical(widget.controller, render.controller) &&
          widget.controller.ownerId == render.owner && render.epoch == _epoch &&
          !render.controller.isDetached && !render.controller.isDisposed &&
          render.generation == render.controller.generation &&
          render.revision == render.controller.currentContextRevision;
    } catch (_) {
      return false;
    }
  }

  bool _canDecide(_RenderedDraft render, GeneratedDraftAttempt attempt,
      GeneratedDraftDecisionKind kind) => _current(render) && !_editing &&
      render.controller.canDecide(attempt.id, kind,
        expectedGeneration: render.generation,
        expectedContextRevision: render.revision);

  void _command(_RenderedDraft render, Future<Object?> Function() command,
      {bool cancel = false}) {
    if (!_current(render, requireEnabled: !cancel) ||
        (cancel ? !render.controller.canCancel
            : render.controller.busy || _editing)) {
      return;
    }
    Future<void> run() async {
      try {
        await command();
      } catch (_) {
        // Controller records command errors for the original owner's display.
      }
    }
    unawaited(run());
  }

  void _decide(_RenderedDraft render, GeneratedDraftAttempt attempt,
      GeneratedDraftDecisionKind kind, {String? editedText}) {
    if (!_canDecide(render, attempt, kind)) return;
    try {
      render.controller.decide(attempt.id, kind,
        expectedGeneration: render.generation,
        expectedContextRevision: render.revision, editedText: editedText);
    } catch (_) {
      // The same controller exposes the failure; no uncaught widget future.
    }
  }

  Future<void> _edit(_RenderedDraft render, GeneratedDraftAttempt attempt) async {
    if (!_canDecide(render, attempt, GeneratedDraftDecisionKind.edit)) return;
    var edited = attempt.rawText!;
    setState(() => _editing = true);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final route = ModalRoute.of<String>(dialogContext);
          void close(String? value) {
            if (!dialogContext.mounted || route == null ||
                !route.isActive || !route.isCurrent) {
              return;
            }
            route.navigator?.pop<String>(value);
          }
          return AlertDialog(
            title: const Text('生成下書きを編集して採用'),
            content: TextFormField(
              initialValue: attempt.rawText,
              onChanged: (value) => edited = value,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '採用する下書き（空欄で消去）'),
            ),
            actions: [
              TextButton(onPressed: () => close(null),
                child: const Text('キャンセル')),
              FilledButton(onPressed: () => close(edited),
                child: const Text('採用')),
            ],
          );
        },
      );
      if (result != null && _current(render) &&
          render.controller.canDecide(attempt.id, GeneratedDraftDecisionKind.edit,
            expectedGeneration: render.generation,
            expectedContextRevision: render.revision)) {
        try {
          render.controller.decide(attempt.id, GeneratedDraftDecisionKind.edit,
            expectedGeneration: render.generation,
            expectedContextRevision: render.revision, editedText: result);
        } catch (_) {
          // Preserve the original controller's visible error and local history.
        }
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final render = _capture();
    final source = controller.source;
    final readiness = controller.readiness;
    final pending = controller.workspace.pending.toList();
    final outcomes = controller.workspace.attempts.where(
      (attempt) => attempt.status != GeneratedDraftStatus.success).toList();
    final adopted = controller.workspace.decisions.where(
      (decision) => decision.kind != GeneratedDraftDecisionKind.discard).toList();
    final discards = controller.workspace.decisions.where(
      (decision) => decision.kind == GeneratedDraftDecisionKind.discard).length;
    final available = render != null && _current(render) &&
        !controller.busy && !_editing && source != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('画像の説明・文章の要約',
          style: Theme.of(context).textTheme.titleMedium),
        if (source == null) const Text('先に出典を選んでください。') else ...[
          Text(_sourceLabel(source)),
          Text('出典：${source.id}'),
          if (source.kind == GeneratedDraftSourceKind.text) ...[
            const Text('原文'),
            SelectableText(source.text!),
          ] else if (controller.imageBytes != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 180),
              child: Image.memory(controller.imageBytes!, fit: BoxFit.contain,
                gaplessPlayback: false,
                errorBuilder: (_, _, _) => const Text('画像を表示できません。')),
            ),
          if (readiness != null) ...[
            Text('利用状態：${readiness.state.name}'),
            if (readiness.reason != null) Text(readiness.reason!),
            _provenance(source, readiness: readiness),
          ],
          Wrap(spacing: 8, runSpacing: 4, children: [
            TextButton(key: const ValueKey('generated-draft-probe'),
              onPressed: available
                  ? () => _command(render, controller.checkAvailability) : null,
              child: const Text('利用可否を確認')),
            if (readiness?.state == GeneratedDraftAvailabilityState.downloadable)
              TextButton(key: const ValueKey('generated-draft-prepare'),
                onPressed: available
                    ? () => _command(render, controller.prepare) : null,
                child: const Text('モデルを準備')),
            FilledButton(key: const ValueKey('generated-draft-generate'),
              onPressed: available &&
                  readiness?.state == GeneratedDraftAvailabilityState.available
                  ? () => _command(render, controller.generate) : null,
              child: Text(source.kind == GeneratedDraftSourceKind.image
                  ? '画像の説明を生成' : '文章の要約を生成')),
          ]),
        ],
        if (controller.busy) ...[
          const LinearProgressIndicator(),
          Text(switch (controller.action) {
            'generate' => '生成中（終了処理まで待機します）',
            'prepare' => 'モデルを準備中',
            _ => '利用可否を確認中',
          }),
          if (controller.action == 'generate')
            TextButton(key: const ValueKey('generated-draft-cancel'),
              onPressed: render != null &&
                  _current(render, requireEnabled: false) && controller.canCancel
                  ? () => _command(render, controller.cancel, cancel: true) : null,
              child: const Text('生成をキャンセル')),
        ],
        if (controller.error != null)
          Text('下書き操作のエラー：${controller.error}（保存完了を示すものではありません）'),
        for (final attempt in pending) _pending(attempt, render),
        if (outcomes.isNotEmpty) ...[
          const Text('直近の失敗・キャンセル'),
          Text('${outcomes.last.status.name} / ${outcomes.last.errorCode}'),
          Text(outcomes.last.errorMessage!),
          if (outcomes.last.rawText?.trim().isNotEmpty ?? false)
            SelectableText(outcomes.last.rawText!),
          _provenance(outcomes.last.source, attempt: outcomes.last),
        ],
        if (adopted.isNotEmpty) ...[
          const Text('採用済みの生成下書き'),
          for (final decision in adopted)
            _adopted(controller.workspace.attempts.firstWhere(
              (attempt) => attempt.id == decision.attemptId), decision),
        ],
        if (controller.workspace.decisions.isNotEmpty)
          Text('確認済み ${controller.workspace.decisions.length}件・破棄 $discards件（履歴を保持）'),
      ],
    );
  }

  Widget _pending(GeneratedDraftAttempt attempt, _RenderedDraft? render) {
    final accept = render != null &&
        _canDecide(render, attempt, GeneratedDraftDecisionKind.accept);
    final discard = render != null &&
        _canDecide(render, attempt, GeneratedDraftDecisionKind.discard);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_sourceLabel(attempt.source)),
        Text('生成下書き・出典：${attempt.source.id}'),
        if (attempt.source.text != null) ...[
          const Text('原文'), SelectableText(attempt.source.text!),
        ],
        const Text('生成された未編集の下書き'),
        SelectableText(attempt.rawText!),
        _provenance(attempt.source, attempt: attempt),
        if (discard && !accept)
          const Text('出典が更新または削除されています。採用せず、破棄できます。'),
        Wrap(spacing: 8, children: [
          FilledButton(key: ValueKey('generated-draft-accept-${attempt.id}'),
            onPressed: accept ? () => _decide(render, attempt,
              GeneratedDraftDecisionKind.accept) : null,
            child: const Text('採用')),
          TextButton(key: ValueKey('generated-draft-edit-${attempt.id}'),
            onPressed: accept ? () => _edit(render, attempt) : null,
            child: const Text('編集して採用')),
          TextButton(key: ValueKey('generated-draft-discard-${attempt.id}'),
            onPressed: discard ? () => _decide(render, attempt,
              GeneratedDraftDecisionKind.discard) : null,
            child: const Text('破棄')),
        ]),
      ],
    )));
  }

  Widget _adopted(GeneratedDraftAttempt attempt, GeneratedDraftDecision decision) {
    final text = decision.kind == GeneratedDraftDecisionKind.edit
        ? decision.editedText! : attempt.rawText!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${_sourceLabel(attempt.source)}・出典：${attempt.source.id}'),
      Text('処理：${attempt.operation.name}'),
      if (text.isEmpty) const Text('消去済み') else SelectableText(text),
      _provenance(attempt.source, attempt: attempt),
    ]);
  }

  Widget _provenance(GeneratedDraftSource source, {
    GeneratedDraftAttempt? attempt,
    GeneratedDraftAvailability? readiness,
  }) {
    final snapshot = attempt?.availability ?? readiness;
    return ExpansionTile(title: const Text('出典・生成情報'), children: [
      SelectableText(jsonEncode(source.toJson())),
      if (attempt != null) ...[
        Text('生成 ID：${attempt.id}'),
        Text('プロバイダー：${attempt.providerId}'),
        Text('処理：${attempt.operation.name} / ${attempt.language}'),
        Text('モデル：${attempt.modelName ?? "未実行"}'),
        Text('プロンプト形式：${attempt.promptTemplate}'),
        if (attempt.prompt != null) SelectableText(attempt.prompt!),
        Text('${attempt.startedAt.toIso8601String()} → ${attempt.completedAt.toIso8601String()}'),
        for (final failure in attempt.cleanupFailures) Text(failure),
      ] else if (snapshot != null) ...[
        Text('プロバイダー：${snapshot.providerId}'),
        Text('処理：${snapshot.operation.name} / ${snapshot.language}'),
        Text('モデル：${snapshot.modelName ?? "未準備"}'),
      ],
    ]);
  }

  String _sourceLabel(GeneratedDraftSource source) =>
      source.kind == GeneratedDraftSourceKind.image
          ? '画像の説明（生成下書き）' : '文章の要約（生成下書き）';
}

final class _RenderedDraft {
  const _RenderedDraft(this.controller, this.owner, this.epoch,
    this.generation, this.revision);
  final GeneratedDraftController controller;
  final String owner;
  final int epoch;
  final int generation;
  final Object? revision;
}
