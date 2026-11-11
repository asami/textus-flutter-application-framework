import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/image_region_fixture.dart';

void main() {
  late ImageRegionFixture h;
  setUp(() async { h = ImageRegionFixture(); await h.open(); });
  tearDown(() async { await h.close(); });

  Future<void> load(WidgetTester tester) async {
    await tester.runAsync(() => h.controller.loadSource());
  }
  Widget view(ImageRegionFrame frame, ValueChanged<ImageRegionGeometry> callback,
    {ImageRegionGeometry? selection, double width = 400,
    TransformationController? transform, bool enabled = true, Key? key}) => MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: ImageRegionSelector(key: key,
          frame: frame, onChanged: callback, selection: selection,
          enabled: enabled, transformationController: transform)))));
  Future<void> drag(WidgetTester tester, Offset start, Offset end) async {
    final origin = tester.getTopLeft(find.byKey(const ValueKey('image-region-draw-surface')));
    final gesture = await tester.startGesture(origin + start);
    await gesture.moveTo(origin + end);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('S1 actual non-square contain drag and overlay preserve source geometry on resize', (tester) async {
    // Given an actual Core upright raster with a 400 by 320 contained viewport.
    await load(tester);
    ImageRegionGeometry? selected;
    void changed(ImageRegionGeometry g) { selected = g; }
    await tester.pumpWidget(view(h.controller.frame!, changed));
    // When a real drag selects an image rectangle and the viewport later narrows.
    await drag(tester, const Offset(40, 80), const Offset(200, 160));
    expect(selected!.x, closeTo(0.1, 0.001));
    expect(selected!.y, closeTo(0.1, 0.001));
    expect(selected!.width, closeTo(0.4, 0.001));
    expect(selected!.height, closeTo(0.4, 0.001));
    final retained = selected;
    await tester.pumpWidget(view(h.controller.frame!, changed, width: 300, selection: retained));
    // Then normalized geometry is identical while its display rectangle changes.
    expect(selected, same(retained));
    final selector = tester.widget<ImageRegionSelector>(find.byType(ImageRegionSelector));
    expect(selector.selection, same(retained));
    final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('image-region-overlay'))).painter!;
    expect(painter, isNotNull);
    final rect = ImageRegionViewport.containRect(pixelWidth: 200, pixelHeight: 100,
      viewportSize: const Size(300, 320));
    final overlay = ImageRegionViewport.selectionRect(retained!, rect);
    expect(overlay, const Rect.fromLTWH(30, 100, 120, 60));
    expect(retained.toJson().keys, isNot(contains('transform')));
    expect(h.store.reads, 1);
    expect(h.ocr.inputs, isEmpty);
  });

  testWidgets('S2 actual letterbox start ignored, endpoint clamped, zero area rejected', (tester) async {
    // Given real source bytes and an initially unselected contained image.
    await load(tester);
    final results = <ImageRegionGeometry>[];
    await tester.pumpWidget(view(h.controller.frame!, results.add));
    // When dragging from letterbox, horizontally at zero height, then beyond image bounds.
    await drag(tester, const Offset(40, 20), const Offset(200, 160));
    await drag(tester, const Offset(40, 80), const Offset(200, 80));
    expect(results, isEmpty);
    await drag(tester, const Offset(40, 80), const Offset(700, 500));
    // Then only the valid positive rectangle is emitted, bounded by the original raster.
    expect(results.length, 1);
    expect(results.single.x + results.single.width, closeTo(1, 0.00001));
    expect(results.single.y + results.single.height, closeTo(1, 0.00001));
  });

  testWidgets('S3 ellipse and circle gestures use equal physical raster axes for circle', (tester) async {
    // Given a two-to-one source aspect ratio and actual reusable selection controls.
    await load(tester);
    final results = <ImageRegionGeometry>[];
    await tester.pumpWidget(view(h.controller.frame!, results.add));
    // When the user chooses ellipse and circle tools for the same unequal-axis drag.
    await tester.tap(find.text('楕円'));
    await tester.pump();
    await drag(tester, const Offset(40, 80), const Offset(200, 160));
    await tester.tap(find.text('円'));
    await tester.pump();
    await drag(tester, const Offset(40, 80), const Offset(200, 160));
    // Then the ellipse preserves unequal axes; the circle has equal raster-pixel axes.
    expect(results.length, 2);
    expect(results.first.shape, ImageRegionShape.ellipse);
    expect(results.first.width * 200, isNot(closeTo(results.first.height * 100, 0.001)));
    expect(results.last.shape, ImageRegionShape.ellipse);
    expect(results.last.width * 200, closeTo(results.last.height * 100, 0.001));
    expect(results.last.width, isNot(closeTo(results.last.height, 0.001)));
  });

  testWidgets('S4 actual InteractiveViewer zoom and pan then draw applies inverse once', (tester) async {
    // Given a borrowed actual InteractiveViewer transformation controller.
    await load(tester);
    final transform = TransformationController();
    addTearDown(transform.dispose);
    final results = <ImageRegionGeometry>[];
    await tester.pumpWidget(view(h.controller.frame!, results.add, transform: transform));
    // When explicit zoom and Move mode pan the viewer before another Select-mode drag.
    await tester.tap(find.byTooltip('拡大'));
    await tester.pump();
    await tester.tap(find.text('画像を動かす'));
    await tester.pump();
    await tester.drag(find.byType(InteractiveViewer), const Offset(-30, -20));
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
    final start = transform.toScene(const Offset(100, 140));
    final end = transform.toScene(const Offset(220, 230));
    final rect = ImageRegionViewport.containRect(pixelWidth: 200, pixelHeight: 100,
      viewportSize: const Size(400, 320));
    final expected = ImageRegionViewport.fromDrag(start: start, end: end, imageRect: rect)!;
    await tester.tap(find.text('範囲を選ぶ'));
    await tester.pump();
    await drag(tester, const Offset(100, 140), const Offset(220, 230));
    // Then actual pointer selection agrees with a single inverse into the canonical source.
    expect(results.length, 1);
    expect(results.single.x, closeTo(expected.x, 0.001));
    expect(results.single.y, closeTo(expected.y, 0.001));
    expect(results.single.width, closeTo(expected.width, 0.001));
    expect(results.single.height, closeTo(expected.height, 0.001));
    await tester.tap(find.text('表示倍率を戻す'));
    await tester.pump();
    expect(transform.value, Matrix4.identity());
  });

  testWidgets('S5 frame and callback owner replacement suppress old gesture callbacks', (tester) async {
    // Given an active old source gesture and its captured actual widget callbacks.
    await load(tester);
    final old = <ImageRegionGeometry>[];
    final next = <ImageRegionGeometry>[];
    await tester.pumpWidget(view(h.controller.frame!, old.add));
    final surface = tester.widget<GestureDetector>(find.byKey(const ValueKey('image-region-draw-surface')));
    surface.onPanStart!(DragStartDetails(localPosition: const Offset(40, 80)));
    surface.onPanUpdate!(DragUpdateDetails(globalPosition: const Offset(200, 160),
      localPosition: const Offset(200, 160), delta: const Offset(160, 80)));
    final otherSource = await h.store.saveMaterial(bytes: h.controller.frame!.pngBytes,
      mediaType: 'image/png', capturedAt: ImageRegionFixture.time);
    final otherFrame = await tester.runAsync(() => h.facade.loadFrame(otherSource));
    // When the source owner is replaced, already-rendered old completion is invoked.
    await tester.pumpWidget(view(otherFrame!, next.add));
    surface.onPanEnd!(DragEndDetails());
    await tester.pump();
    // Then neither the old callback nor replacement owner receives that old source selection.
    expect(old, isEmpty);
    expect(next, isEmpty);
    expect(h.ocr.inputs, isEmpty);
  });

  testWidgets('S6 invalid actual stored source reports failure without fabricating a display frame', (tester) async {
    // Given invalid bytes saved behind a real public image reference.
    final invalid = await h.store.saveMaterial(bytes: Uint8List.fromList([1, 2, 3]),
      mediaType: 'image/png', capturedAt: ImageRegionFixture.time);
    final editor = h.newController(original: invalid);
    // When Core is explicitly asked to decode that source.
    await tester.runAsync(() async { await expectLater(editor.loadSource(), throwsFormatException); });
    // Then the actual error is retained and no fake frame can enter the selector.
    expect(editor.frame, isNull);
    expect(editor.error, isA<FormatException>());
    expect(editor.busy, isFalse);
    editor.dispose();
    expect(h.ocr.inputs, isEmpty);
  });

  testWidgets('S7 same-frame same-callback resize cancels an active draw and permits a fresh draw', (tester) async {
    // Given the same source/callback owner and a real pointer drag in progress.
    await load(tester);
    final results = <ImageRegionGeometry>[];
    void changed(ImageRegionGeometry value) { results.add(value); }
    final retained = ImageRegionFixture.geometry();
    await tester.pumpWidget(view(h.controller.frame!, changed, selection: retained));
    final origin = tester.getTopLeft(find.byKey(const ValueKey('image-region-draw-surface')));
    final gesture = await tester.startGesture(origin + const Offset(40, 80));
    await gesture.moveTo(origin + const Offset(200, 160));
    await tester.pump();
    // When contain geometry changes before that pointer completes.
    await tester.pumpWidget(view(h.controller.frame!, changed, width: 300, selection: retained));
    await gesture.moveTo(origin + const Offset(240, 200));
    await gesture.up();
    await tester.pump();
    // Then no mixed-layout selection is emitted and retained geometry stays intact.
    expect(results, isEmpty);
    expect(tester.widget<ImageRegionSelector>(find.byType(ImageRegionSelector)).selection, same(retained));
    await drag(tester, const Offset(30, 100), const Offset(150, 160));
    expect(results.length, 1);
    expect(results.single.x, closeTo(0.1, 0.001));
    expect(results.single.y, closeTo(0.1, 0.001));
    expect(results.single.width, closeTo(0.4, 0.001));
    expect(results.single.height, closeTo(0.4, 0.001));
  });

  testWidgets('S8 captured gesture callbacks after disposal emit nothing and do not set state', (tester) async {
    // Given captured drawing callbacks with an active source-space draft.
    await load(tester);
    final results = <ImageRegionGeometry>[];
    await tester.pumpWidget(view(h.controller.frame!, results.add));
    final surface = tester.widget<GestureDetector>(find.byKey(const ValueKey('image-region-draw-surface')));
    surface.onPanStart!(DragStartDetails(localPosition: const Offset(40, 80)));
    surface.onPanUpdate!(DragUpdateDetails(globalPosition: const Offset(200, 160),
      localPosition: const Offset(200, 160), delta: const Offset(160, 80)));
    // When the owner is disposed and all captured gesture callbacks run again.
    await tester.pumpWidget(const SizedBox.shrink());
    surface.onPanStart!(DragStartDetails(localPosition: const Offset(40, 80)));
    surface.onPanUpdate!(DragUpdateDetails(globalPosition: const Offset(200, 160),
      localPosition: const Offset(200, 160), delta: const Offset(160, 80)));
    surface.onPanEnd!(DragEndDetails());
    surface.onPanCancel!();
    await tester.pump();
    // Then no retired callback outputs geometry or raises a disposed-state error.
    expect(results, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
