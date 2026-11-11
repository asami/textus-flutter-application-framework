import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'capture_storage_facade.dart';

enum MediaAttachmentAcquisition {
  capturePhoto,
  importPhoto,
  captureVideo,
  importVideo,
}

/// One attachment-input lifetime; a durable original is returned before adoption.
final class MediaAttachmentInputSession {
  MediaAttachmentInputSession({
    required this.storage,
    required this.images,
    required this.videos,
    required this.audio,
    this.recoveryTarget,
    this.recoveryLabel,
  }) {
    if ((recoveryTarget == null) != (recoveryLabel == null)) {
      throw ArgumentError(
        'Recovery target and label must be supplied together',
      );
    }
    _videoRecovery = storage.createVideoRecovery(provider: videos);
  }
  factory MediaAttachmentInputSession.platform(
    CaptureStorageFacade storage, {
    VideoRecoveryTarget? recoveryTarget,
    String? recoveryLabel,
  }) => MediaAttachmentInputSession(
    storage: storage,
    images: MediaInputService(
      provider: createPlatformMediaInputProvider(),
      ownsProvider: true,
    ),
    videos: ImagePickerVideoProvider(),
    audio: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? IosAudioProvider()
        : AndroidAudioProvider(),
    recoveryTarget: recoveryTarget,
    recoveryLabel: recoveryLabel,
  );
  final CaptureStorageFacade storage;
  final MediaInputService images;
  final VideoInputProvider videos;
  final AudioRuntimeProvider audio;
  final VideoRecoveryTarget? recoveryTarget;
  final String? recoveryLabel;
  late final VideoCaptureRecovery _videoRecovery;
  Future<PendingVideoCapture?> pendingVideo() => _videoRecovery.pending();
  bool canRecoverVideo(PendingVideoCapture value) =>
      value.target == recoveryTarget && _videoRecovery.canRecover(value);
  Future<CaptureMaterialReference?> recoverVideo(String id) =>
      _operate(() async {
        final target = recoveryTarget;
        if (target == null) throw StateError('No explicit recovery target');
        return _videoRecovery.recover(id: id, target: target);
      });
  Future<void> discardVideo(String id) => _operate(() async {
    final target = recoveryTarget;
    if (target == null) throw StateError('No explicit recovery target');
    await _videoRecovery.discard(id: id, target: target);
  });
  bool _closed = false, _busy = false, _recording = false;
  Future<void>? _closing;
  Completer<void>? _settled;
  bool get recording => _recording;
  bool get canRecordAudio => audio.isSupported;
  bool canAcquire(MediaAttachmentAcquisition action) => switch (action) {
    MediaAttachmentAcquisition.capturePhoto =>
      images.capability(MediaInputAction.cameraCapture).canAttempt,
    MediaAttachmentAcquisition.importPhoto =>
      images.capability(MediaInputAction.imageImport).canAttempt,
    MediaAttachmentAcquisition.captureVideo => videos.canCapture,
    MediaAttachmentAcquisition.importVideo => videos.canImport,
  };

  Future<CaptureMaterialReference?> acquire(
    MediaAttachmentAcquisition action,
  ) => _operate(() async {
    if (_recording) throw StateError('Stop audio recording first');
    if ((action == MediaAttachmentAcquisition.captureVideo ||
            action == MediaAttachmentAcquisition.importVideo) &&
        recoveryTarget != null) {
      return _videoRecovery.acquire(
        target: recoveryTarget!,
        label: recoveryLabel!,
        fromGallery: action == MediaAttachmentAcquisition.importVideo,
      );
    }
    if (await pendingVideo() != null) {
      throw StateError('中断した動画を復元するか、復元を取り消してください。');
    }
    _alive();
    final Uint8List bytes;
    final String type;
    final String? name;
    final DateTime time;
    if (action == MediaAttachmentAcquisition.capturePhoto ||
        action == MediaAttachmentAcquisition.importPhoto) {
      final photo = action == MediaAttachmentAcquisition.capturePhoto
          ? await images.captureImage()
          : await images.importImage();
      if (photo == null) return null;
      bytes = photo.bytes;
      type = photo.mediaType;
      name = photo.originalName;
      time = photo.capturedAt;
    } else {
      final video = action == MediaAttachmentAcquisition.captureVideo
          ? await videos.capture()
          : await videos.importVideo();
      if (video == null) return null;
      bytes = video.bytes;
      type = video.mediaType;
      name = video.originalName;
      time = video.capturedAt;
    }
    _alive();
    return storage.importMaterial(
      bytes: bytes,
      mediaType: type,
      capturedAt: time,
      originalName: name,
    );
  });
  Future<void> startAudio() => _operate(() async {
    if (_recording) throw StateError('Recording already active');
    await audio.startRecording(AudioRecordingConfiguration());
    _alive();
    _recording = true;
  });
  Future<CaptureMaterialReference> stopAudio() => _operate(() async {
    if (!_recording) throw StateError('No active recording');
    try {
      final original = await audio.stopRecording();
      _alive();
      PcmWaveAudio.parse(original.bytes);
      return await storage.importMaterial(
        bytes: original.bytes,
        mediaType: 'audio/wav',
        capturedAt: original.capturedAt,
        originalName: original.originalName,
      );
    } finally {
      _recording = false;
    }
  });
  Future<T> _operate<T>(Future<T> Function() operation) async {
    _alive();
    if (_busy) throw StateError('Attachment input busy');
    _busy = true;
    final settled = Completer<void>();
    _settled = settled;
    try {
      final result = await operation();
      _alive();
      return result;
    } finally {
      _busy = false;
      settled.complete();
    }
  }

  void _alive() {
    if (_closed) throw StateError('Attachment input closed');
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _videoRecovery.retire();
    return _closing = Future.wait<void>([
      Future.sync(images.close),
      Future.sync(videos.close),
      Future.sync(audio.dispose),
      if (_settled case final settled?) settled.future,
    ]).then((_) {});
  }
}
