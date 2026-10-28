import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'audio_capture_controller.dart';
import 'audio_capture_facade.dart';
import 'image_region_facade.dart';

/// One immutable domain-save input; notification alone makes no save claim.
final class ImageRegionEditorChange {
  /// Snapshots the separate audio review map and validates its workspace links.
  ImageRegionEditorChange({required this.workspace,
    required Map<String, AudioTranscriptReview> audioReviews})
    : audioReviews = Map.unmodifiable(audioReviews) {
    workspace.validateAudioReviews(this.audioReviews);
  }

  /// Immutable Core region histories, without audio bytes or duplicated reports.
  final ImageRegionWorkspace workspace;
  /// Separate immutable reviews keyed by unchanged original audio identity.
  final Map<String, AudioTranscriptReview> audioReviews;
}

/// Caller-owned exact-source editor. Construction and mounting are inert.
final class ImageRegionEditorController implements Listenable {
  /// Borrows services; restored entries for other originals remain untouched.
  ImageRegionEditorController({required this.facade, required this.source,
    ImageRegionWorkspace? initialWorkspace,
    Map<String, AudioTranscriptReview> initialAudioReviews = const {},
    this.audioFacade, DateTime Function()? now, String Function()? idGenerator})
    : _workspace = initialWorkspace ?? ImageRegionWorkspace(),
      _reviews = Map.unmodifiable(initialAudioReviews),
      _now = now ?? DateTime.now, _idGenerator = idGenerator ?? _randomId {
    if (!source.mediaType.startsWith('image/')) {
      throw ArgumentError('An exact image original is required');
    }
    for (final item in _reviews.entries) {
      if (item.key != item.value.original.material.id) {
        throw ArgumentError('Audio review key differs from its original');
      }
    }
    _workspace.validateAudioReviews(_reviews);
    final matching = _workspace.regions.where((e) => e.snapshots.first.source == source);
    if (matching.isNotEmpty) {
      _regionId = matching.last.regionId;
      _revision = matching.last.snapshots.last.revision;
      _selection = matching.last.snapshots.last.geometry;
    }
  }

  /// Borrowed common processing boundary.
  final ImageRegionFacade facade;
  /// Exact original being edited for this owner's entire lifetime.
  final CaptureMaterialReference source;
  /// Optional borrowed common audio service boundary.
  final AudioCaptureFacade? audioFacade;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final _RegionNotifier _notifier = _RegionNotifier();
  final Map<VoidCallback, List<VoidCallback>> _listeners = {};
  final Map<(String, int), _TextDrafts> _drafts = {};
  final Set<String> _issuedIds = {};
  final Map<String, AudioTranscriptReview> _retainedReviews = {};
  final List<ImageRegionDerivation> _retainedDerivations = [];
  final List<ImageRegionExtraction> _retainedExtractions = [];
  ImageRegionWorkspace _workspace;
  Map<String, AudioTranscriptReview> _reviews;
  ImageRegionFrame? _frame;
  ImageRegionGeometry? _selection;
  String? _regionId;
  int? _revision;
  ImageRegionDerivation? _derivation;
  Uint8List? _previewBytes;
  List<RecognitionProviderAvailability> _availability = const [];
  AudioCaptureController? _audioController;
  ImageRegionSnapshot? _audioTarget;
  AudioCaptureController? _capturingChild;
  ImageRegionSnapshot? _capturingTarget;
  CapturedAudio? _pendingAudio;
  Future<void> _audioRetirement = Future<void>.value();
  Future<void>? _operation;
  Future<void>? _detachment;
  Object? _error;
  bool _detached = false;
  bool _disposed = false;
  bool _notifierDisposed = false;
  bool _disposalSettled = false;
  bool _audioReplacing = false;
  bool _preservingAudioDraft = false;
  int _retiringAudio = 0;
  int _generation = 0;
  int _changeVersion = 0;
  int _notificationDepth = 0;

