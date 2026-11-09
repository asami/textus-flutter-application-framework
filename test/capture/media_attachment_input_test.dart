import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../support/image_region_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ready in [false, true]) {
    for (final kind in ['image', 'audio', 'video']) {
      testWidgets(
        '$kind input respects type policy with ${ready ? "ready" : "interrupted"} video recovery',
        (tester) async {
          // Given the same note's durable video intent, either ready or still awaiting native recovery.
          final storage = CaptureStorageFacade(store: RegionFixtureStore());
          final target = VideoRecoveryTarget(
            ownerId: 'book-1',
            elementId: 'note-1',
          );
          final old = storage.createVideoRecovery(
            provider: _RecoveryVideo()..interrupted = !ready,
          );
          if (ready) {
            await old.acquire(target: target, label: '注釈1');
          } else {
            await expectLater(
              old.acquire(target: target, label: '注釈1'),
              throwsStateError,
            );
          }
          old.retire();
          final initial = (await storage.pendingVideoCapture())!;
          final provider = _RecoveryVideo();
          final session = MediaAttachmentInputSession(
            storage: storage,
            images: MediaInputService(provider: _Images(), ownsProvider: true),
            videos: provider,
            audio: _Audio(),
            recoveryTarget: target,
            recoveryLabel: '注釈1',
          );
          CaptureMaterialReference? result;
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showDialog<CaptureMaterialReference>(
                          context: context,
                          builder: (_) => MediaAttachmentInputDialog(
                            session: session,
                            allowedAcquisitions: switch (kind) {
                              'image' => {
                                MediaAttachmentAcquisition.capturePhoto,
                                MediaAttachmentAcquisition.importPhoto,
                              },
                              'video' => {
                                MediaAttachmentAcquisition.captureVideo,
                                MediaAttachmentAcquisition.importVideo,
                              },
                              _ => {},
                            },
                            allowAudio: kind == 'audio',
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
            // When the user opens a type-specific dialog for that original annotation.
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            if (kind == 'video') {
              await tester.tap(find.text('中断した動画を復元'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('この注釈に追加'));
              await tester.pumpAndSettle();
              // Then video input returns the exact original without a second capture.
              expect(result!.mediaType, 'video/mp4');
              expect(await storage.readMaterial(result!), _videoBytes());
              expect(provider.recoveries, ready ? 0 : 1);
              expect(provider.captures, 0);
            } else {
              // Then image/audio input explains the pending video without offering to adopt it.
              expect(find.text('中断した動画を復元'), findsNothing);
              expect(find.text('動画の復元は「動画を追加」から確認してください。'), findsOneWidget);
              expect(
                tester
                    .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'この注釈に追加'),
                    )
                    .onPressed,
                isNull,
              );
              expect(provider.recoveries, 0);
              expect(
                (await storage.pendingVideoCapture())!.toJson(),
                initial.toJson(),
              );
              await tester.tap(find.text('キャンセル'));
              await tester.pumpAndSettle();
              expect(result, isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await session.close();
          }
        },
      );
    }
  }
  for (final foreign in [false, true]) {
    testWidgets(
      'recovery dialog ${foreign ? "rejects another target" : "explicitly restores without another capture"}',
      (tester) async {
        // Given a durable interrupted video and a fresh dialog, without a domain save.
        final store = RegionFixtureStore();
        final storage = CaptureStorageFacade(store: store);
        final target = VideoRecoveryTarget(
          ownerId: 'book-1',
          elementId: 'note-1',
        );
        final interrupted = _RecoveryVideo()..interrupted = true;
        final old = storage.createVideoRecovery(provider: interrupted);
        await expectLater(
          old.acquire(target: target, label: '第7巻 / 注釈1'),
          throwsStateError,
        );
        final originalIntent = (await storage.pendingVideoCapture())!;
        final provider = _RecoveryVideo();
        final session = MediaAttachmentInputSession(
          storage: storage,
          images: MediaInputService(provider: _Images(), ownsProvider: true),
          videos: provider,
          audio: _Audio(),
          recoveryTarget: foreign
              ? VideoRecoveryTarget(ownerId: 'book-2', elementId: 'note-2')
              : target,
          recoveryLabel: '表示中の注釈',
        );
        CaptureMaterialReference? result;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<CaptureMaterialReference>(
                        context: context,
                        builder: (_) =>
                            MediaAttachmentInputDialog(session: session),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          // When a fresh dialog opens for the selected target.
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          // Then any pending video prevents ordinary acquisition until resolved.
          final camera = tester.widget<TextButton>(
            find.widgetWithText(TextButton, '写真を撮る'),
          );
          expect(camera.onPressed, isNull);
          if (foreign) {
            // Then a foreign target cannot consume recovery or alter the original intent.
            expect(find.text('中断した動画を復元'), findsNothing);
            expect(find.textContaining('別の注釈には追加しません'), findsOneWidget);
            await tester.tap(find.text('キャンセル'));
            await tester.pumpAndSettle();
            expect(provider.recoveries, 0);
            expect(
              (await storage.pendingVideoCapture())!.id,
              originalIntent.id,
            );
            expect(result, isNull);
          } else {
            // When the owner explicitly restores and then chooses Add.
            await tester.tap(find.text('中断した動画を復元'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('この注釈に追加'));
            await tester.pumpAndSettle();
            // Then unchanged bytes return to the caller; intent still awaits a domain Save.
            expect(provider.recoveries, 1);
            expect(provider.captures, 0);
            expect(await storage.readMaterial(result!), _videoBytes());
            expect(
              (await storage.pendingVideoCapture())!.state,
              VideoRecoveryState.ready,
            );
          }
          expect(
            await store.listDocumentIds('annotation_candidates_v1'),
            isEmpty,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await session.close();
        }
      },
    );
  }

  testWidgets(
    'unsupported unreturned video recovery stays explicit and does not consume the SDK',
    (tester) async {
      // Given the same durable intent on a provider without lost-data support.
      final storage = CaptureStorageFacade(store: RegionFixtureStore());
      final target = VideoRecoveryTarget(
        ownerId: 'book-1',
        elementId: 'note-1',
      );
      final interrupted = _RecoveryVideo()..interrupted = true;
      await expectLater(
        storage
            .createVideoRecovery(provider: interrupted)
            .acquire(target: target, label: '注釈1'),
        throwsStateError,
      );
      final provider = _RecoveryVideo()..recoverySupported = false;
      final session = MediaAttachmentInputSession(
        storage: storage,
        images: MediaInputService(provider: _Images(), ownsProvider: true),
        videos: provider,
        audio: _Audio(),
        recoveryTarget: target,
        recoveryLabel: '注釈1',
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        MediaAttachmentInputDialog(session: session),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        // When the user opens the dialog with unavailable lost-result capability.
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        // Then recovery is disabled explicitly without consuming the SDK result.
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, '中断した動画を復元'),
        );
        expect(button.onPressed, isNull);
        expect(find.textContaining('自動復元できません'), findsOneWidget);
        expect(provider.recoveries, 0);
        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await session.close();
      }
    },
  );

  group('Durable attachment originals', () {
    late Directory directory;
    late FileCaptureStore store;
    late _Images images;
    late _Audio audio;
    late MediaAttachmentInputSession session;
    setUp(() async {
      // Given a controlled image/audio source and the actual Core filesystem store.
      directory = await Directory.systemTemp.createTemp('attachment-spec-');
      store = FileCaptureStore(directory.path);
      images = _Images();
      audio = _Audio();
      session = MediaAttachmentInputSession(
        storage: CaptureStorageFacade(store: store),
        images: MediaInputService(provider: images, ownsProvider: true),
        videos: _Video(),
        audio: audio,
      );
    });
    tearDown(() async {
      await session.close();
      await directory.delete(recursive: true);
    });

    test('acquisition returns an unchanged durable original, without creating a domain document', () async {
      // When the user explicitly acquires an attachment.
      final original = (await session.acquire(
        MediaAttachmentAcquisition.capturePhoto,
      ))!;
      // Then its original bytes are durable before the reference is returned.
      expect(await store.readMaterial(original), [1, 2, 3]);
      expect(original.mediaType, 'image/jpeg');
      expect(await store.listDocumentIds('annotation_candidates_v1'), isEmpty);
    });

    test(
      'closing pending capture fences it before any original is imported',
      () async {
        // Given an OS picker that has not returned.
        images.gate = Completer<CapturedPhoto?>();
        final pending = session.acquire(
          MediaAttachmentAcquisition.capturePhoto,
        );
        final rejected = expectLater(pending, throwsA(anything));
        // When the caller retires before the image arrives.
        final closing = session.close();
        images.gate!.complete(images.photo);
        await rejected;
        await closing;
        // Then the obsolete completion cannot save or attach a new original.
        expect(
          await Directory('${directory.path}/materials').exists(),
          isFalse,
        );
        expect(audio.disposals, 1);
      },
    );

    test('retained audio is an explicit recording and stop, separate from dictation', () async {
      // Given a fresh attachment session, with no speech/cleanup provider at all.
      await session.startAudio();
      expect(session.recording, isTrue);
      expect(await Directory('${directory.path}/materials').exists(), isFalse);
      // When the user explicitly stops to retain the original.
      final original = await session.stopAudio();
      // Then WAV is saved unchanged and no text or domain document is fabricated.
      expect(original.mediaType, 'audio/wav');
      expect(await store.readMaterial(original), audio.wave);
      expect(session.recording, isFalse);
      expect(await store.listDocumentIds('annotation_candidates_v1'), isEmpty);
    });
  });
  testWidgets(
    'covered attachment actions cannot dismiss another route or start acquisition',
    (tester) async {
      final images = _Images();
      final audio = _Audio();
      final session = MediaAttachmentInputSession(
        storage: CaptureStorageFacade(store: _NoStore()),
        images: MediaInputService(provider: images, ownsProvider: true),
        videos: _Video(),
        audio: audio,
      );
      try {
        // Given a live attachment dialog and its formerly current action callbacks.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<CaptureMaterialReference>(
                    context: context,
                    builder: (_) =>
                        MediaAttachmentInputDialog(session: session),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final cancel = tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'キャンセル'))
            .onPressed!;
        final capture = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '写真を撮る'))
            .onPressed!;
        final navigator = Navigator.of(
          tester.element(find.byType(MediaAttachmentInputDialog)),
        );
        // When another route covers the dialog and stale actions are invoked.
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('foreign')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        cancel();
        capture();
        await tester.pumpAndSettle();
        // Then the foreign route stays visible and neither capture nor disposal starts.
        expect(find.text('foreign'), findsOneWidget);
        expect(images.captures, 0);
        expect(audio.disposals, 0);
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();
        expect(audio.disposals, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await session.close();
      }
    },
  );
}

