import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII='));

void main() {
  group('PC1 PC6 generic role overview and bounded actual previews', () {
    testWidgets('role frames count attached originals and callbacks use exact supplied IDs', (tester) async {
      // Given arbitrary App role IDs and one actual PNG, with an attached unreadable source.
      final owner = Object();
      var reads = 0;
      final capture = <String>[];
      final retake = <String>[];
      final selected = <(String, bool)>[];
      final corrected = <(String, String)>[];
      final retried = <String>[];
      final image = PhotoRoleCaptureImage(materialId: 'original', sourceIdentity: owner,
        readBytes: () { reads++; return _png; }, selected: true,
        readStatusLabel: 'Loaded', recognitionStatusLabel: 'Not recognized');
      final unreadable = PhotoRoleCaptureImage(materialId: 'unreadable', sourceIdentity: owner,
        readBytes: () => null, selected: false, readStatusLabel: 'Read failed',
        recognitionStatusLabel: 'Reports available', errorDescription: 'source offline');
      final roles = [PhotoRoleCaptureItem(id: 'first', label: 'First', images: [image, unreadable]),
        PhotoRoleCaptureItem(id: 'second', label: 'Second', images: []),
        PhotoRoleCaptureItem(id: 'third', label: 'Third', images: []),
        PhotoRoleCaptureItem(id: 'fourth', label: 'Fourth', images: [])];
      Widget host() => _host(PhotoRoleCapturePanel(roles: roles,
        additionalRoles: [PhotoRoleCaptureItem(id: 'extra', label: 'Extra', images: [])],
        onCapture: capture.add, onRetake: retake.add,
        onSelectionChanged: (id, value) => selected.add((id, value)),
        onRoleChanged: (id, role) => corrected.add((id, role)), onRetryRead: retried.add));
      // When the overview builds and its real thumbnail decoder paints.
      await tester.pumpWidget(host());
      await _paint(tester, 'original');
      // Then all four supplied slots exist, and read failure still counts as attached.
      expect(find.text('撮影済み（2枚）'), findsOneWidget);
      expect(find.text('未撮影'), findsNWidgets(3));
      expect(find.byKey(const ValueKey('photo-role:extra')), findsNothing);
      final preview = tester.widget<CaptureImagePreview>(find.byType(CaptureImagePreview).first);
      expect(preview.maxDecodeDimension, 512);
      final resize = tester.widget<Image>(find.byKey(const ValueKey('photo-render:original:0'))).image as ResizeImage;
      expect(resize.width, 512); expect(resize.height, 512);
      expect(resize.allowUpscaling, isFalse);
      // When Add, Retake, Capture, Inspect, selection, correction and read retry are explicit gestures.
      await _tap(tester, 'photo-role-add:first');
      await _tap(tester, 'photo-role-retake:first');
      await _tap(tester, 'photo-role-capture:second');
      await _tap(tester, 'photo-role-inspect:first');
      await _tap(tester, 'photo-selected:original');
      await _tap(tester, 'photo-read-retry:unreadable');
      await _tap(tester, 'photo-correct-role:original');
      await tester.tap(find.text('Second').last); await tester.pumpAndSettle();
      // Then callbacks carry exact supplied identities while Inspect alone performed no domain action.
      expect(capture, ['first', 'second']); expect(retake, ['first']);
      expect(selected, [('original', false)]);
      expect(corrected, [('original', 'second')]); expect(retried, ['unreadable']);
      expect(find.text('読み込み: Read failed'), findsOneWidget);
      expect(find.text('認識: Reports available'), findsOneWidget);
      final readsBefore = reads;
      // When the owner rebuilds the same attached identity and opens Additional photos.
      await tester.pumpWidget(host()); await tester.pump();
      await _tap(tester, 'photo-role-additional');
      // Then the synchronous successful preview snapshot is retained and additional roles are reachable.
      expect(reads, readsBefore);
      expect(find.byKey(const ValueKey('photo-role:extra')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('explicit ready localized original paints thumbnail and inspection without domain commands', (tester) async {
      // Given localized display status and explicit cached readiness for an exact borrowed PNG original.
      final owner = Object();
      var domainCalls = 0;
      final image = PhotoRoleCaptureImage(materialId: 'localized-original', sourceIdentity: owner,
        readBytes: () => _png, selected: true, readStatusLabel: '読み込み済み',
        previewReady: true, recognitionStatusLabel: 'Not recognized');
      await tester.pumpWidget(_host(PhotoRoleCapturePanel(roles: [
        PhotoRoleCaptureItem(id: 'role', label: 'Role', images: [image])],
        onCapture: (_) => domainCalls++, onRetake: (_) => domainCalls++,
        onSelectionChanged: (_, _) => domainCalls++, onRoleChanged: (_, _) => domainCalls++,
        onRetryRead: (_) => domainCalls++)));
      // When the thumbnail decodes and Inspect opens a second independent actual preview.
      await _paint(tester, 'localized-original', within: find.byKey(const ValueKey('photo-thumbnail:localized-original')));
      await _tap(tester, 'photo-role-inspect:role');
      await _paint(tester, 'localized-original', within: find.byKey(const ValueKey('photo-inspected:localized-original')));
      // Then both RawImages paint the exact borrowed identity without any domain or read-retry callback.
      final previews = tester.widgetList<CaptureImagePreview>(find.byType(CaptureImagePreview)).toList();
      expect(previews, hasLength(2));
      for (final preview in previews) {
        expect(preview.materialId, 'localized-original');
        expect(preview.sourceIdentity, same(owner));
        expect(preview.readBytes, same(image.readBytes));
        expect(preview.maxDecodeDimension, 512);
      }
      expect(find.text('読み込み: 読み込み済み'), findsOneWidget);
      expect(domainCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('explicit unready Loaded original does not read while inspection and read retry remain available', (tester) async {
      // Given an attached original whose explicit cached readiness is false despite a legacy Loaded label.
      var reads = 0; var domainCalls = 0;
      final retried = <String>[];
      final image = PhotoRoleCaptureImage(materialId: 'unready-original', sourceIdentity: Object(),
        readBytes: () { reads++; return _png; }, selected: true,
        readStatusLabel: 'Loaded', previewReady: false, recognitionStatusLabel: 'Reports available');
      await tester.pumpWidget(_host(PhotoRoleCapturePanel(roles: [
        PhotoRoleCaptureItem(id: 'role', label: 'Role', images: [image])],
        onCapture: (_) => domainCalls++, onRetake: (_) => domainCalls++,
        onSelectionChanged: (_, _) => domainCalls++, onRoleChanged: (_, _) => domainCalls++,
        onRetryRead: retried.add)));
      // When overview builds and Inspect opens, then neither constructs a decoder or borrows bytes.
      expect(find.byType(CaptureImagePreview), findsNothing);
      expect(reads, 0);
      await _tap(tester, 'photo-role-inspect:role');
      expect(find.byType(CaptureImagePreview), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(reads, 0);
      // Then attachment, selection and supplied status stay truthful and explicit exact-original retry is reachable.
      expect(find.text('撮影済み（1枚）'), findsOneWidget);
      expect(find.text('認識に使用（1枚）'), findsOneWidget);
      expect(find.text('原画像: unready-original'), findsOneWidget);
      expect(find.text('Loaded'), findsNWidgets(2));
      expect(find.text('読み込み: Loaded'), findsOneWidget);
      expect(find.text('認識: Reports available'), findsOneWidget);
      // When only the explicit read retry is tapped, then it forwards identity without locally reading bytes.
      await _tap(tester, 'photo-read-retry:unready-original');
      expect(retried, ['unready-original']);
      expect(domainCalls, 0); expect(reads, 0);
      expect(find.byType(CaptureImagePreview), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('narrow large-text inspection keeps counts and all domain controls reachable', (tester) async {
      // Given a narrow phone with large text and multiple attached actual PNG originals.
      tester.view.physicalSize = const Size(320, 720); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final owner = Object();
      final images = [for (var i = 0; i < 3; i++) PhotoRoleCaptureImage(materialId: 'image-$i',
        sourceIdentity: owner, readBytes: () => _png, selected: true,
        readStatusLabel: 'Loaded', recognitionStatusLabel: 'Not recognized')];
      var selected = 0; var retries = 0;
      // When overview, Inspect and actual selection/retry gestures execute at that scale.
      await tester.pumpWidget(_host(PhotoRoleCapturePanel(roles: [
        PhotoRoleCaptureItem(id: 'long', label: 'A long readable role label', images: images),
        PhotoRoleCaptureItem(id: 'empty', label: 'Another long role label', images: []),
      ], onSelectionChanged: (_, _) => selected++, onRetryRead: (_) => retries++), scale: 2));
      await _tap(tester, 'photo-role-inspect:long');
      await _tap(tester, 'photo-selected:image-2');
      await _tap(tester, 'photo-read-retry:image-2');
      // Then labels/counts stay present, actions are reached, and layout/decoder raises no overflow.
      expect(find.text('撮影済み（3枚）'), findsOneWidget);
      expect(selected, 1); expect(retries, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('PC4 read-only references and local decode recovery', () {
    testWidgets('read-only disables domain mutations but retains inspection and exact read retry', (tester) async {
      // Given one unreadable attached original and read-only presentation with all callbacks supplied.
      var domainCalls = 0; var retries = 0;
      final image = PhotoRoleCaptureImage(materialId: 'original', sourceIdentity: Object(),
        readBytes: () => null, selected: false, readStatusLabel: 'Read failed', recognitionStatusLabel: 'Failure');
      await tester.pumpWidget(_host(PhotoRoleCapturePanel(roles: [
        PhotoRoleCaptureItem(id: 'role', label: 'Role', images: [image])], readOnly: true,
        onCapture: (_) => domainCalls++, onRetake: (_) => domainCalls++,
        onSelectionChanged: (_, _) => domainCalls++, onRoleChanged: (_, _) => domainCalls++,
        onRetryRead: (_) => retries++)));
      // When Inspect and explicit read retry are chosen.
      await _tap(tester, 'photo-role-inspect:role'); await _tap(tester, 'photo-read-retry:original');
      // Then every domain control is disabled and the attached source remains counted.
      for (final key in ['photo-role-add:role', 'photo-role-retake:role']) {
        expect(tester.widget<ElevatedButton>(find.byKey(ValueKey(key))).onPressed, isNull);
      }
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('photo-selected:original'))).onChanged, isNull);
      expect(tester.widget<DropdownButton<String>>(find.byKey(const ValueKey('photo-correct-role:original'))).onChanged, isNull);
      expect(find.text('撮影済み（1枚）'), findsOneWidget);
      expect(domainCalls, 0); expect(retries, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('real decode failure retries only the local preview and borrowed source', (tester) async {
      // Given actual invalid encoded bytes from a borrowed synchronous source.
      var bytes = Uint8List.fromList([1, 2, 3]);
      var reads = 0;
      final owner = Object();
      final image = PhotoRoleCaptureImage(materialId: 'original', sourceIdentity: owner,
        readBytes: () { reads++; return bytes; }, selected: true,
        readStatusLabel: 'Loaded', recognitionStatusLabel: 'Not recognized');
      await tester.pumpWidget(_host(PhotoRoleCapturePanel(roles: [
        PhotoRoleCaptureItem(id: 'role', label: 'Role', images: [image])], readOnly: true)));
      await tester.pumpAndSettle();
      // When the real decoder reports failure, then the fixture source recovers and local Retry is chosen.
      expect(find.text('写真を表示できませんでした'), findsOneWidget);
      bytes = _png;
      final retry = find.text('表示を再試行');
      await tester.ensureVisible(retry); await tester.tap(retry); await tester.pumpAndSettle();
      await _paint(tester, 'original', retry: 1);
      // Then just that preview reads again and paints a genuine decoded image, with no global cache mutation.
      expect(reads, 2); expect(find.text('写真を表示できませんでした'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('role images are snapshots and duplicate public role IDs reject', () {
      // Given mutable caller lists and ambiguous supplied role IDs.
      final source = <PhotoRoleCaptureImage>[];
      final item = PhotoRoleCaptureItem(id: 'same', label: 'Role', images: source);
      // When the caller changes a source list or constructs duplicate choices.
      source.add(PhotoRoleCaptureImage(materialId: 'original', sourceIdentity: Object(),
        readBytes: () => null, selected: true, readStatusLabel: 'Not loaded', recognitionStatusLabel: 'Not recognized'));
      // Then snapshots remain immutable and public choices reject ambiguity.
      expect(item.images, isEmpty);
      expect(() => item.images.clear(), throwsUnsupportedError);
      expect(() => PhotoRoleCapturePanel(roles: [item], additionalRoles: [item]), throwsArgumentError);
    });
  });
}

Widget _host(Widget panel, {double scale = 1}) => MaterialApp(home: Scaffold(body: Builder(
  builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: SingleChildScrollView(child: panel)))));
Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control); await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
  await tester.tap(control); await tester.pumpAndSettle();
}
Future<void> _paint(WidgetTester tester, String id, {int retry = 0, Finder? within}) async {
  final render = find.byKey(ValueKey('photo-render:$id:$retry'));
  final finder = find.descendant(of: within == null ? render : find.descendant(of: within, matching: render),
    matching: find.byType(RawImage));
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump();
    if (finder.evaluate().isNotEmpty && tester.renderObject<RenderImage>(finder.first).image != null) return;
  }
  throw StateError('Actual thumbnail decoder did not paint');
}
