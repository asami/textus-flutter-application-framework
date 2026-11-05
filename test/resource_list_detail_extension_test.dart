import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

const _configuration = ResourceListDetailConfiguration(
  listTitle: 'Resources',
  detailTitle: 'Detail',
  primaryField: 'name',
  detailFields: [ResourceFieldConfiguration(key: 'summary', label: 'Summary')],
  detailActions: [ResourceActionConfiguration(id: 'review', label: 'Review item')],
);

void main() {
  for (final width in [400.0, 1000.0]) {
    testWidgets('G1 defaults preserve selection and configured detail at $width', (
      tester,
    ) async {
      // Given the existing public binding with neither optional argument.
      final session = _session(tester);
      await _mount(tester, session, width: width);
      expect(session.model.selectedId, isNull);
      expect(find.byTooltip('Reload'), findsNothing);
      expect(find.textContaining('Supplement'), findsNothing);
      if (width == 1000) {
        // Then expanded default detail still begins with its selection prompt.
        expect(find.text('項目を選択してください'), findsOneWidget);
      }

      // When the user selects a real public list tile.
      await tester.tap(find.text('First item'));
      await tester.pumpAndSettle();

      // Then configured fields/actions and the same selected object are retained.
      expect(session.model.selectedResource, same(session.source.first));
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('First summary'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Review item'), findsOneWidget);
      expect(find.text('Handler review'), findsNothing);
      expect(find.textContaining('Supplement'), findsNothing);
      expect(find.byTooltip('Reload'), findsNothing);
      if (width == 400) {
        // Then compact defaults expose the established detail back control.
        expect(find.byType(BackButton), findsOneWidget);
      } else {
        // Then expanded defaults keep the list and detail focus control.
        expect(find.text('Second item'), findsOneWidget);
        expect(find.byKey(const Key('resource-detail-focus')), findsOneWidget);
      }
    });

    testWidgets('G2 exact selected record and refreshed content at $width', (
      tester,
    ) async {
      // Given a public source and a caller's scrolling presentation builder.
      final session = _session(tester);
      final received = <ResourceRecord>[];
      Widget supplement(BuildContext context, ResourceRecord record) {
        received.add(record);
        expect(Theme.of(context), isNotNull);
        return Column(
          children: [
            const SizedBox(height: 950),
            Text('Supplement ${record.value('summary')}'),
          ],
        );
      }
      await _mount(tester, session, width: width, supplement: supplement);
      expect(received, isEmpty);

      // When actual selection builds a ready detail.
      await tester.tap(find.text('First item'));
      await tester.pumpAndSettle();

      // Then the exact source object coexists with configured fields/actions.
      expect(received, isNotEmpty);
      expect(received.every((record) => identical(record, session.source.first)),
          isTrue);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Review item'), findsOneWidget);
      final detailScroll = find.ancestor(
        of: find.text('Supplement First summary'),
        matching: find.byType(Scrollable),
      );
      expect(detailScroll, findsOneWidget);
      expect(tester.element(find.ancestor(of: find.text('Summary'),
          matching: find.byType(Scrollable))), same(tester.element(detailScroll)));

      // When content beyond the initial viewport is scrolled into view and painted.
      await tester.scrollUntilVisible(find.text('Supplement First summary'), 250,
          scrollable: detailScroll);
      await tester.pumpAndSettle();

      // Then the supplement is reachable in the same detail scroll.
      expect(find.text('Supplement First summary').hitTestable(), findsOneWidget);

      // When the public detail refresh returns a new value for the same identity.
      final refreshed = ResourceRecord(
        id: session.source.first.id,
        values: {'name': 'First item', 'summary': 'Updated summary'},
      );
      session.source.first = refreshed;
      await session.model.detailView.refresh();
      await tester.pumpAndSettle();

      // Then the callback receives the new exact object without an identity change.
      expect(session.model.selectedId, refreshed.id);
      expect(received.last, same(refreshed));
      expect(find.text('Supplement Updated summary'), findsOneWidget);
      expect(find.text('Supplement First summary'), findsNothing);
    });

    testWidgets('G3 observed delayed detail admits only success at $width', (
      tester,
    ) async {
      // Given a finite delayed selected read and an initially absent supplement.
      final session = _session(tester);
      final gate = session.source.holdDetail('first');
      final received = <ResourceRecord>[];
      var taps = 0;
      await _mount(tester, session, width: width,
          actions: _actions(() => taps++), supplement: (_, record) {
        received.add(record);
        return Text('Supplement ${record.id}');
      });
      expect(received, isEmpty);

      // When a real tile selection is pumped into the held request.
      await tester.tap(find.text('First item'));
      await tester.pump();
      await gate.entered.future;

      // Then loading contains no stale/supplemental data or callback invocation.
      expect(session.model.detailLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(received, isEmpty);
      expect(find.textContaining('Supplement'), findsNothing);
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(taps, 0);

      // When the finite read is released, pumped and observed terminally.
      gate.release(session.source.first);
      await tester.pump();
      await gate.settled.future;
      await tester.pumpAndSettle();

      // Then only the ready exact record admits supplementary content.
      expect(session.model.detailLoading, isFalse);
      expect(received.last, same(session.source.first));
      expect(find.text('Supplement first'), findsOneWidget);
      if (width == 400) {
        // When compact detail returns to the list with selection retained.
        final before = received.length;
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        // Then hidden compact detail never invokes the builder.
        expect(received.length, before);
        expect(find.textContaining('Supplement'), findsNothing);
        expect(session.model.selectedId, 'first');
      }
    });

    for (final missing in [false, true]) {
      testWidgets('G3 safe ${missing ? 'missing' : 'failed'} detail at $width', (
        tester,
      ) async {
        // Given ready content followed by an exact missing or failed result.
        final session = _session(tester);
        final received = <ResourceRecord>[];
        var taps = 0;
        await _mount(tester, session, width: width,
            actions: _actions(() => taps++), supplement: (_, record) {
          received.add(record);
          return Text('Supplement ${record.id}');
        });
        await tester.tap(find.text('First item'));
        await tester.pumpAndSettle();
        expect(find.text('Supplement first'), findsOneWidget);
        final before = received.length;
        session.source.missingDetail = missing;
        session.source.detailError = missing ? null : StateError('private read');

        // When the public detail refresh settles with that result.
        await session.model.detailView.refresh();
        await tester.pumpAndSettle();

        // Then the existing safe diagnostic replaces all supplemental stale data.
        expect(find.text(missing ? '項目が見つかりません' : '詳細を読み込めませんでした。'),
            findsOneWidget);
        expect(find.textContaining('private read'), findsNothing);
        expect(find.textContaining('Supplement'), findsNothing);
        expect(received.length, before);
        expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
        expect(taps, 0);
        // When the caller explicitly taps recovery on the diagnostic detail.
        await tester.tap(find.byTooltip('Reload'));
        // Then only that explicit tap invokes its callback.
        expect(taps, 1);
      });
    }

    testWidgets('G5 caller toolbar remains explicit across presentations at $width', (
      tester,
    ) async {
      // Given enabled/disabled caller actions and no resource selection.
      final session = _session(tester);
      var taps = 0;
      final actions = _actions(() => taps++);
      await _mount(tester, session, width: width, actions: actions);
      expect(taps, 0);
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Unavailable')).onPressed,
          isNull);

      // When only the enabled caller action is explicitly tapped.
      await tester.tap(find.byTooltip('Unavailable'));
      await tester.tap(find.byTooltip('Reload'));
      await tester.pump();
      // Then disabled/build behavior causes no callbacks, and one tap causes one.
      expect(taps, 1);

      // When a public list selection opens detail.
      await tester.tap(find.text('First item'));
      await tester.pumpAndSettle();
      // Then caller actions remain reachable beside established layout controls.
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(taps, 1);
      if (width == 400) {
        // When compact detail uses its existing back control.
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        // Then the caller action remains reachable on the list.
        expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      } else {
        // When existing expanded focus and restore controls are used.
        await tester.tap(find.byKey(const Key('resource-detail-focus')));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
        await tester.tap(find.byKey(const Key('resource-restore-split')));
        await tester.pumpAndSettle();
        // Then both the existing focus and appended caller action return.
        expect(find.byKey(const Key('resource-detail-focus')), findsOneWidget);
        expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      }

      // Given a finite collection refresh, when the actual read is pumped and held.
      final gate = session.source.holdList();
      final loading = session.model.load();
      await tester.pump();
      await gate.entered.future;
      // Then loading still permits explicit caller recovery controls.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Unavailable')).onPressed,
          isNull);
      expect(taps, 1);

      // When the held list is released empty and its continuations are pumped.
      gate.release(const []);
      await tester.pump();
      await loading;
      await gate.settled.future;
      await tester.pumpAndSettle();
      // Then empty presentation keeps the action reachable.
      expect(find.text('項目がありません'), findsOneWidget);
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Unavailable')).onPressed,
          isNull);

      // When a subsequent public list load fails with an internal diagnostic.
      session.source.listError = StateError('private list');
      await session.model.load();
      await tester.pumpAndSettle();
      // Then safe failure still admits an explicit action without invoking it.
      expect(find.text('一覧を読み込めませんでした。'), findsOneWidget);
      expect(find.textContaining('private list'), findsNothing);
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
      expect(tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Unavailable')).onPressed,
          isNull);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('G4 keyed child updates and borrowed owners outlive removal', (
    tester,
  ) async {
    // Given caller state recording its own ordinary Flutter lifetime.
    final session = _session(tester);
    final events = <String>[];
    Widget supplement(BuildContext _, ResourceRecord record) =>
        _LifetimeContent(record: record, events: events);
    await _mount(tester, session, width: 1000, supplement: supplement);

    // When first and then second are selected through real list tiles.
    await tester.tap(find.text('First item'));
    await tester.pumpAndSettle();
    expect(events.where((event) => event == 'init:first'), hasLength(1));
    await tester.tap(find.text('Second item'));
    await tester.pumpAndSettle();
    // Then the different identity disposes first and initializes second once.
    expect(events.where((event) => event == 'dispose:first'), hasLength(1));
    expect(events.where((event) => event == 'init:second'), hasLength(1));
    expect(find.text('Owned First summary'), findsNothing);
    expect(find.text('Owned Second summary'), findsOneWidget);

    // When a same-ID refresh settles before the next ordinary widget rebuild.
    final updated = ResourceRecord(id: 'second', values: {
      'name': 'Second item', 'summary': 'Changed second',
    });
    session.source.second = updated;
    await session.model.detailView.refresh();
    await tester.pumpAndSettle();
    // Then child didUpdateWidget receives the exact refreshed record in its state.
    expect(events, contains('update:second:Changed second'));
    expect(events.where((event) => event == 'init:second'), hasLength(1));
    expect(events.where((event) => event == 'dispose:second'), isEmpty);
    expect(tester.widget<_LifetimeContent>(find.byType(_LifetimeContent)).record,
        same(updated));
    expect(find.text('Owned Changed second'), findsOneWidget);

    // When the caller removes its optional content and then unmounts the tree.
    await _mount(tester, session, width: 1000);
    await tester.pumpWidget(const SizedBox.shrink());
    // Then the current child is disposed once by Flutter.
    expect(events.where((event) => event == 'dispose:second'), hasLength(1));

    // When test-owned borrowed models are independently used after unmount.
    var notifications = 0;
    void changed() => notifications++;
    session.model.addListener(changed);
    session.display.addListener(changed);
    await session.model.load();
    await session.model.select('first');
    session.display.showList();
    session.display.focusDetail();
    // Then presentation removal has not disposed either borrowed authority.
    expect(notifications, greaterThan(0));
    expect(session.model.selectedResource, same(session.source.first));
    expect(session.display.preference,
        ResourceListDetailDisplayPreference.detailFocused);
    session.model.removeListener(changed);
    session.display.removeListener(changed);
  });

  testWidgets('G4 old held read cannot resurrect an earlier identity', (
    tester,
  ) async {
    // Given a finite first-record read and public View generation ownership.
    final session = _session(tester);
    final gate = session.source.holdDetail('first');
    final events = <String>[];
    await _mount(tester, session, width: 1000, supplement: (_, record) =>
        _LifetimeContent(record: record, events: events));

    // When first is pumped into a held read and second becomes the ready selection.
    await tester.tap(find.text('First item'));
    await tester.pump();
    await gate.entered.future;
    expect(find.byType(_LifetimeContent), findsNothing);
    await tester.tap(find.text('Second item'));
    await tester.pumpAndSettle();
    expect(find.text('Owned Second summary'), findsOneWidget);

    // When the old request is released, pumped and its terminal future is observed.
    gate.release(session.source.first);
    await tester.pump();
    await gate.settled.future;
    await tester.pumpAndSettle();
    // Then only second persists, with no first content lifetime resurrected.
    expect(session.model.selectedId, 'second');
    expect(session.model.selectedResource, same(session.source.second));
    expect(events, isNot(contains('init:first')));
    expect(find.text('Owned First summary'), findsNothing);

    // When the containing Widget unmounts with content still supplied.
    await tester.pumpWidget(const SizedBox.shrink());
    // Then the mounted child is disposed exactly once.
    expect(events.where((event) => event == 'dispose:second'), hasLength(1));
  });

  testWidgets('G5 hinge controls precede caller toolbar actions', (tester) async {
    // Given a viable public hinge geometry and caller toolbar widget.
    final session = _session(tester);
    var taps = 0;
    await _mount(tester, session, width: 1000, actions: _actions(() => taps++),
        media: const MediaQueryData(size: Size(1000, 800), displayFeatures: [
          DisplayFeature(bounds: Rect.fromLTWH(490, 0, 20, 800),
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureFlat),
        ]));
    // When actual selection adds the common detail focus control.
    await tester.tap(find.text('First item'));
    await tester.pumpAndSettle();
    // Then hinge/focus ordering and safe separated panes are preserved.
    expect(find.byKey(const Key('fold-separation')), findsOneWidget);
    final actions = tester.widget<AppBar>(find.byType(AppBar)).actions!;
    expect(actions[0].key, const Key('resource-hinge-policy'));
    expect(actions[1].key, const Key('resource-detail-focus'));
    expect(actions[2].key, const Key('caller-reload'));
    expect(taps, 0);
    // When the common hinge menu is opened and dismissed, then caller remains usable.
    await tester.tap(find.byKey(const Key('resource-hinge-policy')));
    await tester.pumpAndSettle();
    expect(find.text('ヒンジを避ける'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reload'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('G5 narrow OS/common scaling keeps action and tall content reachable', (
    tester,
  ) async {
    // Given the public settings/text boundary at 320px, OS2 and common1.3.
    final session = _session(tester);
    final service = _TextSettings();
    final settings = SettingsView.fromService(service: service);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      service.dispose();
    });
    var taps = 0;
    await _mount(tester, session, width: 320, settings: settings,
        actions: _actions(() => taps++), supplement: (_, record) => Column(
          children: [
            for (var index = 0; index < 12; index++)
              Text('Supplement paragraph $index for ${record.id}'),
            const Text('Supplement end', key: Key('supplement-end')),
          ],
        ));
    expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);

    // When a real selection opens detail and its final paragraph is scrolled and painted.
    await tester.tap(find.text('First item'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton).hitTestable(), findsOneWidget);
    final scroll = find.ancestor(of: find.byKey(const Key('supplement-end')),
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.byKey(const Key('supplement-end')), 200,
        scrollable: scroll);
    await tester.pumpAndSettle();
    // Then natural content height scrolls without clipping/overflow at full scaling.
    expect(find.byKey(const Key('supplement-end')).hitTestable(), findsOneWidget);
    final context = tester.element(find.byKey(const Key('supplement-end')));
    expect(MediaQuery.textScalerOf(context).scale(16), closeTo(41.6, 1e-10));
    expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(taps, 0);

    // When the caller action and common back are explicitly tapped.
    await tester.tap(find.byTooltip('Reload'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // Then both remain reachable and callbacks reflect only the explicit tap.
    expect(taps, 1);
    expect(find.text('First item').hitTestable(), findsOneWidget);
    expect(find.text('Supplement end'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<Widget> _actions(VoidCallback reload) => [
  IconButton(key: const Key('caller-reload'), tooltip: 'Reload',
      onPressed: reload, icon: const Icon(Icons.refresh)),
  const IconButton(tooltip: 'Unavailable', onPressed: null,
      icon: Icon(Icons.block)),
];

_Session _session(WidgetTester tester) {
  final session = _Session();
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    // Given test-owned borrowed models, when teardown removes the mounted tree,
    // then settle all entered finite requests before their owners dispose them.
    await tester.pumpWidget(const SizedBox.shrink());
    await session.source.finishGates(tester);
    await tester.pump();
    session.model.dispose();
    session.display.dispose();
  });
  return session;
}

Future<void> _mount(WidgetTester tester, _Session session, {
  required double width,
  Widget Function(BuildContext, ResourceRecord)? supplement,
  List<Widget> actions = const [],
  MediaQueryData? media,
  SettingsView? settings,
}) async {
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(MaterialApp(
    builder: (context, navigator) {
      final navigation = navigator!;
      final child = MediaQuery(
        data: media ?? MediaQueryData(size: Size(width, 800),
            textScaler: TextScaler.linear(settings == null ? 1 : 2)),
        child: navigation,
      );
      // Given an optional borrowed text View, when mounted, then compose its
      // common preference above Navigator using the existing public boundary.
      return settings == null ? child : MediaQuery(
        data: MediaQueryData(size: Size(width, 800),
            textScaler: const TextScaler.linear(2)),
        child: ApplicationTextScaling(view: settings, child: navigation),
      );
    },
    // Given no extensions, when the baseline mounts, then omit both optional
    // arguments entirely; otherwise pass only caller-authored presentation.
    home: supplement == null && actions.isEmpty
        ? ResourceListDetail(configuration: _configuration,
            viewModel: session.model, displayModel: session.display)
        : ResourceListDetail(configuration: _configuration,
            viewModel: session.model, displayModel: session.display,
            detailSupplementBuilder: supplement, additionalActions: actions),
  ));
  await tester.pumpAndSettle();
}

class _Session {
  final source = _Resources();
  late final model = ResourceViewModel(dataSource: source, actionHandler: source);
  final display = ResourceListDetailDisplayModel();
}

class _Resources implements ResourceDataSource, ResourceActionHandler {
  ResourceRecord first = ResourceRecord(id: 'first', values: {
    'name': 'First item', 'summary': 'First summary',
  });
  ResourceRecord second = ResourceRecord(id: 'second', values: {
    'name': 'Second item', 'summary': 'Second summary',
  });
  Object? detailError;
  Object? listError;
  bool missingDetail = false;
  final _detailGates = <String, _Gate<ResourceRecord?>>{};
  final _allDetailGates = <_Gate<ResourceRecord?>>[];
  final _allListGates = <_Gate<List<ResourceRecord>>>[];
  _Gate<List<ResourceRecord>>? _listGate;

  _Gate<ResourceRecord?> holdDetail(String id) {
    final gate = _Gate<ResourceRecord?>();
    _detailGates[id] = gate;
    _allDetailGates.add(gate);
    return gate;
  }

  _Gate<List<ResourceRecord>> holdList() {
    final gate = _Gate<List<ResourceRecord>>();
    _listGate = gate;
    _allListGates.add(gate);
    return gate;
  }

  @override
  Future<List<ResourceRecord>> listResources() async {
    // Given a caller-selected finite gate or error, when the public View reads,
    // then return that exact scenario; otherwise preserve the ordinary records.
    final gate = _listGate;
    _listGate = null;
    if (gate != null) return gate.read();
    final error = listError;
    if (error != null) throw error;
    return [first, second];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    // Given a selected-ID gate, exact error or missing result, when Detail reads,
    // then expose that public outcome without synthesizing supplemental IO.
    final gate = _detailGates.remove(id);
    if (gate != null) return gate.read();
    final error = detailError;
    if (error != null) throw error;
    if (missingDetail) return null;
    return id == first.id ? first : id == second.id ? second : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) => const [
    ResourceAction(id: 'review', label: 'Handler review'),
  ];

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {}

  Future<void> finishGates(WidgetTester tester) async {
    // Given finite fixture requests created in the fake test zone.
    for (final gate in _allDetailGates) {
      gate.release(null);
    }
    for (final gate in _allListGates) {
      gate.release(const []);
    }
    // When teardown bridges entered terminal futures in its current zone
    // before pumping their fake-zone continuations.
    final terminalObservations = <Future<void>>[];
    for (final gate in _allDetailGates) {
      if (gate.entered.isCompleted) {
        terminalObservations.add(gate.settled.future.then<void>((_) {}));
      }
    }
    for (final gate in _allListGates) {
      if (gate.entered.isCompleted) {
        terminalObservations.add(gate.settled.future.then<void>((_) {}));
      }
    }
    await tester.pump();
    // Then every real terminal outcome is observed before owner disposal.
    await Future.wait(terminalObservations);
  }
}

class _Gate<T> {
  final entered = Completer<void>();
  final settled = Completer<void>();
  final _result = Completer<T>();

  Future<T> read() async {
    entered.complete();
    try {
      return await _result.future;
    } finally {
      settled.complete();
    }
  }

  void release(T value) {
    // Given a finite request, when released again during teardown,
    // then retain its original settled outcome instead of completing twice.
    if (!_result.isCompleted) _result.complete(value);
  }
}

class _LifetimeContent extends StatefulWidget {
  const _LifetimeContent({required this.record, required this.events});
  final ResourceRecord record;
  final List<String> events;
  @override
  State<_LifetimeContent> createState() => _LifetimeContentState();
}

class _LifetimeContentState extends State<_LifetimeContent> {
  @override
  void initState() {
    super.initState();
    widget.events.add('init:${widget.record.id}');
  }

  @override
  void didUpdateWidget(_LifetimeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.events.add('update:${widget.record.id}:${widget.record.value('summary')}');
  }

  @override
  void dispose() {
    widget.events.add('dispose:${widget.record.id}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Owned ${widget.record.value('summary')}');
}

class _TextSettings extends ChangeNotifier implements SettingsService {
  @override
  final registry = CommonSettings.registry();
  @override
  SettingsSnapshot get snapshot => SettingsSnapshot(registry: registry,
      values: {CommonSettings.textSizeMultiplier.id: 1.30});
  @override
  Future<void> load() async => throw StateError('Unexpected settings I/O');
  @override
  Future<void> retryLoad() => load();
  @override
  Future<void> retrySave() => load();
  @override
  void setValue(String id, Object value) => throw StateError('Unexpected edit');
  @override
  void resetCommon() => throw StateError('Unexpected reset');
}