  /// Immutable append-only common workspace.
  ImageRegionWorkspace get workspace => _workspace;
  /// Immutable separately owned audio reviews.
  Map<String, AudioTranscriptReview> get audioReviews => _reviews;
  /// Actual canonical raster, available only after explicit load.
  ImageRegionFrame? get frame => _frame;
  /// Current source-space draft geometry.
  ImageRegionGeometry? get selection => _selection;
  /// Exact currently selected entry, or null for a new selection.
  ImageRegionEntry? get currentEntry {
    for (final e in _workspace.regions) { if (e.regionId == _regionId) return e; }
    return null;
  }
  /// Exact retained snapshot, independent of a changed geometry draft.
  ImageRegionSnapshot? get selectedSnapshot => _revision == null
      ? null : currentEntry?.snapshots[_revision! - 1];
  /// Selected stable identity.
  String? get selectedRegionId => _regionId;
  /// Selected retained revision.
  int? get selectedRevision => _revision;
  /// Exact preview provenance for the selected snapshot.
  ImageRegionDerivation? get derivation => _derivation;
  /// Defensive actual stored crop PNG bytes.
  Uint8List? get previewBytes => _previewBytes == null
      ? null : Uint8List.fromList(_previewBytes!);
  /// At most one actual region command remains in flight, even after cancel.
  bool get busy => _operation != null || _audioReplacing;
  /// Last actual command failure or explicit validation failure.
  Object? get error => _error;
  /// Explicit readiness snapshots; an empty list means no check was requested.
  List<RecognitionProviderAvailability> get readiness => _availability;
  /// Terminal route retirement state.
  bool get isDetached => _detached;
  /// Terminal listener-resource state.
  bool get isDisposed => _disposed;
  /// Admission generation for owner-bound UI callbacks.
  int get generation => _generation;
  /// Changes only when actual immutable workspace/review adoption occurs.
  int get changeVersion => _changeVersion;
  /// Common audio controls own recording/transcription/review behavior.
  AudioCaptureController? get audioController => _audioController;
  /// Immutable target captured when the child was explicitly opened.
  ImageRegionSnapshot? get audioTarget => _audioTarget;
  /// Actual reviews retained even when their late result cannot be linked.
  Map<String, AudioTranscriptReview> get retainedAudioReviews =>
      Map.unmodifiable(_retainedReviews);
  /// Actual durable outputs that may have completed after selection retirement.
  List<ImageRegionDerivation> get retainedDerivations => List.unmodifiable(_retainedDerivations);
  /// Raw durable reports remain inspectable without stale workspace adoption.
  List<ImageRegionExtraction> get retainedExtractions => List.unmodifiable(_retainedExtractions);
  /// Exact quotation buffer for this region revision.
  String get quotationText => selectedSnapshot == null ? '' : _currentDraft.quotation.text;
  /// Exact independent comment buffer for this region revision.
  String get commentText => selectedSnapshot == null ? '' : _currentDraft.comment.text;
  /// Human source-check intent for the current quotation buffer.
  bool get sourceConfirmed => selectedSnapshot != null && _currentDraft.quotation.confirmed;
  /// Explicit quotation edit/clear not yet appended to history.
  bool get quotationDirty => selectedSnapshot != null && _currentDraft.quotation.dirty;
  /// Explicit comment edit/clear not yet appended to history.
  bool get commentDirty => selectedSnapshot != null && _currentDraft.comment.dirty;
  /// Any existing target's edited quotation/comment, including an exact clear.
  /// Inspection never creates a target buffer or performs work.
  bool get hasUnsavedText => _drafts.values.any((draft) =>
      draft.quotation.dirty || draft.comment.dirty);
  /// A drawn area which has not been confirmed as the selected snapshot.
  bool get hasUnconfirmedSelection => _selection != null &&
      (selectedSnapshot == null || _selection != selectedSnapshot!.geometry);
  /// Pending intent, owned work, or actual audio review not yet published.
  /// Remains inspectable after detach for the initiating owner's handoff.
  bool get hasPendingInput {
    final child = _audioController;
    final review = child?.review;
    return hasUnsavedText || hasUnconfirmedSelection || busy || selectionLocked || _retiringAudio != 0 ||
        (child?.hasUnsavedText ?? false) || audioFacade?.pendingOriginal != null ||
        (review != null && _reviews[review.original.material.id] != review) ||
        _retainedReviews.entries.any((entry) => _reviews[entry.key] != entry.value);
  }
  /// Exact pending import observed after this child's successful local capture.
  /// This pure read never claims pending bytes from another service borrower.
  bool get ownsPendingAudio {
    final child = _audioController;
    final target = _audioTarget;
    final pending = audioFacade?.pendingOriginal;
    return _live && child != null && target != null && pending != null &&
        !child.isDetached && !child.isDisposed && identical(child, _capturingChild) &&
        identical(target, _capturingTarget) && identical(target, selectedSnapshot) &&
        target.source == source && identical(pending, _pendingAudio);
  }
  /// Owned operations and a bound target's pending original prevent rebinding.
  bool get selectionLocked => _audioReplacing || (_audioController?.busy ?? false) ||
      (_audioTarget != null && audioFacade?.pendingOriginal != null);
  bool get _live => !_detached && !_disposed;

