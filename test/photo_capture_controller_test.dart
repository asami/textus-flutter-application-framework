import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  late PhotoCaptureFacade facade;
  late _SettingsStorage storage;
  late SettingsLifecycleController settings;
  late SettingsView view;
  late PhotoCaptureController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-controller-spec-');
    store = _Store(FileCaptureStore(directory.path));
    camera = _Camera();
    standard = _Provider();
    enhanced = _Provider(enhanced: true);
    facade = PhotoCaptureFacade(service: _service(camera, standard, enhanced, store));
    storage = _SettingsStorage();
    settings = _settings(storage);
    view = SettingsView.fromService(service: settings);
    controller = PhotoCaptureController(facade: facade, settings: view);
  });
  tearDown(() async {
    controller.dispose();
    view.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  group('generic per-operation context and controller lifetime', () {
    test('OC6 all five commands publish distinct durable intent and explicit route preserves desired settings', () async {
      // Given ready borrowed settings, a saved original and enhanced desired intent.
      await controller.initialize();
      controller.selectConfiguration('pixelEnhanced'); await controller.retrySettingsSave();
      final original = (await facade.captureOriginal())!;
      final settingWrites = storage.writes;
      final contexts = <RecognitionOperationContext>[];
      // When all five commands receive distinct immutable caller contexts.
      for (final command in ['capture', 'recover', 'recognizeCurrent', 'recognizeOriginal', 'compareCurrent']) {
        final context = RecognitionOperationContext(sourceRole: ' exact $command ',
          targetKinds: ['unknown kind'], instructions: ' exact $command request ', extensions: {'future': [command]});
        contexts.add(context);
        final RecognitionComparison? report = switch (command) {
          'capture' => await controller.capture(operationContext: context),
          'recover' => await controller.recover(operationContext: context),
          'recognizeCurrent' => await controller.recognizeCurrent(operationContext: context),
          'recognizeOriginal' => await controller.recognizeOriginal(original,
            desiredConfigurationId: 'androidStandard', operationContext: context),
          _ => await controller.compareCurrent(operationContext: context),
        };
        final accepted = report!;
        final loaded = (await LocalRecognitionRepository(store: FileCaptureStore(directory.path)).findById(accepted.id))!;
        // Then only the exact durable report publishes and explicit selection cannot change borrowed intent.
        expect(controller.comparison, same(accepted)); expect(controller.busy, isFalse); expect(controller.error, isNull);
        expect(accepted.operationContext, context); expect(loaded.operationContext, context);
        expect(RecognitionReportCodec.encode(loaded), RecognitionReportCodec.encode(accepted));
        expect(standard.inputs.last.operationContext, same(context));
        expect(standard.inputs.last.bytes, [1, 2, 3]);
        expect(controller.desiredConfigurationId, 'pixelEnhanced'); expect(storage.writes, settingWrites);
        if (command == 'recognizeOriginal') {
          // Given the caller's explicit standard route for the independently saved original.
          // When its actual durable ownership and route are observed.
          // Then settings retain enhanced intent and that exact supplied original is recognized.
          expect(accepted.material, same(original)); expect(accepted.runs.single.desiredConfigurationId, 'androidStandard');
        } else {
          // Given this enhanced or comparison command's actually executed enhancement.
          // When its received context and earlier raw stage are observed.
          // Then the same caller intent reaches the real stage without domain filtering.
          expect(enhanced.inputs.last.operationContext, same(context));
          expect(enhanced.inputs.last.previousResults.single, same(accepted.runs.last.attempts.first.result));
        }
      }
      // Given all completed contextual commands on one controller instance.
      // When the next current-original recognition omits context.
      final legacy = await controller.recognizeCurrent();
      // Then no prior context leaks into input, acceptance or persisted metadata.
      expect(contexts, hasLength(5)); expect(legacy.operationContext, isNull);
      expect(standard.inputs.last.operationContext, isNull); expect(enhanced.inputs.last.operationContext, isNull);
      expect((await facade.findComparison(legacy.id))!.operationContext, isNull);
      expect(store.imports, 3); expect(camera.captures, 2); expect(camera.recoveries, 1);
      expect(store.writes, 6); expect(standard.prepares + enhanced.prepares, 0);
      expect(SettingsRecord.decode(storage.record!).values[RecognitionSettings.configuration.id], 'pixelEnhanced');
    });

    test('OC6 contextual cancellation retains old comparison and next omitted context stays absent', () async {
      // Given ready settings, old durable history and cancelled capture/recovery on the borrowed camera.
      await controller.initialize(); final previous = (await controller.capture())!;
      camera.photo = null;
      final context = RecognitionOperationContext(sourceRole: 'cancelled',
        targetKinds: ['opaque'], instructions: 'requested intent');
      // When both contextual acquisition commands cancel on the existing controller.
      final captured = await controller.capture(operationContext: context);
      final recovered = await controller.recover(operationContext: context);
      // Then old acceptance remains and no requested-context report or provider work is invented.
      expect(captured, isNull); expect(recovered, isNull);
      expect(controller.comparison, same(previous)); expect(controller.error, isNull); expect(controller.busy, isFalse);
      expect(store.writes, 1); expect(store.imports, 1); expect(standard.inputs, hasLength(1));
      expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), [previous.id]);
      // Given the retained saved original after both cancellations.
      // When the next current-original command omits context.
      final next = await controller.recognizeCurrent();
      // Then input, accepted report and fresh durable lookup retain exact absence.
      expect(next.operationContext, isNull); expect(standard.inputs.last.operationContext, isNull);
      expect(controller.comparison, same(next)); expect((await facade.findComparison(next.id))!.operationContext, isNull);
      expect(store.imports, 1); expect(standard.prepares + enhanced.prepares, 0);
    });

    test('OC6 reentrant listener cannot replace start-time intent or context', () async {
      // Given ready standard intent, immutable context and a listener editing borrowed settings at operation start.
      await controller.initialize();
      final context = RecognitionOperationContext(sourceRole: ' start role ',
        targetKinds: ['opaque'], instructions: 'start request');
      var changed = false;
      controller.addListener(() {
        if (controller.busy && !changed) {
          changed = true;
          view.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
          // Given reentrant operation notification while the accepted capture owns the guard.
          // When a listener requests a second contextual operation.
          // Then it is rejected synchronously before changing the accepted request.
          expect(() => controller.capture(operationContext: context), throwsStateError);
        }
      });
      // When the contextual capture begins and the listener changes desired settings.
      final accepted = (await controller.capture(operationContext: context))!;
      // Then the report and real provider retain start-time intent/context while new desired state remains borrowed.
      expect(accepted.runs.single.desiredConfigurationId, 'androidStandard');
      expect(accepted.operationContext, context); expect(standard.inputs.single.operationContext, same(context));
      expect(enhanced.inputs, isEmpty); expect(controller.desiredConfigurationId, 'pixelEnhanced');
      expect(store.writes, 1); expect(controller.comparison, same(accepted));
      expect((await facade.findComparison(accepted.id))!.operationContext, context);
    });

    test('OC6 held contextual provider rejects all five overlaps with one durable acceptance', () async {
      // Given accepted old history, ready settings and a finite provider gate on the saved original.
      await controller.initialize();
      final previous = (await controller.capture())!;
      final context = RecognitionOperationContext(sourceRole: 'held provider',
        targetKinds: ['opaque'], instructions: 'accepted request');
      standard.recognitionGate = Completer<void>(); standard.recognitionEntered = Completer<void>();
      // When explicit contextual recognition holds the provider and all contextual commands compete.
      final active = controller.recognizeOriginal(previous.material, desiredConfigurationId: 'androidStandard',
        operationContext: context);
      await standard.recognitionEntered!.future;
      expect(() => controller.capture(operationContext: context), throwsStateError);
      expect(() => controller.recover(operationContext: context), throwsStateError);
      expect(() => controller.recognizeCurrent(operationContext: context), throwsStateError);
      expect(() => controller.recognizeOriginal(previous.material, desiredConfigurationId: 'androidStandard',
        operationContext: context), throwsStateError);
      expect(() => controller.compareCurrent(operationContext: context), throwsStateError);
      // Then pending work cannot replace the prior durable comparison.
      expect(controller.comparison, same(previous)); expect(store.writes, 1);
      expect(standard.inputs.last.operationContext, same(context));
      // Given only the admitted finite provider gate is released.
      standard.recognitionGate!.complete();
      // When the accepted request settles through durable persistence.
      final accepted = await active;
      // Then exactly one additional durable report publishes and no original is reimported.
      expect(controller.comparison, same(accepted)); expect(accepted.operationContext, context);
      expect((await facade.findComparison(accepted.id))!.operationContext, context);
      expect(store.writes, 2); expect(store.imports, 1); expect(camera.captures, 1);
      expect(standard.inputs, hasLength(2)); expect(controller.busy, isFalse);
    });

    test('OC6 contextual write failure retains old comparison and exact error then absent request recovers', () async {
      // Given old accepted history and one exact actual durability failure.
      await controller.initialize(); final previous = (await controller.capture())!;
      final context = RecognitionOperationContext(sourceRole: 'failed write',
        targetKinds: ['opaque'], instructions: 'requested intent');
      final failure = FileSystemException('actual contextual write failed'); store.writeError = failure;
      // When a contextual current-original operation fails to save its raw report.
      await expectLater(controller.recognizeCurrent(operationContext: context), throwsA(same(failure)));
      // Then failed work cannot publish a comparison or erase accepted history.
      expect(controller.comparison, same(previous)); expect(controller.error, same(failure));
      expect(controller.busy, isFalse); expect(standard.inputs.last.operationContext, same(context));
      expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), [previous.id]);
      // Given the actual write failure has been restored.
      store.writeError = null;
      // When the next current-original request omits context.
      final next = await controller.recognizeCurrent();
      // Then guard/error recovery preserves absence and durably accepts only the new successful report.
      expect(next.operationContext, isNull); expect(controller.comparison, same(next));
      expect(controller.error, isNull); expect((await facade.findComparison(next.id))!.operationContext, isNull);
      expect(store.imports, 1); expect(camera.captures, 1);
    });

    for (final boundary in ['provider', 'write']) {
      for (final fails in [false, true]) {
        test('OC6 disposal during held $boundary ${fails ? "failure" : "success"} prevents late publication or state mutation', () async {
          // Given prior accepted history and this finite provider or durable-write gate.
          await controller.initialize(); final previous = (await controller.capture())!;
          final context = RecognitionOperationContext(sourceRole: 'held-$boundary',
            targetKinds: ['opaque'], instructions: 'start-time intent');
          final gate = Completer<void>();
          final entered = Completer<void>();
          final failure = FileSystemException('actual held $boundary failure');
          if (boundary == 'provider') {
            standard.recognitionGate = gate; standard.recognitionEntered = entered;
          } else {
            store.writeGate = gate; store.writeEntered = entered;
          }
          var notifications = 0; controller.addListener(() => notifications++);
          // When the contextual command enters the held boundary, then disposal precedes its settlement.
          final active = controller.recognizeOriginal(previous.material,
            desiredConfigurationId: 'androidStandard', operationContext: context);
          // Provider exceptions become raw failure reports; store exceptions remain caller failures.
          final terminal = boundary == 'write' && fails ? expectLater(active, throwsA(same(failure))) : null;
          await entered.future;
          // Then pending work has not published or overwritten the old durable report.
          expect(controller.comparison, same(previous));
          expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), [previous.id]);
          final atDispose = notifications;
          final busyAtDispose = controller.busy; final errorAtDispose = controller.error;
          // Given the accepted contextual operation still owns this exact held gate.
          // When controller disposal precedes releasing or failing that gate.
          controller.dispose();
          if (fails) { gate.completeError(failure); } else { gate.complete(); }
          RecognitionComparison? completed;
          if (terminal != null) { await terminal; } else { completed = await active; }
          // Given the disposed controller after its accepted caller future has settled.
          // When state, notifications, durable output and input intent are observed.
          // Then no late controller mutation occurs and only actually saved reports exist.
          expect(controller.comparison, same(previous)); expect(controller.busy, busyAtDispose);
          expect(controller.error, same(errorAtDispose)); expect(notifications, atDispose);
          expect(standard.inputs.last.operationContext, same(context));
          expect(view.snapshot.readState, SettingsReadState.ready);
          expect(() => controller.capture(operationContext: context), throwsStateError);
          expect(camera.captures, 1); expect(store.imports, 1);
          if (completed != null) {
            // Given the actual durable report returned after provider success or captured provider failure.
            // When fresh persistence and raw attempt state are observed.
            // Then exact intent remains requested metadata without late controller acceptance.
            final reopened = (await LocalRecognitionRepository(store: FileCaptureStore(directory.path)).findById(completed.id))!;
            expect(reopened.operationContext, context);
            expect(RecognitionReportCodec.encode(reopened), RecognitionReportCodec.encode(completed));
            expect(reopened.runs.single.attempts.single.result.hasSuccessfulOutput, !fails);
            expect(reopened.runs.single.attempts.single.executed, isTrue);
          } else {
            // Given the caller's actual report-write failure.
            // When durable history is listed after its failed completion.
            // Then only the previously accepted report exists.
            expect(await store.delegate.listDocumentIds(LocalRecognitionRepository.collection), [previous.id]);
          }
        });
      }
    }
  });

  test('G1 G2 explicit original route retains desired intent with no acquisition or import', () async {
    // Given ready enhanced intent and a real original saved independently of recognition.
    await controller.initialize();
    controller.selectConfiguration('pixelEnhanced');
    await controller.retrySettingsSave();
    final original = (await facade.captureOriginal())!;
    final captures = camera.captures; final recoveries = camera.recoveries;
    final imports = store.imports; final writes = storage.writes;
    // When the common explicit-original command requests standard against that exact saved original.
    final report = await controller.recognizeOriginal(original, desiredConfigurationId: 'androidStandard');
    final durable = await facade.findComparison(report.id);
    // Then only the explicit route runs and actual durability is published without changing settings.
    expect(report.runs.single.desiredConfigurationId, 'androidStandard');
    expect(report.material, same(original));
    expect(controller.comparison, same(report));
    expect(RecognitionReportCodec.encode(durable!), RecognitionReportCodec.encode(report));
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
    expect(SettingsRecord.decode(storage.record!).values[RecognitionSettings.configuration.id], 'pixelEnhanced');
    expect(storage.writes, writes);
    expect(camera.captures, captures);
    expect(camera.recoveries, recoveries);
    expect(store.imports, imports);
    expect(standard.inputs.single.material, same(original));
    expect(standard.inputs.single.bytes, [1, 2, 3]);
    expect(enhanced.inputs, isEmpty);
    expect(enhanced.prepares + standard.prepares, 0);
  });

  test('G3 unknown route and blocked settings retain durable history without inference', () async {
    // Given ready settings and an accepted real report.
    await controller.initialize();
    final previous = (await controller.capture())!;
    final calls = standard.inputs.length;
    // When an unknown explicit route is requested on the saved original.
    await expectLater(controller.recognizeOriginal(previous.material,
      desiredConfigurationId: 'unknown'), throwsArgumentError);
    // Then route validation is observable and no report/provider/intent is replaced.
    expect(controller.comparison, same(previous));
    expect(controller.error, isA<ArgumentError>());
    expect(standard.inputs, hasLength(calls));
    expect(controller.desiredConfigurationId, 'androidStandard');
    // Given an initially notLoaded settings service and the same facade's durable saved display.
    final blockedStorage = _SettingsStorage()..readError = StateError('blocked settings');
    final blockedSettings = _settings(blockedStorage);
    final blockedView = SettingsView.fromService(service: blockedSettings);
    final blockedController = PhotoCaptureController(facade: facade, settings: blockedView);
    addTearDown(() {
      blockedController.dispose();
      blockedView.dispose();
      blockedSettings.dispose();
    });
    final loaded = await blockedController.loadComparison(previous.id);
    await blockedController.retrySettingsLoad();
    // When an otherwise known explicit saved-original route is requested.
    await expectLater(blockedController.recognizeOriginal(previous.material,
      desiredConfigurationId: 'androidStandard'), throwsStateError);
    // Then the read barrier rejects work without losing saved display or invoking the camera.
    expect(blockedView.snapshot.readState, SettingsReadState.failed);
    expect(blockedController.comparison, same(loaded));
    expect(standard.inputs, hasLength(calls));
    expect(camera.captures, 1);
    expect(enhanced.inputs, isEmpty);
  });

  test('G4 held explicit original rejects reentrant commands through the common guard', () async {
    // Given a saved original and a finite real provider gate.
    await controller.initialize();
    final original = (await facade.captureOriginal())!;
    standard.recognitionGate = Completer<void>();
    standard.recognitionEntered = Completer<void>();
    // When explicit standard recognition enters its held provider and commands overlap.
    final active = controller.recognizeOriginal(original, desiredConfigurationId: 'androidStandard');
    await standard.recognitionEntered!.future;
    // Then the shared guard rejects every overlapping command before additional work.
    expect(() => controller.recognizeOriginal(original, desiredConfigurationId: 'pixelEnhanced'), throwsStateError);
    expect(() => controller.capture(), throwsStateError);
    expect(() => controller.compareCurrent(), throwsStateError);
    expect(() => controller.refreshAvailability(), throwsStateError);
    expect(() => controller.selectConfiguration('pixelEnhanced'), throwsStateError);
    // Given the admitted provider gate is released.
    standard.recognitionGate!.complete();
    // When the original command completes durably.
    final completed = await active;
    // Then one operation publishes one durable report and releases the shared guard.
    expect(controller.busy, isFalse);
    expect(controller.comparison, same(completed));
    expect(standard.inputs, hasLength(1));
    expect(enhanced.inputs, isEmpty);
    expect(camera.captures, 1);
    expect(store.imports, 1);
  });

  test('G5 explicit original write failure and disposed completion publish only actual accepted work', () async {
    // Given accepted history and a selected real raw-report write failure.
    await controller.initialize();
    final previous = (await controller.capture())!;
    final failure = FileSystemException('raw report cannot save');
    store.writeError = failure;
    // When explicit same-original recognition fails its durability boundary.
    await expectLater(controller.recognizeOriginal(previous.material,
      desiredConfigurationId: 'androidStandard'), throwsA(same(failure)));
    // Then no nondurable completion replaces history and its real error remains observable.
    expect(controller.comparison, same(previous));
    expect(controller.error, same(failure));
    expect(controller.busy, isFalse);
    // Given a finite held provider and restored file persistence.
    store.writeError = null;
    standard.recognitionGate = Completer<void>();
    standard.recognitionEntered = Completer<void>();
    var notifications = 0;
    controller.addListener(() => notifications++);
    // When the explicit command is disposed after provider entry and then completes.
    final active = controller.recognizeOriginal(previous.material, desiredConfigurationId: 'androidStandard');
    await standard.recognitionEntered!.future;
    final atDispose = notifications;
    controller.dispose();
    standard.recognitionGate!.complete();
    final completed = await active;
    // Then the caller receives durable work with no late state/error/notification publication.
    expect(await facade.findComparison(completed.id), isNotNull);
    expect(controller.comparison, same(previous));
    expect(notifications, atDispose);
    expect(() => controller.recognizeOriginal(previous.material,
      desiredConfigurationId: 'androidStandard'), throwsStateError);
    expect(view.snapshot.readState, SettingsReadState.ready);
    expect(camera.captures, 1);
    expect(enhanced.prepares, 0);
  });

  test('C1 constructor requires the registered recognition definition and complete catalog', () {
    // Given common settings without the required recognition definition.
    final common = SettingsController(storage: _SettingsStorage());
    final commonView = SettingsView.fromService(service: common);
    // When the photo controller is composed with that registry.
    // Then schema identity validation rejects composition without I/O.
    expect(() => PhotoCaptureController(facade: facade, settings: commonView), throwsArgumentError);
    expect(camera.captures, 0);
    expect(standard.probes, 0);
    commonView.dispose();
    common.dispose();
    // Given a Core service exposing only the standard catalog choice.
    final incomplete = PhotoCaptureFacade(service: PhotoCaptureService(
      camera: CameraService(provider: camera),
      recognition: ImageRecognitionService(
        registry: RecognitionProviderRegistry(providers: [standard]),
        configurations: [RecognitionConfigurations.androidStandard]),
      store: store));
    // When the controller requires the full registered desired catalog.
    // Then missing enhanced intent is rejected before observation or I/O.
    expect(() => PhotoCaptureController(facade: incomplete, settings: view), throwsArgumentError);
    expect(storage.reads, 0);
    expect(standard.probes, 0);
  });

  test('C1 construction is inert and explicit restore retains enhanced intent and history', () async {
    // Given persisted enhanced intent on a host where enhancement is unavailable.
    storage.record = _preference('pixelEnhanced');
    enhanced.state = RecognitionProviderState.unavailable;
    // When the newly constructed controller is observed before initialization.
    // Then construction performed zero storage, provider or acquisition work.
    expect(storage.reads, 0);
    expect(storage.writes, 0);
    expect(standard.probes, 0);
    expect(camera.captures, 0);
    expect(controller.facade, same(facade));
    expect(controller.settings, same(view));
    // Given explicit owner initialization.
    // When initialization restores settings and probes each provider once.
    await controller.initialize();
    // Then unavailable enhancement retains the saved desired choice.
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
    expect(controller.availability.last.state, RecognitionProviderState.unavailable);
    expect(storage.reads, 1);
    expect(standard.probes, 1);
    expect(enhanced.probes, 1);
    expect(() => controller.availability.clear(), throwsUnsupportedError);
    // Given a durable fallback capture and fresh settings/storage/controller authorities.
    final saved = (await controller.capture())!;
    final nextStorage = _SettingsStorage()..record = storage.record;
    final nextSettings = _settings(nextStorage);
    final nextView = SettingsView.fromService(service: nextSettings);
    final next = PhotoCaptureController(
      facade: PhotoCaptureFacade(service: _service(_Camera(), _Provider(),
        _Provider(enhanced: true), FileCaptureStore(directory.path))), settings: nextView);
    // When the restarted owner explicitly initializes and loads history.
    await next.initialize();
    await next.loadComparison(saved.id);
    // Then preference and the exact durable report survive restart.
    expect(next.desiredConfigurationId, 'pixelEnhanced');
    expect(RecognitionReportCodec.encode(next.comparison!), RecognitionReportCodec.encode(saved));
    next.dispose();
    nextView.dispose();
    nextSettings.dispose();
  });

  test('C2 start-time desired snapshot survives external edits and compare reuses original', () async {
    // Given ready settings and an explicitly selected enhanced preference.
    await controller.initialize();
    controller.selectConfiguration('pixelEnhanced');
    // When selection alone is observed.
    // Then selection performs no acquisition/inference or preparation.
    expect(camera.captures, 0);
    expect(standard.inputs, isEmpty);
    expect(enhanced.prepares, 0);
    // Given a held original acquisition.
    camera.gate = Completer<CapturedPhoto?>();
    // When capture begins, an external settings edit changes the next desired ID.
    final active = controller.capture();
    settings.setValue(RecognitionSettings.configuration.id, 'androidStandard');
    camera.gate!.complete(_photo());
    final first = (await active)!;
    camera.gate = null;
    final second = (await controller.capture())!;
    final compared = await controller.compareCurrent();
    final recognized = await controller.recognizeCurrent();
    // Then current intent changed while the active operation retained its start snapshot.
    expect(first.runs.single.desiredConfigurationId, 'pixelEnhanced');
    expect(second.runs.single.desiredConfigurationId, 'androidStandard');
    expect(controller.desiredConfigurationId, 'androidStandard');
    expect(compared.runs.map((run) => run.desiredConfigurationId), ['androidStandard', 'pixelEnhanced']);
    expect(compared.material, same(second.material));
    expect(recognized.material, same(second.material));
    expect(recognized.runs.single.desiredConfigurationId, 'androidStandard');
    expect(camera.captures, 2);
    expect(store.imports, 2);
    expect(standard.inputs.last.material, same(second.material));
    expect(enhanced.inputs.last.material, same(second.material));
    expect(enhanced.inputs.last.bytes, [1, 2, 3]);
  });

  test('C3 explicit preparation and failed probe preserve accepted report and snapshots', () async {
    // Given a saved report and an unavailable then preparing provider snapshot.
    await controller.initialize();
    final saved = (await controller.capture())!;
    enhanced.state = RecognitionProviderState.unavailable;
    // When readiness is explicitly refreshed, then externally preparing state is probed.
    await controller.refreshAvailability();
    expect(controller.availability.last.reason, 'not supported here');
    enhanced.state = RecognitionProviderState.preparing;
    await controller.refreshAvailability();
    // Then probing made no silent preparation or replacement report.
    expect(controller.availability.last.state, RecognitionProviderState.preparing);
    expect(enhanced.prepares, 0);
    expect(controller.comparison, same(saved));
    // Given a downloadable provider and a held explicit preparation.
    enhanced.state = RecognitionProviderState.downloadable;
    await controller.refreshAvailability();
    enhanced.prepareGate = Completer<void>();
    // When preparation is requested.
    final preparing = controller.prepareProvider('geminiNano');
    await _settle();
    // Then the one operation is busy and no extra inference occurs.
    expect(controller.busy, isTrue);
    expect(enhanced.prepares, 1);
    expect(enhanced.inputs, isEmpty);
    expect(() => controller.prepareProvider('geminiNano'), throwsStateError);
    // Given completion of the admitted model preparation.
    enhanced.prepareGate!.complete();
    // When it settles.
    final available = await preparing;
    // Then only the returned provider snapshot is updated.
    expect(controller.availability.last, same(available));
    expect(available.modelName, 'fixture-model');
    expect(controller.comparison, same(saved));
    // Given an actual Core probe failure from invalid provider provenance.
    final actual = StateError('provenance unavailable');
    final before = controller.availability;
    enhanced.provenanceError = actual;
    // When readiness fails.
    await expectLater(controller.refreshAvailability(), throwsA(same(actual)));
    // Then the exact error is recorded without replacing old availability/report.
    expect(controller.error, same(actual));
    expect(controller.availability, same(before));
    expect(controller.comparison, same(saved));
    // Given an actual downloadable preparation failure.
    enhanced.provenanceError = null;
    enhanced.state = RecognitionProviderState.downloadable;
    await controller.refreshAvailability();
    enhanced.prepareError = actual;
    final beforePrepare = controller.availability;
    // When explicit preparation fails.
    await expectLater(controller.prepareProvider('geminiNano'), throwsA(same(actual)));
    // Then failure is visible and neither accepted state nor desired settings is rewritten.
    expect(controller.error, same(actual));
    expect(controller.availability, same(beforePrepare));
    expect(controller.comparison, same(saved));
    expect(controller.desiredConfigurationId, 'androidStandard');
  });

  test('C4 cancellation, nondurable reports and corrupt/absent history keep accepted report', () async {
    // Given a durable accepted capture.
    await controller.initialize();
    final saved = (await controller.capture())!;
    camera.photo = null;
    // When capture and recovery cancel.
    expect(await controller.capture(), isNull);
    expect(await controller.recover(), isNull);
    // Then cancellation retains the report.
    expect(controller.comparison, same(saved));
    // Given an actual report write failure.
    camera.photo = _photo();
    final actual = StateError('durability failed');
    store.writeError = actual;
    // When new recognition cannot be durably saved.
    await expectLater(controller.recognizeCurrent(), throwsA(same(actual)));
    // Then no nondurable report replaces the accepted one.
    expect(controller.comparison, same(saved));
    expect(controller.error, same(actual));
    // Given absent and corrupt history.
    store.writeError = null;
    await store.delegate.saveDocument(LocalRecognitionRepository.collection, 'corrupt', {});
    // When explicit loads fail.
    await expectLater(controller.loadComparison('absent'), throwsStateError);
    expect(controller.comparison, same(saved));
    await expectLater(controller.loadComparison('corrupt'), throwsFormatException);
    // Then failure remains observable without losing history.
    expect(controller.error, isA<FormatException>());
    expect(controller.comparison, same(saved));
    // Given a later valid explicit recognition.
    // When it completes durably.
    final retried = await controller.recognizeCurrent();
    // Then interaction recovers and publishes only the new accepted report.
    expect(controller.error, isNull);
    expect(controller.comparison, same(retried));
    expect(await facade.findComparison(retried.id), isNotNull);
  });

  test('C5 all busy guards prevent work and settings read barrier permits history display', () async {
    // Given an initial settings read held by the real lifecycle.
    storage.readGate = Completer<String?>();
    final active = controller.initialize();
    // When all public mutating commands attempt to overlap it.
    expect(() => controller.initialize(), throwsStateError);
    expect(() => controller.refreshAvailability(), throwsStateError);
    expect(() => controller.prepareProvider('geminiNano'), throwsStateError);
    expect(() => controller.selectConfiguration('pixelEnhanced'), throwsStateError);
    expect(() => controller.capture(), throwsStateError);
    expect(() => controller.recover(), throwsStateError);
    expect(() => controller.recognizeCurrent(), throwsStateError);
    expect(() => controller.compareCurrent(), throwsStateError);
    expect(() => controller.loadComparison('absent'), throwsStateError);
    expect(() => controller.retrySettingsLoad(), throwsStateError);
    expect(() => controller.retrySettingsSave(), throwsStateError);
    // Then guards caused no extra service work or settings write.
    expect(camera.captures, 0);
    expect(storage.reads, 1);
    expect(storage.writes, 0);
    expect(controller.error, isNull);
    // Given an unsupported persisted envelope.
    storage.readGate!.complete(_preference('pixelEnhanced', version: 99));
    storage.readGate = null;
    // When initialization settles and capture is attempted.
    await active;
    await expectLater(controller.capture(), throwsStateError);
    // Then the unsupported read stays visible and probing still completed.
    expect(view.snapshot.readState, SettingsReadState.unsupported);
    expect(standard.probes, 1);
    expect(camera.captures, 0);
    // Given separately durable history that is displayable without capture readiness.
    final saved = (await facade.capture(desiredConfigurationId: 'androidStandard'))!;
    // When it is explicitly loaded.
    await controller.loadComparison(saved.id);
    // Then the controller displays it while settings remain unsupported.
    expect(controller.comparison!.id, saved.id);
    expect(view.snapshot.readState, SettingsReadState.unsupported);
    // Given a supported envelope for an explicit restoration retry.
    storage.record = _preference('pixelEnhanced');
    // When retry is requested.
    await controller.retrySettingsLoad();
    // Then the read barrier opens and restored intent is retained.
    expect(view.snapshot.readState, SettingsReadState.ready);
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
  });

  test('C5 read/save retries publish actual snapshot failures rather than false durability', () async {
    // Given an actual settings read failure.
    final actual = StateError('settings disk failure');
    storage.readError = actual;
    // When explicit initialize settles through Core's nonfatal read contract.
    await controller.initialize();
    await expectLater(controller.capture(), throwsStateError);
    // Then the snapshot, independent probe and acquisition barrier remain truthful.
    expect(view.snapshot.readState, SettingsReadState.failed);
    expect(view.snapshot.readError, same(actual));
    expect(standard.probes, 1);
    expect(camera.captures, 0);
    // Given a working read followed by a failed settings write.
    storage.readError = null;
    await controller.retrySettingsLoad();
    storage.writeError = actual;
    controller.selectConfiguration('pixelEnhanced');
    // When persistence is explicitly awaited and retried.
    await controller.retrySettingsSave();
    await controller.retrySettingsSave();
    // Then settled retry Futures still expose failure and unsaved intent.
    expect(view.snapshot.saveState, SettingsSaveState.failed);
    expect(view.snapshot.saveError, same(actual));
    expect(view.snapshot.hasUnsavedChanges, isTrue);
    expect(controller.error, isNull);
    expect(controller.desiredConfigurationId, 'pixelEnhanced');
    // Given a held successful retry.
    storage.writeError = null;
    storage.writeGate = Completer<void>();
    final saving = controller.retrySettingsSave();
    await _settle();
    // When the actual adapter acknowledgement remains pending.
    // Then saving/unsaved are visible and overlapping retry is rejected.
    expect(view.snapshot.saveState, SettingsSaveState.saving);
    expect(view.snapshot.hasUnsavedChanges, isTrue);
    expect(() => controller.retrySettingsSave(), throwsStateError);
    // Given acknowledgement from storage.
    storage.writeGate!.complete();
    // When it settles.
    await saving;
    // Then and only then the preference is durable.
    expect(view.snapshot.hasUnsavedChanges, isFalse);
    expect(SettingsRecord.decode(storage.record!).values[RecognitionSettings.configuration.id], 'pixelEnhanced');
  });

  test('C6 disposing held work settles its caller without late state or borrowed disposal', () async {
    // Given an accepted report and a held subsequent acquisition.
    await controller.initialize();
    final previous = (await controller.capture())!;
    camera.gate = Completer<CapturedPhoto?>();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final active = controller.capture();
    final atDispose = notifications;
    // When disposal is repeated before Core finishes.
    controller.dispose();
    controller.dispose();
    camera.gate!.complete(_photo());
    final completed = (await active)!;
    // Then the caller receives durable work with no late mutation/notification.
    expect(completed.id, isNot(previous.id));
    expect(controller.comparison, same(previous));
    expect(notifications, atDispose);
    expect(() => controller.capture(), throwsStateError);
    expect(() => controller.initialize(), throwsStateError);
    expect(() => controller.refreshAvailability(), throwsStateError);
    expect(() => controller.prepareProvider('geminiNano'), throwsStateError);
    expect(() => controller.recover(), throwsStateError);
    expect(() => controller.recognizeCurrent(), throwsStateError);
    expect(() => controller.compareCurrent(), throwsStateError);
    expect(() => controller.loadComparison(previous.id), throwsStateError);
    expect(() => controller.retrySettingsLoad(), throwsStateError);
    expect(() => controller.retrySettingsSave(), throwsStateError);
    expect(() => controller.selectConfiguration('pixelEnhanced'), throwsStateError);
    // Given borrowed authorities retained by their caller.
    camera.gate = null;
    // When they are used directly after controller disposal.
    view.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
    await view.retrySave();
    final report = (await facade.capture(desiredConfigurationId: 'androidStandard'))!;
    // Then settings and service remain usable.
    expect(view.value(RecognitionSettings.configuration), 'pixelEnhanced');
    expect(await facade.findComparison(report.id), isNotNull);
  });

  test('C6 disposal during notification safely detaches and rejects later work', () async {
    // Given a controller listener that disposes its publisher during dispatch.
    var trailing = 0;
    controller.addListener(controller.dispose);
    controller.addListener(() => trailing++);
    // When an external settings edit synchronously notifies the borrowed observer.
    view.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
    // Then physical notifier disposal is deferred and the remaining listener is detached.
    expect(trailing, 0);
    expect(() => controller.retrySettingsLoad(), throwsStateError);
    expect(view.value(RecognitionSettings.configuration), 'pixelEnhanced');
    controller.dispose();
  });
}

