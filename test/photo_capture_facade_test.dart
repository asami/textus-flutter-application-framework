import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Store store;
  late _Camera camera;
  late _Provider standard;
  late _Provider enhanced;
  late PhotoCaptureService service;
  late PhotoCaptureFacade facade;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-facade-spec-');
    store = _Store(FileCaptureStore(directory.path));
    camera = _Camera();
    standard = _Provider();
    enhanced = _Provider(enhanced: true);
    service = _service(camera, standard, enhanced, store);
    facade = PhotoCaptureFacade(service: service);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await directory.delete(recursive: true);
  });

  group('generic operation context forwarding', () {
    test('OC5 all four commands forward distinct intent into exact durable raw reports', () async {
      // Given borrowed real Core runtime/store/providers and an independently saved original.
      final original = (await facade.captureOriginal())!;
      final reports = <RecognitionComparison>[];
      final contexts = <RecognitionOperationContext>[];
      // When each public recognition method receives a distinct operation context.
      for (final command in ['capture', 'recover', 'recognize', 'compare']) {
        final context = RecognitionOperationContext(sourceRole: ' exact $command role ',
          targetKinds: ['unknown kind'], instructions: ' exact $command request ',
          extensions: {'future': [null, true, command]});
        contexts.add(context);
        final RecognitionComparison? report = switch (command) {
          'capture' => await facade.capture(desiredConfigurationId: 'pixelEnhanced', operationContext: context),
          'recover' => await facade.recover(desiredConfigurationId: 'pixelEnhanced', operationContext: context),
          'recognize' => await facade.recognize(original, desiredConfigurationId: 'pixelEnhanced', operationContext: context),
          _ => await facade.compare(original, operationContext: context),
        };
        final accepted = report!; reports.add(accepted);
        final fresh = PhotoCaptureFacade(service: _service(camera, standard, enhanced, FileCaptureStore(directory.path)));
        final loaded = (await fresh.findComparison(accepted.id))!;
        // Then borrowed authority carries exact context, raw kinds/duplicates, provenance and durable identity.
        expect(standard.inputs.last.operationContext, same(context));
        expect(enhanced.inputs.last.operationContext, same(context));
        expect(standard.inputs.last.material, same(accepted.material));
        expect(enhanced.inputs.last.bytes, [1, 2, 3]);
        expect(accepted.operationContext, context); expect(loaded.operationContext, context);
        expect(RecognitionReportCodec.encode(loaded), RecognitionReportCodec.encode(accepted));
        expect(loaded.runs.last.attempts.last.result.candidates.map((candidate) => candidate.kind),
          ['unknown kind', 'unknown kind', 'isbn']);
        expect(loaded.runs.last.attempts.last.result.candidates.map((candidate) => candidate.value),
          [' opaque proposal ', ' opaque proposal ', 'not validated']);
        expect(loaded.extensions['providerProvenance'], isNotNull);
        expect(await FileCaptureStore(directory.path).readMaterial(loaded.material), [1, 2, 3]);
      }
      // Given the four completed contextual operations on one borrowed facade.
      // When the next saved-original caller omits context.
      final legacy = await facade.recognize(original, desiredConfigurationId: 'pixelEnhanced');
      final old = (await facade.findComparison(legacy.id))!;
      // Then no facade state, extra probes/preparation, filtering or reimports affect future intent.
      expect(reports.map((report) => report.operationContext), contexts);
      expect(legacy.operationContext, isNull); expect(old.operationContext, isNull);
      expect(old.extensions.containsKey(RecognitionOperationContext.extensionKey), isFalse);
      expect(standard.inputs.last.operationContext, isNull); expect(enhanced.inputs.last.operationContext, isNull);
      expect(standard.probes, 5); expect(enhanced.probes, 5);
      expect(standard.prepares + enhanced.prepares, 0);
      expect(camera.captures, 2); expect(camera.recoveries, 1); expect(store.imports, 3); expect(store.writes, 5);
      expect(reports[2].material, same(original)); expect(reports[3].material, same(original));
    });

    test('OC5 contextual cancelled capture and empty recovery preserve absence without sticky intent', () async {
      // Given a borrowed camera returning cancellation and one-shot empty recovery.
      camera.photo = null; camera.oneShotRecovery = true;
      final context = RecognitionOperationContext(sourceRole: 'cancelled',
        targetKinds: ['opaque'], instructions: 'requested');
      // When both facade contextual acquisitions cancel.
      final captured = await facade.capture(desiredConfigurationId: 'androidStandard', operationContext: context);
      final recovered = await facade.recover(desiredConfigurationId: 'androidStandard', operationContext: context);
      // Then no context report, source import, probe or preparation is fabricated.
      expect(captured, isNull); expect(recovered, isNull);
      expect(store.imports, 0); expect(store.writes, 0);
      expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
      expect(standard.probes + enhanced.probes, 0); expect(standard.prepares + enhanced.prepares, 0);
      expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
      // Given a new photo on the same facade after cancellation.
      camera.photo = _photo();
      // When the next capture omits context.
      final next = (await facade.capture(desiredConfigurationId: 'androidStandard'))!;
      // Then Core receives legacy absence and returns only its durable report.
      expect(next.operationContext, isNull); expect(standard.inputs.single.operationContext, isNull);
      expect((await facade.findComparison(next.id))!.operationContext, isNull);
    });

    for (final command in ['capture', 'recover', 'recognize', 'compare']) {
      test('OC5 contextual $command forwards the actual write failure and recovers without intent state', () async {
        // Given a real saved original, opaque request and this exact borrowed report-write failure.
        final original = (await facade.captureOriginal())!;
        final context = RecognitionOperationContext(sourceRole: command,
          targetKinds: ['opaque'], instructions: 'requested');
        final failure = FileSystemException('actual $command report failure'); store.writeError = failure;
        // When this contextual forwarding method reaches Core's durability boundary.
        final Future<RecognitionComparison?> pending = switch (command) {
          'capture' => facade.capture(desiredConfigurationId: 'androidStandard', operationContext: context),
          'recover' => facade.recover(desiredConfigurationId: 'androidStandard', operationContext: context),
          'recognize' => facade.recognize(original, desiredConfigurationId: 'androidStandard', operationContext: context),
          _ => facade.compare(original, operationContext: context),
        };
        await expectLater(pending, throwsA(same(failure)));
        // Then failed durability is not converted into a report and exact provider intent remains visible.
        expect(standard.inputs.single.operationContext, same(context));
        expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
        expect(await store.delegate.readMaterial(original), [1, 2, 3]);
        // Given the actual write failure has been cleared.
        store.writeError = null;
        // When the next saved-original operation omits context.
        final next = await facade.recognize(original, desiredConfigurationId: 'androidStandard');
        // Then Core guard recovery and exact legacy absence survive durable reopening.
        expect(standard.inputs.last.operationContext, isNull); expect(next.operationContext, isNull);
        expect((await facade.findComparison(next.id))!.operationContext, isNull);
        expect(standard.prepares + enhanced.prepares, 0);
      });
    }
  });

  group('original-only facade forwarding', () {
    test('R1 exact saved read forwards once without camera support or model readiness', () async {
      // Given an original-only saved reference and unsupported/unavailable borrowed dependencies.
      final material = (await facade.captureOriginal())!;
      camera.supported = false;
      standard.state = RecognitionProviderState.unavailable;
      enhanced.state = RecognitionProviderState.unavailable;
      // When the facade reads that reference through the exact borrowed Core runtime.
      final bytes = await facade.readOriginal(material);
      // Then store/reference/result forwarding performs one actual read and no implicit work.
      expect(store.lastReadReference, same(material)); expect(store.reads, 1); expect(bytes, [1, 2, 3]);
      expect(material, same(store.saved.single)); expect(material.mediaType, 'image/jpeg');
      expect(material.originalName, 'original.jpg'); expect(material.capturedAt, _time);
      expect(material.byteLength, 3); expect(camera.captures, 1); expect(camera.recoveries, 0);
      expect(store.imports, 1); expect(store.writes, 0);
      expect(standard.probes + enhanced.probes, 0); expect(standard.prepares + enhanced.prepares, 0);
      expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
      // Given mutated caller bytes and a fresh facade/service on the same saved root.
      bytes[0] = 99;
      final fresh = PhotoCaptureFacade(service: _service(camera, standard, enhanced, FileCaptureStore(directory.path)));
      // When each facade rereads the saved original.
      final repeated = await facade.readOriginal(material);
      final reopened = await fresh.readOriginal(material);
      // Then caller mutation cannot change persisted originals or generate reports/readiness effects.
      expect(repeated, [1, 2, 3]); expect(reopened, [1, 2, 3]); expect(store.reads, 2);
      expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
      expect(camera.captures, 1); expect(camera.recoveries, 0); expect(store.imports, 1);
      expect(standard.probes + enhanced.probes, 0); expect(standard.prepares + enhanced.prepares, 0);
    });

    for (final fails in [false, true]) {
      test('R2 held facade read ${fails ? "forwards exact failure" : "returns unchanged bytes"} and shares Core exclusion', () async {
        // Given a durable original and an observed finite material-read gate, separate from document errors.
        final material = (await facade.captureOriginal())!;
        final actual = FileSystemException('actual borrowed original read failure');
        store.materialReadGate = Completer<void>();
        if (fails) store.materialReadError = actual;
        // When facade forwarding enters the actual borrowed store read.
        final first = facade.readOriginal(material);
        final terminal = fails ? expectLater(first, throwsA(same(actual))) : null;
        await store.materialReadStarted.future;
        final competitors = <Future<Object?> Function()>[
          facade.captureOriginal, facade.recoverOriginal, service.captureOriginal, service.recoverOriginal,
          () => facade.capture(desiredConfigurationId: 'androidStandard'),
          () => service.capture(desiredConfigurationId: 'androidStandard'),
          () => facade.recover(desiredConfigurationId: 'androidStandard'),
          () => service.recover(desiredConfigurationId: 'androidStandard'),
          () => facade.recognize(material, desiredConfigurationId: 'androidStandard'),
          () => service.recognize(material, desiredConfigurationId: 'androidStandard'),
          () => facade.compare(material), () => service.compare(material),
          facade.availability, service.availability,
          () => facade.prepareProvider('mlkitStandard'), () => service.prepareProvider('mlkitStandard'),
          () => facade.readOriginal(material), () => service.readOriginal(material),
        ];
        for (final competitor in competitors) {
          // Given this exact facade or direct Core competitor while the same material read is held.
          // When it requests the borrowed runtime.
          // Then shared Core ownership rejects before any competing side effect.
          await expectLater(competitor(), throwsStateError);
          expect(camera.captures, 1); expect(camera.recoveries, 0);
          expect(store.imports, 1); expect(store.reads, 1); expect(store.writes, 0);
          expect(standard.probes + enhanced.probes, 0); expect(standard.prepares + enhanced.prepares, 0);
          expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
        }
        // Given only the admitted read gate is released.
        store.materialReadGate!.complete();
        // When that exact read future reaches its terminal result.
        if (fails) { await terminal!; } else { expect(await first, [1, 2, 3]); }
        // Then reference ownership, saved bytes and empty raw history remain unchanged.
        expect(store.lastReadReference, same(material));
        expect(await store.delegate.readMaterial(material), [1, 2, 3]);
        expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
        // Given explicit restoration of only the material-read error.
        store.materialReadError = null;
        // When the same borrowed Core runtime is explicitly read again.
        final next = await service.readOriginal(material);
        // Then Core finally released ownership after success or exact failure.
        expect(next, [1, 2, 3]); expect(store.reads, 2); expect(store.readError, isNull);
        expect(store.imports, 1); expect(store.writes, 0);
      });
    }

    test('A1 A2 forwards actual durable originals without settings or reimport', () async {
      // Given one borrowed Core service/store and independently supplied recovery bytes.
      camera.recoveredPhoto = CapturedPhoto(bytes: Uint8List.fromList([7, 8, 9]),
        mediaType: 'image/png', capturedAt: _time.toLocal(), originalName: 'recovered.png');
      camera.oneShotRecovery = true;
      // When capture and one-shot recovery complete through the facade alone.
      final captured = (await facade.captureOriginal())!;
      final recovered = (await facade.recoverOriginal())!;
      final emptyRecovery = await facade.recoverOriginal();
      camera.photo = null;
      final cancelled = await facade.captureOriginal();
      final reopened = FileCaptureStore(directory.path);
      // Then exact Core references are returned once and original metadata/bytes survive reopening.
      expect(captured, same(store.saved.first)); expect(recovered, same(store.saved.last));
      expect(captured.originalName, 'original.jpg'); expect(captured.mediaType, 'image/jpeg');
      expect(recovered.originalName, 'recovered.png'); expect(recovered.mediaType, 'image/png');
      expect(captured.capturedAt, _time); expect(recovered.capturedAt, _time);
      expect(captured.capturedAt.isUtc, isTrue); expect(recovered.capturedAt.isUtc, isTrue);
      expect(await reopened.readMaterial(captured), [1, 2, 3]);
      expect(await reopened.readMaterial(recovered), [7, 8, 9]);
      expect(emptyRecovery, isNull); expect(cancelled, isNull);
      expect(camera.captures, 2); expect(camera.recoveries, 2);
      expect(store.imports, 2); expect(store.reads, 0); expect(store.writes, 0);
      expect(standard.probes, 0); expect(enhanced.probes, 0);
      expect(standard.prepares, 0); expect(enhanced.prepares, 0);
      expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
      expect(await reopened.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
    });

    for (final action in ['capture', 'recover']) {
      for (final boundary in ['permission', 'camera', 'import', 'unsupported']) {
        test('A3 forwards $action $boundary error and next original action succeeds', () async {
          // Given a retained durable image and the actual selected failure object.
          final retained = (await facade.captureOriginal())!;
          final actual = boundary == 'permission'
            ? PlatformException(code: 'camera_access_denied', message: 'actual permission failure')
            : FileSystemException('actual $boundary failure');
          camera.recoveredPhoto = _photo();
          if (boundary == 'unsupported') { camera.supported = false; }
          else if (boundary == 'import') { store.importError = actual; }
          else { camera.error = actual; }
          // When the facade delegates one failing original-only action.
          final failed = action == 'capture' ? facade.captureOriginal() : facade.recoverOriginal();
          await expectLater(failed, boundary == 'unsupported' ? throwsUnsupportedError : throwsA(same(actual)));
          // Then the exact failure is exposed without retry, fabricated storage or recognition.
          expect(store.saved, [retained]); expect(store.writes, 0); expect(store.reads, 0);
          expect(store.imports, boundary == 'import' ? 2 : 1);
          expect(camera.captures, action == 'capture' && boundary != 'unsupported' ? 2 : 1);
          expect(camera.recoveries, action == 'recover' && boundary != 'unsupported' ? 1 : 0);
          expect(standard.probes, 0); expect(enhanced.probes, 0);
          expect(standard.prepares, 0); expect(enhanced.prepares, 0);
          expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
          expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), isEmpty);
          // Given the injected failing boundary is released for explicit caller reuse.
          camera.error = null; camera.supported = true;
          camera.recoveredPhoto = _photo(); store.importError = null;
          // When the same facade operation is requested again.
          final next = action == 'capture' ? await facade.captureOriginal() : await facade.recoverOriginal();
          // Then Core's shared guard permits it and retained original ownership survives.
          expect(next, isNotNull); expect(await store.delegate.readMaterial(retained), [1, 2, 3]);
        });
      }
    }

    for (final action in ['capture', 'recover']) {
      for (final boundary in ['camera', 'import']) {
        test('A4 facade held original $action $boundary shares Core exclusion', () async {
          // Given one finite acquisition/import gate in the borrowed Core operation.
          final cameraGate = Completer<CapturedPhoto?>();
          final importGate = Completer<void>();
          camera.recoveredPhoto = _photo();
          if (boundary == 'camera') {
            if (action == 'capture') { camera.gate = cameraGate; }
            else { camera.recoveryGate = cameraGate; }
          } else { store.importGate = importGate; }
          // When the original-only facade action owns Core through durability.
          final first = action == 'capture' ? facade.captureOriginal() : facade.recoverOriginal();
          await (boundary == 'import' ? store.importStarted.future
            : action == 'capture' ? camera.captureStarted.future : camera.recoveryStarted.future);
          final overlaps = <Future<Object?> Function()>[
            facade.captureOriginal, facade.recoverOriginal, service.captureOriginal, service.recoverOriginal,
            () => facade.capture(desiredConfigurationId: 'androidStandard'),
            () => facade.recover(desiredConfigurationId: 'androidStandard'),
            () => facade.recognize(_material(), desiredConfigurationId: 'androidStandard'),
            () => facade.compare(_material()), facade.availability,
            () => facade.prepareProvider('mlkitStandard'),
            () => facade.readOriginal(_material()), () => service.readOriginal(_material()),
          ];
          for (final overlap in overlaps) {
            // Given a facade or direct Core competitor for the same borrowed service.
            // When its public operation is requested while the admitted action is held.
            // Then shared Core ownership rejects it before any second work starts.
            await expectLater(overlap(), throwsStateError);
          }
          // Given the admitted finite gate now releases.
          if (boundary == 'camera') { cameraGate.complete(_photo()); }
          else { importGate.complete(); }
          // When the admitted original becomes durable.
          final material = (await first)!;
          // Then forwarding returned that exact reference with one import and no implicit providers.
          expect(material, same(store.saved.single)); expect(store.imports, 1);
          expect(camera.captures, action == 'capture' ? 1 : 0);
          expect(camera.recoveries, action == 'recover' ? 1 : 0);
          expect(store.reads, 0); expect(store.writes, 0);
          expect(standard.probes, 0); expect(enhanced.probes, 0);
          expect(standard.prepares, 0); expect(enhanced.prepares, 0);
          expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
        });
      }
    }

    for (final held in ['capture', 'recover', 'recognize', 'compare', 'availability', 'prepare']) {
      test('A4 direct Core $held ownership rejects facade originals and then releases', () async {
        // Given an actual saved original and a finite gate in this existing Core operation.
        final material = await store.delegate.saveMaterial(bytes: Uint8List.fromList([1, 2, 3]),
          mediaType: 'image/jpeg', capturedAt: _time);
        final gate = Completer<void>();
        Future<void> started;
        Future<Object?> first;
        if (held == 'availability') {
          standard.probeGate = gate; started = standard.probeStarted.future;
          first = service.availability();
        } else if (held == 'prepare') {
          standard.state = RecognitionProviderState.downloadable;
          standard.prepareGate = gate; started = standard.prepareStarted.future;
          first = service.prepareProvider('mlkitStandard');
        } else {
          standard.recognitionGate = gate; started = standard.recognitionStarted.future;
          first = switch (held) {
            'capture' => service.capture(desiredConfigurationId: 'androidStandard'),
            'recover' => service.recover(desiredConfigurationId: 'androidStandard'),
            'recognize' => service.recognize(material, desiredConfigurationId: 'androidStandard'),
            _ => service.compare(material),
          };
        }
        // When both facade original-only methods compete with the pending Core action.
        await started;
        final importsBefore = store.imports;
        final capturesBefore = camera.captures;
        final recoveriesBefore = camera.recoveries;
        await expectLater(facade.captureOriginal(), throwsStateError);
        await expectLater(facade.recoverOriginal(), throwsStateError);
        final readsBefore = store.reads;
        // Given this observed existing Core operation still owns the shared runtime.
        // When facade and direct Core original reads compete with it.
        // Then neither starts another store read.
        await expectLater(facade.readOriginal(material), throwsStateError);
        await expectLater(service.readOriginal(material), throwsStateError);
        expect(store.reads, readsBefore);
        // Then the facade shares Core's guard and made no new acquisition/import.
        expect(store.imports, importsBefore);
        expect(camera.captures, capturesBefore); expect(camera.recoveries, recoveriesBefore);
        // Given completion releases the existing Core operation.
        gate.complete(); await first;
        // When an explicit facade capture is subsequently requested.
        final next = await facade.captureOriginal();
        // Then no separate facade guard prevents the durable original from returning.
        expect(next, isNotNull); expect(store.imports, importsBefore + 1);
      });
    }

    for (final action in ['capture', 'recover']) {
      test('A4 facade pending $action cancellation releases shared Core ownership', () async {
        // Given a pending borrowed camera action through the facade.
        final gate = Completer<CapturedPhoto?>();
        if (action == 'capture') { camera.gate = gate; }
        else { camera.recoveryGate = gate; }
        // When the admitted acquisition explicitly cancels.
        final first = action == 'capture' ? facade.captureOriginal() : facade.recoverOriginal();
        await (action == 'capture' ? camera.captureStarted.future : camera.recoveryStarted.future);
        gate.complete(null);
        final cancelled = await first;
        // Then no import, recognition or report occurred.
        expect(cancelled, isNull); expect(store.imports, 0); expect(store.reads, 0); expect(store.writes, 0);
        expect(standard.probes, 0); expect(enhanced.probes, 0);
        expect(standard.inputs, isEmpty); expect(enhanced.inputs, isEmpty);
        // Given the camera now admits the next explicit operation.
        camera.gate = null; camera.recoveryGate = null;
        // When direct Core original acquisition follows the canceled facade action.
        final next = await service.captureOriginal();
        // Then the shared guard was released and a single actual original was saved.
        expect(next, isNotNull); expect(store.imports, 1);
      });
    }

    test('A5 explicitly recognizes and compares original-only reference without reacquisition', () async {
      // Given an original acquired without settings and an unavailable enhancement provider.
      enhanced.state = RecognitionProviderState.unavailable;
      final material = (await facade.captureOriginal())!;
      // When the caller later chooses recognition and comparison explicitly.
      final recognized = await facade.recognize(material, desiredConfigurationId: 'pixelEnhanced');
      final compared = await facade.compare(material);
      final fresh = PhotoCaptureFacade(service: _service(_Camera(), _Provider(),
        _Provider(enhanced: true), FileCaptureStore(directory.path)));
      // Then Core raw history, original and desired/actual/fallback lineage are forwarded durably.
      expect(recognized.material, same(material)); expect(compared.material, same(material));
      expect(camera.captures, 1); expect(camera.recoveries, 0); expect(store.imports, 1);
      expect(recognized.runs.single.desiredConfigurationId, 'pixelEnhanced');
      expect(recognized.runs.single.actualConfigurationId, 'androidStandard');
      expect(recognized.runs.single.fallbackReason, contains('not supported here'));
      expect(compared.runs.map((run) => run.desiredConfigurationId), ['androidStandard', 'pixelEnhanced']);
      expect(compared.runs.last.actualConfigurationId, 'androidStandard');
      expect(compared.runs.last.fallbackReason, contains('not supported here'));
      expect(compared.runs.first.attempts.single, same(compared.runs.last.attempts.first));
      expect(compared.runs.first.attempts.single.result.text, ' raw OCR ');
      expect(standard.inputs, hasLength(2)); expect(enhanced.inputs, isEmpty);
      expect(standard.prepares, 0); expect(enhanced.prepares, 0);
      for (final input in standard.inputs) {
        // Given this later explicit provider input.
        // When the borrowed original identity and bytes are inspected.
        // Then the facade has preserved the exact unchanged Core material.
        expect(input.material, same(material)); expect(input.bytes, [1, 2, 3]);
      }
      expect(RecognitionReportCodec.encode((await fresh.findComparison(recognized.id))!),
        RecognitionReportCodec.encode(recognized));
      expect(RecognitionReportCodec.encode((await fresh.findComparison(compared.id))!),
        RecognitionReportCodec.encode(compared));
      expect(await fresh.listComparisonsForMaterial(material.id), hasLength(2));
      expect(await FileCaptureStore(directory.path).readMaterial(material), [1, 2, 3]);
    });
  });

  test('F1 forwards desired routes and persists same-original comparison raw history', () async {
    // Given a borrowed service with two controlled providers and real local storage.
    // When capture, recovery, recognition and comparison explicitly choose routes.
    final captured = (await facade.capture(desiredConfigurationId: 'pixelEnhanced'))!;
    final recovered = (await facade.recover(desiredConfigurationId: 'androidStandard'))!;
    final recognized = await facade.recognize(captured.material, desiredConfigurationId: 'pixelEnhanced');
    final compared = await facade.compare(captured.material,
      configurationIds: ['androidStandard', 'pixelEnhanced']);
    final fresh = PhotoCaptureFacade(service: _service(_Camera(), _Provider(),
      _Provider(enhanced: true), FileCaptureStore(directory.path)));
    final reopened = await fresh.findComparison(compared.id);
    final history = await fresh.listComparisonsForMaterial(captured.material.id);
    // Then each chosen ID, original, ordered raw stage and shared linkage survives a fresh reader.
    expect(facade.configurations, same(service.configurations));
    expect(() => facade.configurations.clear(), throwsUnsupportedError);
    expect(captured.runs.single.desiredConfigurationId, 'pixelEnhanced');
    expect(recovered.runs.single.desiredConfigurationId, 'androidStandard');
    expect(recognized.runs.single.desiredConfigurationId, 'pixelEnhanced');
    expect(compared.runs.map((run) => run.desiredConfigurationId), ['androidStandard', 'pixelEnhanced']);
    expect(compared.material, same(captured.material));
    expect(recognized.material, same(captured.material));
    expect(standard.inputs.last.material, same(captured.material));
    expect(standard.inputs.last.bytes, [1, 2, 3]);
    expect(camera.captures, 1);
    expect(camera.recoveries, 1);
    expect(store.imports, 2);
    expect(standard.inputs.length, 4);
    expect(enhanced.inputs.length, 3);
    expect(RecognitionReportCodec.encode(reopened!), RecognitionReportCodec.encode(compared));
    expect(history.map((report) => report.id), containsAll([captured.id, recognized.id, compared.id]));
    expect(reopened.runs.first.attempts.single, same(reopened.runs.last.attempts.first));
    expect(reopened.runs.last.attempts.last.inputAttemptIds,
      [reopened.runs.first.attempts.single.id]);
    expect(reopened.runs.last.attempts.last.result.candidates.map((candidate) => candidate.kind),
      ['unknown kind', 'unknown kind', 'isbn']);
    expect(reopened.runs.first.attempts.single.result.barcodes.map((barcode) => barcode.value),
      [' second ', 'first']);
    expect(await fresh.listComparisonsForMaterial(recovered.material.id), hasLength(1));
  });

  test('F2 cancellation and exact acquisition/storage errors never repeat work', () async {
    // Given cancellation followed by actual acquisition and report-storage failures.
    camera.photo = null;
    // When explicit capture and recovery cancel.
    expect(await facade.capture(desiredConfigurationId: 'androidStandard'), isNull);
    expect(await facade.recover(desiredConfigurationId: 'pixelEnhanced'), isNull);
    // Then no original or inference was created.
    expect(store.imports, 0);
    expect(standard.inputs, isEmpty);
    // Given a camera failure object.
    final acquisitionError = StateError('camera failed');
    camera.error = acquisitionError;
    // When capture fails once.
    await expectLater(facade.capture(desiredConfigurationId: 'pixelEnhanced'), throwsA(same(acquisitionError)));
    // Then the identical error is observable and acquisition was not retried.
    expect(camera.captures, 2);
    // Given a subsequent actual report save failure.
    camera.error = null;
    camera.photo = _photo();
    final storageError = StateError('report write failed');
    store.writeError = storageError;
    // When Core cannot durably save the recognized result.
    await expectLater(facade.capture(desiredConfigurationId: 'androidStandard'), throwsA(same(storageError)));
    // Then storage was attempted once and the facade remains usable after explicit recovery.
    expect(store.writes, 1);
    expect(standard.inputs, hasLength(1));
    // Given repaired fixture storage for a new explicit operation.
    store.writeError = null;
    // When another capture succeeds.
    final accepted = (await facade.capture(desiredConfigurationId: 'androidStandard'))!;
    // Then its result is findable and no failed operation was silently repeated.
    expect(await facade.findComparison(accepted.id), isNotNull);
    expect(camera.captures, 4);
    expect(store.writes, 2);
  });

  test('F3 explicit readiness/preparation forwards model snapshots and failures', () async {
    // Given a downloadable enhancement, with no constructor I/O.
    enhanced.state = RecognitionProviderState.downloadable;
    // When availability is explicitly probed.
    final before = await facade.availability();
    // Then probing started no download, acquisition or inference.
    expect(before.last.state, RecognitionProviderState.downloadable);
    expect(enhanced.probes, 1);
    expect(enhanced.prepares, 0);
    expect(enhanced.inputs, isEmpty);
    expect(camera.captures, 0);
    // Given the actual preparation failure.
    final actual = StateError('download failed');
    enhanced.prepareError = actual;
    // When explicit preparation fails, then an explicit retry succeeds.
    await expectLater(facade.prepareProvider('geminiNano'), throwsA(same(actual)));
    enhanced.prepareError = null;
    final prepared = await facade.prepareProvider('geminiNano');
    // Then model state is forwarded and preparation did not run inference.
    expect(prepared.state, RecognitionProviderState.available);
    expect(prepared.modelName, 'fixture-model');
    expect(enhanced.prepares, 2);
    expect(enhanced.inputs, isEmpty);
  });

  test('F3 default factory uses shared store and one explicit Nano replacement without inference', () async {
    // Given an unsupported host, an already saved original and a one-shot provider iterable.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final material = await store.saveMaterial(bytes: Uint8List.fromList([1, 2, 3]),
      mediaType: 'image/jpeg', capturedAt: _time);
    var iterations = 0;
    Iterable<ImageRecognitionProvider> providers() sync* {
      iterations++;
      if (iterations > 1) throw StateError('provider iterable reread');
      yield enhanced;
    }
    // When the default factory opens using those exact overrides, then explicitly probes.
    final defaults = await openDefaultPhotoCaptureFacade(store: store, additionalProviders: providers());
    expect(enhanced.probes, 0);
    final availability = await defaults.availability();
    // Then the replacement wins, no channel inference/preparation happened, and shared storage is readable.
    expect(iterations, 1);
    expect(defaults.isSupported, isFalse);
    expect(availability.last.state, RecognitionProviderState.available);
    expect(enhanced.probes, 1);
    expect(enhanced.prepares, 0);
    expect(enhanced.inputs, isEmpty);
    expect(await defaults.listComparisonsForMaterial(material.id), isEmpty);
    expect(await store.readMaterial(material), [1, 2, 3]);
  });
}