  _TextDrafts get _currentDraft => _draftFor(selectedSnapshot!);
  _TextDrafts _draftFor(ImageRegionSnapshot snapshot) =>
      _drafts.putIfAbsent((snapshot.regionId, snapshot.revision), () {
        final entry = _workspace.regions.firstWhere((e) => e.regionId == snapshot.regionId);
        final quotes = entry.quotations.where((v) => v.regionRevision == snapshot.revision);
        final comments = entry.comments.where((v) => v.regionRevision == snapshot.revision);
        return _TextDrafts(_TextBuffer.fromRevision(quotes.isEmpty ? null : quotes.last),
          _TextBuffer.fromRevision(comments.isEmpty ? null : comments.last));
      });

  /// Explicit source read; no providers or microphone are prepared.
  Future<void> loadSource() => _command((token, snapshot) async {
    final value = await facade.loadFrame(source);
    if (_matches(token, snapshot)) {
      if (value.source != source) throw StateError('Frame belongs to another original');
      _frame = value;
    }
  });

  /// Updates source geometry only; manual text buffers stay with their targets.
  void setSelection(ImageRegionGeometry geometry) {
    _requireSelection();
    if (_frame == null) throw StateError('Load the source image first');
    _retireSelection();
    _selection = geometry;
    _notify();
  }

  /// Restores retained geometry without deleting drafts or retained histories.
  void cancelSelection() {
    _requireSelection();
    _retireSelection();
    _selection = selectedSnapshot?.geometry;
    _notify();
  }

  /// Selects only this exact original's retained region and revision.
  void selectRegion(String regionId, {int? revision}) {
    _requireSelection();
    final matches = _workspace.regions.where((e) => e.regionId == regionId);
    if (matches.isEmpty) throw ArgumentError('Unknown region');
    final entry = matches.single;
    final r = revision ?? entry.snapshots.last.revision;
    if (entry.snapshots.first.source != source || r <= 0 || r > entry.snapshots.length) {
      throw ArgumentError('Select an existing revision of this exact original');
    }
    _retireSelection();
    _regionId = regionId;
    _revision = r;
    _selection = selectedSnapshot!.geometry;
    _notify();
  }

  /// Begins another region without moving or dropping another target's drafts.
  void startNewRegion() {
    _requireSelection();
    _retireSelection();
    _regionId = null;
    _revision = null;
    _selection = null;
    _notify();
  }

  /// Appends a stable region or next contiguous geometry revision explicitly.
  ImageRegionEditorChange confirmSelection() {
    _requireSelection();
    final frame = _frame;
    final geometry = _selection;
    if (frame == null || geometry == null) throw StateError('Load and draw a positive image area first');
    final old = selectedSnapshot;
    if (old != null && geometry == old.geometry) return change;
    _preserveAudioDraft();
    final entry = currentEntry;
    final id = entry?.regionId ?? _nextId();
    final snapshot = ImageRegionSnapshot(regionId: id,
      revision: (entry?.snapshots.length ?? 0) + 1, source: source,
      pixelWidth: frame.pixelWidth, pixelHeight: frame.pixelHeight,
      geometry: geometry, recordedAt: _time([
        source.capturedAt, if (entry != null) entry.snapshots.last.recordedAt,
      ]));
    final next = entry == null ? ImageRegionEntry(snapshots: [snapshot])
      : _copyEntry(entry, snapshots: [...entry.snapshots, snapshot]);
    final workspace = _replace(_workspace, next);
    _retireSelection();
    _regionId = id;
    _revision = snapshot.revision;
    _publish(workspace, _reviews);
    return change;
  }

  /// Derives and reads only the exact confirmed snapshot; never a draft crop.
  Future<void> previewSelection() {
    _requireConfirmed();
    return _command((token, snapshot) async {
      await _deriveAndRead(token, snapshot!);
    });
  }

  Future<ImageRegionDerivation> _deriveAndRead(int token, ImageRegionSnapshot snapshot) async {
    var value = _matches(token, snapshot) ? _derivation : null;
    if (value == null) {
      value = await facade.derive(snapshot);
      _retainedDerivations.add(value);
    }
    final bytes = await facade.readDerived(value);
    if (_matches(token, snapshot)) {
      _derivation = value;
      _previewBytes = Uint8List.fromList(bytes);
    }
    return value;
  }

  /// Retains raw recognition, without preparing providers or adopting text.
  Future<void> recognize({bool supplementWithLocalAi = false}) {
    _requireConfirmed();
    return _command((token, snapshot) async {
      final derived = await _deriveAndRead(token, snapshot!);
      if (!_matches(token, snapshot)) return;
      final extraction = await facade.recognize(derived,
        supplementWithLocalAi: supplementWithLocalAi);
      _retainedExtractions.add(extraction);
      if (!_matches(token, snapshot)) return;
      final entry = currentEntry!;
      _publish(_replace(_workspace, _copyEntry(entry,
        extractions: [...entry.extractions, extraction])), _reviews);
    });
  }

