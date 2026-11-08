import 'dart:async';
import 'dart:typed_data';

import 'package:textus_flutter_core/textus_flutter_core.dart';

// Controlled providers exercise field/Display integration; never native quality.
class VoiceInputFixture {
  int sessions = 0, generations = 0, audioDisposals = 0, cleanupDisposals = 0;
  bool cleanupAvailable = true, failure = false;
  Completer<VoiceTextCleanupResult>? gate;
  Completer<AudioProviderTranscript>? speechGate;
  Completer<void>? closeGate;
  VoiceTextInputSession session() {
    sessions++;
    final audio = _Audio(this);
    return VoiceTextInputSession(
      runtime: audio,
      speech: audio,
      cleanup: _Cleanup(this),
    );
  }
}

class _Audio
    implements AudioRuntimeProvider, TransientAudioTranscriptionProvider {
  _Audio(this.owner);
  final VoiceInputFixture owner;
  @override
  String get id => 'controlled-speech';
  @override
  bool get isSupported => true;
  @override
  Future<void> startRecording(
    AudioRecordingConfiguration configuration,
  ) async {}
  @override
  Future<CapturedAudio> stopRecording() async =>
      CapturedAudio(bytes: Uint8List(2), capturedAt: DateTime.utc(2026));
  @override
  Future<AudioProviderTranscript> transcribeCaptured(
    Uint8List bytes, {
    String locale = 'ja-JP',
  }) async => owner.speechGate != null
      ? await owner.speechGate!.future
      : AudioProviderTranscript(text: 'ええと第7巻です。あと8巻も。');
  @override
  Future<AudioProviderAvailability> availability(String locale) async =>
      AudioProviderAvailability(
        providerId: id,
        locale: locale,
        state: AudioProviderState.available,
      );
  @override
  Future<AudioProviderAvailability> prepare(String locale) =>
      availability(locale);
  @override
  Future<void> dispose() async {
    owner.audioDisposals++;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> cancelRecording() async {}
  @override
  Future<void> play(Uint8List bytes) async {}
  @override
  Future<void> stopPlayback() async {}
  @override
  Future<AudioProviderTranscript> transcribe(AudioTranscriptionInput input) =>
      throw UnimplementedError();
}

class _Cleanup implements VoiceTextCleanupProvider {
  _Cleanup(this.owner);
  final VoiceInputFixture owner;
  @override
  Future<VoiceTextCleanupAvailability> availability() async =>
      VoiceTextCleanupAvailability(
        state: owner.cleanupAvailable
            ? VoiceTextCleanupState.available
            : VoiceTextCleanupState.unavailable,
        providerId: 'controlled',
        modelName: owner.cleanupAvailable ? 'controlled' : null,
        reason: owner.cleanupAvailable ? null : 'controlled unavailable',
      );
  @override
  Future<void> prepare() async {}
  @override
  Future<VoiceTextCleanupResult> cleanup(String text) async {
    owner.generations++;
    if (owner.failure) throw StateError('controlled native failure');
    if (owner.gate != null) return owner.gate!.future;
    return VoiceTextCleanupResult(
      source: text,
      text: '第7巻です。あと8巻も。',
      providerId: 'controlled',
      modelName: 'controlled',
    );
  }

  @override
  Future<void> dispose() async {
    owner.cleanupDisposals++;
    await owner.closeGate?.future;
  }
}