final _time = DateTime.utc(2026, 10, 6);
CapturedPhoto _photo() => CapturedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]), mediaType: 'image/jpeg',
  capturedAt: _time, originalName: 'original.jpg',
);
CaptureMaterialReference _material() => CaptureMaterialReference(
  id: 'original', mediaType: 'image/jpeg', byteLength: 3, capturedAt: _time,
);

final class _Camera implements CameraProvider {
  bool supported = true;
  CapturedPhoto? photo = _photo();
  CapturedPhoto? recoveredPhoto;
  bool oneShotRecovery = false;
  Object? error;
  Completer<CapturedPhoto?>? gate;
  Completer<CapturedPhoto?>? recoveryGate;
  int captures = 0;
  int recoveries = 0;
  final captureStarted = Completer<void>();
  final recoveryStarted = Completer<void>();
  @override
  bool get isSupported => supported;
  @override
  Future<CapturedPhoto?> capturePhoto() async {
    captures++;
    if (!captureStarted.isCompleted) { captureStarted.complete(); }
    if (error != null) throw error!;
    return gate == null ? photo : gate!.future;
  }
  @override
  Future<CapturedPhoto?> recoverLostPhoto() async {
    recoveries++;
    if (!recoveryStarted.isCompleted) { recoveryStarted.complete(); }
    if (error != null) throw error!;
    if (recoveryGate != null) return recoveryGate!.future;
    if (recoveredPhoto != null || oneShotRecovery) {
      final recovered = recoveredPhoto;
      recoveredPhoto = null;
      return recovered;
    }
    return photo;
  }
}