  /// Explicit provider readiness check, separate from inference/preparation.
  Future<void> refreshAvailability() => _command((token, snapshot) async {
    final result = await facade.availability();
    if (_matches(token, snapshot)) _availability = List.unmodifiable(result);
  });

  /// Explicit provider preparation, never dispatched by build or construction.
  Future<void> prepareProvider(String providerId) => _command((token, snapshot) async {
    final result = await facade.prepareProvider(providerId);
    if (_matches(token, snapshot)) {
      _availability = List.unmodifiable([
        ..._availability.where((r) => r.providerId != providerId), result,
      ]);
    }
  });

  /// Retires result adoption; the actual command remains busy until it settles.
  void cancelPendingResult() {
    _requireLive();
    _generation++;
    _notify();
  }

  /// Exact manual quotation text; existing selected source association survives.
  void setQuotationText(String text) {
    _requireText();
    _currentDraft.quotation..text = text..dirty = true;
    _notify();
  }

  /// Exact independent manual comment text, including an intentional clear.
  void setCommentText(String text) {
    _requireText();
    _currentDraft.comment..text = text..dirty = true;
    _notify();
  }

  /// Explicit inspection intent, required even for manually entered quotations.
  void setSourceConfirmed(bool value) {
    _requireText();
    _currentDraft.quotation..confirmed = value..dirty = true;
    _notify();
  }

  ImageRegionExtraction _extraction(String? id) {
    _requireText();
    final matches = currentEntry!.extractions.where((e) =>
      e.derivation.region.revision == _revision && (id == null || e.id == id));
    if (matches.isEmpty) throw StateError('Recognize this confirmed revision first');
    return matches.last;
  }

  /// Prefills only actual executed OCR from this revision; confirmation resets.
  void useOcrText([String? extractionId]) {
    final extraction = _extraction(extractionId);
    final attempts = extraction.comparison.runs.expand((r) => r.attempts).where((a) =>
      a.executed && a.availability.capabilities.contains(RecognitionCapability.ocr) && a.result.text != null);
    if (attempts.isEmpty) throw StateError('No executed OCR text for this area; enter text manually');
    _currentDraft.quotation.adopt(attempts.first.result.text!, RegionTextOrigin.ocr, extraction.id);
    _notify();
  }

  /// Explicitly selects actual AI output; human source confirmation is separate.
  void useAiCandidate(String extractionId, String attemptId,
    {int? candidateIndex, bool interpretation = false}) {
    final extraction = _extraction(extractionId);
    final attempts = extraction.comparison.runs.expand((r) => r.attempts)
      .where((a) => a.id == attemptId && a.executed);
    if (attempts.isEmpty || (interpretation == (candidateIndex != null))) {
      throw ArgumentError('Choose one executed AI candidate or interpretation');
    }
    final attempt = attempts.first;
    String text;
    if (interpretation) {
      if (!attempt.availability.capabilities.contains(RecognitionCapability.imageInterpretation) ||
          attempt.result.interpretation == null) { throw ArgumentError('No executed interpretation'); }
      text = attempt.result.interpretation!;
    } else {
      final index = candidateIndex!;
      if (!attempt.availability.capabilities.contains(RecognitionCapability.candidateOrganization) ||
          !attempt.result.candidateOrganizationCompleted || index < 0 ||
          index >= attempt.result.candidates.length) { throw ArgumentError('No executed candidate'); }
      text = attempt.result.candidates[index].value;
    }
    _currentDraft.quotation.adopt(text, RegionTextOrigin.ai, extraction.id);
    _notify();
  }

  /// Appends only the current confirmed quotation buffer.
  ImageRegionEditorChange recordQuotation() => _commit(only: (_regionId, _revision, true));
  /// Appends only the current comment buffer, without a source-check requirement.
  ImageRegionEditorChange recordComment() => _commit(only: (_regionId, _revision, false));
  /// Atomically validates and appends every dirty target; failures adopt nothing.
  ImageRegionEditorChange commitTextDrafts() => _commit();
  /// Immutable current save/notification input.
  ImageRegionEditorChange get change => ImageRegionEditorChange(workspace: _workspace, audioReviews: _reviews);

