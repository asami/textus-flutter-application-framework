import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  group('painted query, evidence and borrowed ownership', () {
    testWidgets('mount and typing are inert; real Core query resolves exactly once', (tester) async {
      // Given actual FileCaptureStore/Core composition and an independent pending manual editor.
      late Directory directory;
      late _TrackingService service;
      final corpus = _Corpus([_document()]);
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('tfaf-retrieval-widget-');
        service = _TrackingService(CaptureStorageFacade(store: FileCaptureStore(directory.path))
          .createMaterialRetrievalService(corpus: corpus, corpusId: 'books'));
      });
      final controller = MaterialRetrievalController(service: service);
      final opened = <MaterialRetrievalDocument>[];
      Future<void> open(MaterialRetrievalDocument value) async { opened.add(value); }
      await tester.pumpWidget(_app(controller, open));
      await tester.enterText(find.byKey(const ValueKey('manual-editor')), '未保存の手入力');
      await tester.enterText(_query, '日本語 ab12');
      expect(service.searches, 0);
      expect(corpus.loads, 0);
      // When the human explicitly searches and then explicitly opens its current result.
      await _tap(tester, 'search', realIo: true);
      await _waitForCommand(tester, controller);
      await _frames(tester);
      expect(find.text('端末内の語句一致検索'), findsOneWidget);
      expect(find.text('空白で区切った語句をすべて含む資料を検索します'), findsOneWidget);
      expect(find.text('1件表示 / 1件一致・対象1件'), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, _document().text);
      await _tap(tester, 'open-0', realIo: true);
      await _waitForCommand(tester, controller);
      await _frames(tester);
      // Then only the exact current source opens, while the external pending editor survives.
      expect(opened, [_document()]);
      expect(service.searches, 1);
      expect(service.resolves, 1);
      expect(corpus.loads, 2);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('manual-editor')))
        .controller?.text, isNull);
      expect(find.text('未保存の手入力'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await controller.detach();
        controller.dispose();
        expect(service.closes, 0);
        await service.close();
        await directory.delete(recursive: true);
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('painted counts exact selectable evidence and scalar omissions remain truthful', (tester) async {
      // Given a controlled typed result with exact scalar evidence and more matches than returned.
      final document = _document(text: '${'前' * 50}日本語${'後' * 180}');
      final service = _Service()..documents = [document]..totalMatches = 3..indexedCount = 4;
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      // When the panel paints the current result without additional service work.
      await tester.pumpWidget(_app(controller, (_) async {}));
      // Then labels/counts/omissions describe Core offsets without modifying the selectable snippet.
      expect(find.text('1件表示 / 3件一致・対象4件'), findsOneWidget);
      expect(find.text('表示上限を超える結果があります'), findsOneWidget);
      expect(find.text('前略'), findsOneWidget);
      expect(find.text('後略'), findsOneWidget);
      expect(find.text(document.title), findsOneWidget);
      expect(find.text(document.sourceLabel), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
        controller.result!.hits.single.snippet);
      expect(service.searches, 1);
      await _cleanup(tester, controller, service);
    });

    testWidgets('ordinary repaint preserves cursor and a valid pending command', (tester) async {
      // Given a visible query with a human cursor selection and delayed service result.
      final service = _Service()..searchGate = Completer<MaterialRetrievalResult>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      Future<void> open(MaterialRetrievalDocument _) async {}
      late StateSetter repaint;
      await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
        repaint = setState;
        return _body(controller, open);
      })));
      final field = tester.widget<TextField>(_query).controller!;
      field.selection = const TextSelection.collapsed(offset: 1);
      await _tap(tester, 'search');
      // When unrelated host state repaints while that exact command remains pending.
      repaint(() {});
      await _frames(tester);
      expect(field.selection.baseOffset, 1);
      expect(field.text, '日本語');
      service.searchGate!.complete(service.result(MaterialRetrievalQuery('日本語')));
      await _frames(tester);
      // Then ordinary repaint does not retire the live command or reset the input cursor.
      expect(controller.result!.hits, hasLength(1));
      expect(service.searches, 1);
      expect(field.selection.baseOffset, 1);
      await _cleanup(tester, controller, service);
    });

    testWidgets('busy typing retains exact new input and cancel waits for original cleanup', (tester) async {
      // Given a pending query that keeps its original service future gated.
      final service = _Service()..searchGate = Completer<MaterialRetrievalResult>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await tester.pumpWidget(_app(controller, (_) async {}));
      await _tap(tester, 'search');
      // When a human edits during busy, then the original future completes after cancellation.
      expect(tester.widget<TextField>(_query).enabled, isTrue);
      await tester.enterText(_query, '  次の入力　');
      await _frames(tester);
      expect(controller.busy, isTrue);
      expect(find.text('元の処理の終了を待っています'), findsOneWidget);
      expect(service.tokens.single!.isCanceled, isTrue);
      service.searchGate!.complete(service.result(MaterialRetrievalQuery('日本語')));
      await _frames(tester);
      // Then the old result cannot overwrite the new buffer and no automatic successor search runs.
      expect(controller.query, '  次の入力　');
      expect(tester.widget<TextField>(_query).controller!.text, '  次の入力　');
      expect(controller.result, isNull);
      expect(controller.busy, isFalse);
      expect(service.searches, 1);
      await _cleanup(tester, controller, service);
    });

    testWidgets('explicit Cancel keeps spinner through cleanup and reports canceled outcome', (tester) async {
      // Given a delayed current Search and the rendered Cancel button for its exact owner.
      final service = _Service()..searchGate = Completer<MaterialRetrievalResult>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await tester.pumpWidget(_app(controller, (_) async {}));
      await _tap(tester, 'search');
      // When Cancel retires the token before the service's original cleanup completes.
      await _tap(tester, 'cancel');
      expect(controller.busy, isTrue);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('元の処理の終了を待っています'), findsOneWidget);
      service.searchGate!.complete(service.result(MaterialRetrievalQuery('日本語')));
      await _frames(tester);
      // Then actual settlement ends busy, with no success or automatic query/save action.
      expect(controller.busy, isFalse);
      expect(controller.status, MaterialRetrievalStatus.canceled);
      expect(find.text('検索操作を取り消しました'), findsOneWidget);
      expect(controller.result, isNull);
      expect(service.searches, 1);
      await _cleanup(tester, controller, service);
    });

    for (final outcome in ['empty', 'failure', 'unsupported', 'bounds']) {
      testWidgets('$outcome is friendly and preserves edit/retry without raw private errors', (tester) async {
        // Given a typed isolated UI port with the selected terminal outcome.
        final service = _Service();
        if (outcome == 'empty') {
          service.documents = [];
        } else if (outcome != 'bounds') {
          service.failure = outcome == 'unsupported'
            ? UnsupportedError('/private/opaque-source')
            : const FileSystemException('private-error', '/private/opaque-source');
        }
        final input = outcome == 'bounds' ? '語' * 257 : '日本語';
        final controller = MaterialRetrievalController(service: service)..setQuery(input);
        await tester.pumpWidget(_app(controller, (_) async {}));
        // When the user explicitly submits that query.
        await _tap(tester, 'search');
        // Then the panel gives a human outcome while controller errors and the exact buffer remain inspectable.
        expect(find.textContaining('/private/opaque-source'), findsNothing);
        expect(tester.widget<TextField>(_query).controller!.text, input);
        expect(tester.widget<TextField>(_query).enabled, isTrue);
        expect(find.textContaining(switch (outcome) {
          'empty' => '一致する資料はありません',
          'unsupported' => 'この環境では検索を利用できません',
          'bounds' => '検索語句が上限を超えています',
          _ => '検索処理に失敗しました',
        }), findsOneWidget);
        if (outcome != 'empty') {
          expect(controller.error, isNotNull);
        }
        service.failure = null;
        service.documents = [_document()];
        await tester.enterText(_query, '日本語 ab12');
        await _tap(tester, 'search');
        expect(controller.status, MaterialRetrievalStatus.ready);
        await _cleanup(tester, controller, service);
      });
    }

    testWidgets('explicit rebuild shows notice and needs manual Search', (tester) async {
      // Given a painted result with an intact human query buffer.
      final service = _Service();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      await tester.pumpWidget(_app(controller, (_) async {}));
      // When the human explicitly chooses to recreate the derived index.
      await _tap(tester, 'rebuild');
      // Then the notice is truthful and no automatic follow-up search or result is fabricated.
      expect(find.text('索引を再作成しました。検索ボタンで再検索してください'), findsOneWidget);
      expect(service.rebuilds, 1);
      expect(service.searches, 1);
      expect(controller.result, isNull);
      expect(tester.widget<TextField>(_query).controller!.text, '日本語');
      await _tap(tester, 'search');
      expect(controller.result!.hits, hasLength(1));
      await _cleanup(tester, controller, service);
    });
  });

  group('rendered action admission and current source opening', () {
    testWidgets('route-free isolated host admits exactly the current available source', (tester) async {
      // Given an isolated common panel with no ModalRoute and a valid published result.
      final service = _Service();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      final opened = <MaterialRetrievalDocument>[];
      await tester.pumpWidget(MaterialApp(builder: (_, _) =>
        _body(controller, (value) async { opened.add(value); })));
      // When explicit Open resolves without any application route composition.
      await _tap(tester, 'open-0');
      // Then null route is allowed while all source and owner witnesses remain enforced.
      expect(opened, [_document()]);
      expect(service.resolves, 1);
      await _cleanup(tester, controller, service);
    });

    testWidgets('old Cancel closure cannot cancel a newer resolve on the same result', (tester) async {
      // Given a first gated resolve and its rendered command-specific Cancel closure.
      final service = _Service()..resolveGate = Completer<MaterialRetrievalResolution>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      await tester.pumpWidget(_app(controller, (_) async {}));
      await _tap(tester, 'open-0');
      final oldCancel = _button(tester, 'cancel');
      service.resolveGate!.complete(MaterialRetrievalResolution(
        status: MaterialRetrievalResolutionStatus.available, document: _document()));
      await _frames(tester);
      service.resolveGate = Completer<MaterialRetrievalResolution>();
      // When another resolve starts on the unchanged result before the old Cancel callback fires.
      await _tap(tester, 'open-0');
      oldCancel();
      await _frames(tester);
      // Then the old callback has no permission over the newer original command.
      expect(controller.canCancel, isTrue);
      expect(controller.busy, isTrue);
      expect(service.resolves, 2);
      service.resolveGate!.complete(MaterialRetrievalResolution(
        status: MaterialRetrievalResolutionStatus.available, document: _document()));
      await _frames(tester);
      await _cleanup(tester, controller, service);
    });

    testWidgets('earlier completion listener successor rejects the original rendered Cancel', (tester) async {
      // Given a listener registered before the panel and a first gated Open resolve.
      final firstRelease = Completer<MaterialRetrievalResolution>();
      final secondRelease = Completer<MaterialRetrievalResolution>();
      final service = _Service()..resolveGate = firstRelease;
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      final result = controller.result!;
      final hit = result.hits.single;
      var started = false;
      Future<MaterialRetrievalResolution?>? successor;
      void startSuccessor() {
        if (!started && !controller.busy &&
            controller.resolution?.status == MaterialRetrievalResolutionStatus.available) {
          started = true;
          service.resolveGate = secondRelease;
          successor = controller.resolveHit(hit);
        }
      }
      controller.addListener(startSuccessor);
      final opened = <MaterialRetrievalDocument>[];
      await tester.pumpWidget(_app(controller, (value) async { opened.add(value); }));
      try {
        await _tap(tester, 'open-0');
        final oldCancel = _button(tester, 'cancel');
        final originalVersion = controller.resultVersion;
        expect(service.resolves, 1);
        expect(service.resolveTokens, hasLength(1));
        // When the earlier listener reserves a same-hit successor during completion notification.
        firstRelease.complete(MaterialRetrievalResolution(
          status: MaterialRetrievalResolutionStatus.available, document: hit.document));
        await _frames(tester);
        oldCancel();
        await _frames(tester);
        // Then the retained original Cancel cannot cancel the successor or admit the old Open.
        expect(started, isTrue);
        expect(successor, isNotNull);
        expect(controller.resultVersion, greaterThan(originalVersion));
        expect(controller.result, same(result));
        expect(controller.result!.hits.single, same(hit));
        expect(controller.canCancel, isTrue);
        expect(controller.busy, isTrue);
        expect(controller.status, MaterialRetrievalStatus.resolving);
        expect(service.searches, 1);
        expect(service.resolves, 2);
        expect(service.resolveTokens, hasLength(2));
        expect(identical(service.resolveTokens.first, service.resolveTokens.last), isFalse);
        expect(service.resolveTokens.first!.isCanceled, isFalse);
        expect(service.resolveTokens.last!.isCanceled, isFalse);
        expect(opened, isEmpty);
        expect(service.closes, 0);
        // When the successor completes its own available resolution.
        secondRelease.complete(MaterialRetrievalResolution(
          status: MaterialRetrievalResolutionStatus.available, document: hit.document));
        await _frames(tester);
        final available = await successor;
        // Then its actual source is returned without reviving the original navigation.
        expect(available?.status, MaterialRetrievalResolutionStatus.available);
        expect(available?.document, hit.document);
        expect(controller.resolution, same(available));
        expect(controller.status, MaterialRetrievalStatus.ready);
        expect(controller.busy, isFalse);
        expect(controller.canCancel, isFalse);
        expect(opened, isEmpty);
        // When the human explicitly opens the currently rendered result again.
        service.resolveGate = null;
        await _tap(tester, 'open-0');
        // Then exactly that fresh command opens the complete selected document once.
        expect(opened, [hit.document]);
        expect(service.resolves, 3);
        expect(service.resolveTokens, hasLength(3));
        expect(service.resolveTokens.last!.isCanceled, isFalse);
        expect(service.searches, 1);
        expect(controller.status, MaterialRetrievalStatus.ready);
        expect(controller.busy, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        controller.removeListener(startSuccessor);
        if (!firstRelease.isCompleted) {
          firstRelease.complete(MaterialRetrievalResolution(
            status: MaterialRetrievalResolutionStatus.available, document: hit.document));
        }
        if (!secondRelease.isCompleted) {
          secondRelease.complete(MaterialRetrievalResolution(
            status: MaterialRetrievalResolutionStatus.available, document: hit.document));
        }
        await _frames(tester);
        await successor;
        await _cleanup(tester, controller, service);
      }
    });

    testWidgets('Cancel during resolution denies opening and waits for its original future', (tester) async {
      // Given a visible current-source resolve held by its original service future.
      final service = _Service()..resolveGate = Completer<MaterialRetrievalResolution>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      var opens = 0;
      await tester.pumpWidget(_app(controller, (_) async { opens++; }));
      await _tap(tester, 'open-0');
      // When the user explicitly cancels source opening before actual resolution completes.
      await _tap(tester, 'cancel');
      expect(controller.busy, isTrue);
      service.resolveGate!.complete(MaterialRetrievalResolution(
        status: MaterialRetrievalResolutionStatus.available, document: _document()));
      await _frames(tester);
      // Then available data from retired work cannot navigate, and busy ends only at settlement.
      expect(opens, 0);
      expect(controller.busy, isFalse);
      expect(controller.status, MaterialRetrievalStatus.canceled);
      await _cleanup(tester, controller, service);
    });

    testWidgets('controller replacement while Search is pending preserves the new input buffer', (tester) async {
      // Given a mounted original owner with a pending search and a distinct new owner/query.
      final service = _Service()..searchGate = Completer<MaterialRetrievalResult>();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      final newService = _Service();
      final replacement = MaterialRetrievalController(service: newService)..setQuery('  新しい入力　');
      var selected = controller;
      late StateSetter rebuild;
      Future<void> open(MaterialRetrievalDocument _) async {}
      await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
        rebuild = setState;
        return _body(selected, open);
      })));
      await _tap(tester, 'search');
      // When the widget borrows a replacement controller before the old result finishes.
      rebuild(() => selected = replacement);
      await _frames(tester);
      service.searchGate!.complete(service.result(MaterialRetrievalQuery('日本語')));
      await _frames(tester);
      // Then old work stays in its old controller and cannot mutate the replacement input or UI.
      expect(controller.result!.hits, hasLength(1));
      expect(controller.isClosed, isFalse);
      expect(tester.widget<TextField>(_query).controller!.text, '  新しい入力　');
      expect(replacement.result, isNull);
      expect(newService.searches, 0);
      expect(find.byType(SelectableText), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await controller.detach();
      controller.dispose();
      await replacement.detach();
      replacement.dispose();
      expect(service.closes, 0);
      expect(newService.closes, 0);
      await service.close();
      await newService.close();
    });

    for (final status in [MaterialRetrievalResolutionStatus.stale,
      MaterialRetrievalResolutionStatus.unavailable]) {
      testWidgets('$status cannot open and labels old evidence until explicit fresh Search', (tester) async {
        // Given a rendered hit whose current source is stale or no longer available.
        final service = _Service()..resolutionStatus = status;
        final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
        await controller.search();
        final opened = <MaterialRetrievalDocument>[];
        await tester.pumpWidget(_app(controller, (value) async { opened.add(value); }));
        final retained = _button(tester, 'open-0');
        // When the old result resolves and an old captured Open closure is invoked again.
        retained();
        await _frames(tester);
        retained();
        await _frames(tester);
        // Then no source opens; the snippet is clearly non-actionable search-time evidence.
        expect(opened, isEmpty);
        expect(service.resolves, 1);
        expect(find.text('検索時点の参考情報（開くことはできません）'),
          status == MaterialRetrievalResolutionStatus.stale ? findsOneWidget : findsNothing);
        if (status == MaterialRetrievalResolutionStatus.stale) {
          expect(_buttonOrNull(tester, 'open-0'), isNull);
        } else {
          expect(find.byType(SelectableText), findsNothing);
          expect(find.byKey(const ValueKey('material-retrieval-open-0')), findsNothing);
          expect(controller.result, isNull);
        }
        expect(find.textContaining(status == MaterialRetrievalResolutionStatus.stale
          ? '出典が更新されています' : '出典は削除されたか'), findsOneWidget);
        service.resolutionStatus = MaterialRetrievalResolutionStatus.available;
        await _tap(tester, 'search');
        await _tap(tester, 'open-0');
        expect(opened, [_document()]);
        await _cleanup(tester, controller, service);
      });
    }

    for (final action in ['search', 'rebuild', 'cancel', 'open-0']) {
      for (final gate in ['false', 'throw', 'reenter', 'detach']) {
        testWidgets('$gate live interaction gate denies retained $action command', (tester) async {
          // Given a rendered command whose policy will change without a widget rebuild.
          final service = _Service();
          final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
          if (action == 'open-0') {
            await controller.search();
          }
          var mode = 'allow';
          bool allowed() {
            if (mode == 'throw') {
              throw StateError('policy failed');
            }
            if (mode == 'reenter') {
              controller.setQuery('replacement');
              return true;
            }
            if (mode == 'detach') {
              unawaited(controller.detach());
              return true;
            }
            return mode != 'false';
          }
          var opens = 0;
          await tester.pumpWidget(_app(controller, (_) async { opens++; }, allowed: allowed));
          if (action == 'cancel') {
            service.searchGate = Completer<MaterialRetrievalResult>();
            await _tap(tester, 'search');
          }
          final retained = _button(tester, action);
          final searches = service.searches;
          // When the former enabled closure calls a false/throwing/reentrant live gate.
          mode = gate;
          retained();
          await _frames(tester);
          // Then the callback grants no stale capability and launches no new service/navigation work.
          expect(service.searches, searches);
          expect(service.rebuilds, 0);
          expect(service.resolves, 0);
          expect(opens, 0);
          if (action == 'cancel') {
            expect(service.tokens.single!.isCanceled, gate == 'reenter' || gate == 'detach');
            service.searchGate!.complete(service.result(MaterialRetrievalQuery('日本語')));
            await _frames(tester);
          }
          await _cleanup(tester, controller, service);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final change in ['controller', 'callback', 'interaction', 'query', 'result', 'remove']) {
      testWidgets('retained Open denies $change replacement before invocation', (tester) async {
        // Given an exact rendered result/owner and a separately prepared replacement owner.
        final service = _Service();
        final replacementService = _Service();
        final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
        final replacement = MaterialRetrievalController(service: replacementService)..setQuery('別');
        await controller.search();
        var selected = controller;
        var present = true;
        var opens = 0;
        Future<void> open(MaterialRetrievalDocument _) async { opens++; }
        Future<void> otherOpen(MaterialRetrievalDocument _) async { opens += 100; }
        var callback = open;
        bool originalGate() => true;
        bool replacementGate() => true;
        var gate = originalGate;
        late StateSetter rebuild;
        await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
          rebuild = setState;
          return present ? _body(selected, callback, allowed: gate) : const SizedBox();
        })));
        final retained = _button(tester, 'open-0');
        // When a rendered identity changes before the old closure runs.
        if (change == 'query') {
          controller.setQuery('changed');
        } else if (change == 'result') {
          await controller.search();
        } else {
          rebuild(() {
            if (change == 'controller') { selected = replacement; }
            if (change == 'callback') { callback = otherOpen; }
            if (change == 'interaction') { gate = replacementGate; }
            if (change == 'remove') { present = false; }
          });
        }
        await _frames(tester);
        retained();
        await _frames(tester);
        // Then no old closure resolves/navigates or changes a replacement query/controller.
        expect(opens, 0);
        expect(service.resolves, 0);
        expect(replacement.query, '別');
        expect(replacementService.searches, 0);
        expect(controller.isClosed, isFalse);
        await tester.pumpWidget(const SizedBox());
        await controller.detach();
        controller.dispose();
        await replacement.detach();
        replacement.dispose();
        expect(service.closes, 0);
        expect(replacementService.closes, 0);
        await service.close();
        await replacementService.close();
      });
    }

    for (final change in ['controller', 'callback', 'interaction', 'remove', 'covered', 'popped']) {
      testWidgets('pending resolution denies $change owner before onOpen', (tester) async {
        // Given a rendered Open held in current-source resolution by an explicit gate.
        final service = _Service()..resolveGate = Completer<MaterialRetrievalResolution>();
        final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
        final replacementService = _Service();
        final replacement = MaterialRetrievalController(service: replacementService);
        await controller.search();
        final navigator = GlobalKey<NavigatorState>();
        var selected = controller;
        var present = true;
        var opens = 0;
        Future<void> open(MaterialRetrievalDocument _) async { opens++; }
        Future<void> otherOpen(MaterialRetrievalDocument _) async { opens += 100; }
        var callback = open;
        bool firstGate() => true;
        bool nextGate() => true;
        var gate = firstGate;
        late StateSetter rebuild;
        await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
          home: const Scaffold(body: Text('underlying route'))));
        unawaited(navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) =>
          StatefulBuilder(builder: (_, setState) {
            rebuild = setState;
            return present ? _body(selected, callback, allowed: gate) : const SizedBox();
          }))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _frames(tester);
        await _tap(tester, 'open-0');
        // When owner, policy, callback or the actual initiating route retires during resolution.
        if (change == 'covered') {
          unawaited(navigator.currentState!.push<void>(MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('cover')))));
        } else if (change == 'popped') {
          navigator.currentState!.pop();
        } else {
          rebuild(() {
            if (change == 'controller') { selected = replacement; }
            if (change == 'callback') { callback = otherOpen; }
            if (change == 'interaction') { gate = nextGate; }
            if (change == 'remove') { present = false; }
          });
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _frames(tester);
        service.resolveGate!.complete(MaterialRetrievalResolution(
          status: MaterialRetrievalResolutionStatus.available, document: _document()));
        await _frames(tester);
        // Then available source data never reaches an obsolete navigation callback or replacement UI.
        expect(opens, 0);
        expect(service.resolves, 1);
        expect(replacement.result, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await controller.detach();
        controller.dispose();
        await replacement.detach();
        replacement.dispose();
        await service.close();
        await replacementService.close();
      });
    }

    testWidgets('covered retained closure is denied and current route can explicitly open after uncover', (tester) async {
      // Given a current root result and its exact captured Open callback.
      final service = _Service();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      final navigator = GlobalKey<NavigatorState>();
      var opens = 0;
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
        home: _body(controller, (_) async { opens++; })));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      final retained = _button(tester, 'open-0');
      // When an actual covering route is pushed, then later popped.
      unawaited(navigator.currentState!.push<void>(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('cover')))));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      retained();
      await _frames(tester);
      expect(service.resolves, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      await _tap(tester, 'open-0');
      // Then only a current explicit action resolves the source exactly once.
      expect(opens, 1);
      expect(service.resolves, 1);
      await _cleanup(tester, controller, service);
    });

    testWidgets('own onOpen may push and await navigation without duplicate invocation', (tester) async {
      // Given an available source and a navigation callback that waits for its own pushed route.
      final service = _Service();
      final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
      await controller.search();
      final navigator = GlobalKey<NavigatorState>();
      var opens = 0;
      var returns = 0;
      Future<void> open(MaterialRetrievalDocument value) async {
        expectSync(value, _document());
        opens++;
        await navigator.currentState!.push<void>(MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('opened source'))));
        returns++;
      }
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: _body(controller, open)));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      final retained = _button(tester, 'open-0');
      // When explicit Open invokes and awaits that actual pushed source route.
      retained();
      await _frames(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      retained();
      await _frames(tester);
      expect(opens, 1);
      expect(returns, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      // Then its legitimate navigation completes once without stale error or duplicate resolution.
      expect(returns, 1);
      expect(service.resolves, 1);
      expect(find.textContaining('資料を開けませんでした'), findsNothing);
      await _cleanup(tester, controller, service);
    });

    for (final change in ['none', 'replacement', 'remove']) {
      testWidgets('callback failure after $change is observed only by its current widget owner', (tester) async {
        // Given an Open callback that remains pending after receiving its exact current source.
        final service = _Service();
        final controller = MaterialRetrievalController(service: service)..setQuery('日本語');
        await controller.search();
        final replacementService = _Service();
        final replacement = MaterialRetrievalController(service: replacementService)..setQuery('replacement');
        final callback = Completer<void>();
        var selected = controller;
        var present = true;
        var calls = 0;
        Future<void> open(MaterialRetrievalDocument _) { calls++; return callback.future; }
        late StateSetter rebuild;
        await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
          rebuild = setState;
          return present ? _body(selected, open) : const SizedBox();
        })));
        await _tap(tester, 'open-0');
        // When the original callback fails after its widget owner is retained, replaced or removed.
        rebuild(() {
          if (change == 'replacement') { selected = replacement; }
          if (change == 'remove') { present = false; }
        });
        await _frames(tester);
        callback.completeError(StateError('/private/navigation-failure'));
        await _frames(tester);
        // Then failure is consumed, and only the unchanged owner displays a friendly message.
        expect(calls, 1);
        expect(find.textContaining('資料を開けませんでした'),
          change == 'none' ? findsOneWidget : findsNothing);
        expect(find.textContaining('/private/navigation-failure'), findsNothing);
        expect(replacement.query, 'replacement');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await controller.detach();
        controller.dispose();
        await replacement.detach();
        replacement.dispose();
        expect(service.closes, 0);
        await service.close();
        await replacementService.close();
      });
    }
  });
}