final class _Provider implements ImageRecognitionProvider, ImageRecognitionProviderProvenance {
  _Provider({this.enhanced = false});
  final bool enhanced;
  RecognitionProviderState state = RecognitionProviderState.available;
  Object? prepareError;
  Object? provenanceError;
  Completer<void>? prepareGate;
  Completer<void>? probeGate;
  Completer<void>? recognitionGate;
  final probeStarted = Completer<void>();
  final prepareStarted = Completer<void>();
  final recognitionStarted = Completer<void>();
  int probes = 0;
  int prepares = 0;
  final inputs = <ImageRecognitionInput>[];
  ImageRecognitionResult? output;
  @override
  RecognitionProviderDescriptor get descriptor => RecognitionProviderDescriptor(
    id: enhanced ? 'geminiNano' : 'mlkitStandard', label: enhanced ? 'Enhanced' : 'Standard',
    capabilities: enhanced
      ? {RecognitionCapability.imageInterpretation, RecognitionCapability.candidateOrganization}
      : {RecognitionCapability.ocr, RecognitionCapability.barcodes},
  );
  @override
  Map<String, Object?> get provenance {
    if (provenanceError != null) throw provenanceError!;
    return {'model': 'fixture-model', 'opaque': [true, null, ' raw ']};
  }
  @override
  Future<RecognitionProviderAvailability> availability() async {
    probes++;
    if (!probeStarted.isCompleted) { probeStarted.complete(); }
    if (probeGate != null) await probeGate!.future;
    return RecognitionProviderAvailability(
      providerId: descriptor.id, state: state, capabilities: descriptor.capabilities,
      modelName: 'fixture-model',
      reason: state == RecognitionProviderState.unavailable ? 'not supported here' : null,
    );
  }
  @override
  Future<void> prepare() async {
    prepares++;
    if (!prepareStarted.isCompleted) { prepareStarted.complete(); }
    if (prepareGate != null) await prepareGate!.future;
    if (prepareError != null) throw prepareError!;
    state = RecognitionProviderState.available;
  }
  @override
  Future<ImageRecognitionResult> recognize(ImageRecognitionInput input) async {
    inputs.add(input);
    if (!recognitionStarted.isCompleted) { recognitionStarted.complete(); }
    if (recognitionGate != null) await recognitionGate!.future;
    return output ?? (enhanced
      ? ImageRecognitionResult(
          interpretation: ' raw interpretation ', candidateOrganizationCompleted: true,
          candidates: [
            RecognitionCandidate(kind: 'unknown kind', value: ' opaque proposal '),
            RecognitionCandidate(kind: 'unknown kind', value: ' opaque proposal '),
            RecognitionCandidate(kind: 'isbn', value: 'not validated'),
          ],
        )
      : ImageRecognitionResult(text: ' raw OCR ', barcodeCompleted: true, barcodes: [
          RecognizedImageBarcode(value: ' second ', format: 'rawFormat'),
          RecognizedImageBarcode(value: 'first', format: 'anotherFormat'),
        ]));
  }
}