  ImageRegionEditorChange _commit({(String?, int?, bool)? only}) {
    _requireLive();
    if (only != null) _requireText();
    final pending = <(ImageRegionSnapshot, _TextBuffer, bool)>[];
    for (final item in _drafts.entries) {
      final entry = _workspace.regions.firstWhere((e) => e.regionId == item.key.$1);
      final snapshot = entry.snapshots[item.key.$2 - 1];
      for (final isQuote in [true, false]) {
        final b = isQuote ? item.value.quotation : item.value.comment;
        if (b.dirty && (only == null ||
            (only.$1 == snapshot.regionId && only.$2 == snapshot.revision && only.$3 == isQuote))) {
          if (isQuote && !b.confirmed) throw StateError('Check each dirty quotation against its source before saving');
          pending.add((snapshot, b, isQuote));
        }
      }
    }
    final child = only == null ? _audioController : null;
    final target = _audioTarget;
    final token = _generation;
    if (only == null && (_audioReplacing || (child?.busy ?? false) ||
        audioFacade?.pendingOriginal != null)) {
      throw StateError('Finish the audio operation or save the pending original before saving the passage');
    }
    if (child != null && (child.isDetached || child.isDisposed || target == null ||
        !identical(target, selectedSnapshot) || target.source != source)) {
      throw StateError('Open audio for the current confirmed area before saving the passage');
    }
    var next = _workspace;
    for (final item in pending) {
      final snapshot = item.$1;
      final b = item.$2;
      final e = next.regions.firstWhere((v) => v.regionId == snapshot.regionId);
      final revision = RegionTextRevision(id: _nextId(), regionRevision: snapshot.revision,
        text: b.text, recordedAt: _time([
          snapshot.recordedAt,
          ...e.quotations.map((v) => v.recordedAt), ...e.comments.map((v) => v.recordedAt),
          ...e.extractions.map((v) => v.comparison.createdAt),
          ...e.audioLinks.map((v) => v.recordedAt),
          if (b.audioId != null) ..._reviewTimes(_reviews[b.audioId]!),
        ]), origin: b.origin, sourceReportId: b.reportId,
        audioMaterialId: b.audioId, transcriptRevisionIndex: b.transcriptIndex,
        sourceConfirmed: b.confirmed);
      next = _replace(next, _copyEntry(e,
        quotations: item.$3 ? [...e.quotations, revision] : null,
        comments: item.$3 ? null : [...e.comments, revision]));
    }
    next.validateAudioReviews(_reviews);
    ImageRegionWorkspace.requireRetainedPrefix(_workspace, next);
    var reviews = _reviews;
    var audioChanged = false;
    if (child != null && child.hasUnsavedText) {
      final audioTarget = target!;
      final review = child.recordCorrection();
      // Notification may synchronously retire this owner. Keep the actual
      // correction available for handoff, but never publish it to a stale target.
      _retainReview(review);
      if (!_matches(token, target) || !identical(child, _audioController) ||
          !identical(target, _audioTarget) || child.isDetached || child.isDisposed) {
        throw StateError('Audio owner retired while saving; retain its review before reopening');
      }
      final id = review.original.material.id;
      final old = _reviews[id];
      if (old != null) AudioTranscriptReview.requireRetainedPrefix(old, review);
      for (final entry in next.regions) {
        for (final link in entry.audioLinks.where((l) => l.audioMaterialId == id)) {
          if (entry.regionId != audioTarget.regionId || link.regionRevision != audioTarget.revision) {
            throw ArgumentError('An audio original cannot rebind to another region');
          }
        }
      }
      final entry = next.regions.firstWhere((e) => e.regionId == audioTarget.regionId);
      if (!entry.audioLinks.any((l) => l.audioMaterialId == id)) {
        next = _replace(next, _copyEntry(entry, audioLinks: [
          ...entry.audioLinks, RegionAudioLink(audioMaterialId: id, regionRevision: audioTarget.revision,
            recordedAt: _time([audioTarget.recordedAt, review.original.material.capturedAt])),
        ]));
      }
      reviews = {..._reviews, id: review};
      audioChanged = true;
    }
    for (final item in pending) { item.$2.dirty = false; }
    if (pending.isNotEmpty || audioChanged) _publish(next, reviews);
    return change;
  }

  /// Explicitly opens common audio controls for the exact confirmed snapshot.
  Future<void> beginAudioComment() => _openAudio(null);

  /// Restores an original already linked to this exact region revision.
  Future<void> selectAudio(String audioMaterialId) {
    _requireConfirmed();
    if (!currentEntry!.audioLinks.any((l) => l.audioMaterialId == audioMaterialId && l.regionRevision == _revision)) {
      throw ArgumentError('Audio belongs to another area or revision');
    }
    return _openAudio(_reviews[audioMaterialId]!);
  }

