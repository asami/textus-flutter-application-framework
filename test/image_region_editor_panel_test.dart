import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/image_region_fixture.dart';

void main() {
  late ImageRegionFixture h;
  setUp(() async { h = ImageRegionFixture(); await h.open(); });
  tearDown(() async { await h.close(); });

  Widget panel({ImageRegionEditorController? controller,
    ValueChanged<ImageRegionEditorChange>? onChanged,
    Future<void> Function(ImageRegionEditorChange)? onSave,
    bool Function()? policy, double width = 600, double textScale = 1}) => MaterialApp(
    home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: SingleChildScrollView(child: Align(alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: ImageRegionEditorPanel(
          controller: controller ?? h.controller, onChanged: onChanged,
          onSave: onSave, interactionAllowed: policy)))))));
  Finder key(String suffix) => find.byKey(ValueKey('image-region-$suffix'));
  Future<void> pressFinder(WidgetTester tester, Finder finder,
    {bool Function()? complete}) async {
    if (tester.testTextInput.isVisible) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      final done = Completer<void>();
      void settled() {
        if ((complete?.call() ?? !h.controller.busy) && !done.isCompleted) done.complete();
      }
      h.controller.addListener(settled);
      try {
        settled();
        await done.future.timeout(const Duration(seconds: 5));
      } finally {
        h.controller.removeListener(settled);
      }
    });
    await tester.pumpAndSettle();
  }
  Future<void> press(WidgetTester tester, String suffix) => pressFinder(tester, key(suffix));
  Future<void> confirm(WidgetTester tester) async {
    await tester.runAsync(() => h.confirm().timeout(const Duration(seconds: 5)));
  }

  testWidgets('P1 inert mount with primary fields and collapsed diagnostics', (tester) async {
    // Given a fresh caller-owned editor and explicit domain-save callback.
    await tester.pumpWidget(panel(onSave: (_) async {}));
    // When the panel builds and idle frames settle.
    await tester.pumpAndSettle();
    // Then the primary flow is visible while provider work and diagnostics stay inactive.
    expect(find.text('原画像を開く'), findsOneWidget);
    expect(find.text('引用文'), findsOneWidget);
    expect(find.text('コメント'), findsOneWidget);
    expect(find.text('引用・コメントを保存'), findsOneWidget);
    expect(find.text('認識結果・処理の詳細'), findsOneWidget);
    expect(find.text('文字認識の利用可否を確認'), findsNothing);
    expect(find.text('端末内AIで補完して読み取る'), findsNothing);
    expect(h.store.reads, 0);
    expect(h.ocr.probes + h.ai.probes + h.audio.probes + h.audio.starts, 0);
    expect(h.controller.workspace.regions, isEmpty);
  });

  testWidgets('P2 explicit load draw confirm preview OCR-use source-check comment and immutable save', (tester) async {
    // Given an inert panel recording actual immutable adoptions and domain saves.
    final changes = <ImageRegionEditorChange>[];
    final saves = <ImageRegionEditorChange>[];
    await tester.pumpWidget(panel(onChanged: changes.add, onSave: (change) async { saves.add(change); }));
    // When the user explicitly loads, draws, confirms, previews and recognizes a selected area.
    await press(tester, 'load');
    final draw = find.byKey(const ValueKey('image-region-draw-surface'));
    await tester.ensureVisible(draw);
    await tester.pump();
    final bounds = tester.getRect(draw);
    final gesture = await tester.startGesture(bounds.topLeft + const Offset(60, 80));
    await gesture.moveTo(bounds.topLeft + const Offset(240, 200));
    await gesture.up();
    await tester.pump();
    await press(tester, 'confirm');
    await press(tester, 'preview');
    await press(tester, 'recognize');
    expect(h.controller.quotationText, '');
    expect(find.text('OCRの文字を引用文に使う'), findsOneWidget);
    await press(tester, 'use-ocr');
    await tester.ensureVisible(key('source-check'));
    await tester.tap(key('source-check'));
    await tester.pump();
    await tester.enterText(key('comment'), ' separate note ');
    await press(tester, 'save');
    // Then exactly selected raw OCR is explicitly adopted and the caller receives both immutable maps together.
    expect(saves.length, 1);
    expect(saves.single.workspace.regions.single.quotations.single.text, h.ocr.text);
    expect(saves.single.workspace.regions.single.comments.single.text, ' separate note ');
    expect(changes, isNotEmpty);
    expect(() => saves.single.audioReviews.clear(), throwsUnsupportedError);
    expect(find.text('保存しました'), findsOneWidget);
    expect(h.ai.inputs, isEmpty);
    expect(h.ocr.preparations + h.audio.starts, 0);
  });

  testWidgets('P3 unavailable local provider supports manual source-checked save', (tester) async {
    // Given actual unavailable Core providers and a confirmed source snapshot.
    h.ocr.unavailable = true;
    h.ai.unavailable = true;
    await confirm(tester);
    await tester.runAsync(() => h.controller.recognize().timeout(const Duration(seconds: 5)));
    ImageRegionEditorChange? saved;
    await tester.pumpWidget(panel(onSave: (value) async { saved = value; }));
    // When entering manual quotation and comment, then explicitly checking the source and saving.
    await tester.ensureVisible(key('quotation'));
    await tester.enterText(key('quotation'), ' manual 日本語 ');
    await tester.ensureVisible(key('source-check'));
    await tester.tap(key('source-check'));
    await tester.enterText(key('comment'), 'manual comment');
    await press(tester, 'save');
    // Then provider unavailability never disables manual adoption or invents OCR output.
    expect(saved!.workspace.regions.single.quotations.single.origin, RegionTextOrigin.manual);
    expect(saved!.workspace.regions.single.comments.single.text, 'manual comment');
    expect(h.ocr.inputs, isEmpty);
    expect(find.text('読み取れた文字がありません。引用文を入力することもできます。'), findsOneWidget);
  });

  testWidgets('P4 unconfirmed dirty quote gives actionable save error without partial domain save', (tester) async {
    // Given a confirmed area and a separately edited comment and unconfirmed quotation.
    await confirm(tester);
    var saves = 0;
    await tester.pumpWidget(panel(onSave: (_) async { saves++; }));
    await tester.ensureVisible(key('quotation'));
    await tester.enterText(key('quotation'), 'unchecked');
    await tester.enterText(key('comment'), 'independent comment');
    // When 引用・コメントを保存 is explicitly invoked before the human source check.
    await press(tester, 'save');
    // Then no text history or domain save is partially adopted and the reason is visible.
    expect(saves, 0);
    expect(h.controller.currentEntry!.quotations, isEmpty);
    expect(h.controller.currentEntry!.comments, isEmpty);
    expect(find.text('操作を完了できませんでした。範囲を確定し、引用文を原文と照合してから再度お試しください。処理の詳細も確認できます。'), findsOneWidget);
    expect(h.controller.quotationText, 'unchecked');
    expect(h.controller.commentText, 'independent comment');
  });

  testWidgets('P5 captured owner buttons and text callbacks reject replacement and current policy denial', (tester) async {
    // Given rendered actions and editor callbacks captured from the original owner.
    await confirm(tester);
    var allowed = true;
    var saves = 0;
    await tester.pumpWidget(panel(policy: () => allowed, onSave: (_) async { saves++; }));
    final oldOcr = tester.widget<OutlinedButton>(key('recognize')).onPressed!;
    final oldText = tester.widget<TextField>(key('quotation')).onChanged!;
    final oldSave = tester.widget<FilledButton>(key('save')).onPressed!;
    // When current policy changes without rebuilding and old callbacks are invoked.
    allowed = false;
    oldOcr();
    oldText('denied exact text');
    oldSave();
    await tester.pump();
    expect(h.ocr.inputs, isEmpty);
    expect(h.controller.quotationText, '');
    final replacement = h.newController();
    allowed = true;
    await tester.pumpWidget(panel(controller: replacement, policy: () => allowed,
      onSave: (_) async { saves++; }));
    oldOcr();
    oldText('old owner text');
    oldSave();
    await tester.pump();
    // Then neither owner is mutated or saved by an already-rendered retired action.
    expect(h.ocr.inputs, isEmpty);
    expect(h.controller.quotationText, '');
    expect(replacement.quotationText, '');
    expect(saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    replacement.dispose();
  });

  testWidgets('P6 busy/error presentation, editable manual text, explicit advanced AI only', (tester) async {
    // Given a confirmed area and a real OCR provider held during an admitted command.
    await confirm(tester);
    await tester.runAsync(() => h.controller.previewSelection().timeout(const Duration(seconds: 5)));
    h.ocr.gate = Completer<void>();
    await tester.pumpWidget(panel(onSave: (_) async {}));
    late Future<void> operation;
    await tester.runAsync(() async {
      operation = h.controller.recognize();
      await h.ocr.entered.future.timeout(const Duration(seconds: 5));
    });
    await tester.pump();
    // When manual text is edited while OCR waits and its actual completion later fails.
    expect(find.text('選択範囲を処理しています'), findsOneWidget);
    await tester.ensureVisible(key('quotation'));
    await tester.enterText(key('quotation'), 'manual while OCR waits');
    h.ocr.failure = StateError('controlled provider failure');
    h.ocr.gate!.complete();
    await tester.runAsync(() => operation.timeout(const Duration(seconds: 5)));
    await tester.pumpAndSettle();
    expect(h.controller.quotationText, 'manual while OCR waits');
    expect(h.ai.inputs, isEmpty);
    expect(h.controller.error, isNull);
    expect(find.text('読み取れた文字がありません。引用文を入力することもできます。'), findsOneWidget);
    expect(find.textContaining('controlled provider failure'), findsNothing);
    await tester.ensureVisible(key('details'));
    await tester.tap(key('details'));
    await tester.pumpAndSettle();
    // Then raw provider failure is inspectable and AI remains an explicit secondary action.
    expect(find.textContaining('controlled provider failure'), findsOneWidget);
    expect(find.text('端末内AIで補完して読み取る'), findsNothing);
    expect(h.ocr.preparations + h.ai.preparations, 0);
    expect(h.controller.busy, isFalse);
  });

  testWidgets('P7 common audio/transcript panels link/update once and copy correction only to comment', (tester) async {
    // Given a confirmed image target with optional borrowed common audio services.
    await confirm(tester);
    final changes = <ImageRegionEditorChange>[];
    await tester.pumpWidget(panel(onChanged: changes.add, onSave: (_) async {}));
    // When explicit opening and existing common controls record, stop, transcribe and correct.
    await press(tester, 'begin-audio');
    expect(find.byType(AudioCapturePanel), findsOneWidget);
    expect(find.byType(TranscriptReviewPanel), findsOneWidget);
    expect(h.audio.starts, 0);
    final record = find.byKey(const ValueKey('audio-capture-record'));
    await pressFinder(tester, record, complete: () => h.controller.audioController!.recordingStarted);
    final stop = find.byKey(const ValueKey('audio-capture-stop'));
    await pressFinder(tester, stop, complete: () => !h.controller.audioController!.busy);
    final transcribe = find.byKey(const ValueKey('audio-capture-transcribe'));
    await pressFinder(tester, transcribe, complete: () => !h.controller.audioController!.busy);
    final transcript = find.byKey(const ValueKey('transcript-review-text'));
    await tester.ensureVisible(transcript);
    await tester.enterText(transcript, 'corrected spoken comment');
    await press(tester, 'use-transcript');
    await press(tester, 'save');
    // Then common controls remain authoritative and only one original link is stored alongside its separate review.
    expect(h.audio.starts, 1);
    expect(h.audio.transcriptions, 1);
    expect(h.controller.currentEntry!.audioLinks.length, 1);
    expect(h.controller.currentEntry!.comments.single.text, 'corrected spoken comment');
    expect(h.controller.currentEntry!.comments.single.transcriptRevisionIndex, 1);
    expect(h.controller.quotationText, '');
    expect(changes.last.audioReviews.values.single.revisions.last.text, 'corrected spoken comment');
  });

  testWidgets('P8 captured audio callback cannot attach to replaced region controller owner', (tester) async {
    // Given a rendered common audio panel bound to an immutable exact region target.
    await confirm(tester);
    await tester.runAsync(() => h.controller.beginAudioComment().timeout(const Duration(seconds: 5)));
    await tester.pumpWidget(panel(onSave: (_) async {}));
    final common = tester.widget<AudioCapturePanel>(find.byType(AudioCapturePanel));
    final oldCallback = common.onReviewChanged!;
    final child = h.controller.audioController!;
    await tester.runAsync(() => child.startRecording().timeout(const Duration(seconds: 5)));
    final review = await tester.runAsync(() => child.stopRecording().timeout(const Duration(seconds: 5)));
    final replacement = h.newController(workspace: h.controller.workspace);
    // When this panel is replaced and its old common callback completes later.
    await tester.pumpWidget(panel(controller: replacement, onSave: (_) async {}));
    oldCallback(review!);
    await tester.pump();
    // Then no original review or link is published to either retired/replacement callback owner.
    expect(h.controller.audioReviews, isEmpty);
    expect(replacement.audioReviews, isEmpty);
    expect(replacement.workspace.regions.single.audioLinks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => replacement.detach().timeout(const Duration(seconds: 5)));
    replacement.dispose();
  });

  testWidgets('P9 restored workspace/reviews show exact text and use common audio after reopening', (tester) async {
    // Given saved image text and an exact separately retained original audio review.
    await confirm(tester);
    h.controller.setQuotationText('saved source text');
    h.controller.setSourceConfirmed(true);
    h.controller.setCommentText('saved comment');
    h.controller.commitTextDrafts();
    await tester.runAsync(() => h.controller.beginAudioComment().timeout(const Duration(seconds: 5)));
    final child = h.controller.audioController!;
    await tester.runAsync(() => child.startRecording().timeout(const Duration(seconds: 5)));
    final review = await tester.runAsync(() => child.stopRecording().timeout(const Duration(seconds: 5)));
    h.controller.attachAudioReview(review!, target: h.controller.audioTarget!);
    final saved = h.controller.change;
    await tester.runAsync(() => h.controller.detach().timeout(const Duration(seconds: 5)));
    h.controller.dispose();
    h.controller = (await tester.runAsync(() async =>
        h.newController(workspace: saved.workspace, reviews: saved.audioReviews)))!;
    // When the reopened panel selects its existing exact original audio.
    await tester.pumpWidget(panel(onSave: (_) async {}));
    await press(tester, 'select-audio-${review.original.material.id}');
    // Then original text and common playback controls remain usable with no new capture.
    expect(tester.widget<TextField>(key('quotation')).controller!.text, 'saved source text');
    expect(tester.widget<TextField>(key('comment')).controller!.text, 'saved comment');
    expect(h.controller.audioController!.review, review);
    expect(find.byKey(const ValueKey('audio-capture-play')), findsOneWidget);
    expect(h.audio.starts, 1);
  }, timeout: const Timeout(Duration(seconds: 20)));

  testWidgets('P10 accessibility-scaled narrow primary flow has no layout overflow', (tester) async {
    // Given a confirmed image target in a narrow, doubled-text-scale viewport.
    await confirm(tester);
    await tester.pumpWidget(panel(width: 280, textScale: 2, onSave: (_) async {}));
    // When primary fields and the 引用・コメントを保存 route are laid out and scrolled.
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('save'));
    await tester.pumpAndSettle();
    // Then all primary controls remain in the scroll route without a Flutter overflow exception.
    expect(tester.takeException(), isNull);
    expect(find.text('引用・コメントを保存'), findsOneWidget);
    expect(find.byType(ImageRegionSelector), findsOneWidget);
    expect(h.ocr.inputs, isEmpty);
    expect(h.audio.starts, 0);
  });

  for (final exact in ['  saved spoken 日本語\n ', '']) {
    testWidgets('P11 引用・コメントを保存 retains dirty common transcript ${exact.isEmpty ? "clear" : "edit"} without Copy', (tester) async {
      // Given independent saved region text and a linked common raw transcription.
      await confirm(tester);
      h.controller.setQuotationText('saved source');
      h.controller.setSourceConfirmed(true);
      h.controller.setCommentText('saved separate comment');
      h.controller.commitTextDrafts();
      await tester.runAsync(() => (() async {
        await h.controller.beginAudioComment();
        final child = h.controller.audioController!;
        await child.startRecording();
        h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
        h.controller.attachAudioReview(await child.transcribe(), target: h.controller.audioTarget!);
      })().timeout(const Duration(seconds: 5)));
      final originalReview = h.controller.audioController!.review!;
      final id = originalReview.original.material.id;
      final saves = <ImageRegionEditorChange>[];
      final changes = <ImageRegionEditorChange>[];
      await tester.pumpWidget(panel(onChanged: changes.add, onSave: (value) async { saves.add(value); }));
      // When the common transcript field is edited and 引用・コメントを保存 is physically tapped.
      final transcript = find.byKey(const ValueKey('transcript-review-text'));
      await tester.ensureVisible(transcript);
      await tester.pumpAndSettle();
      await tester.enterText(transcript, exact);
      await press(tester, 'save');
      // Then the single combined Save keeps the exact correction, raw report and original link.
      expect(saves.length, 1);
      expect(changes.length, 1);
      final retained = saves.single.audioReviews[id]!;
      expect(retained.revisions.last.text, exact);
      expect(retained.revisions.length, originalReview.revisions.length + 1);
      expect(retained.original, same(originalReview.original));
      expect(retained.reports.single, same(originalReview.reports.single));
      final entry = saves.single.workspace.regions.single;
      expect(entry.audioLinks.single.audioMaterialId, id);
      expect(entry.quotations.single.text, 'saved source');
      expect(entry.comments.single.text, 'saved separate comment');
      expect(h.controller.audioController!.hasUnsavedText, isFalse);
    });
  }

  testWidgets('P12 failed passage Save leaves dirty transcript unrecorded until source confirmation', (tester) async {
    // Given a common raw transcript plus dirty quotation/comment buffers.
    await confirm(tester);
    await tester.runAsync(() => (() async {
      await h.controller.beginAudioComment();
      final child = h.controller.audioController!;
      await child.startRecording();
      h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
      h.controller.attachAudioReview(await child.transcribe(), target: h.controller.audioTarget!);
    })().timeout(const Duration(seconds: 5)));
    final child = h.controller.audioController!;
    final originalReview = child.review!;
    h.controller.setQuotationText('unchecked source');
    h.controller.setCommentText('separate comment');
    final before = h.controller.workspace;
    final reviews = h.controller.audioReviews;
    final saves = <ImageRegionEditorChange>[];
    final changes = <ImageRegionEditorChange>[];
    await tester.pumpWidget(panel(onChanged: changes.add, onSave: (value) async { saves.add(value); }));
    final transcript = find.byKey(const ValueKey('transcript-review-text'));
    await tester.ensureVisible(transcript);
    await tester.pumpAndSettle();
    await tester.enterText(transcript, ' exact correction\n');
    // When Save is physically tapped before the source check, then confirmed and retried.
    await press(tester, 'save');
    expect(saves, isEmpty);
    expect(changes, isEmpty);
    expect(h.controller.workspace, same(before));
    expect(h.controller.audioReviews, same(reviews));
    expect(child.review, same(originalReview));
    expect(child.hasUnsavedText, isTrue);
    expect(find.text('操作を完了できませんでした。範囲を確定し、引用文を原文と照合してから再度お試しください。処理の詳細も確認できます。'), findsOneWidget);
    await press(tester, 'source-check');
    await press(tester, 'save');
    // Then the successful retry saves one combined adoption without copying transcript into text.
    expect(saves.length, 1);
    expect(changes.length, 1);
    final entry = saves.single.workspace.regions.single;
    expect(entry.quotations.single.text, 'unchecked source');
    expect(entry.comments.single.text, 'separate comment');
    expect(entry.audioLinks.length, 1);
    final retained = saves.single.audioReviews[originalReview.original.material.id]!;
    expect(retained.revisions.last.text, ' exact correction\n');
    expect(retained.revisions.length, originalReview.revisions.length + 1);
    expect(retained.reports.single, same(originalReview.reports.single));
  });

  testWidgets('P13 admitted common Stop settles once despite temporary policy denial and region generation change', (tester) async {
    // Given actual common recording and a Stop held at durable-original storage.
    await confirm(tester);
    var allowed = true;
    final changes = <ImageRegionEditorChange>[];
    final adopted = (await tester.runAsync(() async => Completer<void>()))!;
    await tester.pumpWidget(panel(policy: () => allowed, onChanged: (value) {
      changes.add(value);
      if (!adopted.isCompleted) adopted.complete();
    }, onSave: (_) async {}));
    await press(tester, 'begin-audio');
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    final record = find.byKey(const ValueKey('audio-capture-record'));
    final oldRecord = tester.widget<ElevatedButton>(record).onPressed!;
    final oldBegin = tester.widget<OutlinedButton>(key('begin-audio')).onPressed!;
    await pressFinder(tester, record, complete: () => child.recordingStarted);
    h.store.audioSaveGate = Completer<void>();
    final stop = find.byKey(const ValueKey('audio-capture-stop'));
    await tester.ensureVisible(stop);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(stop);
      await h.store.audioSaveEntered.future.timeout(const Duration(seconds: 5));
    });
    // When only regional result admission changes, then policy denies new commands before Stop settles.
    h.controller.cancelPendingResult();
    allowed = false;
    oldRecord();
    oldBegin();
    expect(h.audio.starts, 1);
    expect(h.controller.audioController, same(child));
    expect(changes, isEmpty);
    await tester.runAsync(() async {
      h.store.audioSaveGate!.complete();
      await adopted.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    // Then accepted completion publishes exactly once to the original target without new capture/preparation.
    final review = child.review!;
    final entry = changes.single.workspace.regions.single;
    expect(entry.snapshots.single, same(target));
    expect(entry.audioLinks.single.audioMaterialId, review.original.material.id);
    expect(changes.single.audioReviews[review.original.material.id], same(review));
    expect(h.controller.audioReviews[review.original.material.id], same(review));
    expect(h.controller.hasPendingInput, isFalse);
    expect(h.audio.starts, 1);
    expect(h.audio.stops, 1);
    expect(h.audio.transcriptions + h.audio.preparations, 0);
    expect(allowed, isFalse);
  });

  testWidgets('P14 admitted common Stop cannot deliver to a replacement region controller', (tester) async {
    // Given a durable common Stop accepted by the original mounted region owner.
    await confirm(tester);
    final oldChanges = <ImageRegionEditorChange>[];
    final replacementChanges = <ImageRegionEditorChange>[];
    await tester.pumpWidget(panel(onChanged: oldChanges.add, onSave: (_) async {}));
    await press(tester, 'begin-audio');
    final child = h.controller.audioController!;
    await pressFinder(tester, find.byKey(const ValueKey('audio-capture-record')),
      complete: () => child.recordingStarted);
    h.store.audioSaveGate = Completer<void>();
    final stop = find.byKey(const ValueKey('audio-capture-stop'));
    await tester.ensureVisible(stop);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(stop);
      await h.store.audioSaveEntered.future.timeout(const Duration(seconds: 5));
    });
    final replacement = await tester.runAsync(() async => h.newController(workspace: h.controller.workspace));
    // When the mounted controller is replaced before the actual durable Save settles.
    await tester.pumpWidget(panel(controller: replacement!, onChanged: replacementChanges.add,
      onSave: (_) async {}));
    await tester.runAsync(() async {
      h.store.audioSaveGate!.complete();
      await h.controller.detach().timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    // Then neither callback owner receives a stale adoption; the original owner retains actual audio for handoff.
    final actual = child.review!;
    expect(oldChanges, isEmpty);
    expect(replacementChanges, isEmpty);
    expect(h.controller.audioReviews, isEmpty);
    expect(replacement.audioReviews, isEmpty);
    expect(replacement.workspace.regions.single.audioLinks, isEmpty);
    expect(h.controller.retainedAudioReviews[actual.original.material.id], same(actual));
    expect(h.controller.hasPendingInput, isTrue);
    expect(h.audio.starts, 1);
    expect(h.audio.disposals, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => replacement.detach().timeout(const Duration(seconds: 5)));
    replacement.dispose();
  });

  testWidgets('P15 accepted callback from a replaced common child cannot bind the old original to its successor', (tester) async {
    // Given a captured common completion callback and a real original from that child.
    await confirm(tester);
    await tester.runAsync(() => h.controller.beginAudioComment().timeout(const Duration(seconds: 5)));
    await tester.pumpWidget(panel(onSave: (_) async {}));
    final oldCallback = tester.widget<AudioCapturePanel>(find.byType(AudioCapturePanel)).onReviewChanged!;
    final child = h.controller.audioController!;
    await tester.runAsync(() => child.startRecording().timeout(const Duration(seconds: 5)));
    final review = await tester.runAsync(() => child.stopRecording().timeout(const Duration(seconds: 5)));
    // When this same region owner explicitly replaces only its common audio child.
    await tester.runAsync(() => h.controller.beginAudioComment().timeout(const Duration(seconds: 5)));
    await tester.pumpAndSettle();
    final replacement = h.controller.audioController!;
    oldCallback(review!);
    await tester.pump();
    // Then the retired child's accepted callback cannot adopt into the new child's target lifetime.
    expect(replacement, isNot(same(child)));
    expect(replacement.review, isNull);
    expect(h.controller.audioReviews, isEmpty);
    expect(h.controller.currentEntry!.audioLinks, isEmpty);
    expect(h.controller.retainedAudioReviews[review.original.material.id], same(review));
    expect(h.controller.hasPendingInput, isTrue);
    expect(h.audio.starts, 1);
    expect(h.audio.disposals, 0);
  });

  testWidgets('P16 common Retry save recovers only the initiating child while a preexisting idle borrower is denied', (tester) async {
    // Given an idle second-source child sharing the facade before A starts its common recording.
    await confirm(tester);
    final other = (await tester.runAsync(() => (() async {
      final source = await h.store.saveMaterial(bytes: h.controller.frame!.pngBytes,
        mediaType: 'image/png', capturedAt: ImageRegionFixture.time);
      final editor = h.newController(original: source);
      await editor.loadSource();
      editor.setSelection(ImageRegionFixture.geometry());
      editor.confirmSelection();
      await editor.beginAudioComment();
      return editor;
    })().timeout(const Duration(seconds: 5))))!;
    final idle = other.audioController!;
    final changes = <ImageRegionEditorChange>[];
    await tester.pumpWidget(panel(onChanged: changes.add, onSave: (_) async {}));
    await press(tester, 'begin-audio');
    final child = h.controller.audioController!;
    final target = h.controller.audioTarget!;
    await pressFinder(tester, find.byKey(const ValueKey('audio-capture-record')),
      complete: () => child.recordingStarted);
    h.store.audioSaveError = StateError('controlled common Stop import failure');
    final count = h.store.saves;
    // When common Stop fails before storage and the idle borrower renders the same pending service state.
    await pressFinder(tester, find.byKey(const ValueKey('audio-capture-stop')),
      complete: () => !child.busy);
    final pending = h.audioFacade.pendingOriginal!;
    expect(h.controller.ownsPendingAudio, isTrue);
    expect(h.controller.audioTarget, same(target));
    expect(h.controller.audioController, same(child));
    expect(changes, isEmpty);
    final retry = find.byKey(const ValueKey('audio-capture-retry-save'));
    expect(tester.widget<ElevatedButton>(retry).onPressed, isNotNull);
    await tester.pumpWidget(panel(controller: other, onSave: (_) async {}));
    await tester.pumpAndSettle();
    expect(idle.canRetryPendingOriginal, isTrue);
    expect(idle.recordingStarted, isFalse);
    expect(other.ownsPendingAudio, isFalse);
    expect(tester.widget<ElevatedButton>(retry).onPressed, isNull);
    await pressFinder(tester, retry);
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.store.saves, count);
    expect(idle.review, isNull);
    expect(other.audioReviews, isEmpty);
    expect(other.currentEntry!.audioLinks, isEmpty);
    await tester.ensureVisible(key('comment'));
    await tester.enterText(key('comment'), 'manual route remains editable');
    expect(other.commentText, 'manual route remains editable');
    h.store.audioSaveError = null;
    await tester.pumpWidget(panel(onChanged: changes.add, onSave: (_) async {}));
    await tester.pumpAndSettle();
    await pressFinder(tester, retry, complete: () => !child.busy);
    // Then the initiating common child imports the exact bytes once and links only its original target.
    final review = child.review!;
    expect(h.store.materials[review.original.material.id], orderedEquals(pending.bytes));
    expect(h.store.saves, count + 1);
    expect(h.audio.starts, 1);
    expect(h.audio.stops, 1);
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(h.controller.selectionLocked, isFalse);
    expect(h.audioFacade.pendingOriginal, isNull);
    expect(changes.single.workspace.regions.single.snapshots.single, same(target));
    expect(changes.single.workspace.regions.single.audioLinks.single.audioMaterialId,
      review.original.material.id);
    expect(other.currentEntry!.audioLinks, isEmpty);
    await tester.runAsync(() => other.detach().timeout(const Duration(seconds: 5)));
    other.dispose();
    expect(h.audio.disposals, 0);
  });

  testWidgets('P17 physical transcript Copy stops after adoption navigates to another region', (tester) async {
    // Given independent A/B comments and an actual common transcript on A.
    await confirm(tester);
    final first = h.controller.selectedRegionId!;
    h.controller.setCommentText('A unchanged');
    h.controller.recordComment();
    h.controller.startNewRegion();
    h.controller.setSelection(ImageRegionFixture.geometry(x: 0.2));
    h.controller.confirmSelection();
    final second = h.controller.selectedRegionId!;
    h.controller.setCommentText('B unchanged');
    h.controller.recordComment();
    h.controller.selectRegion(first);
    await tester.runAsync(() => (() async {
      await h.controller.beginAudioComment();
      final child = h.controller.audioController!;
      await child.startRecording();
      h.controller.attachAudioReview(await child.stopRecording(), target: h.controller.audioTarget!);
      h.controller.attachAudioReview(await child.transcribe(), target: h.controller.audioTarget!);
    })().timeout(const Duration(seconds: 5)));
    final version = h.controller.changeVersion;
    var navigated = false;
    await tester.pumpWidget(panel(onChanged: (_) {
      if (!navigated && h.controller.changeVersion == version + 1) {
        navigated = true;
        h.controller.selectRegion(second);
      }
    }, onSave: (_) async {}));
    final transcript = find.byKey(const ValueKey('transcript-review-text'));
    await tester.ensureVisible(transcript);
    await tester.pumpAndSettle();
    await tester.enterText(transcript, ' exact A transcript\n');
    // When physical Copy adopts the correction and its caller synchronously navigates to B.
    await press(tester, 'use-transcript');
    // Then B's field/history receive no A text or provenance and A's actual correction remains retained.
    expect(navigated, isTrue);
    expect(h.controller.selectedRegionId, second);
    expect(tester.widget<TextField>(key('comment')).controller!.text, 'B unchanged');
    expect(h.controller.currentEntry!.comments.single.text, 'B unchanged');
    expect(h.controller.currentEntry!.comments.single.audioMaterialId, isNull);
    expect(h.controller.commentDirty, isFalse);
    expect(h.controller.quotationText, '');
    expect(h.controller.retainedAudioReviews.values.single.revisions.last.text, ' exact A transcript\n');
    expect(h.controller.workspace.regions.first.comments.single.text, 'A unchanged');
  });

  testWidgets('P18 physical unbound manual Save leaves generic pending audio for its original common Retry', (tester) async {
    // Given separate common generic audio controls and a confirmed region with no bound audio target.
    await confirm(tester);
    final generic = (await tester.runAsync(() async => AudioCaptureController(
      facade: h.audioFacade, now: () => ImageRegionFixture.time)))!;
    final changes = <ImageRegionEditorChange>[];
    final saves = <ImageRegionEditorChange>[];
    final audioReviews = <AudioTranscriptReview>[];
    Finder region(String suffix) => find.descendant(
      of: find.byKey(const ValueKey('unbound-region-panel')), matching: key(suffix));
    Finder audio(String suffix) => find.descendant(
      of: find.byKey(const ValueKey('generic-audio-panel')),
      matching: find.byKey(ValueKey('audio-capture-$suffix')));
    Future<void> pressAudio(String suffix, bool Function() doneWhen) async {
      await tester.pumpAndSettle();
      await tester.ensureVisible(audio(suffix));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final done = Completer<void>();
        void settled() {
          if (doneWhen() && !done.isCompleted) done.complete();
        }
        generic.addListener(settled);
        try {
          await tester.tap(audio(suffix));
          settled();
          await done.future.timeout(const Duration(seconds: 5));
        } finally {
          generic.removeListener(settled);
        }
      });
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Column(children: [
        ImageRegionEditorPanel(key: const ValueKey('unbound-region-panel'),
          controller: h.controller, onChanged: changes.add,
          onSave: (value) async { saves.add(value); }),
        AudioCapturePanel(key: const ValueKey('generic-audio-panel'),
          controller: generic, onReviewChanged: audioReviews.add),
      ])))));
    await pressAudio('record', () => generic.recordingStarted);
    h.store.audioSaveError = StateError('generic common Stop import failure');
    final savesBefore = h.store.saves;
    await pressAudio('stop', () => !generic.busy);
    final pending = h.audioFacade.pendingOriginal!;
    expect(audioReviews, isEmpty);
    expect(h.controller.audioController, isNull);
    expect(h.controller.audioTarget, isNull);
    // When the user enters manual fields, explicitly checks the source and physically taps 引用・コメントを保存.
    await tester.ensureVisible(region('quotation'));
    await tester.pumpAndSettle();
    await tester.enterText(region('quotation'), '  manual 原文\n');
    await pressFinder(tester, region('source-check'));
    await tester.ensureVisible(region('comment'));
    await tester.pumpAndSettle();
    await tester.enterText(region('comment'), ' independent manual comment ');
    await pressFinder(tester, region('save'));
    // Then one immutable manual change saves without consuming, importing or linking foreign audio.
    expect(saves.length, 1);
    expect(changes.length, 1);
    final entry = saves.single.workspace.regions.single;
    expect(entry.quotations.single.text, '  manual 原文\n');
    expect(entry.quotations.single.sourceConfirmed, isTrue);
    expect(entry.comments.single.text, ' independent manual comment ');
    expect(entry.audioLinks, isEmpty);
    expect(saves.single.audioReviews, isEmpty);
    expect(h.controller.retainedAudioReviews, isEmpty);
    expect(h.controller.ownsPendingAudio, isFalse);
    expect(h.audioFacade.pendingOriginal, same(pending));
    expect(h.store.saves, savesBefore);
    expect(find.text('保存しました'), findsOneWidget);
    // When the separate original common controls explicitly retry after storage recovers.
    h.store.audioSaveError = null;
    await pressAudio('retry-save', () => !generic.busy);
    // Then exact original bytes reach only the generic review, with no recapture or region adoption.
    final review = audioReviews.single;
    expect(generic.review, same(review));
    expect(h.store.materials[review.original.material.id], orderedEquals(pending.bytes));
    expect(h.audioFacade.pendingOriginal, isNull);
    expect(h.store.saves, savesBefore + 1);
    expect(h.controller.audioReviews, isEmpty);
    expect(h.controller.currentEntry!.audioLinks, isEmpty);
    expect(changes.length, 1);
    expect(saves.length, 1);
    expect(h.audio.starts, 1);
    expect(h.audio.stops, 1);
    expect(h.audio.probes + h.audio.preparations + h.audio.transcriptions, 0);
    expect(h.ocr.inputs, isEmpty);
    expect(h.ai.inputs, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => generic.detach().timeout(const Duration(seconds: 5)));
    generic.dispose();
    expect(h.audio.disposals, 0);
  });
}
