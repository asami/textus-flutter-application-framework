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
      if (_owns(c, owner)) setState(() { _saveResult = 'Save completed'; });
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
      Text('Select a passage', style: Theme.of(context).textTheme.titleLarge),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('load', frame == null ? 'Load source image' : 'Reload source image', c.loadSource, enabled: !c.busy),
        button('new', 'New area', c.startNewRegion, enabled: !c.selectionLocked),
      ]),
      if (frame != null) ImageRegionSelector(key: ObjectKey(c), frame: frame,
        selection: c.selection, enabled: allowed && !c.selectionLocked,
        onChanged: (geometry) {
          if (_allows(c, owner, target)) c.setSelection(geometry);
        }),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('confirm', 'Confirm selected area', () { c.confirmSelection(); },
          enabled: frame != null && c.selection != null && !c.selectionLocked),
        button('cancel-selection', 'Cancel area change', c.cancelSelection, enabled: !c.selectionLocked),
        button('preview', 'Preview selected area', c.previewSelection, enabled: confirmed && !c.busy),
      ]),
      if (c.previewBytes != null) SizedBox(height: 160, child: CaptureImagePreview(
        key: ValueKey(c.derivation!.input.id), materialId: c.derivation!.input.id,
        sourceIdentity: c.derivation!, readBytes: () => c.previewBytes,
        semanticLabel: 'Exact saved selected area preview',
        errorBuilder: (_, error, _) => Text('Crop display failed: $error'),
      )),
      Wrap(spacing: 8, runSpacing: 4, children: [
        button('recognize', 'Recognize selected area', c.recognize, enabled: confirmed && !c.busy),
        if (c.busy) button('cancel-result', 'Ignore pending result', c.cancelPendingResult),
      ]),
      if (c.busy) const Text('Area operation in progress'),
      if (ocr != null) ...[
        Text(ocr.result.text!, maxLines: 3, overflow: TextOverflow.ellipsis),
        Align(alignment: Alignment.centerLeft, child: button('use-ocr', 'Use OCR text',
          () => c.useOcrText(latest!.id))),
      ] else if (latest != null) const Text('No executed OCR text. You can enter the quotation manually.'),
      TextField(key: const ValueKey('image-region-quotation'), controller: _quotation,
        enabled: allowed && c.selectedSnapshot != null, minLines: 3, maxLines: null,
        decoration: const InputDecoration(labelText: 'Quotation',
          helperText: 'Keep verbatim wording and check it against the source.'),
        onChanged: (text) {
          if (_allows(c, owner, target)) { c.setQuotationText(text); }
          else if (_owns(c, owner)) { _syncText(); }
        }),
      CheckboxListTile(key: const ValueKey('image-region-source-check'),
        contentPadding: EdgeInsets.zero, title: const Text('I checked the quotation against the source'),
        value: c.sourceConfirmed, onChanged: allowed && c.selectedSnapshot != null
          ? (value) { if (_allows(c, owner, target)) c.setSourceConfirmed(value ?? false); } : null),
      if (c.audioFacade != null) ...[
        Align(alignment: Alignment.centerLeft, child: button('begin-audio', 'Add spoken comment',
          c.beginAudioComment, enabled: confirmed && !c.selectionLocked)),
        if (entry != null) Wrap(spacing: 8, children: [
          for (final link in entry.audioLinks.where((l) => l.regionRevision == c.selectedRevision))
            button('select-audio-${link.audioMaterialId}', 'Open audio ${link.audioMaterialId}',
              () => c.selectAudio(link.audioMaterialId), enabled: !c.selectionLocked),
        ]),
        if (child != null && audioTarget != null) ...[
          AudioCapturePanel(key: ObjectKey(child), controller: child,
            interactionAllowed: audioAllowed, onReviewChanged: attach),
          TranscriptReviewPanel(key: ValueKey(child), controller: child,
            interactionAllowed: audioAllowed, onReviewChanged: attach),
          Align(alignment: Alignment.centerLeft, child: button('use-transcript', 'Use transcript as comment',
            c.useTranscriptAsComment, enabled: child.review != null)),
        ],
      ],
      TextField(key: const ValueKey('image-region-comment'), controller: _comment,
        enabled: allowed && c.selectedSnapshot != null, minLines: 3, maxLines: null,
        decoration: const InputDecoration(labelText: 'Comment',
          helperText: 'Your explanation or spoken comment, separate from the quotation.'),
        onChanged: (text) {
          if (_allows(c, owner, target)) { c.setCommentText(text); }
          else if (_owns(c, owner)) { _syncText(); }
        }),
      Align(alignment: Alignment.centerLeft, child: FilledButton(
        key: const ValueKey('image-region-save'),
        onPressed: allowed && widget.onSave != null ? () => unawaited(_save(c, owner, target)) : null,
        child: Text(_saving ? 'Saving passage…' : 'Save passage'))),
      if (_saveResult != null) Text(_saveResult!),
      if (_error != null || c.error != null) Text('Passage error: ${_error ?? c.error}'),
      ExpansionTile(key: const ValueKey('image-region-history'), title: const Text('Areas and revision history'), children: [
        for (final region in c.workspace.regions.where((e) => e.snapshots.first.source == c.source))
          Wrap(spacing: 8, children: [
            for (final snapshot in region.snapshots)
              button('select-${region.regionId}-${snapshot.revision}',
                '${region.regionId}, revision ${snapshot.revision}',
                () => c.selectRegion(region.regionId, revision: snapshot.revision), enabled: !c.selectionLocked),
          ]),
        if (entry != null) ...[
          for (final text in entry.quotations) ListTile(title: Text(text.text),
            subtitle: Text('Quotation revision ${text.regionRevision}, ${text.origin.name}')),
          for (final text in entry.comments) ListTile(title: Text(text.text),
            subtitle: Text('Comment revision ${text.regionRevision}, ${text.origin.name}')),
        ],
      ]),
      ExpansionTile(key: const ValueKey('image-region-details'), title: const Text('Raw recognition and provider details'), children: [
        Text('Original: ${c.source.id}'),
        if (c.selectedSnapshot != null) Text('Area: ${c.selectedSnapshot!.toJson()}'),
        if (c.derivation != null) Text('Preview provenance: ${c.derivation!.toJson()}'),
        button('availability', 'Check recognition availability', c.refreshAvailability, enabled: !c.busy),
        for (final state in c.readiness) ListTile(title: Text('${state.providerId}: ${state.state.name}'),
          subtitle: Text(state.reason ?? state.modelName ?? ''),
          trailing: state.state == RecognitionProviderState.downloadable ? TextButton(
            onPressed: allowed && !c.busy ? () => unawaited(_run(c, owner, target,
              () => c.prepareProvider(state.providerId))) : null,
            child: const Text('Prepare')) : null),
        for (final extraction in extractions) ...[
          Text('Report ${extraction.id}'),
          for (final run in extraction.comparison.runs) ...[
            Text('${run.desiredConfigurationId}: ${run.status.name}; actual ${run.actualConfigurationId ?? 'unavailable'}'),
            if (run.fallbackReason != null) Text('Fallback: ${run.fallbackReason}'),
            for (final attempt in run.attempts) ...[
              Text('${attempt.providerId}: ${attempt.executed ? 'executed' : 'not executed'}'),
              if (attempt.result.text != null) SelectableText(attempt.result.text!),
              if (attempt.result.interpretation != null) SelectableText(attempt.result.interpretation!),
              for (final failure in attempt.result.failures) Text('${failure.code}: ${failure.message}'),
            ],
          ],
        ],
      ]),
      ExpansionTile(key: const ValueKey('image-region-ai'), title: const Text('Advanced: optional local AI'), children: [
        const Text('Suggestions require explicit selection and a human source check before quotation adoption.'),
        button('recognize-ai', 'Recognize with local AI supplement',
          () => c.recognize(supplementWithLocalAi: true), enabled: confirmed && !c.busy),
        for (final extraction in extractions)
          for (final attempt in extraction.comparison.runs.expand((r) => r.attempts).where((a) => a.executed)) ...[
            if (attempt.result.interpretation != null)
              button('use-ai-${attempt.id}', 'Use interpretation for source checking',
                () => c.useAiCandidate(extraction.id, attempt.id, interpretation: true)),
            for (var i = 0; i < attempt.result.candidates.length; i++)
              button('use-ai-${attempt.id}-$i', 'Use candidate: ${attempt.result.candidates[i].value}',
                () => c.useAiCandidate(extraction.id, attempt.id, candidateIndex: i)),
          ],
      ]),
    ]);
  }
}
