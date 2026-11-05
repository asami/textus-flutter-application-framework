import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

const _configuration = ResourceListDetailConfiguration(
  listTitle: 'Resources',
  detailTitle: 'Detail',
  primaryField: 'name',
  detailFields: [ResourceFieldConfiguration(key: 'summary', label: 'Summary')],
);

void main() {
  group('Shared semantic owners and independent presentation attachments', () {
    testWidgets('L1 a new sibling reads after build without notifying during build', (
      tester,
    ) async {
      // Given a mounted borrower observing externally owned collection/detail.
      final session = _session(tester, 'shared');
      final first = session.borrow();
      final second = session.borrow();
      final firstDisplay = session.display();
      final secondDisplay = session.display();
      Widget root({required bool includeSecond}) => MaterialApp(
        home: Row(
          children: [
            Expanded(child: _page(first, firstDisplay, key: const Key('first'))),
            if (includeSecond)
              Expanded(child: _page(second, secondDisplay, key: const Key('second'))),
          ],
        ),
      );
      await tester.pumpWidget(root(includeSecond: false));
      await tester.pumpAndSettle();
      expect(session.source.reads, 1);
      expect(first.resources!.single, same(session.source.record));
      await first.select('shared');
      firstDisplay.openDetail();
      await tester.pumpAndSettle();

      // When a second presentation attaches to those exact semantic owners.
      await tester.pumpWidget(root(includeSecond: true));
      await tester.pumpAndSettle();

      // Then each attachment reads in the post-frame phase without sibling errors.
      expect(session.source.reads, 2);
      expect(session.source.phases, everyElement(SchedulerPhase.postFrameCallbacks));
      expect(first, isNot(same(second)));
      expect(firstDisplay, isNot(same(secondDisplay)));
      expect(first.collectionView, same(second.collectionView));
      expect(first.detailView, same(second.detailView));
      expect(second.resources!.map((record) => record.id), ['shared']);
      expect(first.selectedResource, same(session.source.record));
      expect(second.selectedResource, same(session.source.record));
      expect(firstDisplay.compactDetailRequested, isTrue);
      expect(secondDisplay.compactDetailRequested, isFalse);
      expect(find.text('Summary of shared'), findsOneWidget);
      expect(find.text('Resource shared'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('L2 same-model rebuilding stays idle and explicit Refresh reads once', (
      tester,
    ) async {
      // Given a mounted public presentation with a configured selected detail.
      final session = _session(tester, 'selected');
      final model = session.borrow();
      final display = session.display();
      await tester.pumpWidget(_root(model, display));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resource selected'));
      await tester.pumpAndSettle();
      expect(model.selectedId, 'selected');
      expect(find.text('Summary of selected'), findsOneWidget);

      // When an ordinary reconstruction retains the same model attachment.
      await tester.pumpWidget(_root(model, display));
      await tester.pumpAndSettle();

      // Then it neither reloads nor changes the configured selected record.
      expect(session.source.reads, 1);
      expect(model.selectedResource, same(session.source.record));
      expect(find.text('Summary of selected'), findsOneWidget);

      // When the actual public Refresh toolbar action is tapped.
      await tester.tap(find.byKey(const Key('refresh')));
      await tester.pumpAndSettle();

      // Then exactly one further immediate read retains detail selection.
      expect(session.source.reads, 2);
      expect(session.source.phases.first, SchedulerPhase.postFrameCallbacks);
      expect(session.source.phases.last, isNot(SchedulerPhase.postFrameCallbacks));
      expect(model.selectedId, 'selected');
      expect(model.selectedResource, same(session.source.record));
      expect(find.text('Summary of selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('L3 same-State replacement reads B and detaches A observation', (
      tester,
    ) async {
      // Given two external semantic owners and one mounted keyed presentation on A.
      final a = _session(tester, 'A');
      final b = _session(tester, 'B');
      final oldModel = a.borrow();
      final newModel = b.borrow();
      final display = a.display();
      var detailBuilds = 0;
      Widget supplement(BuildContext context, ResourceRecord record) {
        detailBuilds++;
        return Text('Supplement ${record.id}');
      }
      await tester.pumpWidget(_root(oldModel, display, supplement: supplement));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resource A'));
      await tester.pumpAndSettle();
      expect(find.text('Summary of A'), findsOneWidget);

      // When the same keyed widget receives B and selects B's actual list row.
      await tester.pumpWidget(_root(newModel, display, supplement: supplement));
      await tester.pumpAndSettle();
      display.showList();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resource B'));
      await tester.pumpAndSettle();

      // Then exactly B's attachment reads and selected content comes from B.
      expect(a.source.reads, 1);
      expect(b.source.reads, 1);
      expect(b.source.phases, [SchedulerPhase.postFrameCallbacks]);
      expect(newModel.selectedResource, same(b.source.record));
      expect(find.text('Summary of B'), findsOneWidget);
      expect(find.text('Supplement B'), findsOneWidget);
      expect(find.text('Summary of A'), findsNothing);
      final buildsBeforeOldNotification = detailBuilds;

      // When the detached external A model reads and selects again.
      await oldModel.load();
      await oldModel.select('A');
      await tester.pump();

      // Then A stays usable without rebuilding B or publishing A's selection.
      expect(detailBuilds, buildsBeforeOldNotification);
      expect(oldModel.resources!.single, same(a.source.record));
      expect(oldModel.selectedResource, same(a.source.record));
      expect(newModel.selectedResource, same(b.source.record));
      expect(find.text('Summary of B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Reservations before drawing a frame', () {
    testWidgets('L4 removal before the callback starts no read', (tester) async {
      // Given a real State built through the public binding before a frame draws.
      final session = _session(tester, 'removed');
      final model = session.borrow();
      final display = session.display();
      _buildBeforeFrame(tester, _bare(model, display));
      expect(find.byType(ResourceListDetail), findsOneWidget);
      expect(session.source.reads, 0);

      // When the presentation is removed and finalized before its reserved frame.
      _buildBeforeFrame(tester, const SizedBox.shrink());
      await tester.pump();

      // Then the actual callback cannot start a removed attachment's read.
      expect(session.source.reads, 0);
      expect(model.resources, isNull);
      expect(find.byType(ResourceListDetail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('L4 A-to-B replacement before the callback starts only B', (
      tester,
    ) async {
      // Given A mounted without drawing its reserved frame and external B ready.
      final a = _session(tester, 'reserved-A');
      final b = _session(tester, 'reserved-B');
      final oldModel = a.borrow();
      final newModel = b.borrow();
      final display = a.display();
      _buildBeforeFrame(tester, _bare(oldModel, display));
      expect(a.source.reads, 0);

      // When the same keyed State attaches B before the callbacks are pumped.
      _buildBeforeFrame(tester, _bare(newModel, display));
      expect(b.source.reads, 0);
      await tester.pump();
      await tester.pumpAndSettle();

      // Then only B's current reservation starts and exact B data is rendered.
      expect(a.source.reads, 0);
      expect(oldModel.resources, isNull);
      expect(b.source.reads, 1);
      expect(b.source.phases, [SchedulerPhase.postFrameCallbacks]);
      expect(newModel.resources!.map((record) => record.id), ['reserved-B']);
      expect(find.text('Resource reserved-B'), findsOneWidget);
      expect(find.text('Resource reserved-A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Started reads and explicit recovery', () {
    testWidgets('L5 a held read completes after unmount and external owners stay usable', (
      tester,
    ) async {
      // Given an actual source read held behind finite entry/release/completion gates.
      final session = _session(tester, 'late');
      final model = session.borrow();
      final display = session.display();
      final gate = session.source.holdNextRead();
      await tester.pumpWidget(_root(model, display));
      await _until(tester, () => gate.entered.isCompleted);
      expect(session.source.reads, 1);
      expect(model.listLoading, isTrue);
      expect(gate.completed.isCompleted, isFalse);

      // When the borrower unmounts and its source owner releases the started read.
      await tester.pumpWidget(const SizedBox.shrink());
      gate.release();
      await _until(tester, () => gate.completed.isCompleted && !model.listLoading);

      // Then root semantic views retain exact results with no UI resurrection/error.
      expect(session.collection.resources!.single, same(session.source.record));
      expect(model.resources!.map((record) => record.id), ['late']);
      expect(find.byType(ResourceListDetail), findsNothing);
      expect(tester.takeException(), isNull);

      // When external semantic/display owners are explicitly used after removal.
      await model.load();
      await model.select('late');
      var displayNotices = 0;
      void listener() {
        displayNotices++;
      }
      display.addListener(listener);
      display.focusDetail();
      display.removeListener(listener);

      // Then another real read and selection succeed and the display was not disposed.
      expect(session.source.reads, 2);
      expect(session.collection.resources!.single, same(session.source.record));
      expect(session.detail.resource, same(session.source.record));
      expect(model.selectedId, 'late');
      expect(displayNotices, 1);
      expect(find.byType(ResourceListDetail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final failure in [false, true]) {
      testWidgets('L6 ${failure ? 'failed' : 'empty'} auto read rebuild stays idle and Refresh recovers', (
        tester,
      ) async {
        // Given an actual finite held source yielding either empty success or failure.
        final session = _session(tester, 'recovered');
        session.source.empty = !failure;
        session.source.error = failure ? StateError('private source failure') : null;
        final model = session.borrow();
        final display = session.display();
        final gate = session.source.holdNextRead();
        await tester.pumpWidget(_root(model, display));
        await _until(tester, () => gate.entered.isCompleted);
        expect(model.listLoading, isTrue);

        // When the source owner releases the read and its real outcome completes.
        gate.release();
        await _until(tester, () => gate.completed.isCompleted && !model.listLoading);
        await tester.pumpAndSettle();

        // Then empty and failed results remain observably distinct and safe.
        expect(model.listFailed, failure);
        expect(find.text('一覧を読み込めませんでした。'), failure ? findsOneWidget : findsNothing);
        expect(find.text('項目がありません'), failure ? findsNothing : findsOneWidget);
        expect(find.textContaining('private source failure'), findsNothing);
        expect(model.resources, failure ? isNull : isEmpty);
        expect(session.source.reads, 1);
        expect(session.source.phases, [SchedulerPhase.postFrameCallbacks]);

        // Given a source recovered independently of the current presentation.
        session.source.empty = false;
        session.source.error = null;
        // When an ordinary reconstruction uses that same model.
        await tester.pumpWidget(_root(model, display));
        await tester.pumpAndSettle();
        // Then rebuilding does not retry or invent successful data.
        expect(session.source.reads, 1);
        expect(model.listFailed, failure);
        expect(find.text('Resource recovered'), findsNothing);

        // When the user's actual public Refresh action retries that source.
        await tester.tap(find.byKey(const Key('refresh')));
        await tester.pumpAndSettle();
        // Then exactly one new read recovers actual IDs and configured selection.
        expect(session.source.reads, 2);
        expect(model.listFailed, isFalse);
        expect(model.resources!.map((record) => record.id), ['recovered']);
        expect(find.text('Resource recovered'), findsOneWidget);
        await tester.tap(find.text('Resource recovered'));
        await tester.pumpAndSettle();
        expect(model.selectedResource, same(session.source.record));
        expect(find.text('Summary of recovered'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _page(
  ResourceViewModel model,
  ResourceListDetailDisplayModel display, {
  Key key = const Key('presentation'),
  Widget Function(BuildContext, ResourceRecord)? supplement,
}) => ResourceListDetail(
  key: key,
  configuration: _configuration,
  viewModel: model,
  displayModel: display,
  detailSupplementBuilder: supplement,
  additionalActions: [
    IconButton(
      key: const Key('refresh'),
      tooltip: 'Refresh',
      icon: const Icon(Icons.refresh),
      onPressed: model.load,
    ),
  ],
);

Widget _root(
  ResourceViewModel model,
  ResourceListDetailDisplayModel display, {
  Widget Function(BuildContext, ResourceRecord)? supplement,
}) => MaterialApp(home: _page(model, display, supplement: supplement));

Widget _bare(ResourceViewModel model, ResourceListDetailDisplayModel display) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Localizations(
          locale: const Locale('en'),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          // L4 omits the unused caller Refresh action because this pre-frame root has no Overlay.
          child: Theme(
            data: ThemeData(),
            child: ResourceListDetail(
              key: const Key('presentation'),
              configuration: _configuration,
              viewModel: model,
              displayModel: display,
            ),
          ),
        ),
      ),
    );

void _buildBeforeFrame(WidgetTester tester, Widget root) {
  final binding = tester.binding;
  binding.attachRootWidget(binding.wrapWithDefaultView(root));
  binding.buildOwner!.buildScope(binding.rootElement!);
  binding.buildOwner!.finalizeTree();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100; frame++) {
    if (ready()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 1));
  }
  throw StateError('Public lifecycle operation exceeded its finite frame budget');
}

_Session _session(WidgetTester tester, String id) {
  final session = _Session(_Source(id));
  addTearDown(() async {
    // Given fixture-owned operations and borrowed mounted presentations.
    session.source.releaseAll();
    // When teardown removes widgets and observes released reads before disposal.
    await tester.pumpWidget(const SizedBox.shrink());
    await _until(tester, () => !session.collection.loading);
    // Then semantic and display owners are disposed only by their fixture owner.
    session.dispose();
  });
  return session;
}

final class _Session {
  _Session(this.source) {
    collection = ResourceCollectionView(dataSource: source);
    detail = ResourceDetailView(dataSource: source);
  }

  final _Source source;
  late final ResourceCollectionView collection;
  late final ResourceDetailView detail;
  final _borrowers = <ResourceViewModel>[];
  final _displays = <ResourceListDetailDisplayModel>[];

  ResourceViewModel borrow() {
    final model = ResourceViewModel.fromViews(collectionView: collection, detailView: detail);
    _borrowers.add(model);
    return model;
  }

  ResourceListDetailDisplayModel display() {
    final model = ResourceListDetailDisplayModel();
    _displays.add(model);
    return model;
  }

  void dispose() {
    for (final model in _borrowers) {
      model.dispose();
    }
    for (final display in _displays) {
      display.dispose();
    }
    detail.dispose();
    collection.dispose();
  }
}

final class _ReadGate {
  final entered = Completer<void>();
  final completed = Completer<void>();
  final _released = Completer<void>();

  void release() {
    if (!_released.isCompleted) {
      _released.complete();
    }
  }
}

final class _Source implements ResourceDataSource {
  _Source(String id) : record = ResourceRecord(
    id: id,
    values: {'name': 'Resource $id', 'summary': 'Summary of $id'},
  );

  final ResourceRecord record;
  final phases = <SchedulerPhase>[];
  final _gates = <_ReadGate>[];
  _ReadGate? _nextGate;
  int reads = 0;
  bool empty = false;
  Object? error;

  _ReadGate holdNextRead() {
    final gate = _ReadGate();
    _gates.add(gate);
    _nextGate = gate;
    return gate;
  }

  void releaseAll() {
    for (final gate in _gates) {
      gate.release();
    }
  }

  @override
  Future<List<ResourceRecord>> listResources() async {
    reads++;
    phases.add(SchedulerBinding.instance.schedulerPhase);
    final gate = _nextGate;
    _nextGate = null;
    gate?.entered.complete();
    try {
      if (gate != null) {
        await gate._released.future.timeout(const Duration(seconds: 10));
      }
      if (error != null) {
        throw error!;
      }
      return empty ? const [] : [record];
    } finally {
      gate?.completed.complete();
    }
  }

  @override
  Future<ResourceRecord?> getResource(String id) async => id == record.id ? record : null;
}