final _query = find.byKey(const ValueKey('material-retrieval-query'));

Widget _app(MaterialRetrievalController controller,
  Future<void> Function(MaterialRetrievalDocument) open, {bool Function()? allowed,}
) => MaterialApp(home: _body(controller, open, allowed: allowed));

Widget _body(MaterialRetrievalController controller,
  Future<void> Function(MaterialRetrievalDocument) open, {bool Function()? allowed,}
) => Scaffold(body: SingleChildScrollView(child: Column(children: [
  MaterialRetrievalPanel(controller: controller, onOpen: open, interactionAllowed: allowed),
  const TextField(key: ValueKey('manual-editor')),
])));

VoidCallback? _buttonOrNull(WidgetTester tester, String action) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey('material-retrieval-$action'))).onPressed;
VoidCallback _button(WidgetTester tester, String action) => _buttonOrNull(tester, action)!;

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, String action, {bool realIo = false}) async {
  await _frames(tester);
  final finder = find.byKey(ValueKey('material-retrieval-$action'));
  await tester.ensureVisible(finder);
  if (realIo) {
    await tester.runAsync(() => tester.tap(finder));
  } else {
    await tester.tap(finder);
  }
  await _frames(tester);
}

Future<void> _waitForCommand(WidgetTester tester, MaterialRetrievalController controller) async {
  for (var i = 0; i < 500 && controller.busy; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(controller.busy, isFalse, reason: 'bounded actual retrieval settlement');
}

Future<void> _cleanup(WidgetTester tester, MaterialRetrievalController controller,
  MaterialRetrievalService service,
) async {
  await tester.pumpWidget(const SizedBox());
  await controller.detach();
  controller.dispose();
  await service.close();
}

MaterialRetrievalDocument _document({String text = 'そのままの日本語 😀e\u0301 ＡＢ１２'}) =>
    MaterialRetrievalDocument(reference: MaterialSourceReference(
      materialSetId: 'book', sourceId: 'quote', materialId: 'material', regionId: 'region'),
      revision: 'r1', title: '資料の題名', sourceLabel: '原文の引用', text: text,
      availability: MaterialSourceAvailability.available);

final class _Corpus implements MaterialRetrievalCorpus {
  _Corpus(this.documents);
  final List<MaterialRetrievalDocument> documents;
  int loads = 0;
  @override
  Future<MaterialRetrievalCorpusSnapshot> load() async {
    loads++;
    return MaterialRetrievalCorpusSnapshot(corpusId: 'books', documents: documents);
  }
}

/// Isolated typed paint/lifecycle port; this is not backend qualification.
final class _Service implements MaterialRetrievalService {
  List<MaterialRetrievalDocument> documents = [_document()];
  Completer<MaterialRetrievalResult>? searchGate;
  Completer<MaterialRetrievalResolution>? resolveGate;
  Object? failure;
  int searches = 0;
  int resolves = 0;
  int rebuilds = 0;
  int closes = 0;
  int? totalMatches;
  int? indexedCount;
  MaterialRetrievalResolutionStatus resolutionStatus = MaterialRetrievalResolutionStatus.available;
  final tokens = <MaterialRetrievalCancellation?>[];
  final resolveTokens = <MaterialRetrievalCancellation?>[];
  @override
  MaterialRetrievalCapability get capability => const LocalLexicalRetrievalProvider().capability;
  MaterialRetrievalResult result(MaterialRetrievalQuery query) {
    final actual = const LocalLexicalRetrievalProvider().search(query,
      MaterialRetrievalCorpusSnapshot(corpusId: 'books', documents: documents));
    return MaterialRetrievalResult(query: query, capability: capability, hits: actual.hits,
      totalMatches: totalMatches ?? actual.totalMatches,
      indexedSourceCount: indexedCount ?? actual.indexedSourceCount);
  }
  @override
  Future<MaterialRetrievalResult> search(MaterialRetrievalQuery query,
    {MaterialRetrievalCancellation? cancellation}) {
    searches++;
    tokens.add(cancellation);
    final error = failure;
    if (error != null) {
      return Future.error(error);
    }
    return searchGate?.future ?? Future.value(result(query));
  }
  @override
  Future<MaterialRetrievalResolution> resolve(MaterialRetrievalHit hit,
    {MaterialRetrievalCancellation? cancellation}) {
    resolves++;
    resolveTokens.add(cancellation);
    return resolveGate?.future ?? Future.value(MaterialRetrievalResolution(
      status: resolutionStatus,
      document: resolutionStatus == MaterialRetrievalResolutionStatus.unavailable ? null
        : resolutionStatus == MaterialRetrievalResolutionStatus.stale
          ? _document(text: '更新された日本語') : hit.document));
  }
  @override
  Future<void> rebuild({MaterialRetrievalCancellation? cancellation}) async { rebuilds++; }
  @override
  Future<void> close() async { closes++; }
}

final class _TrackingService implements MaterialRetrievalService {
  _TrackingService(this.delegate);
  final MaterialRetrievalService delegate;
  Future<Object?>? pending;
  int searches = 0;
  int resolves = 0;
  int closes = 0;
  @override
  MaterialRetrievalCapability get capability => delegate.capability;
  @override
  Future<MaterialRetrievalResult> search(MaterialRetrievalQuery query,
    {MaterialRetrievalCancellation? cancellation}) {
    searches++;
    final future = delegate.search(query, cancellation: cancellation);
    pending = future;
    return future;
  }
  @override
  Future<MaterialRetrievalResolution> resolve(MaterialRetrievalHit hit,
    {MaterialRetrievalCancellation? cancellation}) {
    resolves++;
    final future = delegate.resolve(hit, cancellation: cancellation);
    pending = future;
    return future;
  }
  @override
  Future<void> rebuild({MaterialRetrievalCancellation? cancellation}) =>
      delegate.rebuild(cancellation: cancellation);
  @override
  Future<void> close() async { closes++; await delegate.close(); }
}
