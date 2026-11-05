import 'dart:async';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/image_region_editor_controller.dart';
import 'audio_capture_panel.dart';
import 'capture_image_preview.dart';
import 'image_region_selector.dart';
import 'transcript_review_panel.dart';

/// Reusable explicit image-area quotation and independent comment editor.
class ImageRegionEditorPanel extends StatefulWidget {
  /// Borrows the controller; mounting never loads, prepares or records anything.
  const ImageRegionEditorPanel({required this.controller, this.onChanged,
    this.onSave, this.interactionAllowed, super.key});

  /// Caller-owned exact-source interaction lifetime.
  final ImageRegionEditorController controller;
  /// Actual immutable adoption, with no file/persistence claim.
  final ValueChanged<ImageRegionEditorChange>? onChanged;
  /// Caller-owned atomic domain Save of workspace and separate audio reviews.
  final Future<void> Function(ImageRegionEditorChange)? onSave;
  /// Pure caller admission reevaluated at each event, including captured events.
  final bool Function()? interactionAllowed;

  @override
  State<ImageRegionEditorPanel> createState() => _ImageRegionEditorPanelState();
}

String _originLabel(RegionTextOrigin origin) => switch (origin) {
  RegionTextOrigin.manual => '手入力',
  RegionTextOrigin.ocr => 'OCR',
  RegionTextOrigin.ai => 'AI候補',
  RegionTextOrigin.transcript => '文字起こし',
};

String _providerStateLabel(RecognitionProviderState state) => switch (state) {
  RecognitionProviderState.available => '利用可能',
  RecognitionProviderState.unavailable => '利用不可',
  RecognitionProviderState.downloadable => 'ダウンロード可能',
  RecognitionProviderState.preparing => '準備中',
};

String _runStatusLabel(RecognitionRunStatus status) => switch (status) {
  RecognitionRunStatus.completed => '完了',
  RecognitionRunStatus.partial => '一部完了',
  RecognitionRunStatus.failed => '失敗',
  RecognitionRunStatus.unavailable => '利用不可',
};