  Future<void> _openAudio(AudioTranscriptReview? review) async {
    _requireConfirmed();
    if (audioFacade?.pendingOriginal != null) {
      throw StateError('Retry the pending audio original with its initiating controls before opening audio');
    }
    if (selectionLocked || audioFacade == null) throw StateError('Audio unavailable or an owned operation is active');
    _preserveAudioDraft();
    if (review != null) review = _reviews[review.original.material.id]!;
    final target = selectedSnapshot!;
    final token = _generation;
    _audioReplacing = true;
    _retireAudio();
    _notify();
    try {
      await _audioRetirement;
      if (!_matches(token, target)) return;
      if (audioFacade!.pendingOriginal != null) {
        throw StateError('Retry the pending audio original with its initiating controls before opening audio');
      }
      _audioTarget = target;
      _audioController = AudioCaptureController(facade: audioFacade!, initialReview: review, now: _now);
      _audioController!.addListener(_audioChanged);
    } catch (error) {
      if (_live) _error = error;
      rethrow;
    } finally {
      _audioReplacing = false;
      _notify();
    }
  }

  void _audioChanged() {
    final child = _audioController;
    final target = _audioTarget;
    if (child != null && target != null && identical(target, selectedSnapshot) && target.source == source) {
      final pending = audioFacade?.pendingOriginal;
      if (child.recordingStarted) {
        _capturingChild = child;
        _capturingTarget = target;
        _pendingAudio = null;
      } else if (!child.busy) {
        if (pending == null) {
          // Actual cancellation, failed start or completed import consumes ownership.
          _capturingChild = null;
          _capturingTarget = null;
          _pendingAudio = null;
        } else if (child.review == null && child.error != null &&
            identical(child, _capturingChild) && identical(target, _capturingTarget)) {
          _pendingAudio ??= pending;
        }
      }
    }
    _notify();
  }

  /// Links one original once or atomically updates only its retained review.
  ImageRegionEditorChange attachAudioReview(AudioTranscriptReview review,
    {required ImageRegionSnapshot target}) {
    _requireLive();
    if (!identical(target, _audioTarget) || !identical(target, selectedSnapshot) ||
        target.source != source || _audioController == null ||
        _audioController!.isDetached || _audioController!.isDisposed) {
      throw StateError('Audio callback no longer owns this exact selected target');
    }
    final id = review.original.material.id;
    final old = _reviews[id];
    if (old != null) AudioTranscriptReview.requireRetainedPrefix(old, review);
    for (final entry in _workspace.regions) {
      for (final link in entry.audioLinks.where((l) => l.audioMaterialId == id)) {
        if (entry.regionId != target.regionId || link.regionRevision != target.revision) {
          throw ArgumentError('An audio original cannot rebind to another region');
        }
      }
    }
    final entry = currentEntry!;
    final linked = entry.audioLinks.any((l) => l.audioMaterialId == id);
    final next = linked ? _workspace : _replace(_workspace, _copyEntry(entry, audioLinks: [
      ...entry.audioLinks, RegionAudioLink(audioMaterialId: id, regionRevision: target.revision,
        recordedAt: _time([target.recordedAt, review.original.material.capturedAt])),
    ]));
    _retainReview(review);
    _publish(next, {..._reviews, id: review});
    return change;
  }

  /// Copies common retained transcript/correction into the comment only.
  void useTranscriptAsComment() {
    _requireConfirmed();
    final child = _audioController;
    final target = _audioTarget;
    final snapshot = selectedSnapshot!;
    final token = _generation;
    if (child == null || target == null || child.review == null) throw StateError('Record or select audio first');
    bool owns() => _matches(token, snapshot) && identical(child, _audioController) &&
        identical(target, _audioTarget) && identical(target, snapshot) && target.source == source &&
        !child.isDetached && !child.isDisposed;
    if (!owns()) throw StateError('Transcript no longer owns this exact selected target');
    final review = child.hasUnsavedText ? child.recordCorrection() : child.review!;
    _retainReview(review);
    if (!owns()) throw StateError('Audio owner retired while recording its transcript correction');
    attachAudioReview(review, target: target);
    if (!owns()) throw StateError('Audio owner retired while adopting its transcript');
    final b = _draftFor(snapshot).comment;
    String text;
    if (review.revisions.isNotEmpty) {
      text = review.revisions.last.text;
      b.transcriptIndex = review.revisions.length - 1;
      b.reportId = null;
    } else {
      final reports = review.reports.where((r) => r.status == AudioTranscriptStatus.success);
      if (reports.isEmpty) throw StateError('Enter or recognize a transcript first');
      text = reports.last.text!;
      b.reportId = reports.last.id;
      b.transcriptIndex = null;
    }
    b..text = text..dirty = true..origin = RegionTextOrigin.transcript
      ..audioId = review.original.material.id..confirmed = false;
    _notify();
  }

  void _retainReview(AudioTranscriptReview review) {
    final id = review.original.material.id;
    final old = _retainedReviews[id];
    if (old != null) AudioTranscriptReview.requireRetainedPrefix(old, review);
    _retainedReviews[id] = review;
  }

