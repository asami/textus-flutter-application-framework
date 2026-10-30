import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Public-API fixture: real PNG decoding/cropping/reporting, controlled providers.
/// These in-memory observations do not qualify native interruption or storage.
final class ImageRegionFixture {
  final store = RegionFixtureStore();
  final ocr = RegionFixtureRecognitionProvider();
  final ai = RegionFixtureRecognitionProvider(enhanced: true);
  final audio = RegionFixtureAudioProvider();
  late final CaptureMaterialReference source;
  late final ImageRegionFacade facade;
  late final AudioCaptureFacade audioFacade;
  late ImageRegionEditorController controller;
  int _ids = 0;

  /// One UTC instant keeps provider, geometry and audio provenance comparable.
  static final time = DateTime.utc(2026, 10, 28, 12);

  /// Builds valid source bytes without reading a frame or probing providers.
  Future<void> open() async {
    final raster = img.Image(width: 200, height: 100, numChannels: 4);
    for (var y = 0; y < raster.height; y++) {
      for (var x = 0; x < raster.width; x++) {
        raster.setPixelRgba(x, y, x < 100 ? 240 : 20, y < 50 ? 30 : 200, 60, 255);
      }
    }
    source = await store.saveMaterial(bytes: Uint8List.fromList(img.encodePng(raster)),
      mediaType: 'image/png', capturedAt: time.subtract(const Duration(minutes: 1)));
    facade = ImageRegionFacade(service: ImageRegionService(store: store,
      clock: () => time, recognition: ImageRecognitionService(
        clock: () => time, registry: RecognitionProviderRegistry(providers: [ocr, ai]))));
    audioFacade = AudioCaptureFacade(service: AudioCaptureService(
      runtime: audio, transcription: audio, store: store, now: () => time));
    controller = newController();
  }

  /// Reopens using the same actual services/store and immutable caller histories.
  ImageRegionEditorController newController({ImageRegionWorkspace? workspace,
    Map<String, AudioTranscriptReview> reviews = const {}, CaptureMaterialReference? original}) =>
      ImageRegionEditorController(facade: facade, source: original ?? source,
        audioFacade: audioFacade, initialWorkspace: workspace, initialAudioReviews: reviews,
        now: () => time, idGenerator: () => 'editor${_ids++}');

  /// Explicit convenient source load and confirmed positive rectangle.
  Future<void> confirm() async {
    await controller.loadSource();
    controller.setSelection(geometry());
    controller.confirmSelection();
  }

  /// Normalized source geometry, distinct from any viewport dimensions.
  static ImageRegionGeometry geometry({double x = 0.1, double y = 0.1,
    double width = 0.4, double height = 0.6,
    ImageRegionShape shape = ImageRegionShape.rectangle}) => ImageRegionGeometry(
      shape: shape, x: x, y: y, width: width, height: height);

  /// Releases controlled gates and only this fixture's interaction resources.
  Future<void> close() async {
    for (final gate in [store.readGate, store.audioSaveGate, ocr.gate, ai.gate,
      audio.transcriptGate, audio.playGate, audio.cancelGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await controller.detach().timeout(const Duration(seconds: 5));
    controller.dispose();
  }
}

/// Snapshotted in-memory store with observable read/save failure and gates.
final class RegionFixtureStore implements LocalCaptureStore {
  final materials = <String, Uint8List>{};
  final documents = <String, Map<String, Object?>>{};
  int reads = 0;
  int saves = 0;
  int documentWrites = 0;
  Completer<void>? readGate;
  Completer<void>? audioSaveGate;
  Completer<void> readEntered = Completer<void>();
  Completer<void> audioSaveEntered = Completer<void>();
  Object? readError;
  Object? audioSaveError;
  bool wrongReadLength = false;

  @override
  Future<CaptureMaterialReference> saveMaterial({required Uint8List bytes,
    required String mediaType, required DateTime capturedAt, String? originalName}) async {
    final snapshot = Uint8List.fromList(bytes);
    if (mediaType.startsWith('audio/')) {
      if (!audioSaveEntered.isCompleted) audioSaveEntered.complete();
      if (audioSaveGate != null) await audioSaveGate!.future;
      if (audioSaveError != null) throw audioSaveError!;
    }
    final id = 'material${saves++}';
    materials[id] = snapshot;
    return CaptureMaterialReference(id: id, mediaType: mediaType,
      byteLength: snapshot.length, capturedAt: capturedAt, originalName: originalName);
  }
  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) async {
    reads++;
    if (!readEntered.isCompleted) readEntered.complete();
    if (readGate != null) await readGate!.future;
    if (readError != null) throw readError!;
    final bytes = materials[reference.id];
    if (bytes == null) throw StateError('Missing original ${reference.id}');
    return wrongReadLength ? Uint8List(1) : Uint8List.fromList(bytes);
  }
  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) async {
    documentWrites++;
    documents['$collection/$id'] = _detach(document);
  }
  @override
  Future<Map<String, Object?>?> readDocument(String collection, String id) async {
    final value = documents['$collection/$id'];
    return value == null ? null : _detach(value);
  }
  @override
  Future<List<String>> listDocumentIds(String collection) async => documents.keys
    .where((k) => k.startsWith('$collection/')).map((k) => k.substring(collection.length + 1)).toList()..sort();
  Map<String, Object?> _detach(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);
}

