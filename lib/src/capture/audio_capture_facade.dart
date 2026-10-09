import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Exact public Core forwarding with explicit service ownership.
final class AudioCaptureFacade {
  /// Borrows [service] unless its composition owner opts into disposal.
  factory AudioCaptureFacade({
    required AudioCaptureService service,
    bool ownsService = false,
  }) => AudioCaptureFacade._(service, ownsService);

  AudioCaptureFacade._(this._service, this.ownsService);

  final AudioCaptureService _service;

  /// Whether explicit facade disposal releases its service.
  final bool ownsService;

  /// Shared Core state, including operations belonging to other callers.
  AudioCaptureState get state => _service.state;

  /// Runtime support without native work.
  bool get isSupported => _service.isSupported;

  /// Exact immutable original awaiting durable import retry.
  CapturedAudio? get pendingOriginal => _service.pendingOriginal;

  /// Checks exact-locale readiness without preparing a model.
  Future<AudioProviderAvailability> availability({String locale = 'ja-JP'}) =>
      _service.availability(locale: locale);

  /// Explicitly prepares the exact locale.
  Future<AudioProviderAvailability> prepareTranscription({
    String locale = 'ja-JP',
  }) => _service.prepareTranscription(locale: locale);

  /// Explicitly starts capture with the caller's duration configuration.
  Future<void> startRecording({AudioRecordingConfiguration? configuration}) =>
      _service.startRecording(configuration: configuration);

  /// Returns an original only after Core's durable import.
  Future<OriginalAudio> stopRecording() => _service.stopRecording();

  /// Cancels unsaved capture.
  Future<void> cancelRecording() => _service.cancelRecording();

  /// Retries retained exact bytes without capture.
  Future<OriginalAudio> retryPendingOriginal() =>
      _service.retryPendingOriginal();

  /// Plays unchanged saved original bytes.
  Future<void> playOriginal(OriginalAudio original) =>
      _service.playOriginal(original);

  /// Stops the current Core playback.
  Future<void> stopPlayback() => _service.stopPlayback();

  /// Recognizes saved input, retaining Core's exact result and diagnostics.
  Future<AudioTranscriptReport> transcribe(
    OriginalAudio original, {
    String locale = 'ja-JP',
  }) => _service.transcribe(original, locale: locale);

  /// Nonterminally cancels current Core readiness/preparation/recognition.
  Future<void> cancelTranscription() => _service.cancelTranscription();

  /// Releases only explicitly owned service resources; caller storage is borrowed.
  Future<void> dispose() =>
      ownsService ? _service.dispose() : Future<void>.value();
}

/// Opens an inert owned default Core service using the exact supplied store.
Future<AudioCaptureFacade> openDefaultAudioCaptureFacade({
  LocalCaptureStore? store,
}) async => AudioCaptureFacade(
  service: await openDefaultAudioCaptureService(store: store),
  ownsService: true,
);