  void _preserveAudioDraft() {
    if (_preservingAudioDraft) return;
    final child = _audioController;
    final target = _audioTarget;
    final token = _generation;
    if (!_live || child == null || target == null || child.busy ||
        !child.canRecordCorrection || !identical(target, selectedSnapshot) || target.source != source) {
      return;
    }
    bool owns() => _matches(token, target) && identical(child, _audioController) &&
        identical(target, _audioTarget) && !child.isDetached && !child.isDisposed;
    _preservingAudioDraft = true;
    try {
      final review = child.recordCorrection();
      _retainReview(review);
      if (!owns()) throw StateError('Audio owner retired while retaining its transcript');
      attachAudioReview(review, target: target);
      if (!owns()) throw StateError('Audio target changed while retaining its transcript');
    } finally {
      _preservingAudioDraft = false;
    }
  }

  void _retireAudio() {
    final child = _audioController;
    if (child == null) return;
    _audioController = null;
    _audioTarget = null;
    _capturingChild = null;
    _capturingTarget = null;
    _pendingAudio = null;
    child.removeListener(_audioChanged);
    final prior = _audioRetirement;
    final completion = Completer<void>();
    _audioRetirement = completion.future;
    _retiringAudio++;
    // Observe failures now as well as through replacement/detach awaiting it.
    unawaited(_audioRetirement.then<void>((_) {}, onError: (Object error, StackTrace _) {
      if (_live) { _error = error; _notify(); }
    }));
    Future<void> settle() async {
      try {
        try {
          // Retain already-entered intent after unbinding the parent listener.
          if (!child.busy && child.canRecordCorrection) {
            _retainReview(child.recordCorrection());
          }
        } finally {
          // The join is reserved before correction or cleanup can reenter.
          final settling = child.detach();
          await Future.wait<void>([prior, settling]);
        }
      } finally {
        try {
          final review = child.review;
          if (review != null) _retainReview(review);
        } finally {
          child.dispose();
          _retiringAudio--;
        }
      }
    }
    settle().then(completion.complete, onError: completion.completeError);
  }

  void _retireSelection() {
    _preserveAudioDraft();
    _generation++;
    _derivation = null;
    _previewBytes = null;
    _retireAudio();
  }

  Future<void> _command(Future<void> Function(int, ImageRegionSnapshot?) action) {
    _requireLive();
    if (busy) throw StateError('Wait for the admitted region command to finish');
    final token = _generation;
    final snapshot = selectedSnapshot;
    final completion = Completer<void>();
    final settled = completion.future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _operation = settled;
    _error = null;
    _notify();
    Future<void> run() async {
      Object? failure;
      StackTrace? trace;
      try {
        if (!_matches(token, snapshot)) throw StateError('Region owner retired before launch');
        await action(token, snapshot);
      } catch (error, stack) {
        failure = error;
        trace = stack;
        if (_live) _error = error;
      } finally {
        _operation = null;
        if (failure == null) { completion.complete(); }
        else { completion.completeError(failure, trace!); }
        _notify();
      }
    }
    unawaited(run());
    return completion.future;
  }

  bool _matches(int token, ImageRegionSnapshot? snapshot) => _live &&
      token == _generation && identical(snapshot, selectedSnapshot) &&
      (snapshot == null || snapshot.source == source);
  void _requireLive() { if (!_live) throw StateError('Region editor is detached or disposed'); }
  void _requireSelection() {
    _requireLive();
    if (selectionLocked) throw StateError('Finish the owned audio operation before changing area');
  }
  void _requireText() {
    _requireLive();
    if (selectedSnapshot == null) throw StateError('Confirm a selected area first');
  }
  void _requireConfirmed() {
    _requireText();
    if (_selection != selectedSnapshot!.geometry) throw StateError('Confirm the changed area first');
  }