final _time = DateTime.utc(2026, 10, 6);
CapturedPhoto _photo() => CapturedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]), mediaType: 'image/jpeg',
  capturedAt: _time, originalName: 'original.jpg',
);

final class _Camera implements CameraProvider {
  bool supported = true;
  CapturedPhoto? photo = _photo();
  Object? error;
  Completer<CapturedPhoto?>? gate;
  int captures = 0;
  int recoveries = 0;
  @override
  bool get isSupported => supported;
  @override
  Future<CapturedPhoto?> capturePhoto() async {
    captures++;
    if (error != null) throw error!;
    return gate == null ? photo : gate!.future;
  }
  @override
  Future<CapturedPhoto?> recoverLostPhoto() async {
    recoveries++;
    if (error != null) throw error!;
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
  Completer<void>? recognitionGate;
  Completer<void>? recognitionEntered;
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
    return RecognitionProviderAvailability(
      providerId: descriptor.id, state: state, capabilities: descriptor.capabilities,
      modelName: 'fixture-model',
      reason: state == RecognitionProviderState.unavailable ? 'not supported here' : null,
    );
  }
  @override
  Future<void> prepare() async {
    prepares++;
    if (prepareGate != null) await prepareGate!.future;
    if (prepareError != null) throw prepareError!;
    state = RecognitionProviderState.available;
  }
  @override
  Future<ImageRecognitionResult> recognize(ImageRecognitionInput input) async {
    inputs.add(input);
    if (recognitionEntered != null && !recognitionEntered!.isCompleted) recognitionEntered!.complete();
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
  Completer<void>? writeGate;
  Completer<void>? writeEntered;
  int writes = 0;
  int imports = 0;
  @override
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes, required String mediaType,
    required DateTime capturedAt, String? originalName,
  }) {
    imports++;
    return delegate.saveMaterial(bytes: bytes, mediaType: mediaType,
      capturedAt: capturedAt, originalName: originalName);
  }
  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) => delegate.readMaterial(reference);
  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) async {
    writes++;
    if (writeEntered != null && !writeEntered!.isCompleted) writeEntered!.complete();
    if (writeGate != null) await writeGate!.future;
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

final class _SettingsStorage implements SettingsStorage {
  String? record;
  Object? readError;
  Object? writeError;
  Completer<String?>? readGate;
  Completer<void>? writeGate;
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> read() async {
    reads++;
    if (readError != null) throw readError!;
    return readGate == null ? record : readGate!.future;
  }
  @override
  Future<void> write(String value) async {
    writes++;
    if (writeGate != null) await writeGate!.future;
    if (writeError != null) throw writeError!;
    record = value;
  }
}

SettingsLifecycleController _settings(_SettingsStorage storage) => SettingsLifecycleController(
  registry: RecognitionSettings.registry(), storage: storage,
  resetDefinitions: RecognitionSettings.definitions,
);

String _preference(String desired, {int version = 1}) => SettingsRecord.empty()
    .withUpdates({RecognitionSettings.configuration.id: desired}).encode()
    .replaceFirst('"version":1', '"version":$version');

Future<void> _settle() => Future<void>.delayed(Duration.zero);