class _ImageRegionEditorPanelState extends State<ImageRegionEditorPanel> {
  late final TextEditingController _quotation;
  late final TextEditingController _comment;
  int _ownerGeneration = 0;
  late int _seenChangeVersion;
  bool _saving = false;
  String? _saveResult;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _quotation = TextEditingController(text: widget.controller.quotationText);
    _comment = TextEditingController(text: widget.controller.commentText);
    _seenChangeVersion = widget.controller.changeVersion;
    widget.controller.addListener(_changed);
  }
  @override
  void didUpdateWidget(ImageRegionEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      _ownerGeneration++;
      _saving = false;
      _saveResult = null;
      _error = null;
      _seenChangeVersion = widget.controller.changeVersion;
      _syncText();
      widget.controller.addListener(_changed);
    }
  }
  void _syncText() {
    void sync(TextEditingController local, String value) {
      if (local.text != value) {
        local.value = TextEditingValue(text: value,
          selection: TextSelection.collapsed(offset: value.length));
      }
    }
    sync(_quotation, widget.controller.quotationText);
    sync(_comment, widget.controller.commentText);
  }
  void _changed() {
    if (!mounted) return;
    final controller = widget.controller;
    final owner = _ownerGeneration;
    _syncText();
    final changed = _seenChangeVersion != controller.changeVersion;
    _seenChangeVersion = controller.changeVersion;
    final callback = widget.onChanged;
    setState(() {});
    if (changed && _owns(controller, owner)) callback?.call(controller.change);
  }
  bool _owns(ImageRegionEditorController c, int owner) => mounted &&
    owner == _ownerGeneration && identical(c, widget.controller) &&
    !c.isDetached && !c.isDisposed;
  bool _allows(ImageRegionEditorController c, int owner, [int? targetGeneration]) {
    if (!_owns(c, owner) || _saving ||
        (targetGeneration != null && c.generation != targetGeneration)) {
      return false;
    }
    try { return widget.interactionAllowed?.call() ?? true; } catch (_) { return false; }
  }
  Future<void> _run(ImageRegionEditorController c, int owner, int target,
    FutureOr<void> Function() action) async {
    if (!_allows(c, owner, target)) return;
    setState(() { _error = null; _saveResult = null; });
    try { await action(); }
    catch (error) { if (_owns(c, owner)) setState(() { _error = error; }); }
  }
  Future<void> _save(ImageRegionEditorController c, int owner, int target) async {
    if (!_allows(c, owner, target)) return;
    final callback = widget.onSave;
    if (callback == null) return;
    try {
      if (c.selectedSnapshot == null || c.selection != c.selectedSnapshot!.geometry) {
        throw StateError('Select and confirm an image area before saving the passage');
      }
      final value = c.commitTextDrafts();
      if (!_allows(c, owner, target)) return;
      setState(() { _saving = true; _saveResult = null; _error = null; });
      await callback(value);
      if (_owns(c, owner)) setState(() { _saveResult = '保存しました'; });
    } catch (error) {
      if (_owns(c, owner)) setState(() { _error = error; });
    } finally {
      if (_owns(c, owner)) setState(() { _saving = false; });
    }
  }
  @override
  void dispose() {
    _ownerGeneration++;
    widget.controller.removeListener(_changed);
    _quotation.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final owner = _ownerGeneration;
    final target = c.generation;
    final allowed = _allows(c, owner, target);
    final confirmed = c.selectedSnapshot != null && c.selection == c.selectedSnapshot!.geometry;
    final frame = c.frame;
    final entry = c.currentEntry;
    final extractions = entry?.extractions.where((e) =>
      e.derivation.region.revision == c.selectedRevision).toList() ?? <ImageRegionExtraction>[];
    final latest = extractions.isEmpty ? null : extractions.last;
    final ocr = latest?.comparison.runs.expand((r) => r.attempts).where((a) =>
      a.executed && a.availability.capabilities.contains(RecognitionCapability.ocr) && a.result.text != null).firstOrNull;
    Widget button(String key, String label, FutureOr<void> Function() action, {bool enabled = true}) =>
      OutlinedButton(key: ValueKey('image-region-$key'),
        onPressed: allowed && enabled ? () => unawaited(_run(c, owner, target, action)) : null,
        child: Text(label));
    final child = c.audioController;
    final audioTarget = c.audioTarget;
    bool audioAllowed() => _allows(c, owner, target) &&
      identical(c.audioController, child) && identical(c.audioTarget, audioTarget) &&
      (c.audioFacade?.pendingOriginal == null || c.ownsPendingAudio);
    void attach(AudioTranscriptReview review) {
      // Accepted work settles to its exact owner independently of new-input policy.
      if (!_owns(c, owner) || child == null || audioTarget == null ||
          !identical(c.audioController, child) || !identical(c.audioTarget, audioTarget) ||
          !identical(c.selectedSnapshot, audioTarget) || audioTarget.source != c.source ||
          child.isDetached || child.isDisposed) {
        return;
      }
      try { c.attachAudioReview(review, target: audioTarget); }
      catch (error) { if (_owns(c, owner)) setState(() { _error = error; }); }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('引用箇所を選ぶ', style: Theme.of(context).textTheme.titleLarge),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('load', frame == null ? '原画像を開く' : '原画像を再読み込み', c.loadSource, enabled: !c.busy),
        button('new', '新しい範囲', c.startNewRegion, enabled: !c.selectionLocked),
      ]),
      if (frame != null) ImageRegionSelector(key: ObjectKey(c), frame: frame,
        selection: c.selection, enabled: allowed && !c.selectionLocked,
        onChanged: (geometry) {
          if (_allows(c, owner, target)) c.setSelection(geometry);
        }),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('confirm', '選択範囲を確定', () { c.confirmSelection(); },
          enabled: frame != null && c.selection != null && !c.selectionLocked),
        button('cancel-selection', '範囲の変更を取り消す', c.cancelSelection, enabled: !c.selectionLocked),
        button('preview', '選択範囲を確認', c.previewSelection, enabled: confirmed && !c.busy),
      ]),
      if (c.previewBytes != null) SizedBox(height: 160, child: CaptureImagePreview(
        key: ValueKey(c.derivation!.input.id), materialId: c.derivation!.input.id,
        sourceIdentity: c.derivation!, readBytes: () => c.previewBytes,
        semanticLabel: '保存済みの選択範囲',
        errorBuilder: (_, error, _) => const Text('選択範囲を表示できませんでした。'),
      )),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('recognize', '選択範囲を文字起こし', c.recognize, enabled: confirmed && !c.busy),
        if (c.busy) button('cancel-result', '処理結果を採用せず中止', c.cancelPendingResult),
      ]),
      if (c.busy) const Text('選択範囲を処理しています'),
      if (ocr != null) ...[
        Text(ocr.result.text!, maxLines: 3, overflow: TextOverflow.ellipsis),
        Align(alignment: Alignment.centerLeft, child: button('use-ocr', 'OCRの文字を引用文に使う',
          () => c.useOcrText(latest!.id))),
      ] else if (latest != null) const Text('読み取れた文字がありません。引用文を入力することもできます。'),
      TextField(key: const ValueKey('image-region-quotation'), controller: _quotation,
        enabled: allowed && c.selectedSnapshot != null, minLines: 3, maxLines: null,
        decoration: const InputDecoration(labelText: '引用文',
          helperText: '原文の表記を保ち、画像と照合してください。'),
        onChanged: (text) {
          if (_allows(c, owner, target)) { c.setQuotationText(text); }
          else if (_owns(c, owner)) { _syncText(); }
        }),
      CheckboxListTile(key: const ValueKey('image-region-source-check'),
        contentPadding: EdgeInsets.zero, title: const Text('引用文を原文と照合した'),
        value: c.sourceConfirmed, onChanged: allowed && c.selectedSnapshot != null
          ? (value) { if (_allows(c, owner, target)) c.setSourceConfirmed(value ?? false); } : null),
      if (c.audioFacade != null) ...[
        Align(alignment: Alignment.centerLeft, child: button('begin-audio', '音声コメントを追加',
          c.beginAudioComment, enabled: confirmed && !c.selectionLocked)),
        if (entry != null) Wrap(spacing: 8, children: [
          for (final link in entry.audioLinks.where((l) => l.regionRevision == c.selectedRevision))
            button('select-audio-${link.audioMaterialId}', '音声を開く ${link.audioMaterialId}',
              () => c.selectAudio(link.audioMaterialId), enabled: !c.selectionLocked),
        ]),
        if (child != null && audioTarget != null) ...[
          AudioCapturePanel(key: ObjectKey(child), controller: child,
            interactionAllowed: audioAllowed, onReviewChanged: attach),
          TranscriptReviewPanel(key: ValueKey(child), controller: child,
            interactionAllowed: audioAllowed, onReviewChanged: attach),
          Align(alignment: Alignment.centerLeft, child: button('use-transcript', '文字起こしをコメントに使う',
            c.useTranscriptAsComment, enabled: child.review != null)),
        ],
      ],
      TextField(key: const ValueKey('image-region-comment'), controller: _comment,
        enabled: allowed && c.selectedSnapshot != null, minLines: 3, maxLines: null,
        decoration: const InputDecoration(labelText: 'コメント',
          helperText: '引用文とは分けて、自分の説明や音声コメントを記入します。'),
        onChanged: (text) {
          if (_allows(c, owner, target)) { c.setCommentText(text); }
          else if (_owns(c, owner)) { _syncText(); }
        }),
      Align(alignment: Alignment.centerLeft, child: FilledButton(
        key: const ValueKey('image-region-save'),
        onPressed: allowed && widget.onSave != null ? () => unawaited(_save(c, owner, target)) : null,
        child: Text(_saving ? '引用・コメントを保存しています…' : '引用・コメントを保存'))),
      if (_saveResult != null) Text(_saveResult!),
      if (_error != null || c.error != null) Text('操作を完了できませんでした。範囲を確定し、引用文を原文と照合してから再度お試しください。処理の詳細も確認できます。'),
      ExpansionTile(key: const ValueKey('image-region-history'), title: const Text('範囲と変更履歴'), children: [
        for (final region in c.workspace.regions.where((e) => e.snapshots.first.source == c.source))
          Wrap(spacing: 8, children: [
            for (final snapshot in region.snapshots)
              button('select-${region.regionId}-${snapshot.revision}',
                '${region.regionId}、変更履歴 ${snapshot.revision}',
                () => c.selectRegion(region.regionId, revision: snapshot.revision), enabled: !c.selectionLocked),
          ]),
        if (entry != null) ...[
          for (final text in entry.quotations) ListTile(title: Text(text.text),
            subtitle: Text('引用文の変更履歴 ${text.regionRevision}、${_originLabel(text.origin)}')),
          for (final text in entry.comments) ListTile(title: Text(text.text),
            subtitle: Text('コメントの変更履歴 ${text.regionRevision}、${_originLabel(text.origin)}')),
        ],
      ]),
      ExpansionTile(key: const ValueKey('image-region-details'), title: const Text('認識結果・処理の詳細'), children: [
        if (_error != null || c.error != null) Text('処理の詳細: ${_error ?? c.error}'),
        Text('原画像: ${c.source.id}'),
        if (c.selectedSnapshot != null) Text('選択範囲: ${c.selectedSnapshot!.toJson()}'),
        if (c.derivation != null) Text('確認画像の導出元: ${c.derivation!.toJson()}'),
        button('availability', '文字認識の利用可否を確認', c.refreshAvailability, enabled: !c.busy),
        for (final state in c.readiness) ListTile(title: Text('${state.providerId}: ${_providerStateLabel(state.state)}'),
          subtitle: Text(state.reason ?? state.modelName ?? ''),
          trailing: state.state == RecognitionProviderState.downloadable ? TextButton(
            onPressed: allowed && !c.busy ? () => unawaited(_run(c, owner, target,
              () => c.prepareProvider(state.providerId))) : null,
            child: const Text('利用準備')) : null),
        for (final extraction in extractions) ...[
          Text('認識記録 ${extraction.id}'),
          for (final run in extraction.comparison.runs) ...[
            Text('${run.desiredConfigurationId}: ${_runStatusLabel(run.status)}; 実際の構成 ${run.actualConfigurationId ?? '利用不可'}'),
            if (run.fallbackReason != null) Text('標準処理への切替理由: ${run.fallbackReason}'),
            for (final attempt in run.attempts) ...[
              Text('${attempt.providerId}: ${attempt.executed ? '実行済み' : '未実行'}'),
              if (attempt.result.text != null) SelectableText(attempt.result.text!),
              if (attempt.result.interpretation != null) SelectableText(attempt.result.interpretation!),
              for (final failure in attempt.result.failures) Text('${failure.code}: ${failure.message}'),
            ],
          ],
        ],
      ]),
      ExpansionTile(key: const ValueKey('image-region-ai'), title: const Text('詳細設定：端末内AIによる補完'), children: [
        const Text('候補は自分で選び、原文と照合してから引用文として採用してください。'),
        button('recognize-ai', '端末内AIで補完して読み取る',
          () => c.recognize(supplementWithLocalAi: true), enabled: confirmed && !c.busy),
        for (final extraction in extractions)
          for (final attempt in extraction.comparison.runs.expand((r) => r.attempts).where((a) => a.executed)) ...[
            if (attempt.result.interpretation != null)
              button('use-ai-${attempt.id}', '解釈を原文確認の参考にする',
                () => c.useAiCandidate(extraction.id, attempt.id, interpretation: true)),
            for (var i = 0; i < attempt.result.candidates.length; i++)
              button('use-ai-${attempt.id}-$i', '候補を使う: ${attempt.result.candidates[i].value}',
                () => c.useAiCandidate(extraction.id, attempt.id, candidateIndex: i)),
          ],
      ]),
    ]);
  }
}