  DateTime _time(Iterable<DateTime> floors) {
    var value = _now().toUtc();
    for (final floor in floors) { if (value.isBefore(floor)) value = floor.toUtc(); }
    return value;
  }
  Iterable<DateTime> _reviewTimes(AudioTranscriptReview r) => [
    r.original.material.capturedAt, ...r.reports.map((v) => v.completedAt),
    ...r.revisions.map((v) => v.recordedAt),
  ];
  String _nextId() {
    final id = _idGenerator();
    final existing = <String>{source.id, ..._reviews.keys,
      for (final e in _workspace.regions) ...[
        e.regionId, ...e.extractions.map((v) => v.id),
        ...e.quotations.map((v) => v.id), ...e.comments.map((v) => v.id),
      ],
    };
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(id) ||
        existing.contains(id) || !_issuedIds.add(id)) { throw StateError('Invalid or colliding generated identity'); }
    return id;
  }
  static String _randomId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
  ImageRegionWorkspace _replace(ImageRegionWorkspace workspace, ImageRegionEntry entry) =>
    ImageRegionWorkspace(regions: [
      for (final old in workspace.regions) old.regionId == entry.regionId ? entry : old,
      if (!workspace.regions.any((e) => e.regionId == entry.regionId)) entry,
    ]);
  ImageRegionEntry _copyEntry(ImageRegionEntry e, {
    Iterable<ImageRegionSnapshot>? snapshots, Iterable<ImageRegionExtraction>? extractions,
    Iterable<RegionTextRevision>? quotations, Iterable<RegionTextRevision>? comments,
    Iterable<RegionAudioLink>? audioLinks,
  }) => ImageRegionEntry(snapshots: snapshots ?? e.snapshots, extractions: extractions ?? e.extractions,
      quotations: quotations ?? e.quotations, comments: comments ?? e.comments, audioLinks: audioLinks ?? e.audioLinks);
  void _publish(ImageRegionWorkspace workspace, Map<String, AudioTranscriptReview> reviews) {
    ImageRegionWorkspace.requireRetainedPrefix(_workspace, workspace);
    workspace.validateAudioReviews(reviews);
    for (final item in _reviews.entries) {
      if (!reviews.containsKey(item.key)) throw ArgumentError('Cannot drop retained audio');
      AudioTranscriptReview.requireRetainedPrefix(item.value, reviews[item.key]!);
    }
    _workspace = workspace;
    _reviews = Map.unmodifiable(reviews);
    _changeVersion++;
    _notify();
  }

  /// Terminally fences callbacks and awaits actual region/child settlement.
  /// Original-owner adapters must inspect retainedAudioReviews after awaiting.
  Future<void> detach() {
    if (_detachment != null) return _detachment!;
    final completion = Completer<void>();
    _detachment = completion.future;
    _detached = true;
    _generation++;
    final operation = _operation;
    _retireAudio();
    Future<void> settle() async {
      if (operation != null) await operation;
      await _audioRetirement;
    }
    settle().then(completion.complete, onError: completion.completeError);
    return completion.future;
  }

  @override
  void addListener(VoidCallback listener) {
    _requireLive();
    void guarded() { if (_live) listener(); }
    (_listeners[listener] ??= []).add(guarded);
    _notifier.addListener(guarded);
  }
  @override
  void removeListener(VoidCallback listener) {
    if (_notifierDisposed) return;
    final guards = _listeners[listener];
    if (guards == null || guards.isEmpty) return;
    _notifier.removeListener(guards.removeLast());
    if (guards.isEmpty) _listeners.remove(listener);
  }
  void _notify() {
    if (!_live) return;
    _notificationDepth++;
    try { _notifier.emit(); } finally {
      _notificationDepth--;
      if (_disposed && _disposalSettled && _notificationDepth == 0) _releaseNotifier();
    }
  }
  /// Arranges safe asynchronous detach; borrowed services are never disposed.
  void dispose() {
    if (_disposed) return;
    final settlement = detach();
    _disposed = true;
    unawaited(settlement.then<void>((_) {
      _disposalSettled = true;
      _releaseNotifier();
    }, onError: (Object _, StackTrace _) {
      _disposalSettled = true;
      _releaseNotifier();
    }));
  }
  void _releaseNotifier() {
    if (_notifierDisposed || _notificationDepth != 0) return;
    _notifierDisposed = true;
    _listeners.clear();
    _notifier.dispose();
  }
}

final class _RegionNotifier extends ChangeNotifier {
  void emit() { notifyListeners(); }
}
final class _TextDrafts {
  _TextDrafts(this.quotation, this.comment);
  final _TextBuffer quotation;
  final _TextBuffer comment;
}
final class _TextBuffer {
  _TextBuffer.fromRevision(RegionTextRevision? revision)
    : text = revision?.text ?? '', confirmed = revision?.sourceConfirmed ?? false,
      origin = revision?.origin ?? RegionTextOrigin.manual,
      reportId = revision?.sourceReportId, audioId = revision?.audioMaterialId,
      transcriptIndex = revision?.transcriptRevisionIndex;
  String text;
  bool confirmed;
  bool dirty = false;
  RegionTextOrigin origin;
  String? reportId;
  String? audioId;
  int? transcriptIndex;
  void adopt(String value, RegionTextOrigin source, String report) {
    text = value;
    origin = source;
    reportId = report;
    audioId = null;
    transcriptIndex = null;
    dirty = true;
    confirmed = false;
  }
}