class _Images implements MediaInputProvider {
  int captures = 0;
  Completer<CapturedPhoto?>? gate;
  CapturedPhoto get photo => CapturedPhoto(
    bytes: Uint8List.fromList([1, 2, 3]),
    mediaType: 'image/jpeg',
    capturedAt: DateTime.utc(2026),
  );
  @override
  Map<MediaInputAction, MediaInputCapability> get capabilities => {
    for (final action in [
      MediaInputAction.cameraCapture,
      MediaInputAction.imageImport,
    ])
      action: const MediaInputCapability(
        support: MediaAdapterSupport.supported,
        device: MediaDeviceAvailability.available,
        permission: MediaPermissionState.allowed,
      ),
  };
  @override
  Future<Map<MediaInputAction, MediaInputCapability>> inspect() async =>
      capabilities;
  @override
  Future<CapturedPhoto?> captureImage() async {
    captures++;
    return gate != null ? gate!.future : photo;
  }

  @override
  Future<CapturedPhoto?> importImage() => captureImage();
  @override
  Future<void> close() async {}
}

class _Video implements VideoInputProvider {
  @override
  bool get canRecoverLostVideo => false;
  @override
  bool get canCapture => false;
  @override
  bool get canImport => false;
  @override
  Future<CapturedVideo?> capture() async =>
      throw UnsupportedError('controlled');
  @override
  Future<CapturedVideo?> importVideo() => capture();
  @override
  Future<CapturedVideo?> recoverLostVideo() async => null;
  @override
  Future<void> close() async {}
}

