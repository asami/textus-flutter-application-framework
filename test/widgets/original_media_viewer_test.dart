import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/src/widgets/original_media_viewer.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform previous;
  late _Player player;

  setUp(() {
    previous = VideoPlayerPlatform.instance;
    player = _Player();
    VideoPlayerPlatform.instance = player;
  });

  tearDown(() async {
    VideoPlayerPlatform.instance = previous;
    await player.events.close();
    final source = player.source;
    if (source != null) {
      final directory = File.fromUri(Uri.parse(source.uri!)).parent;
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  testWidgets(
    'portrait video reserves reachable controls in a bounded viewport at normal and large text sizes',
    (tester) async {
      // Given a controlled portrait decoder and a bounded phone-sized viewer.
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = CaptureMaterialReference(
        id: 'original',
        mediaType: 'video/quicktime',
        byteLength: 3,
        capturedAt: DateTime.utc(2026),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      Future<Uint8List> readOriginal(CaptureMaterialReference _) async => bytes;
      Widget screen(double scale) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: OriginalMediaViewer(
                    original: original,
                    readOriginal: readOriginal,
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Confirm')),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(screen(1));
        await player.ready.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      // When the visible play control is tapped in the bounded viewer.
      final viewer = find.byType(OriginalMediaViewer);
      final play = find.byTooltip('再生');
      expect(play.hitTestable(), findsOneWidget);
      expect(tester.getRect(viewer).contains(tester.getCenter(play)), isTrue);
      await tester.tap(play);
      await tester.pump();
      // Then one platform play is issued without a layout exception.
      expect(player.plays, 1);
      expect(tester.takeException(), isNull);

      // When the viewport is shortened and text is doubled.
      await tester.tap(find.byTooltip('一時停止'));
      await tester.pump();
      tester.view.physicalSize = const Size(390, 320);
      await tester.pumpWidget(screen(2));
      await tester.pump();
      // Then the controls remain within the viewer and are still usable.
      expect(find.byTooltip('再生').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(viewer).contains(tester.getCenter(find.byTooltip('再生'))),
        isTrue,
      );
      expect(
        tester.getRect(find.text('0 / 2 秒')).bottom,
        lessThanOrEqualTo(tester.getRect(viewer).bottom),
      );
      await tester.tap(find.byTooltip('再生'));
      await tester.pump();
      expect(player.plays, 2);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await player.waitForCleanup().timeout(const Duration(seconds: 5));
      });
    },
  );

  testWidgets(
    'portrait video shrink wraps in a vertical scroll view and its controls can be reached',
    (tester) async {
      // Given the same controlled portrait video in an unbounded scroll view.
      tester.view.physicalSize = const Size(390, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = CaptureMaterialReference(
        id: 'original',
        mediaType: 'video/quicktime',
        byteLength: 3,
        capturedAt: DateTime.utc(2026),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OriginalMediaViewer(
                  original: original,
                  readOriginal: (_) async => Uint8List.fromList([1, 2, 3]),
                ),
              ),
            ),
          ),
        );
        await player.ready.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      // When the user scrolls to the play control.
      await tester.ensureVisible(find.byTooltip('再生'));
      await tester.pumpAndSettle();
      // Then no flex constraint error occurs and playback can be requested.
      expect(find.byTooltip('再生').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('再生'));
      await tester.pump();
      expect(player.plays, 1);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await player.waitForCleanup().timeout(const Duration(seconds: 5));
      });
    },
  );
}

class _Player extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final ready = Completer<void>();
  DataSource? source;
  int plays = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 2),
        size: const Size(1080, 1920),
      ),
    );
    ready.complete();
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.blue);
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  Future<void> waitForCleanup() async {
    final directory = File.fromUri(Uri.parse(source!.uri!)).parent;
    while (await directory.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}
