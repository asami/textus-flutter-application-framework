import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  testWidgets('PV1 successful snapshot and painted provider survive fresh callbacks', (tester) async {
    // Given a real PNG, fixed owner/material and a loader returning fresh copies.
    final bytes = await _png(tester, 32, 16);
    final expected = bytes.toList();
    final owner = Object();
    var reads = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return CaptureImagePreview(
        key: const ValueKey('preview'),
        materialId: 'original', sourceIdentity: owner,
        imageKey: const ValueKey('painted-original'),
        semanticLabel: 'Validated original',
        readBytes: () { reads++; return Uint8List.fromList(bytes); },
      );
    })));
    await _painted(tester);
    final provider = _provider(tester);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final frame = _render(tester).image;
    // When ordinary parent layout/text updates create fresh loader closures.
    for (var index = 0; index < 4; index++) {
      rebuild(() {});
      await tester.pump();
      // Then successful acquisition, provider/cache key and actual painted frame stay stable.
      expect(reads, 1);
      expect(_provider(tester), same(provider));
      expect(await _provider(tester).obtainKey(ImageConfiguration.empty), key);
      expect(_render(tester).image, same(frame));
      expect(_snapshot(provider), orderedEquals(expected));
      expect(bytes, orderedEquals(expected));
      expect(find.byKey(const ValueKey('painted-original')), findsOneWidget);
      expect(_image(tester).semanticLabel, 'Validated original');
      expect(_image(tester).fit, BoxFit.contain);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV2 actual large PNG decoder fits both axes at default 2048', (tester) async {
    // Given a real large landscape original with exact encoded bytes.
    final bytes = await _png(tester, 3072, 1536);
    final expected = bytes.toList();
    // When Flutter resolves and paints its actual bounded decoder.
    await tester.pumpWidget(_host(CaptureImagePreview(
      materialId: 'large', sourceIdentity: Object(), readBytes: () => bytes,
    )));
    await _painted(tester);
    // Then the actual decoded frame respects both limits and the original aspect.
    final decoded = _render(tester).image!;
    expect(decoded.width, 2048);
    expect(decoded.height, 1024);
    expect(decoded.width / decoded.height, 2);
    expect(_snapshot(_provider(tester)), orderedEquals(expected));
    expect(bytes, orderedEquals(expected));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV3 small portrait actual decoder never upscales', (tester) async {
    // Given a small portrait PNG whose intrinsic dimensions are below the bound.
    final bytes = await _png(tester, 16, 32);
    // When the common preview actually decodes and paints it.
    await tester.pumpWidget(_host(CaptureImagePreview(
      materialId: 'portrait', sourceIdentity: Object(), readBytes: () => bytes,
    )));
    await _painted(tester);
    // Then painted intrinsic dimensions and aspect remain those of the original.
    expect(_render(tester).image!.width, 16);
    expect(_render(tester).image!.height, 32);
    expect(_render(tester).image!.width / _render(tester).image!.height, 0.5);
    expect(_snapshot(_provider(tester)), orderedEquals(bytes));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV4 material then borrowed owner replacement evicts exact old keys', (tester) async {
    // Given a mounted successful preview, three distinct originals and fixed outer State.
    final originals = [await _png(tester, 30, 15), await _png(tester, 20, 10),
      await _png(tester, 10, 20)];
    var owner = Object();
    var materialId = 'first';
    var index = 0;
    var reads = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return CaptureImagePreview(
        key: const ValueKey('retained-preview'),
        materialId: materialId, sourceIdentity: owner,
        readBytes: () { reads++; return originals[index]; },
      );
    })));
    await _painted(tester);
    var previous = _provider(tester);
    var oldKey = await previous.obtainKey(ImageConfiguration.empty);
    expect(PaintingBinding.instance.imageCache.containsKey(oldKey), isTrue);
    // When material identity changes under the same owner, then owner changes under that ID.
    for (var replacement = 1; replacement <= 2; replacement++) {
      rebuild(() {
        index = replacement;
        if (replacement == 1) { materialId = 'second'; } else { owner = Object(); }
      });
      await tester.pump();
      await _painted(tester, expectedWidth: replacement == 1 ? 20 : 10);
      // Then only the new original is painted, each identity is read once and its old key is evicted.
      final current = _provider(tester);
      expect(current, isNot(same(previous)));
      expect(reads, replacement + 1);
      expect(_snapshot(current), orderedEquals(originals[replacement]));
      expect(PaintingBinding.instance.imageCache.containsKey(oldKey), isFalse);
      previous = current;
      oldKey = await current.obtainKey(ImageConfiguration.empty);
      expect(PaintingBinding.instance.imageCache.containsKey(oldKey), isTrue);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV5 null loader retries on widget update then retains available snapshot', (tester) async {
    // Given a validated-byte port that has not yet supplied its real PNG.
    final bytes = await _png(tester, 24, 12);
    final owner = Object();
    Uint8List? available;
    var reads = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return CaptureImagePreview(materialId: 'waiting', sourceIdentity: owner,
        readBytes: () { reads++; return available; });
    })));
    expect(reads, 1);
    expect(find.byType(Image), findsNothing);
    // When actual parent update makes already validated bytes available.
    rebuild(() => available = bytes);
    await tester.pump();
    await _painted(tester);
    final provider = _provider(tester);
    rebuild(() {});
    await tester.pump();
    // Then the eventual frame is painted and ordinary updates perform no further reads.
    expect(reads, 2);
    expect(_provider(tester), same(provider));
    expect(_render(tester).image!.width, 24);
    expect(_snapshot(provider), orderedEquals(bytes));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV6 disposal evicts owned key while unrelated cache and borrowed owner survive', (tester) async {
    // Given one successful preview and an independently cached real original.
    final bytes = await _png(tester, 28, 14);
    final unrelated = MemoryImage(await _png(tester, 18, 9));
    final owner = _BorrowedOwner();
    await tester.pumpWidget(_host(CaptureImagePreview(
      materialId: 'owned', sourceIdentity: owner, readBytes: () => bytes,
    )));
    await _painted(tester);
    final cache = PaintingBinding.instance.imageCache;
    final ownedKey = await _provider(tester).obtainKey(ImageConfiguration.empty);
    await tester.runAsync(() => precacheImage(unrelated,
      tester.element(find.byType(CaptureImagePreview))));
    await tester.pump();
    final unrelatedKey = await unrelated.obtainKey(ImageConfiguration.empty);
    expect(cache.containsKey(ownedKey), isTrue);
    expect(cache.containsKey(unrelatedKey), isTrue);
    // When the preview's owning widget disappears through normal disposal.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Then only its private resize key is evicted, with no borrowed disposal or late UI error.
    expect(cache.containsKey(ownedKey), isFalse);
    expect(cache.containsKey(unrelatedKey), isTrue);
    expect(owner.disposed, isFalse);
    expect(tester.takeException(), isNull);
    await unrelated.evict();
  });

  testWidgets('PV7 actual decode failure stays visible without reacquiring on rebuild', (tester) async {
    // Given invalid encoded bytes and the caller's visible decode-error builder.
    final owner = Object();
    var reads = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return CaptureImagePreview(materialId: 'invalid', sourceIdentity: owner,
        readBytes: () { reads++; return Uint8List.fromList([1, 2, 3]); },
        errorBuilder: (_, _, _) => const Text('Actual original decode failed'));
    })));
    // When the real Flutter decoder reports failure and the parent rebuilds.
    await _until(tester, () => find.text('Actual original decode failed').evaluate().isNotEmpty);
    final provider = _provider(tester);
    rebuild(() {});
    await tester.pump();
    // Then the caller's error remains visible with stable identity and no fabricated successful frame.
    expect(find.text('Actual original decode failed'), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
    expect(_provider(tester), same(provider));
    expect(reads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PV8 caller mutation and bound change retain read-only detached encoded snapshot', (tester) async {
    // Given a mounted privately detached PNG snapshot and cached owned key.
    final bytes = await _png(tester, 40, 20);
    final expected = bytes.toList();
    final owner = Object();
    var bound = 2048;
    var reads = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return CaptureImagePreview(materialId: 'immutable', sourceIdentity: owner,
        maxDecodeDimension: bound,
        readBytes: () { reads++; return bytes; });
    })));
    await _painted(tester);
    final previous = _provider(tester);
    final snapshot = _snapshot(previous);
    final oldKey = await previous.obtainKey(ImageConfiguration.empty);
    expect(() => snapshot[0] = 0, throwsUnsupportedError);
    // When the caller mutates its buffer and only the presentation bound changes.
    bytes[0] = 0;
    rebuild(() => bound = 10);
    await tester.pump();
    await _painted(tester, expectedWidth: 10);
    // Then the same original snapshot supplies a new bounded real frame without another read.
    final current = _provider(tester);
    expect(reads, 1);
    expect(current, isNot(same(previous)));
    expect(_snapshot(current), same(snapshot));
    expect(snapshot, orderedEquals(expected));
    expect(current.width, 10);
    expect(current.height, 10);
    expect(current.policy, ResizeImagePolicy.fit);
    expect(current.allowUpscaling, isFalse);
    expect(_render(tester).image!.height, 5);
    expect(PaintingBinding.instance.imageCache.containsKey(oldKey), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

Image _image(WidgetTester tester) => tester.widget<Image>(find.byType(Image));
ResizeImage _provider(WidgetTester tester) => _image(tester).image as ResizeImage;
Uint8List _snapshot(ResizeImage provider) => (provider.imageProvider as MemoryImage).bytes;
RenderImage _render(WidgetTester tester) => tester.renderObject<RenderImage>(find.byType(RawImage));

Future<void> _painted(WidgetTester tester, {int? expectedWidth}) => _until(tester, () {
  final images = find.byType(RawImage);
  if (images.evaluate().isEmpty) return false;
  final image = _render(tester).image;
  return image != null && (expectedWidth == null || image.width == expectedWidth);
});

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 200; frame++) {
    await tester.pump();
    if (ready()) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  throw StateError('Actual decoded preview state was not observed within the frame budget');
}

Future<Uint8List> _png(WidgetTester tester, int width, int height) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xff225588));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return Uint8List.fromList(encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes));
    } finally {
      image.dispose();
      picture.dispose();
    }
  }))!;
}

class _BorrowedOwner {
  bool disposed = false;
  void dispose() { disposed = true; }
}