Uint8List _videoBytes() => Uint8List.fromList([
  0,
  0,
  0,
  20,
  ...'ftypmp42'.codeUnits,
  0,
  0,
  0,
  0,
  ...'mp42'.codeUnits,
]);

// Container-only source, not a playable-codec assertion.
class _RecoveryVideo extends _Video {
  bool interrupted = false, recoverySupported = true;
  int captures = 0, recoveries = 0;
  @override
  bool get canCapture => true;
  @override
  bool get canImport => true;
  @override
  bool get canRecoverLostVideo => recoverySupported;
  @override
  Future<CapturedVideo?> capture() async {
    captures++;
    if (interrupted) throw StateError('controlled OS interruption');
    return CapturedVideo(bytes: _videoBytes(), capturedAt: DateTime.utc(2026));
  }

  @override
  Future<CapturedVideo?> recoverLostVideo() async {
    recoveries++;
    return CapturedVideo(bytes: _videoBytes(), capturedAt: DateTime.utc(2026));
  }
}

class _Audio implements AudioRuntimeProvider {
  final wave = PcmWaveAudio.encode(Uint8List(32));
  int disposals = 0;
  @override
  bool get isSupported => true;
  @override
  Future<void> startRecording(
    AudioRecordingConfiguration configuration,
  ) async {}
  @override
  Future<CapturedAudio> stopRecording() async =>
      CapturedAudio(bytes: wave, capturedAt: DateTime.utc(2026));
  @override
  Future<void> cancelRecording() async {}
  @override
  Future<void> play(Uint8List bytes) async {}
  @override
  Future<void> stopPlayback() async {}
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

// Any storage call here is a failure; this case tests navigation only.
class _NoStore implements LocalCaptureStore {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected storage IO in navigation test');
}
