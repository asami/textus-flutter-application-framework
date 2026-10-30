import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/image_region_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImageRegionFixture h;
  setUp(() async { h = ImageRegionFixture(); await h.open(); });
  tearDown(() async { await h.close(); });

  test('R1 inert construction and explicit exact canonical source load', () async {
    // Given real saved PNG bytes and an inert composed editor.
    expect(h.controller.frame, isNull);
    expect(h.store.reads, 0);
    expect(h.ocr.probes, 0);
    expect(h.audio.starts, 0);
    // When loading the source explicitly through Core.
    await h.controller.loadSource();
    final frame = h.controller.frame!;
    final pixels = img.decodePng(frame.pngBytes)!;
    // Then exact source, canonical dimensions and original pixels are observable.
    expect(frame.source, h.source);
    expect([frame.pixelWidth, frame.pixelHeight], [200, 100]);
    expect(pixels.getPixel(0, 0).r, 240);
    expect(h.ocr.inputs, isEmpty);
    expect(h.ocr.preparations + h.ai.preparations + h.audio.preparations, 0);
    expect(h.controller.busy, isFalse);
  });

  test('R2 stable contiguous revisions, independent regions and preserved other sources', () async {
    // Given one confirmed region plus an unrelated exact source entry.
    await h.confirm();
    final first = h.controller.selectedSnapshot!;
    final other = CaptureMaterialReference(id: 'otherImage', mediaType: 'image/png',
      byteLength: h.source.byteLength, capturedAt: h.source.capturedAt);
    final otherEntry = ImageRegionEntry(snapshots: [ImageRegionSnapshot(regionId: 'otherRegion',
      revision: 1, source: other, pixelWidth: 200, pixelHeight: 100,
      geometry: ImageRegionFixture.geometry(), recordedAt: ImageRegionFixture.time)]);
    final initial = ImageRegionWorkspace(regions: [otherEntry, ...h.controller.workspace.regions]);
    h.controller.dispose();
    h.controller = h.newController(workspace: initial);
    expect(h.controller.selectedRegionId, first.regionId);
    expect(() => h.controller.selectRegion('otherRegion'), throwsArgumentError);
    await h.controller.loadSource();
    // When revising geometry, reconfirming unchanged geometry, and creating another region.
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
    h.controller.confirmSelection();
    h.controller.confirmSelection();
    expect(h.controller.selectedRevision, 2);
    expect(h.controller.quotationText, '');
    expect(h.controller.currentEntry!.snapshots.first, same(first));
    h.controller.startNewRegion();
    h.controller.setSelection(ImageRegionFixture.geometry(y: 0.2));
    h.controller.confirmSelection();
    // Then old exact histories/source remain, while the new identity starts at revision one.
    expect(h.controller.workspace.regions.length, 3);
    expect(h.controller.workspace.regions.first, same(otherEntry));
    expect(h.controller.selectedRegionId, isNot(first.regionId));
    expect(h.controller.selectedRevision, 1);
    expect(() => h.controller.selectRegion(first.regionId, revision: 3), throwsArgumentError);
    ImageRegionWorkspace.requireRetainedPrefix(initial, h.controller.workspace);
  });

  test('R3 draft switching and atomic all-target save preserve Unicode and blank clears', () async {
    // Given independent unsaved buffers on two exact region revisions.
    await h.confirm();
    final firstId = h.controller.selectedRegionId!;
    h.controller.setQuotationText('  原文\n ');
    h.controller.setCommentText(' first comment ');
    h.controller.setSourceConfirmed(true);
    h.controller.startNewRegion();
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.3));
    h.controller.confirmSelection();
    final secondId = h.controller.selectedRegionId!;
    h.controller.setQuotationText('second unconfirmed');
    // When one quotation lacks confirmation, no target is partially appended.
    final before = h.controller.workspace;
    expect(h.controller.commitTextDrafts, throwsStateError);
    expect(h.controller.workspace, same(before));
    h.controller.selectRegion(firstId);
    expect(h.controller.quotationText, '  原文\n ');
    expect(h.controller.commentText, ' first comment ');
    h.controller.selectRegion(secondId);
    h.controller.setSourceConfirmed(true);
    final saved = h.controller.commitTextDrafts();
    h.controller.selectRegion(firstId);
    h.controller.setQuotationText('');
    h.controller.setCommentText('');
    h.controller.commitTextDrafts();
    // Then exact distinct histories include intentional clears and immutable transfer data.
    expect(saved.workspace.regions.first.quotations.single.text, '  原文\n ');
    expect(saved.workspace.regions.first.comments.single.text, ' first comment ');
    expect(h.controller.currentEntry!.quotations.last.text, '');
    expect(h.controller.currentEntry!.comments.last.text, '');
    expect(() => saved.audioReviews.clear(), throwsUnsupportedError);
    expect(h.controller.quotationDirty || h.controller.commentDirty, isFalse);
  });

  test('R4 geometry revision never relabels quotation or silently drops old drafts', () async {
    // Given dirty text on retained geometry revision one.
    await h.confirm();
    final id = h.controller.selectedRegionId!;
    h.controller.setQuotationText('first geometry text');
    h.controller.setSourceConfirmed(true);
    // When confirming revision two and editing its separate comment.
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
    h.controller.confirmSelection();
    expect(h.controller.quotationText, '');
    expect(h.controller.commentText, '');
    h.controller.setCommentText('revision two');
    h.controller.commitTextDrafts();
    h.controller.selectRegion(id, revision: 1);
    // Then each text remains bound to its original exact revision.
    expect(h.controller.quotationText, 'first geometry text');
    expect(h.controller.commentText, '');
    expect(h.controller.currentEntry!.quotations.single.regionRevision, 1);
    expect(h.controller.currentEntry!.comments.single.regionRevision, 2);
  });

  test('R5 exact saved crop, explicit OCR and sticky source through manual editing', () async {
    // Given a confirmed ellipse with a dirty manual quotation.
    await h.confirm();
    h.controller.setSelection(ImageRegionFixture.geometry(shape: ImageRegionShape.ellipse));
    h.controller.confirmSelection();
    h.controller.setQuotationText('manual stays');
    // When explicitly previewing then recognizing without adopting.
    await h.controller.previewSelection();
    final crop = img.decodePng(h.controller.previewBytes!)!;
    expect([crop.width, crop.height], [80, 60]);
    expect(crop.getPixel(0, 0).r, 255);
    expect(crop.getPixel(40, 30).r, 240);
    await h.controller.recognize();
    expect(h.controller.quotationText, 'manual stays');
    expect(h.ai.inputs, isEmpty);
    final extraction = h.controller.currentEntry!.extractions.single;
    h.controller.useOcrText(extraction.id);
    expect(h.controller.recordQuotation, throwsStateError);
    h.controller.setQuotationText(' corrected 原文 ');
    h.controller.setSourceConfirmed(true);
    h.controller.recordQuotation();
    // Then raw output and actual derivation remain exact; adoption records OCR provenance.
    final quote = h.controller.currentEntry!.quotations.single;
    expect(quote.origin, RegionTextOrigin.ocr);
    expect(quote.sourceReportId, extraction.id);
    expect(quote.text, ' corrected 原文 ');
    expect(extraction.comparison.runs.single.attempts.single.result.text, h.ocr.text);
    expect(extraction.derivation.input, h.controller.derivation!.input);
    expect(h.ocr.preparations + h.ai.preparations, 0);
  });

  test('R6 explicit AI output selection still requires human source confirmation', () async {
    // Given a confirmed source with no provider execution or adopted quotation.
    await h.confirm();
    // When AI is explicitly requested and an actually executed candidate is selected.
    await h.controller.recognize(supplementWithLocalAi: true);
    final extraction = h.controller.currentEntry!.extractions.single;
    final ai = extraction.comparison.runs.last.attempts.last;
    expect(h.controller.quotationText, '');
    h.controller.useAiCandidate(extraction.id, ai.id, candidateIndex: 0);
    expect(h.controller.quotationText, 'AI candidate');
    expect(h.controller.recordQuotation, throwsStateError);
    h.controller.setSourceConfirmed(true);
    h.controller.recordQuotation();
    // Then only explicit source-checked adoption is retained, separate from raw interpretation.
    expect(h.controller.currentEntry!.quotations.single.origin, RegionTextOrigin.ai);
    expect(ai.result.interpretation, 'AI interpretation');
    expect(h.ai.inputs.length, 1);
    expect(h.ai.preparations, 0);
    expect(() => h.controller.useAiCandidate(extraction.id, 'absent', interpretation: true), throwsArgumentError);
  });

  test('R7 actual unavailable readiness permits exact manual quotation and comment', () async {
    // Given actual Core recognition with unavailable local providers.
    h.ocr.unavailable = true;
    h.ai.unavailable = true;
    await h.confirm();
    // When checking availability and requesting OCR, then entering manual text.
    await h.controller.refreshAvailability();
    await h.controller.recognize();
    expect(h.controller.readiness.every((a) => a.state == RecognitionProviderState.unavailable), isTrue);
    expect(() => h.controller.useOcrText(), throwsStateError);
    h.controller.setQuotationText('manual 原文');
    h.controller.setSourceConfirmed(true);
    h.controller.setCommentText('manual note');
    h.controller.commitTextDrafts();
    // Then no provider executed or prepared; manual history remains fully usable.
    expect(h.ocr.inputs, isEmpty);
    expect(h.controller.currentEntry!.quotations.single.origin, RegionTextOrigin.manual);
    expect(h.controller.currentEntry!.comments.single.text, 'manual note');
    expect(h.ocr.preparations + h.ai.preparations, 0);
  });

  for (final retirement in ['selection', 'revision', 'cancel', 'detach']) {
    test('R8 held OCR $retirement fences adoption but retains actual durable report', () async {
      // Given an explicitly admitted OCR command held in the actual provider port.
      await h.confirm();
      await h.controller.previewSelection();
      h.ocr.gate = Completer<void>();
      final operation = h.controller.recognize();
      await h.ocr.entered.future;
      h.controller.setQuotationText('concurrent manual');
      // When the original operation's selection generation is retired.
      Future<void>? detached;
      switch (retirement) {
        case 'selection': h.controller.startNewRegion();
        case 'revision':
          h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
          h.controller.confirmSelection();
        case 'cancel': h.controller.cancelPendingResult();
        case 'detach': detached = h.controller.detach();
      }
      expect(h.controller.busy, isTrue);
      if (retirement != 'detach') expect(h.controller.recognize, throwsStateError);
      h.ocr.gate!.complete();
      await operation;
      if (detached != null) await detached;
      // Then no retired result rebinds, its raw durable report survives, and busy releases.
      expect(h.controller.workspace.regions.expand((e) => e.extractions), isEmpty);
      expect(h.controller.retainedExtractions.length, 1);
      expect(h.store.documents, isNotEmpty);
      expect(h.controller.busy, isFalse);
    });
  }

  test('R9 held source read and actual failure release busy without stale frame', () async {
    // Given an explicit read held before Core produces a frame.
    h.store.readGate = Completer<void>();
    final load = h.controller.loadSource();
    await h.store.readEntered.future;
    // When cancel retires adoption and the read subsequently settles.
    h.controller.cancelPendingResult();
    h.store.readGate!.complete();
    await load;
    expect(h.controller.frame, isNull);
    h.store.readError = StateError('actual controlled read failure');
    await expectLater(h.controller.loadSource(), throwsStateError);
    // Then actual error is observable and a subsequent explicit command can recover.
    expect(h.controller.error, isA<StateError>());
    expect(h.controller.busy, isFalse);
    h.store.readError = null;
    await h.controller.loadSource();
    expect(h.controller.frame!.source, h.source);
    expect(h.controller.error, isNull);
  });

  test('R10 preparation is a separate explicit action and no inference occurs', () async {
    // Given actual downloadable readiness.
    h.ai.downloadable = true;
    // When the user explicitly checks and then prepares that provider.
    await h.controller.refreshAvailability();
    expect(h.ai.preparations, 0);
    await h.controller.prepareProvider(RecognitionConfigurations.enhancedProviderId);
    // Then readiness reflects real preparation, with no frame read or inference.
    expect(h.ai.preparations, 1);
    expect(h.ai.inputs, isEmpty);
    expect(h.store.reads, 0);
    expect(h.controller.readiness.last.state, RecognitionProviderState.available);
  });

  test('R11 common audio exact link, correction index, comment-only copy and reopen', () async {
    // Given an exact confirmed snapshot and explicit opening of common controls.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    expect(h.audio.starts + h.audio.probes + h.audio.preparations, 0);
    // When existing common commands record, save, transcribe and manually correct.
    await child.startRecording();
    expect(h.controller.startNewRegion, throwsStateError);
    final original = await child.stopRecording();
    h.controller.attachAudioReview(original, target: target);
    final recognized = await child.transcribe();
    h.controller.attachAudioReview(recognized, target: target);
    child.setDraftText('  corrected spoken 日本語\n');
    h.controller.useTranscriptAsComment();
    h.controller.recordComment();
    final saved = h.controller.change;
    final id = original.original.material.id;
    // Then one unchanged original link and the retained correction index feed only comment.
    expect(h.controller.currentEntry!.audioLinks.length, 1);
    expect(h.controller.quotationText, '');
    final comment = h.controller.currentEntry!.comments.single;
    expect(comment.text, '  corrected spoken 日本語\n');
    expect(comment.origin, RegionTextOrigin.transcript);
    expect(comment.audioMaterialId, id);
    expect(comment.transcriptRevisionIndex, 1);
    expect(saved.audioReviews[id]!.revisions.last.text, comment.text);
    await h.controller.detach();
    h.controller.dispose();
    h.controller = h.newController(workspace: saved.workspace, reviews: saved.audioReviews);
    await h.controller.selectAudio(id);
    expect(h.controller.audioController!.draftText, comment.text);
    expect(h.controller.commentText, comment.text);
    await h.controller.audioController!.playOriginal();
    expect(h.audio.plays, 1);
    expect(h.audio.disposals, 0);
  });

  test('R12 common owned playback/transcription lock selection and stale target cannot rebind', () async {
    // Given a linked exact original opened in existing common controls.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    await child.startRecording();
    final review = await child.stopRecording();
    h.controller.attachAudioReview(review, target: target);
    // When common playback and transcription are held at their real provider ports.
    h.audio.playGate = Completer<void>();
    final playing = child.playOriginal();
    // Given the cancellation oracle is installed before Stop can reject playback.
    final cancelledPlayback = expectLater(playing, throwsStateError);
    await h.audio.playEntered.future;
    expect(h.controller.cancelSelection, throwsStateError);
    // When the user stops playback after its actual port entry.
    await child.stopPlayback();
    // Then the original promise reports the unchanged Core cancellation contract.
    await cancelledPlayback;
    h.audio.transcriptGate = Completer<void>();
    final transcribing = child.transcribe();
    await h.audio.transcriptEntered.future;
    expect(() => h.controller.selectRegion(target.regionId), throwsStateError);
    h.audio.transcriptGate!.complete();
    final updated = await transcribing;
    h.controller.attachAudioReview(updated, target: target);
    h.controller.startNewRegion();
    // Then retired common callbacks cannot attach the original to another region.
    expect(() => h.controller.attachAudioReview(updated, target: target), throwsStateError);
    expect(h.controller.workspace.regions.single.audioLinks.single.audioMaterialId, review.original.material.id);
    expect(h.controller.selectedSnapshot, isNull);
  });

  test('R13 durable stop during detach retained unlinked for original-owner handoff', () async {
    // Given a common audio stop held specifically at durable-original save.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    await child.startRecording();
    h.store.audioSaveGate = Completer<void>();
    final saving = child.stopRecording();
    await h.store.audioSaveEntered.future;
    var notices = 0;
    h.controller.addListener(() { notices++; });
    // When the route retires before that actual save completes.
    final detached = h.controller.detach();
    final retiredNotices = notices;
    h.store.audioSaveGate!.complete();
    final actual = await saving;
    await detached;
    // Then the unchanged original is recoverable but neither linked nor published to a retired owner.
    expect(h.controller.retainedAudioReviews[actual.original.material.id], actual);
    expect(h.controller.workspace.regions.single.audioLinks, isEmpty);
    expect(h.controller.audioReviews, isEmpty);
    expect(notices, retiredNotices);
    expect(() => h.controller.attachAudioReview(actual, target: target), throwsStateError);
    expect(child.isDisposed, isTrue);
    expect(h.audio.disposals, 0);
  });

  test('R14 invalid identity and missing initial audio review reject before adoption', () async {
    // Given a valid exact region and an unresolved original audio link.
    await h.confirm();
    final entry = h.controller.currentEntry!;
    final invalid = ImageRegionWorkspace(regions: [ImageRegionEntry(snapshots: entry.snapshots,
      audioLinks: [RegionAudioLink(audioMaterialId: 'missingAudio', regionRevision: 1,
        recordedAt: ImageRegionFixture.time)])]);
    // When callers attempt unresolved restoration or a colliding generated region identity.
    expect(() => h.newController(workspace: invalid), throwsArgumentError);
    final colliding = ImageRegionEditorController(facade: h.facade, source: h.source,
      idGenerator: () => h.source.id);
    await colliding.loadSource();
    colliding.setSelection(ImageRegionFixture.geometry());
    expect(colliding.confirmSelection, throwsStateError);
    // Then no invalid history is adopted and borrowed services remain reusable.
    expect(colliding.workspace.regions, isEmpty);
    await colliding.detach();
    colliding.dispose();
    expect(h.controller.workspace.regions.single, same(entry));
  });

  for (final exact in ['  dirty spoken 日本語\n ', '']) {
    test('R15 full Save retains exact dirty transcript ${exact.isEmpty ? "clear" : "edit"} without copying text', () async {
      // Given a linked original/raw report and independent retained region text.
      await h.confirm();
      h.controller.setQuotationText('verbatim source');
      h.controller.setSourceConfirmed(true);
      h.controller.setCommentText('independent comment');
      h.controller.commitTextDrafts();
      await h.controller.beginAudioComment();
      final child = h.controller.audioController!;
      final target = h.controller.audioTarget!;
      await child.startRecording();
      h.controller.attachAudioReview(await child.stopRecording(), target: target);
      final recognized = await child.transcribe();
      h.controller.attachAudioReview(recognized, target: target);
      final before = h.controller.workspace;
      final version = h.controller.changeVersion;
      child.setDraftText(exact);
      // When full Save runs without either Record correction or Copy transcript.
      final saved = h.controller.commitTextDrafts();
      final id = recognized.original.material.id;
      final retained = saved.audioReviews[id]!;
      // Then one exact revision is appended and original/report/text ownership is unchanged.
      expect(retained.revisions.length, recognized.revisions.length + 1);
      expect(retained.revisions.last.text, exact);
      expect(retained.original, same(recognized.original));
      expect(retained.reports.single, same(recognized.reports.single));
      expect(saved.workspace, same(before));
      expect(saved.workspace.regions.single.audioLinks.single.audioMaterialId, id);
      expect(saved.workspace.regions.single.quotations.single.text, 'verbatim source');
      expect(saved.workspace.regions.single.comments.single.text, 'independent comment');
      expect(child.hasUnsavedText, isFalse);
      expect(h.controller.changeVersion, version + 1);
    });
  }

  test('R16 unconfirmed quotation prevents partial audio correction then confirmation saves together', () async {
    // Given a dirty transcript and unconfirmed quotation plus an independent comment.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
    final recognized = await child.transcribe();
    h.controller.attachAudioReview(recognized, target: h.controller.audioTarget!);
    child.setDraftText(' exact unsaved transcript\n');
    h.controller.setQuotationText('unchecked quote');
    h.controller.setCommentText('independent comment');
    final before = h.controller.workspace;
    final reviews = h.controller.audioReviews;
    final version = h.controller.changeVersion;
    // When Save fails validation, then the user confirms and retries.
    expect(h.controller.commitTextDrafts, throwsStateError);
    expect(h.controller.workspace, same(before));
    expect(h.controller.audioReviews, same(reviews));
    expect(child.review, same(recognized));
    expect(child.hasUnsavedText, isTrue);
    expect(h.controller.changeVersion, version);
    h.controller.setSourceConfirmed(true);
    final saved = h.controller.commitTextDrafts();
    // Then only the successful retry publishes one combined immutable adoption.
    expect(saved.workspace.regions.single.quotations.single.text, 'unchecked quote');
    expect(saved.workspace.regions.single.comments.single.text, 'independent comment');
    final retained = saved.audioReviews[recognized.original.material.id]!;
    expect(retained.revisions.last.text, ' exact unsaved transcript\n');
    expect(retained.revisions.length, recognized.revisions.length + 1);
    expect(retained.reports.single, same(recognized.reports.single));
    expect(saved.workspace.regions.single.audioLinks.length, 1);
    expect(h.controller.changeVersion, version + 1);
  });

  test('R17 reentrant detach returns the reserved future and awaits actual owned cancellation', () async {
    // Given owned active recording and a cancel port that synchronously reenters the parent.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    h.audio.cancelGate = Completer<void>();
    Future<void>? reentered;
    h.audio.onCancelRecording = () { reentered = h.controller.detach(); };
    var notices = 0;
    h.controller.addListener(() { notices++; });
    final version = h.controller.changeVersion;
    // When terminal retirement reaches that port before actual cancellation settles.
    final detached = h.controller.detach();
    expect(reentered, same(detached));
    expect(h.controller.detach(), same(detached));
    var settled = false;
    unawaited(detached.then((_) { settled = true; }));
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
    expect(child.isDisposed, isFalse);
    expect(h.audio.cancellations, 1);
    h.audio.cancelGate!.complete();
    await detached;
    // Then every join waits for owned cleanup; the borrowed service and terminal owner stay untouched.
    expect(settled, isTrue);
    expect(child.isDisposed, isTrue);
    expect(h.audio.disposals, 0);
    expect(h.controller.changeVersion, version);
    expect(notices, 0);
  });

  test('R18 full Save rejects owned recording while manual comment editing remains available', () async {
    // Given an owned active capture on this exact confirmed area.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    // When manual text is edited and full Save is requested before finishing capture.
    h.controller.setCommentText('manual during recording');
    final before = h.controller.workspace;
    expect(h.controller.commitTextDrafts, throwsStateError);
    // Then the buffer stays editable, but no partial text history is published.
    expect(h.controller.workspace, same(before));
    expect(h.controller.currentEntry!.comments, isEmpty);
    expect(h.controller.commentText, 'manual during recording');
    expect(h.controller.commentDirty, isTrue);
    await child.cancelRecording();
    expect(h.controller.commitTextDrafts().workspace.regions.single.comments.single.text,
      'manual during recording');
  });

  test('R19 retirement during correction retains actual child review without publishing', () async {
    // Given a dirty child transcript whose correction notification retires the parent.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    final original = await child.stopRecording();
    h.controller.attachAudioReview(original, target: h.controller.audioTarget!);
    child.setDraftText(' exact retiring correction\n');
    h.controller.setCommentText('unpublished comment');
    final before = h.controller.workspace;
    final reviews = h.controller.audioReviews;
    final version = h.controller.changeVersion;
    Future<void>? retirement;
    h.controller.addListener(() { retirement ??= h.controller.detach(); });
    // When full Save records the correction but loses its original owner before adoption.
    expect(h.controller.commitTextDrafts, throwsStateError);
    await retirement;
    // Then the correction survives for handoff while text/history maps remain unpublished.
    final retained = h.controller.retainedAudioReviews[original.original.material.id]!;
    expect(retained.revisions.single.text, ' exact retiring correction\n');
    expect(retained.original, same(original.original));
    expect(h.controller.workspace, same(before));
    expect(h.controller.audioReviews, same(reviews));
    expect(h.controller.changeVersion, version);
    expect(h.controller.currentEntry!.comments, isEmpty);
  });

  test('R20 pending getters inspect all target drafts and geometry without starting work', () async {
    // Given an inert editor with no frames, buffers, provider activity or notices.
    var notices = 0;
    h.controller.addListener(() { notices++; });
    for (var read = 0; read < 3; read++) {
      expect(h.controller.hasUnsavedText, isFalse);
      expect(h.controller.hasUnconfirmedSelection, isFalse);
      expect(h.controller.hasPendingInput, isFalse);
    }
    expect(notices, 0);
    expect(h.store.reads, 0);
    expect(h.audio.starts + h.audio.probes + h.ocr.probes + h.ai.probes, 0);
    await h.confirm();
    final first = h.controller.selectedRegionId!;
    h.controller.startNewRegion();
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
    expect(h.controller.hasUnconfirmedSelection, isTrue);
    expect(h.controller.hasPendingInput, isTrue);
    h.controller.confirmSelection();
    final second = h.controller.selectedRegionId!;
    expect(h.controller.hasUnconfirmedSelection, isFalse);
    expect(h.controller.hasPendingInput, isFalse);
    // When quotation/comment edits on region one are followed by a clean target.
    h.controller.selectRegion(first);
    h.controller.setQuotationText(' exact source\n');
    h.controller.setSourceConfirmed(true);
    h.controller.setCommentText('');
    h.controller.selectRegion(second);
    // Then all-target flags retain even a blank clear despite clean current-target flags.
    expect(h.controller.quotationDirty || h.controller.commentDirty, isFalse);
    expect(h.controller.hasUnsavedText, isTrue);
    expect(h.controller.hasPendingInput, isTrue);
    final saved = h.controller.commitTextDrafts();
    expect(saved.workspace.regions.first.quotations.single.text, ' exact source\n');
    expect(saved.workspace.regions.first.comments.single.text, '');
    expect(h.controller.hasUnsavedText, isFalse);
    expect(h.controller.hasPendingInput, isFalse);
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.3));
    expect(h.controller.hasUnconfirmedSelection, isTrue);
    h.controller.cancelSelection();
    expect(h.controller.hasUnconfirmedSelection, isFalse);
    expect(h.controller.hasPendingInput, isFalse);
  });

  for (final exact in ['  navigation correction 日本語\n ', '']) {
    test('R21 transcript ${exact.isEmpty ? "clear" : "edit"} survives audio replacement and region navigation', () async {
      // Given independent region text and a linked actual original/raw transcript.
      await h.confirm();
      final first = h.controller.selectedRegionId!;
      h.controller.setQuotationText('unconfirmed quote stays dirty');
      h.controller.setCommentText('independent comment stays dirty');
      await h.controller.beginAudioComment();
      final child = h.controller.audioController!;
      await child.startRecording();
      h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
      final recognized = await child.transcribe();
      h.controller.attachAudioReview(recognized, target: h.controller.audioTarget!);
      final id = recognized.original.material.id;
      child.setDraftText(exact);
      // When opening the same original first, then another child, and another region.
      await h.controller.selectAudio(id).timeout(const Duration(seconds: 5));
      expect(h.controller.audioController!.draftText, exact);
      expect(h.controller.audioController!.review!.revisions.length, recognized.revisions.length + 1);
      final firstCorrection = h.controller.audioController!.review!;
      h.controller.audioController!.setDraftText(exact);
      await h.controller.beginAudioComment().timeout(const Duration(seconds: 5));
      expect(h.controller.audioController!.review, isNull);
      h.controller.startNewRegion();
      h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
      h.controller.confirmSelection();
      expect(h.controller.currentEntry!.audioLinks, isEmpty);
      h.controller.selectRegion(first);
      await h.controller.selectAudio(id).timeout(const Duration(seconds: 5));
      h.controller.audioController!.setDraftText(exact);
      h.controller.startNewRegion();
      h.controller.selectRegion(first);
      await h.controller.selectAudio(id).timeout(const Duration(seconds: 5));
      // Then each entered intent has its exact retained prefix without adopting region text.
      final retained = h.controller.audioController!.review!;
      AudioTranscriptReview.requireRetainedPrefix(firstCorrection, retained);
      expect(retained.revisions.length, recognized.revisions.length + 3);
      expect(retained.revisions.last.text, exact);
      expect(retained.reports.single, same(recognized.reports.single));
      expect(retained.original, same(recognized.original));
      expect(h.controller.currentEntry!.audioLinks.single.audioMaterialId, id);
      expect(h.controller.currentEntry!.quotations, isEmpty);
      expect(h.controller.currentEntry!.comments, isEmpty);
      expect(h.controller.quotationText, 'unconfirmed quote stays dirty');
      expect(h.controller.commentText, 'independent comment stays dirty');
      expect(h.controller.hasUnsavedText, isTrue);
      expect(h.audio.starts, 1);
      expect(h.audio.transcriptions, 1);
      expect(h.audio.preparations + h.ocr.probes + h.ai.probes, 0);
    });

    test('R22 terminal detach retains exact transcript ${exact.isEmpty ? "clear" : "edit"} without publication', () async {
      // Given a published original/raw report and a dirty common transcript.
      await h.confirm();
      await h.controller.beginAudioComment();
      final child = h.controller.audioController!;
      await child.startRecording();
      h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
      final recognized = await child.transcribe();
      h.controller.attachAudioReview(recognized, target: h.controller.audioTarget!);
      child.setDraftText(exact);
      final workspace = h.controller.workspace;
      final reviews = h.controller.audioReviews;
      final version = h.controller.changeVersion;
      var notices = 0;
      h.controller.addListener(() { notices++; });
      // When an external route owner detaches instead of invoking Save or Copy.
      await h.controller.detach().timeout(const Duration(seconds: 5));
      // Then exact entered intent is handed back under its original without a terminal publication.
      final retained = h.controller.retainedAudioReviews[recognized.original.material.id]!;
      AudioTranscriptReview.requireRetainedPrefix(recognized, retained);
      expect(retained.revisions.length, recognized.revisions.length + 1);
      expect(retained.revisions.last.text, exact);
      expect(retained.reports.single, same(recognized.reports.single));
      expect(h.controller.workspace, same(workspace));
      expect(h.controller.audioReviews, same(reviews));
      expect(h.controller.changeVersion, version);
      expect(h.controller.hasPendingInput, isTrue);
      expect(h.controller.hasUnsavedText, isFalse);
      expect(notices, 0);
      expect(h.audio.disposals, 0);
    });
  }

  test('R23 pending input tracks held work and unadopted actual audio until equal adoption', () async {
    // Given an explicit source load held at the real storage boundary.
    h.store.readGate = Completer<void>();
    final loading = h.controller.loadSource();
    await h.store.readEntered.future.timeout(const Duration(seconds: 5));
    expect(h.controller.hasPendingInput, isTrue);
    h.store.readGate!.complete();
    await loading.timeout(const Duration(seconds: 5));
    expect(h.controller.hasPendingInput, isFalse);
    h.controller.setSelection(ImageRegionFixture.geometry());
    h.controller.confirmSelection();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    // When capture completes without the consumer yet adopting its actual review.
    await child.startRecording();
    expect(h.controller.hasPendingInput, isTrue);
    final actual = await child.stopRecording();
    expect(h.controller.hasPendingInput, isTrue);
    final equal = AudioTranscriptReview(original: actual.original,
      reports: actual.reports, revisions: actual.revisions);
    h.controller.attachAudioReview(equal, target: h.controller.audioTarget!);
    // Then equal published history clears pending state; a subsequent dirty edit clears only on Save.
    expect(h.controller.hasPendingInput, isFalse);
    child.setDraftText('');
    expect(h.controller.hasPendingInput, isTrue);
    h.controller.commitTextDrafts();
    expect(h.controller.hasPendingInput, isFalse);
    // Given another owned capture whose actual cancellation remains held after detach.
    await h.controller.beginAudioComment().timeout(const Duration(seconds: 5));
    await h.controller.audioController!.startRecording();
    h.audio.cancelGate = Completer<void>();
    // When its child is unbound, the retirement join still counts as pending owned work.
    final detached = h.controller.detach();
    expect(h.controller.audioController, isNull);
    expect(h.controller.hasPendingInput, isTrue);
    h.audio.cancelGate!.complete();
    await detached.timeout(const Duration(seconds: 5));
    // Then settled cancellation with no new original or draft leaves no pending input.
    expect(h.controller.hasPendingInput, isFalse);
    expect(h.audio.disposals, 0);
  });

  test('R24 reentrant navigation retains the old transcript without linking it to the new target', () async {
    // Given a dirty common transcript and a listener that navigates during correction.
    await h.confirm();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    final original = await child.stopRecording();
    h.controller.attachAudioReview(original, target: h.controller.audioTarget!);
    final old = h.controller.selectedSnapshot!;
    child.setDraftText('retained on reentrant navigation');
    var navigated = false;
    h.controller.addListener(() {
      if (!navigated) {
        navigated = true;
        h.controller.startNewRegion();
      }
    });
    // When outer navigation starts preserving text and the inner navigation retires its target.
    expect(h.controller.startNewRegion, throwsStateError);
    // Then the actual correction is retained only for the old original and no new target receives it.
    expect(h.controller.selectedSnapshot, isNull);
    expect(h.controller.workspace.regions.single.snapshots.single, same(old));
    expect(h.controller.audioReviews[original.original.material.id], same(original));
    expect(h.controller.retainedAudioReviews[original.original.material.id]!.revisions.single.text,
      'retained on reentrant navigation');
    expect(h.controller.hasPendingInput, isTrue);
  });

  test('R25 failed audio import locks its exact child and target until same-child Retry succeeds', () async {
    // Given two image regions and one successful local recording owned by region A.
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(h.store.reads + h.audio.starts + h.audio.probes, 0);
    await h.confirm();
    final first = h.controller.selectedRegionId!;
    h.controller.startNewRegion();
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
    h.controller.confirmSelection();
    final second = h.controller.selectedRegionId!;
    h.controller.selectRegion(first);
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    await child.startRecording();
    final savedCount = h.store.saves;
    h.store.audioSaveError = StateError('controlled audio import failure');
    // When actual Stop fails before storing audio, attempts to rebind its pending original are rejected.
    await expectLater(child.stopRecording().timeout(const Duration(seconds: 5)), throwsStateError);
    final pending = h.audioFacade.pendingOriginal!;
    expect(h.controller.ownsPendingAudio, isTrue);
    expect(h.controller.selectionLocked, isTrue);
    expect(h.controller.startNewRegion, throwsStateError);
    expect(() => h.controller.selectRegion(second), throwsStateError);
    expect(() => h.controller.setSelection(ImageRegionFixture.geometry(x: 0.3)), throwsStateError);
    await expectLater(h.controller.beginAudioComment(), throwsStateError);
    expect(h.controller.audioController, same(child));
    expect(h.controller.audioTarget, same(target));
    expect(h.controller.selectedSnapshot, same(target));
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.store.saves, savedCount);
    h.controller.setCommentText('manual text still editable');
    // Then a bound pending original still blocks all-target Save without adopting manual text.
    final beforeSave = h.controller.workspace;
    expect(h.controller.commitTextDrafts, throwsStateError);
    expect(h.controller.workspace, same(beforeSave));
    expect(h.controller.currentEntry!.comments, isEmpty);
    expect(h.controller.commentDirty, isTrue);
    // When the initiating common child retries the exact original after storage recovers.
    h.store.audioSaveError = null;
    final actual = await child.retryPendingOriginal().timeout(const Duration(seconds: 5));
    h.controller.attachAudioReview(actual, target: target);
    // Then the same bytes are imported once and linked only to A, with no new recording.
    expect(h.store.materials[actual.original.material.id], orderedEquals(pending.bytes));
    expect(h.store.saves, savedCount + 1);
    expect(h.audio.starts, 1);
    expect(h.audio.stops, 1);
    expect(h.audioFacade.pendingOriginal, isNull);
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(h.controller.selectionLocked, isFalse);
    expect(h.controller.currentEntry!.audioLinks.single.audioMaterialId, actual.original.material.id);
    expect(h.controller.commentText, 'manual text still editable');
    h.controller.selectRegion(second);
    expect(h.controller.currentEntry!.audioLinks, isEmpty);
  });

  test('R26 shared pending audio is never claimed by an idle borrower or a fresh source owner', () async {
    // Given a second source whose idle child predates A's local recording failure.
    await h.confirm();
    await h.controller.beginAudioComment();
    final owner = h.controller.audioController!;
    final otherSource = await h.store.saveMaterial(bytes: h.controller.frame!.pngBytes,
      mediaType: 'image/png', capturedAt: ImageRegionFixture.time);
    final other = h.newController(original: otherSource);
    await other.loadSource();
    other.setSelection(ImageRegionFixture.geometry());
    other.confirmSelection();
    await other.beginAudioComment();
    final idle = other.audioController!;
    await owner.startRecording();
    expect(idle.state, AudioCaptureState.recording);
    expect(idle.recordingStarted, isFalse);
    expect(idle.busy, isFalse);
    h.store.audioSaveError = StateError('controlled import failure');
    // When only A's actual Stop leaves retryable bytes in the borrowed facade.
    await expectLater(owner.stopRecording(), throwsStateError);
    final pending = h.audioFacade.pendingOriginal!;
    expect(h.controller.ownsPendingAudio, isTrue);
    expect(other.ownsPendingAudio, isFalse);
    await expectLater(other.beginAudioComment(), throwsStateError);
    expect(other.audioController, same(idle));
    final fresh = h.newController(original: otherSource);
    await fresh.loadSource();
    fresh.setSelection(ImageRegionFixture.geometry());
    fresh.confirmSelection();
    final freshTarget = fresh.selectedSnapshot!;
    await expectLater(fresh.beginAudioComment(), throwsStateError);
    // Then a fresh editor retains its manual route without guessing a pending audio target.
    expect(fresh.audioController, isNull);
    expect(fresh.audioTarget, isNull);
    expect(fresh.selectedSnapshot, same(freshTarget));
    expect(fresh.selectionLocked, isFalse);
    fresh.setCommentText('manual foreign-source note');
    expect(fresh.commentText, 'manual foreign-source note');
    fresh.startNewRegion();
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(other.audioReviews, isEmpty);
    expect(fresh.audioReviews, isEmpty);
    expect(other.workspace.regions.single.audioLinks, isEmpty);
    await h.controller.detach().timeout(const Duration(seconds: 5));
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(h.audioFacade.pendingOriginal, same(pending));
    await expectLater(other.beginAudioComment(), throwsStateError);
    await other.detach().timeout(const Duration(seconds: 5));
    await fresh.detach().timeout(const Duration(seconds: 5));
    other.dispose();
    fresh.dispose();
    expect(h.audio.disposals, 0);
  });

  for (final stage in ['correction', 'adoption']) {
    for (final retirement in ['region', 'detach', 'child']) {
      test('R27 transcript Copy fences $retirement during $stage notification', () async {
        // Given independent A/B comments and A's dirty common transcript with actual raw provenance.
        await h.confirm();
        final first = h.controller.selectedRegionId!;
        h.controller.setCommentText('A comment stays');
        h.controller.recordComment();
        h.controller.startNewRegion();
        h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
        h.controller.confirmSelection();
        final second = h.controller.selectedRegionId!;
        h.controller.setCommentText('B comment stays');
        h.controller.recordComment();
        h.controller.selectRegion(first);
        await h.controller.beginAudioComment();
        final child = h.controller.audioController!;
        await child.startRecording();
        h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
        final recognized = await child.transcribe();
        h.controller.attachAudioReview(recognized, target: h.controller.audioTarget!);
        child.setDraftText('  exact A spoken correction\n');
        final version = h.controller.changeVersion;
        var fired = false;
        Future<void>? settlement;
        h.controller.addListener(() {
          final expected = stage == 'correction' ? version : version + 1;
          if (!fired && h.controller.changeVersion == expected && !child.hasUnsavedText &&
              child.review!.revisions.length == recognized.revisions.length + 1) {
            fired = true;
            switch (retirement) {
              case 'region': h.controller.selectRegion(second);
              case 'detach': settlement = h.controller.detach();
              case 'child': settlement = h.controller.beginAudioComment();
            }
          }
        });
        // When Copy's synchronous correction/adoption notification retires its exact continuation owner.
        expect(h.controller.useTranscriptAsComment, throwsStateError);
        if (settlement != null) await settlement!.timeout(const Duration(seconds: 5));
        // Then no replacement or retired draft receives A's text/provenance; actual correction survives.
        expect(fired, isTrue);
        final retained = h.controller.retainedAudioReviews[recognized.original.material.id]!;
        expect(retained.revisions.last.text, '  exact A spoken correction\n');
        expect(retained.revisions.length, recognized.revisions.length + 1);
        expect(retained.reports.single, same(recognized.reports.single));
        expect(h.controller.workspace.regions.first.comments.single.text, 'A comment stays');
        expect(h.controller.workspace.regions.last.comments.single.text, 'B comment stays');
        expect(h.controller.workspace.regions.expand((entry) => entry.comments)
          .every((comment) => comment.audioMaterialId == null), isTrue);
        if (retirement == 'region') {
          expect(h.controller.commentText, 'B comment stays');
          h.controller.selectRegion(first);
        }
        expect(h.controller.commentText, 'A comment stays');
        expect(h.controller.commentDirty, isFalse);
        expect(h.controller.quotationText, '');
      });
    }
  }

  test('R28 ordinary transcript Copy preserves an intentional exact clear', () async {
    // Given an existing independently saved comment and common generated transcript.
    await h.confirm();
    h.controller.setCommentText('old comment');
    h.controller.recordComment();
    await h.controller.beginAudioComment();
    final child = h.controller.audioController!;
    await child.startRecording();
    h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
    h.controller.attachAudioReview(await child.transcribe(), target: h.controller.audioTarget!);
    // When the user explicitly clears the common draft and copies it to the comment.
    child.setDraftText('');
    h.controller.useTranscriptAsComment();
    final saved = h.controller.recordComment();
    // Then the exact clear and correction index are preserved without quotation adoption.
    final comment = saved.workspace.regions.single.comments.last;
    final review = saved.audioReviews.values.single;
    expect(comment.text, '');
    expect(comment.origin, RegionTextOrigin.transcript);
    expect(comment.transcriptRevisionIndex, review.revisions.length - 1);
    expect(comment.audioMaterialId, review.original.material.id);
    expect(review.revisions.last.text, '');
    expect(h.controller.quotationText, '');
  });

  test('R29 canceled local capture cannot claim a later pending original from another borrower', () async {
    // Given a locally observed recording that actually canceled without a pending original.
    await h.confirm();
    await h.controller.beginAudioComment();
    final canceled = h.controller.audioController!;
    await canceled.startRecording();
    await canceled.cancelRecording();
    expect(h.audioFacade.pendingOriginal, isNull);
    expect(canceled.busy, isFalse);
    final other = h.newController(workspace: h.controller.workspace);
    await other.beginAudioComment();
    final actualOwner = other.audioController!;
    await actualOwner.startRecording();
    h.store.audioSaveError = StateError('later borrower import failure');
    // When another child's Stop fails and the canceled child observes its own rejected new command.
    await expectLater(actualOwner.stopRecording(), throwsStateError);
    final pending = h.audioFacade.pendingOriginal!;
    expect(canceled.refreshAvailability, throwsStateError);
    // Then prior local recording history is insufficient to claim the new exact pending original.
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(other.ownsPendingAudio, isTrue);
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.controller.audioReviews, isEmpty);
    expect(h.controller.currentEntry!.audioLinks, isEmpty);
    await other.detach().timeout(const Duration(seconds: 5));
    other.dispose();
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.audio.disposals, 0);
  });

  test('R30 unbound all-target manual Save preserves foreign pending audio for its generic initiating controls', () async {
    // Given a confirmed region without audio controls and a separate generic recording whose import fails.
    await h.confirm();
    final generic = AudioCaptureController(facade: h.audioFacade, now: () => ImageRegionFixture.time);
    await generic.startRecording().timeout(const Duration(seconds: 5));
    h.store.audioSaveError = StateError('generic audio import failure');
    final savesBefore = h.store.saves;
    await expectLater(generic.stopRecording().timeout(const Duration(seconds: 5)), throwsStateError);
    final pending = h.audioFacade.pendingOriginal!;
    expect(h.controller.audioController, isNull);
    expect(h.controller.audioTarget, isNull);
    expect(h.controller.ownsPendingAudio, isFalse);
    h.controller.setQuotationText('  manual 原文\n ');
    h.controller.setCommentText(' independent comment\n');
    final before = h.controller.workspace;
    // When all-target Save first fails the quotation check, then succeeds after explicit confirmation.
    expect(h.controller.commitTextDrafts, throwsStateError);
    expect(h.controller.workspace, same(before));
    expect(h.controller.currentEntry!.comments, isEmpty);
    h.controller.setSourceConfirmed(true);
    final saved = h.controller.commitTextDrafts();
    // Then exact manual histories save together without adopting or consuming another owner's pending original.
    final entry = saved.workspace.regions.single;
    expect(entry.quotations.single.text, '  manual 原文\n ');
    expect(entry.quotations.single.sourceConfirmed, isTrue);
    expect(entry.quotations.single.origin, RegionTextOrigin.manual);
    expect(entry.comments.single.text, ' independent comment\n');
    expect(entry.comments.single.origin, RegionTextOrigin.manual);
    expect(entry.audioLinks, isEmpty);
    expect(saved.audioReviews, isEmpty);
    expect(h.controller.retainedAudioReviews, isEmpty);
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.store.saves, savesBefore);
    expect(h.controller.hasUnsavedText, isFalse);
    // When the separate generic owner explicitly retries the exact original after storage recovers.
    h.store.audioSaveError = null;
    final actual = await generic.retryPendingOriginal().timeout(const Duration(seconds: 5));
    // Then only its own common review receives the import; the region remains manual and unlinked.
    expect(h.store.materials[actual.original.material.id], orderedEquals(pending.bytes));
    expect(generic.review, same(actual));
    expect(h.audioFacade.pendingOriginal, isNull);
    expect(h.store.saves, savesBefore + 1);
    expect(h.controller.audioReviews, isEmpty);
    expect(h.controller.currentEntry!.audioLinks, isEmpty);
    expect(h.audio.starts, 1);
    expect(h.audio.stops, 1);
    expect(h.audio.transcriptions + h.audio.preparations + h.audio.probes, 0);
    expect(h.ocr.inputs, isEmpty);
    expect(h.ai.inputs, isEmpty);
    await generic.detach().timeout(const Duration(seconds: 5));
    generic.dispose();
    expect(h.audio.disposals, 0);
  });
}