/// Deterministic local OCR/AI, including unavailable, downloadable and held work.
final class RegionFixtureRecognitionProvider implements ImageRecognitionProvider {
  RegionFixtureRecognitionProvider({this.enhanced = false});
  final bool enhanced;
  bool unavailable = false;
  bool downloadable = false;
  int probes = 0;
  int preparations = 0;
  final inputs = <ImageRecognitionInput>[];
  Completer<void>? gate;
  final entered = Completer<void>();
  Object? failure;
  String text = ' exact OCR 日本語\n ';

  @override
  RecognitionProviderDescriptor get descriptor => RecognitionProviderDescriptor(
    id: enhanced ? RecognitionConfigurations.enhancedProviderId : RecognitionConfigurations.standardProviderId,
    label: 'Controlled local fixture', capabilities: enhanced
      ? {RecognitionCapability.imageInterpretation, RecognitionCapability.candidateOrganization}
      : {RecognitionCapability.ocr, RecognitionCapability.barcodes});
  @override
  Future<RecognitionProviderAvailability> availability() async {
    probes++;
    return RecognitionProviderAvailability(providerId: descriptor.id,
      capabilities: descriptor.capabilities, state: unavailable
        ? RecognitionProviderState.unavailable : downloadable
          ? RecognitionProviderState.downloadable : RecognitionProviderState.available,
      reason: unavailable ? 'Fixture local provider unavailable' : null);
  }
  @override
  Future<void> prepare() async { preparations++; downloadable = false; }
  @override
  Future<ImageRecognitionResult> recognize(ImageRecognitionInput input) async {
    inputs.add(input);
    if (!entered.isCompleted) entered.complete();
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    return enhanced ? ImageRecognitionResult(interpretation: 'AI interpretation',
      candidateOrganizationCompleted: true,
      candidates: [RecognitionCandidate(kind: 'suggestion', value: 'AI candidate')])
      : ImageRecognitionResult(text: text, barcodeCompleted: true);
  }
}

/// Existing common AudioCaptureService is exercised through its public ports.
final class RegionFixtureAudioProvider implements AudioRuntimeProvider, AudioTranscriptionProvider {
  int starts = 0;
  int stops = 0;
  int probes = 0;
  int preparations = 0;
  int transcriptions = 0;
  int plays = 0;
  int disposals = 0;
  Completer<void>? transcriptGate;
  Completer<void>? playGate;
  final playEntered = Completer<void>();
  final transcriptEntered = Completer<void>();
  Completer<void>? cancelGate;
  void Function()? onCancelRecording;
  int cancellations = 0;
  @override
  String get id => 'regionAudio';
  @override
  bool get isSupported => true;
  @override
  Future<void> startRecording(AudioRecordingConfiguration configuration) async { starts++; }
  @override
  Future<CapturedAudio> stopRecording() async {
    stops++;
    return CapturedAudio(bytes: PcmWaveAudio.encode(Uint8List(3200)),
      capturedAt: ImageRegionFixture.time);
  }
  @override
  Future<void> cancelRecording() async {
    cancellations++;
    onCancelRecording?.call();
    if (cancelGate != null) await cancelGate!.future;
  }
  @override
  Future<void> play(Uint8List bytes) async {
    plays++;
    if (!playEntered.isCompleted) playEntered.complete();
    if (playGate != null) await playGate!.future;
  }
  @override
  Future<void> stopPlayback() async {
    if (playGate != null && !playGate!.isCompleted) playGate!.complete();
  }
  @override
  Future<AudioProviderAvailability> availability(String locale) async {
    probes++;
    return AudioProviderAvailability(providerId: id, locale: locale, state: AudioProviderState.available);
  }
  @override
  Future<AudioProviderAvailability> prepare(String locale) async {
    preparations++;
    return availability(locale);
  }
  @override
  Future<AudioProviderTranscript> transcribe(AudioTranscriptionInput input) async {
    transcriptions++;
    if (!transcriptEntered.isCompleted) transcriptEntered.complete();
    if (transcriptGate != null) await transcriptGate!.future;
    return AudioProviderTranscript(text: ' exact spoken 日本語 ');
  }
  @override
  Future<void> cancel() async {
    if (transcriptGate != null && !transcriptGate!.isCompleted) transcriptGate!.complete();
  }
  @override
  Future<void> dispose() async { disposals++; }
}