final class _Store implements LocalCaptureStore {
  _Store(this.delegate);
  final LocalCaptureStore delegate;
  Object? writeError;
  Object? readError;
  Object? importError;
  Object? materialReadError;
  CaptureMaterialReference? lastReadReference;
  Completer<void>? materialReadGate;
  final materialReadStarted = Completer<void>();
  Completer<void>? importGate;
  final importStarted = Completer<void>();
  final saved = <CaptureMaterialReference>[];
  int reads = 0;
  int writes = 0;
  int imports = 0;
  @override
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes, required String mediaType,
    required DateTime capturedAt, String? originalName,
  }) async {
    imports++;
    if (!importStarted.isCompleted) { importStarted.complete(); }
    if (importGate != null) await importGate!.future;
    if (importError != null) throw importError!;
    final material = await delegate.saveMaterial(bytes: bytes, mediaType: mediaType,
      capturedAt: capturedAt, originalName: originalName);
    saved.add(material);
    return material;
  }
  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) async {
    reads++;
    lastReadReference = reference;
    if (!materialReadStarted.isCompleted) { materialReadStarted.complete(); }
    if (materialReadGate != null) { await materialReadGate!.future; }
    if (materialReadError != null) { throw materialReadError!; }
    return delegate.readMaterial(reference);
  }
  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) async {
    writes++;
    if (writeError != null) throw writeError!;
    await delegate.saveDocument(collection, id, document);
  }
  @override
  Future<Map<String, Object?>?> readDocument(String collection, String id) async {
    if (readError != null) throw readError!;
    return delegate.readDocument(collection, id);
  }
  @override
  Future<List<String>> listDocumentIds(String collection) => delegate.listDocumentIds(collection);
}

var _serviceIdentities = 0;
PhotoCaptureService _service(_Camera camera, _Provider standard, _Provider enhanced, LocalCaptureStore store) {
  final serviceIdentity = _serviceIdentities++;
  var tick = 0;
  var identity = 0;
  return PhotoCaptureService(
    camera: CameraService(provider: camera),
    recognition: ImageRecognitionService(
      registry: RecognitionProviderRegistry(providers: [standard, enhanced]),
      clock: () => _time.add(Duration(milliseconds: tick++ * 7)),
      idGenerator: () => 'recognition${serviceIdentity}_${identity++}',
    ),
    store: store,
  );
}
