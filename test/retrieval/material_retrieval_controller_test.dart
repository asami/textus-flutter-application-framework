import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  late Directory directory;
  late FileCaptureStore files;
  late _Corpus corpus;
  late LocalMaterialRetrievalService service;
  late MaterialRetrievalController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tfaf-retrieval-');
    files = FileCaptureStore(directory.path);
    corpus = _Corpus([_document()]);
    service = LocalMaterialRetrievalService(store: files, corpus: corpus, corpusId: 'books');
    controller = MaterialRetrievalController(service: service);
  });
  tearDown(() async {
    await controller.detach();
    controller.dispose();
    await service.close();
    await directory.delete(recursive: true);
  });

  group('shared capture storage and actual lexical results', () {
    test('factory is inert and borrows the exact durable capture store', () async {
      // Given a facade over an observed real store with retained human history.
      final observed = _Store(files);
      final facade = CaptureStorageFacade(store: observed);
      await facade.saveDocument('human_history', 'one', {'text': '保存済みの手入力'});
      final reads = observed.reads;
      final writes = observed.writes;
      final local = facade.createMaterialRetrievalService(corpus: corpus, corpusId: 'books');
      final owner = MaterialRetrievalController(service: local);
      // When constructing and typing, no source or index IO is performed.
      owner.setQuery('日本語 ab12');
      expect(corpus.loads, 0);
      expect(observed.reads, reads);
      expect(observed.writes, writes);
      await owner.search();
      await owner.detach();
      owner.dispose();
      await local.close();
      final persisted = await facade.readDocument(
        LocalMaterialRetrievalService.indexCollection, 'books');
      final reopenedCorpus = _Corpus([_document(text: '新しい日本語 ＡＢ１２', revision: 'r2')]);
      final reopened = CaptureStorageFacade(store: FileCaptureStore(directory.path))
          .createMaterialRetrievalService(corpus: reopenedCorpus, corpusId: 'books');
      final current = await reopened.search(MaterialRetrievalQuery('日本語 ab12'));
      await reopened.close();
      await facade.saveDocument('human_history', 'two', {'text': '次の手入力'});
      // Then exact-store calls, persisted cache and fresh authority survive service closure.
      expect(observed.reads, reads + 2);
      expect(observed.writes, writes + 2);
      expect(persisted!['corpusId'], 'books');
      expect((persisted['documents']! as List).single, containsPair('text', _document().text));
      expect(current.hits.single.document, reopenedCorpus.documents.single);
      expect(reopenedCorpus.loads, 1);
      expect(await facade.readDocument('human_history', 'one'), {'text': '保存済みの手入力'});
      expect(await facade.readDocument('human_history', 'two'), {'text': '次の手入力'});
    });

    test('Japanese width AND terms retain exact snippets and bounded counts', () async {
      // Given 51 matching current sources and one source missing the second term.
      final text = '${'前' * 60}日本語 😀e\u0301 ＡＢ１２${'後' * 180}';
      corpus.documents = [
        for (var i = 0; i < 51; i++) _document(id: 'source-${i.toString().padLeft(2, '0')}', text: text),
        _document(id: 'no-and', text: '日本語だけ'),
      ];
      // When explicit Search submits the exact human buffer through real Core.
      controller.setQuery(' 日本語　ab12 ');
      await controller.search();
      final result = controller.result!;
      final hit = result.hits.first;
      // Then literal normalization/AND and scalar evidence are Core's actual values.
      expect(controller.query, ' 日本語　ab12 ');
      expect(result.query.text, controller.query);
      expect(result.hits, hasLength(50));
      expect(result.totalMatches, 51);
      expect(result.indexedSourceCount, 52);
      expect(result.hasMore, isTrue);
      expect(hit.snippet, String.fromCharCodes(text.runes.toList()
        .sublist(hit.snippetStart, hit.snippetEnd)));
      expect(hit.snippetStart, 20);
      expect(hit.snippetEnd, 180);
      expect(result.capability.mode, MaterialRetrievalMode.lexical);
      expect(result.capability.supportsSemanticRetrieval, isFalse);
    });

    test('blank is inert and an explicit no-hit query is empty', () async {
      // Given a new owner with no submitted query.
      controller.setQuery(' \t　');
      // When Search is requested for blank input, then for an unmatched literal.
      await controller.search();
      expect(corpus.loads, 0);
      expect(controller.canSearch, isFalse);
      controller.setQuery('存在しない語句');
      await controller.search();
      // Then blank never invokes IO and a real no-hit result preserves truthful counts.
      expect(controller.status, MaterialRetrievalStatus.empty);
      expect(controller.result!.hits, isEmpty);
      expect(controller.result!.totalMatches, 0);
      expect(controller.result!.hasMore, isFalse);
      expect(corpus.loads, 1);
    });

    test('query bounds preserve the exact editable buffer and allow retry', () async {
      // Given input over Core's scalar bound, with no controller-side truncation.
      final input = '語' * 257;
      controller.setQuery(input);
      // When explicit Search validates the query, then a human shortens and retries.
      await controller.search();
      expect(controller.query, input);
      expect(controller.error, isArgumentError);
      expect(controller.status, MaterialRetrievalStatus.error);
      expect(controller.result, isNull);
      expect(corpus.loads, 0);
      controller.setQuery('日本語');
      await controller.search();
      // Then the corrected buffer is usable and the old error cannot hide the new result.
      expect(controller.error, isNull);
      expect(controller.status, MaterialRetrievalStatus.ready);
      expect(controller.result!.hits.single.document, _document());
    });

    test('actual IO failure clears old success without a cached fallback', () async {
      // Given a successful real query and a corpus whose next actual file read fails.
      controller.setQuery('日本語');
      await controller.search();
      corpus.onLoad = () async {
        await File('${directory.path}/missing-source').readAsString();
        return corpus.snapshot;
      };
      // When the same explicit query reloads current authority.
      await controller.search();
      // Then the observable original failure cannot masquerade as an old successful hit.
      expect(controller.error, isA<FileSystemException>());
      expect(controller.status, MaterialRetrievalStatus.error);
      expect(controller.query, '日本語');
      expect(controller.result, isNull);
      expect(controller.busy, isFalse);
    });

    test('malformed index requires explicit rebuild followed by manual search', () async {
      // Given actual durable malformed index data in the facade's selected collection.
      await files.saveDocument(LocalMaterialRetrievalService.indexCollection, 'books', {'version': 900});
      controller.setQuery('日本語');
      // When Search reports corruption, then the human explicitly rebuilds that cache.
      await controller.search();
      expect(controller.error, isA<FormatException>());
      expect(corpus.loads, 0);
      await controller.rebuild();
      // Then a notice and intact query require another explicit Search to produce results.
      expect(controller.rebuildCompleted, isTrue);
      expect(controller.query, '日本語');
      expect(controller.result, isNull);
      expect(corpus.loads, 1);
      expect((await files.readDocument(LocalMaterialRetrievalService.indexCollection, 'books'))!['version'], 1);
      await controller.search();
      expect(controller.status, MaterialRetrievalStatus.ready);
      expect(controller.rebuildCompleted, isFalse);
      expect(corpus.loads, 2);
    });

    for (final change in ['update', 'delete', 'denied']) {
      test('$change source cannot open from an old result; fresh query restores authority', () async {
        // Given a real published hit whose complete current source changes later.
        controller.setQuery('日本語');
        await controller.search();
        final hit = controller.result!.hits.single;
        corpus.documents = switch (change) {
          'update' => [_document(text: '更新された日本語', revision: 'r2')],
          'delete' => [],
          _ => [_document(availability: MaterialSourceAvailability.denied)],
        };
        // When opening the captured hit resolves current authority twice.
        final resolution = await controller.resolveHit(hit);
        final loads = corpus.loads;
        final repeated = await controller.resolveHit(hit);
        // Then no old open is admitted and old callbacks cannot become replacement navigation.
        expect(resolution, isNull);
        expect(repeated, isNull);
        expect(corpus.loads, loads);
        expect(controller.resolution!.status, change == 'update'
          ? MaterialRetrievalResolutionStatus.stale : MaterialRetrievalResolutionStatus.unavailable);
        if (change != 'update') {
          expect(controller.resolution!.document, isNull);
          expect(controller.result, isNull);
        }
        // Given restored current permission/content, only a fresh explicit Search can re-admit it.
        final current = _document(text: '現在の日本語', revision: 'r3');
        corpus.documents = [current];
        // When the human searches and opens that new result.
        await controller.search();
        final available = await controller.resolveHit(controller.result!.hits.single);
        // Then exactly the new current source is available, with the former result retired.
        expect(available!.status, MaterialRetrievalResolutionStatus.available);
        expect(available.document, current);
        expect(await controller.resolveHit(hit), isNull);
      });
    }
  });

  group('owned commands and adversarial public callback boundaries', () {
    test('launch listener Cancel prevents service IO before it starts', () async {
      // Given a current query with a listener canceling the original launch reservation.
      final port = _Port(service);
      final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
      owner.addListener(() {
        if (owner.canCancel) {
          owner.cancel();
        }
      });
      // When Search notifies its synchronous launch listener before crossing the service port.
      await owner.search();
      // Then cancellation is typed by its owned token and no underlying source IO starts.
      expect(port.searches, 0);
      expect(corpus.loads, 0);
      expect(owner.status, MaterialRetrievalStatus.canceled);
      expect(owner.busy, isFalse);
      await owner.detach();
      owner.dispose();
    });

    test('detach joins only its own original future while another owner remains active', () async {
      // Given a completed original owner and a different owner's gated real source load.
      controller.setQuery('日本語');
      await controller.search();
      final entered = Completer<void>();
      final release = Completer<MaterialRetrievalCorpusSnapshot>();
      corpus.onLoad = () {
        entered.complete();
        return release.future;
      };
      final other = MaterialRetrievalController(service: service)..setQuery('日本語');
      final running = other.search();
      await entered.future;
      // When the completed original owner detaches while the shared service is still busy elsewhere.
      await controller.detach();
      // Then detachment returns without joining or canceling the other owner's borrowed service tail.
      expect(controller.isClosed, isTrue);
      expect(other.busy, isTrue);
      release.complete(corpus.snapshot);
      await running;
      expect(other.result!.hits, hasLength(1));
      await other.detach();
      other.dispose();
    });

    test('unsupported service remains unavailable with exact input and no fallback', () async {
      // Given a public service port that truthfully rejects this platform.
      final port = _Port(service)..searchFailure = UnsupportedError('private/path');
      final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
      // When an explicit query reaches that unsupported port.
      await owner.search();
      // Then the controller preserves the actual error and input without inventing results.
      expect(owner.status, MaterialRetrievalStatus.unavailable);
      expect(owner.error, isUnsupportedError);
      expect(owner.query, '日本語');
      expect(owner.result, isNull);
      await owner.detach();
      owner.dispose();
      expect(port.closes, 0);
    });

    for (final action in ['cancel', 'type', 'detach', 'dispose']) {
      test('$action during real corpus IO retains original cleanup and borrowed ownership', () async {
        // Given actual Core/file IO held at the caller's current-corpus public port.
        final entered = Completer<void>();
        final release = Completer<MaterialRetrievalCorpusSnapshot>();
        corpus.onLoad = () {
          entered.complete();
          return release.future;
        };
        final port = _Port(service);
        final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
        final command = owner.search();
        await entered.future;
        var joined = false;
        Future<void>? joining;
        // When the original owner is canceled, edited, detached or synchronously disposed.
        switch (action) {
          case 'cancel': owner.cancel();
          case 'type': owner.setQuery('  次の語句　');
          case 'detach': joining = owner.detach().then((_) => joined = true);
          case 'dispose':
            owner.dispose();
            joining = owner.detach().then((_) => joined = true);
        }
        await owner.search();
        expect(owner.busy, isTrue);
        expect(port.searches, 1);
        expect(joined, isFalse);
        release.complete(corpus.snapshot);
        await command;
        if (joining != null) {
          await joining;
        }
        // Then original cleanup releases busy without old success or borrowed service closure.
        expect(owner.busy, isFalse);
        expect(owner.result, isNull);
        expect(owner.query, action == 'type' ? '  次の語句　' : '日本語');
        expect(port.closes, 0);
        expect(port.tokens.single!.isCanceled, isTrue);
        if (action == 'cancel') {
          expect(owner.status, MaterialRetrievalStatus.canceled);
        }
        if (action == 'type') {
          expect(owner.status, MaterialRetrievalStatus.idle);
        }
        await owner.detach();
        owner.dispose();
        corpus.onLoad = null;
        expect((await service.search(MaterialRetrievalQuery('日本語'))).hits, hasLength(1));
      });
    }

    test('typed cancellation from public service is observable without future error', () async {
      // Given a service reporting its typed cancellation before producing evidence.
      final port = _Port(service)..searchFailure = const MaterialRetrievalCanceled();
      final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
      // When the explicit Search future settles.
      await owner.search();
      // Then the typed outcome is canceled and neither result nor unhandled failure escapes.
      expect(owner.status, MaterialRetrievalStatus.canceled);
      expect(owner.error, isA<MaterialRetrievalCanceled>());
      expect(owner.result, isNull);
      await owner.detach();
      owner.dispose();
    });

    for (final action in ['query', 'detach']) {
      test('source callback $action reentry cannot publish an old document', () async {
        // Given actual Core source authority reentering its controller during a source load.
        controller.setQuery('日本語');
        corpus.onLoad = () async {
          if (action == 'query') {
            controller.setQuery('  新しい入力　');
          } else {
            unawaited(controller.detach());
          }
          return corpus.snapshot;
        };
        // When explicit Search crosses the application-owned corpus callback.
        await controller.search();
        // Then no old result/error overwrites the replacement query or retired owner.
        expect(controller.result, isNull);
        expect(controller.error, isNull);
        expect(controller.query, action == 'query' ? '  新しい入力　' : '日本語');
        expect(controller.isClosed, action == 'detach');
        expect(controller.busy, isFalse);
        expect(await files.readDocument(LocalMaterialRetrievalService.indexCollection, 'books'), isNull);
      });
    }

    for (final operation in ['resolve', 'rebuild']) {
      test('detach joins original $operation cleanup without closing its borrowed service', () async {
        // Given a genuine source plus a later gated authority lookup for resolve/rebuild.
        controller.setQuery('日本語');
        await controller.search();
        final hit = controller.result!.hits.single;
        final entered = Completer<void>();
        final release = Completer<MaterialRetrievalCorpusSnapshot>();
        corpus.onLoad = () {
          entered.complete();
          return release.future;
        };
        final Future<void> running = operation == 'resolve'
          ? controller.resolveHit(hit).then<void>((_) {}) : controller.rebuild();
        await entered.future;
        var joined = false;
        // When this owner detaches while that original operation still borrows source IO.
        final joining = controller.detach().then((_) { joined = true; });
        expect(joined, isFalse);
        expect(controller.busy, isTrue);
        release.complete(corpus.snapshot);
        await running;
        await joining;
        // Then detachment joins actual cleanup, rejects new work and leaves the service usable.
        expect(joined, isTrue);
        expect(controller.busy, isFalse);
        expect(controller.rebuildCompleted, isFalse);
        await controller.search();
        await controller.rebuild();
        expect(corpus.loads, 2);
        corpus.onLoad = null;
        expect((await service.search(MaterialRetrievalQuery('日本語'))).hits, hasLength(1));
      });
    }

    for (final stage in ['launch', 'capability', 'completion']) {
      for (final action in ['query', 'close', 'throw']) {
        test('$stage $action callback cannot launch or publish obsolete work', () async {
          // Given an owner whose external listener/capability can retire the original reservation.
          final port = _Port(service);
          final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
          var fired = false;
          void retire() {
            if (fired) {
              return;
            }
            fired = true;
            switch (action) {
              case 'query': owner.setQuery('新しい入力');
              case 'close': owner.dispose();
              case 'throw': throw StateError('listener failed');
            }
          }
          if (stage == 'capability') {
            port.onCapability = retire;
          } else {
            owner.addListener(() {
              if (stage == 'launch' ? owner.busy : owner.result != null) {
                retire();
              }
            });
          }
          // When Search crosses that synchronous launch/completion callback.
          await owner.search();
          // Then only a still-current owner may expose results, and no replacement is overwritten.
          expect(fired, isTrue);
          expect(port.searches, stage == 'completion' ? 1 : 0);
          if (action != 'close') {
            expect(owner.result, isNull);
          }
          expect(owner.query, action == 'query' ? '新しい入力' : '日本語');
          expect(owner.busy, isFalse);
          expect(port.closes, 0);
          await owner.detach();
          owner.dispose();
        });
      }
    }

    test('ordinary listeners keep current work valid and canceled owner does not cancel another owner', () async {
      // Given two controllers borrowing one real service and an ordinary repaint listener.
      final entered = Completer<void>();
      final release = Completer<MaterialRetrievalCorpusSnapshot>();
      var firstLoad = true;
      corpus.onLoad = () {
        if (firstLoad) {
          firstLoad = false;
          entered.complete();
          return release.future;
        }
        return Future.value(corpus.snapshot);
      };
      final other = MaterialRetrievalController(service: service)..setQuery('日本語');
      var repaints = 0;
      controller.addListener(() => repaints++);
      controller.setQuery('日本語');
      final original = controller.search();
      await entered.future;
      final successor = other.search();
      // When the original is canceled and another owner's queued request continues.
      controller.cancel();
      release.complete(corpus.snapshot);
      await original;
      await successor;
      // Then cancellation remains token-local and ordinary repaint does not retire valid work.
      expect(controller.result, isNull);
      expect(other.result!.hits.single.document, _document());
      expect(repaints, greaterThanOrEqualTo(3));
      await other.detach();
      other.dispose();
    });

    test('resolve completion listener retires its available return value', () async {
      // Given a valid current result and a listener editing as resolution completes.
      controller.setQuery('日本語');
      await controller.search();
      final hit = controller.result!.hits.single;
      controller.addListener(() {
        if (controller.resolution != null) {
          controller.setQuery('別の入力');
        }
      });
      // When the actual service reports the available source to that completion listener.
      final value = await controller.resolveHit(hit);
      // Then no available value escapes after the listener changes the query owner witness.
      expect(value, isNull);
      expect(controller.query, '別の入力');
      expect(controller.result, isNull);
      expect(controller.resolution, isNull);
    });

    test('resolve launch listener retires admission before source lookup', () async {
      // Given a genuine hit whose owner changes its query during the resolving notification.
      controller.setQuery('日本語');
      await controller.search();
      final hit = controller.result!.hits.single;
      final loads = corpus.loads;
      controller.addListener(() {
        if (controller.status == MaterialRetrievalStatus.resolving) {
          controller.setQuery('新しい語句');
        }
      });
      // When an old rendered hit requests resolution through that reentrant listener.
      final value = await controller.resolveHit(hit);
      // Then no obsolete source lookup starts or clears the replacement query.
      expect(value, isNull);
      expect(corpus.loads, loads);
      expect(controller.query, '新しい語句');
      expect(controller.result, isNull);
    });

    test('resolve completion can start a successor without old cleanup clearing it', () async {
      // Given a current source and a completion listener starting another owned Search.
      controller.setQuery('日本語');
      await controller.search();
      final hit = controller.result!.hits.single;
      var started = false;
      Future<void>? successor;
      controller.addListener(() {
        if (!started && !controller.busy && controller.resolution != null) {
          started = true;
          successor = controller.search();
        }
      });
      // When the old resolve completes and that listener takes a new reservation.
      final value = await controller.resolveHit(hit);
      await successor;
      // Then the old available value is retired while the successor's actual result remains valid.
      expect(started, isTrue);
      expect(value, isNull);
      expect(controller.result!.hits.single.document, _document());
      expect(controller.status, MaterialRetrievalStatus.ready);
      expect(controller.error, isNull);
    });

    test('synchronous same-hit successor retires the old resolve and retains its own reservation', () async {
      // Given actual Core/file storage with two gated current-source lookups.
      final port = _Port(service);
      final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
      await owner.search();
      final result = owner.result!;
      final hit = result.hits.single;
      final renderedVersion = owner.resultVersion;
      final firstEntered = Completer<void>();
      final secondEntered = Completer<void>();
      final firstRelease = Completer<MaterialRetrievalCorpusSnapshot>();
      final secondRelease = Completer<MaterialRetrievalCorpusSnapshot>();
      var lookups = 0;
      corpus.onLoad = () {
        lookups++;
        if (lookups == 1) {
          firstEntered.complete();
          return firstRelease.future;
        }
        secondEntered.complete();
        return secondRelease.future;
      };
      var started = false;
      int? successorVersion;
      Future<MaterialRetrievalResolution?>? successor;
      void startSuccessor() {
        if (!started && !owner.busy &&
            owner.resolution?.status == MaterialRetrievalResolutionStatus.available) {
          started = true;
          successor = owner.resolveHit(hit);
          successorVersion = owner.resultVersion;
        }
      }
      owner.addListener(startSuccessor);
      final original = owner.resolveHit(hit);
      final originalVersion = owner.resultVersion;
      try {
        await firstEntered.future;
        // When completion synchronously reserves another resolve on the identical hit.
        firstRelease.complete(corpus.snapshot);
        final retired = await original;
        await secondEntered.future;
        // Then the original admission is retired while the new original IO remains owned.
        expect(retired, isNull);
        expect(started, isTrue);
        expect(originalVersion, greaterThan(renderedVersion));
        expect(successorVersion, greaterThan(originalVersion));
        expect(owner.resultVersion, successorVersion);
        expect(identical(owner.result, result), isTrue);
        expect(identical(owner.result!.hits.single, hit), isTrue);
        expect(owner.busy, isTrue);
        expect(owner.canCancel, isTrue);
        expect(port.resolves, 2);
        expect(port.resolveTokens, hasLength(2));
        expect(identical(port.resolveTokens.first, port.resolveTokens.last), isFalse);
        expect(port.resolveTokens.every((token) => token != null && !token.isCanceled), isTrue);
        expect(corpus.loads, 3);
        expect(port.closes, 0);
        // When the successor's own source lookup completes normally.
        secondRelease.complete(corpus.snapshot);
        final available = await successor;
        // Then only that successor grants the exact current source and settles its busy state.
        expect(available?.status, MaterialRetrievalResolutionStatus.available);
        expect(available?.document, hit.document);
        expect(owner.resolution, same(available));
        expect(owner.result, same(result));
        expect(owner.resultVersion, successorVersion);
        expect(owner.status, MaterialRetrievalStatus.ready);
        expect(owner.busy, isFalse);
        expect(owner.error, isNull);
        expect(port.closes, 0);
      } finally {
        owner.removeListener(startSuccessor);
        if (!firstRelease.isCompleted) {
          firstRelease.complete(corpus.snapshot);
        }
        if (!secondRelease.isCompleted) {
          secondRelease.complete(corpus.snapshot);
        }
        await original;
        await successor;
        await owner.detach();
        owner.dispose();
        corpus.onLoad = null;
      }
    });

    test('resolve cannot grant an altered available source from an adversarial port', () async {
      // Given an actual searched hit but an external port returning another available address.
      final port = _Port(service);
      final owner = MaterialRetrievalController(service: port)..setQuery('日本語');
      await owner.search();
      port.resolveValue = MaterialRetrievalResolution(
        status: MaterialRetrievalResolutionStatus.available,
        document: _document(id: 'different'));
      // When the selected hit resolves through that public port.
      final value = await owner.resolveHit(owner.result!.hits.single);
      // Then the altered address is an observable error and never navigation permission.
      expect(value, isNull);
      expect(owner.error, isStateError);
      expect(owner.result, isNull);
      await owner.detach();
      owner.dispose();
    });

    for (final outcome in ['failure', 'unsupported', 'cancel']) {
      test('explicit rebuild $outcome preserves truthful status without success notice', () async {
        // Given a controller whose rebuild operation returns a public terminal failure.
        final port = _Port(service)..rebuildFailure = switch (outcome) {
          'failure' => const FormatException('bad cache'),
          'unsupported' => UnsupportedError('unsupported'),
          _ => const MaterialRetrievalCanceled(),
        };
        final owner = MaterialRetrievalController(service: port)..setQuery('exact query');
        // When the human explicitly rebuilds.
        await owner.rebuild();
        // Then failure/unavailability/cancellation cannot claim a successful recreated index.
        expect(owner.status, switch (outcome) {
          'failure' => MaterialRetrievalStatus.error,
          'unsupported' => MaterialRetrievalStatus.unavailable,
          _ => MaterialRetrievalStatus.canceled,
        });
        expect(owner.rebuildCompleted, isFalse);
        expect(owner.query, 'exact query');
        expect(owner.result, isNull);
        await owner.detach();
        owner.dispose();
      });
    }
  });
}

MaterialRetrievalDocument _document({String id = 'quote', String revision = 'r1',
  String text = '原文の日本語 😀e\u0301 ＡＢ１２',
  MaterialSourceAvailability availability = MaterialSourceAvailability.available,
}) => MaterialRetrievalDocument(
  reference: MaterialSourceReference(materialSetId: 'book', sourceId: id,
    materialId: 'material', regionId: 'region'),
  revision: revision, title: '本の引用', sourceLabel: '引用欄', text: text,
  availability: availability);

final class _Corpus implements MaterialRetrievalCorpus {
  _Corpus(this.documents);
  List<MaterialRetrievalDocument> documents;
  int loads = 0;
  Future<MaterialRetrievalCorpusSnapshot> Function()? onLoad;
  MaterialRetrievalCorpusSnapshot get snapshot =>
      MaterialRetrievalCorpusSnapshot(corpusId: 'books', documents: documents);
  @override
  Future<MaterialRetrievalCorpusSnapshot> load() {
    loads++;
    return onLoad?.call() ?? Future.value(snapshot);
  }
}

final class _Port implements MaterialRetrievalService {
  _Port(this.delegate);
  final MaterialRetrievalService delegate;
  int searches = 0;
  int resolves = 0;
  int closes = 0;
  Object? searchFailure;
  Object? rebuildFailure;
  void Function()? onCapability;
  MaterialRetrievalResolution? resolveValue;
  final tokens = <MaterialRetrievalCancellation?>[];
  final resolveTokens = <MaterialRetrievalCancellation?>[];
  @override
  MaterialRetrievalCapability get capability {
    onCapability?.call();
    return delegate.capability;
  }
  @override
  Future<MaterialRetrievalResult> search(MaterialRetrievalQuery query,
    {MaterialRetrievalCancellation? cancellation}) {
    searches++;
    tokens.add(cancellation);
    final failure = searchFailure;
    return failure == null ? delegate.search(query, cancellation: cancellation)
        : Future.error(failure);
  }
  @override
  Future<MaterialRetrievalResolution> resolve(MaterialRetrievalHit hit,
    {MaterialRetrievalCancellation? cancellation}) {
    resolves++;
    resolveTokens.add(cancellation);
    return resolveValue == null ? delegate.resolve(hit, cancellation: cancellation)
      : Future.value(resolveValue!);
  }
  @override
  Future<void> rebuild({MaterialRetrievalCancellation? cancellation}) {
    final failure = rebuildFailure;
    return failure == null ? delegate.rebuild(cancellation: cancellation)
        : Future.error(failure);
  }
  @override
  Future<void> close() async {
    closes++;
    await delegate.close();
  }
}

final class _Store implements LocalCaptureStore {
  _Store(this.delegate);
  final LocalCaptureStore delegate;
  int reads = 0;
  int writes = 0;
  @override
  Future<Map<String, Object?>?> readDocument(String collection, String id) {
    reads++;
    return delegate.readDocument(collection, id);
  }
  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) {
    writes++;
    return delegate.saveDocument(collection, id, document);
  }
  @override
  Future<List<String>> listDocumentIds(String collection) => delegate.listDocumentIds(collection);
  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) => delegate.readMaterial(reference);
  @override
  Future<CaptureMaterialReference> saveMaterial({required Uint8List bytes,
    required String mediaType, required DateTime capturedAt, String? originalName,
  }) => delegate.saveMaterial(bytes: bytes, mediaType: mediaType,
    capturedAt: capturedAt, originalName: originalName);
}
