import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

void main() {
  testWidgets('W01 single defaults retain sequential selection', (
    tester,
  ) async {
    // Given two borrowed resource pages and a single-pane default with focus disabled.
    final session = _session(tester);
    session.view.setValue(
      CommonSettings.panePreference.id,
      SettingsPanePreference.preferSinglePane,
    );
    await _pump(tester, session, allowFocus: false);

    // When an eligible list restores split before and after sequential selection.
    expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-restore-split')));
    await tester.pumpAndSettle();
    expect(find.text('項目を選択してください'), findsOneWidget);
    session.view.setValue(
      CommonSettings.panePreference.id,
      SettingsPanePreference.preferSinglePane,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A first'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
    expect(find.text('A second'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-restore-split')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tab B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B first'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Then back keeps semantic selections and each tab uses the common consumer.
    expect(session.models[0].selectedId, 'A-first');
    expect(session.models[1].selectedId, 'B-first');
    expect(find.text('B second'), findsOneWidget);
    expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
    expect(
      session.displays[0].preferenceOverride,
      ResourceListDetailDisplayPreference.split,
    );
    expect(session.displays[1].preferenceOverride, isNull);
    expect(session.sources.map((source) => source.listCalls), [1, 1]);
    expect(session.sources.map((source) => source.getCalls), [1, 1]);
    expect(session.storage.readCount, 0);
    expect(session.storage.writeCount, 0);
    expect(session.observer.pushes, 1);
  });

  testWidgets('W02 global events retain both tab resource owners', (
    tester,
  ) async {
    // Given a visited first tab and an unmounted second tab with its own selection.
    final session = _session(tester);
    await _pump(tester, session);
    await tester.tap(find.text('A first'));
    await tester.pumpAndSettle();
    session.displays[0].focusDetail();
    session.displays[0].setHingePolicy(ResourceListDetailHingePolicy.avoid);
    await session.models[1].select('B-first');
    session.displays[1].focusDetail();
    session.displays[1].setHingePolicy(ResourceListDetailHingePolicy.span);
    final collections = session.models
        .map((model) => model.collectionView)
        .toList();
    final details = session.models.map((model) => model.detailView).toList();
    final selected = session.models
        .map((model) => model.selectedResource)
        .toList();

    // When common edits/reset reach an unmounted tab, then both visited tabs resize.
    session.view.setValue(
      CommonSettings.panePreference.id,
      SettingsPanePreference.preferSinglePane,
    );
    expect(
      session.displays.map((model) => model.preferenceOverride),
      everyElement(isNull),
    );
    expect(
      session.displays[0].hingePolicyOverride,
      ResourceListDetailHingePolicy.avoid,
    );
    expect(
      session.displays[1].hingePolicyOverride,
      ResourceListDetailHingePolicy.span,
    );
    session.view.resetCommon();
    expect(
      session.displays.map((model) => model.hingePolicyOverride),
      everyElement(isNull),
    );
    expect(session.sources[1].listCalls, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tab B'));
    await tester.pumpAndSettle();
    session.displays[1].restoreSplit();
    await tester.tap(find.text('Tab A'));
    await tester.pumpAndSettle();
    session.displays[0].focusDetail();
    final calls = session.sources
        .map(
          (source) => (source.listCalls, source.getCalls, source.actionCalls),
        )
        .toList();
    session.view.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
    session.binding.updateCapabilities(SettingsCapabilities());
    await _pump(tester, session, size: const Size(400, 900));
    session.binding.updateCapabilities(
      SettingsCapabilities(supported: {'hinge'}),
    );
    await _pump(tester, session);

    // Then settings/environment events keep owners, projections, queries and routes.
    expect(
      session.displays[0].preferenceOverride,
      ResourceListDetailDisplayPreference.detailFocused,
    );
    expect(
      session.displays[1].preferenceOverride,
      ResourceListDetailDisplayPreference.split,
    );
    for (var index = 0; index < 2; index++) {
      expect(session.models[index].collectionView, same(collections[index]));
      expect(session.models[index].detailView, same(details[index]));
      expect(session.models[index].selectedResource, same(selected[index]));
    }
    expect(
      session.sources.map(
        (source) => (source.listCalls, source.getCalls, source.actionCalls),
      ),
      calls,
    );
    expect(find.text('A detail'), findsOneWidget);
    expect(
      find.byType(ResourceListDetail, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(session.observer.pushes, 1);
    expect(session.observer.pops, 0);
    expect(session.storage.readCount, 0);
    expect(session.storage.writeCount, 0);
  });

  for (final axis in Axis.values) {
    for (final gap in [20.0, 0.0]) {
      testWidgets('W03 ${axis.name} $gap safe geometry and menu', (
        tester,
      ) async {
        // Given a measured offset body, bottom navigation and a common avoid policy.
        final session = _session(tester);
        session.view.setValue(
          CommonSettings.hingePreference.id,
          SettingsHingePreference.avoid,
        );
        final data = _feature(axis: axis, gap: gap);
        await _pump(tester, session, data: data, topOffset: 24);
        await tester.tap(find.text('A first'));
        await tester.pumpAndSettle();
        final body = _bodyRect(tester, data.size);
        final expectedList = axis == Axis.vertical
            ? Rect.fromLTRB(20, body.top, 490, body.bottom)
            : Rect.fromLTRB(20, body.top, 970, 440);
        final expectedDetail = axis == Axis.vertical
            ? Rect.fromLTRB(490 + gap, body.top, 970, body.bottom)
            : Rect.fromLTRB(20, 440 + gap, 970, body.bottom);

        // When common avoid is resolved and the menu and spanning choice are used.
        final list = _listRect(tester, session.models[0]);
        final detail = _detailRect(tester);
        await tester.tap(find.byKey(const Key('resource-hinge-policy')));
        await tester.pumpAndSettle();
        final avoid = tester
            .widget<CheckedPopupMenuItem<ResourceListDetailHingePolicy>>(
              find.byKey(const Key('resource-hinge-avoid')),
            );
        final span = tester
            .widget<CheckedPopupMenuItem<ResourceListDetailHingePolicy>>(
              find.byKey(const Key('resource-hinge-span')),
            );

        // Then both exact continuous panes and unchanged menu viability are observable.
        expect(list, expectedList);
        expect(detail, expectedDetail);
        expect(avoid.checked, isTrue);
        expect(avoid.enabled, isTrue);
        expect(span.checked, isFalse);
        expect(span.enabled, isTrue);
        expect(
          find.text('ヒンジ部分では内容が隠れる場合があります'),
          gap > 0 ? findsOneWidget : findsNothing,
        );

        // When span is chosen in the toolbar and detail is focused.
        await tester.tap(find.byKey(const Key('resource-hinge-span')));
        await tester.pumpAndSettle();
        final spanningList = _listRect(tester, session.models[0]);
        final spanningDetail = _detailRect(tester);
        await tester.tap(find.byKey(const Key('resource-detail-focus')));
        await tester.pumpAndSettle();

        // Then span preserves minimum panes, warning, selection and the whole safe body.
        expect(spanningList.left, body.left);
        expect(spanningList.width, greaterThanOrEqualTo(280));
        expect(spanningDetail.right, body.right);
        expect(spanningDetail.width, greaterThanOrEqualTo(280));
        expect(spanningDetail.left, spanningList.right + 1);
        expect(_detailRect(tester), body);
        final menu = tester
            .widget<PopupMenuButton<ResourceListDetailHingePolicy>>(
              find.byKey(const Key('resource-hinge-policy')),
            );
        expect(
          menu.tooltip,
          gap > 0
              ? contains('ヒンジ部分では内容が隠れる場合があります')
              : isNot(contains('ヒンジ部分では内容が隠れる場合があります')),
        );
        expect(
          session.view.value(CommonSettings.hingePreference),
          SettingsHingePreference.avoid,
        );
        expect(session.models[0].selectedId, 'A-first');
        expect(session.sources[0].listCalls, 1);
        expect(session.sources[0].getCalls, 1);
        expect(session.sources[0].actionCalls, 0);
      });
    }

    testWidgets('W03 ${axis.name} avoid stays compact', (tester) async {
      // Given dual preference and an asymmetric separator with undersized leading pane.
      final session = _session(tester);
      session.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferDualPane,
      );
      session.view.setValue(
        CommonSettings.hingePreference.id,
        SettingsHingePreference.avoid,
      );
      final data = _feature(
        axis: axis,
        gap: 20,
        coordinate: axis == Axis.vertical ? 200 : 180,
      );
      await _pump(tester, session, data: data);

      // When physical viability and menu enablement are resolved.
      final compact = _listRect(tester, session.models[0]);
      final body = _bodyRect(tester, data.size);
      await tester.tap(find.byKey(const Key('resource-hinge-policy')));
      await tester.pumpAndSettle();
      final avoid = tester
          .widget<CheckedPopupMenuItem<ResourceListDetailHingePolicy>>(
            find.byKey(const Key('resource-hinge-avoid')),
          );
      final span = tester
          .widget<CheckedPopupMenuItem<ResourceListDetailHingePolicy>>(
            find.byKey(const Key('resource-hinge-span')),
          );

      // Then avoid is not promoted and compact content uses the largest continuous region.
      expect(
        compact,
        axis == Axis.vertical
            ? Rect.fromLTRB(220, body.top, 970, body.bottom)
            : Rect.fromLTRB(20, 200, 970, body.bottom),
      );
      expect(avoid.checked, isTrue);
      expect(avoid.enabled, isFalse);
      expect(span.enabled, isTrue);
      expect(find.byKey(const Key('resource-restore-split')), findsNothing);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
      expect(session.displays[0].hingePolicyOverride, isNull);
      expect(session.models[0].selectedId, isNull);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // When the full viewport also becomes too small for span.
      final small = _feature(
        axis: axis,
        gap: 20,
        size: const Size(500, 400),
        coordinate: axis == Axis.vertical ? 200 : 150,
      );
      await _pump(tester, session, data: small, size: small.size);

      // Then no viable policy or expanded presentation control is offered.
      expect(find.byKey(const Key('resource-hinge-policy')), findsNothing);
      expect(find.byKey(const Key('resource-restore-split')), findsNothing);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
      expect(session.sources[0].listCalls, 1);
      expect(session.sources[0].getCalls, 0);
    });
  }

  testWidgets('W04 single default retains session across resize', (
    tester,
  ) async {
    // Given a physically eligible single default and two reusable display models.
    final session = _session(tester);
    session.view.setValue(
      CommonSettings.panePreference.id,
      SettingsPanePreference.preferSinglePane,
    );
    await _pump(tester, session);

    // When explicit split, selected focus, shrink and expansion occur.
    await tester.tap(find.byKey(const Key('resource-restore-split')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A first'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-detail-focus')));
    await tester.pumpAndSettle();
    await _pump(tester, session, size: const Size(400, 900));
    final compactFocus = find
        .byKey(const Key('resource-detail-focus'))
        .evaluate()
        .length;
    final compactRestore = find
        .byKey(const Key('resource-restore-split'))
        .evaluate()
        .length;
    await _pump(tester, session);

    // Then compact hides controls and expansion restores focused selected detail.
    expect(compactFocus, 0);
    expect(compactRestore, 0);
    expect(find.text('A second'), findsNothing);
    expect(find.text('A detail'), findsOneWidget);
    expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);

    // When explicit split is restored and space shrinks and expands again.
    await tester.tap(find.byKey(const Key('resource-restore-split')));
    await tester.pumpAndSettle();
    await _pump(tester, session, size: const Size(400, 900));
    expect(find.byKey(const Key('resource-restore-split')), findsNothing);
    await _pump(tester, session);

    // Then split and the same selection return above the bottom navigation.
    expect(find.text('A second'), findsOneWidget);
    expect(find.text('A detail'), findsOneWidget);
    expect(
      session.displays[0].preferenceOverride,
      ResourceListDetailDisplayPreference.split,
    );
    expect(session.models[0].selectedId, 'A-first');
    expect(
      _detailRect(tester).bottom,
      tester.getRect(find.byType(NavigationBar)).top,
    );
    expect(session.sources[0].listCalls, 1);
    expect(session.sources[0].getCalls, 1);
    expect(session.observer.pushes, 1);
  });

  testWidgets('W05 capability return retains stored hinge', (tester) async {
    // Given actual restoration of span with a capability-disabled common hinge.
    final session = _session(tester);
    session.binding.updateCapabilities(SettingsCapabilities());
    final load = session.view.load();
    session.storage.reads.single.succeed(
      SettingsRecord.empty().withUpdates({
        CommonSettings.hingePreference.id: 'span',
      }).encode(),
    );
    await tester.pump();
    await load;
    final saved = session.view.snapshot;
    final data = _feature(axis: Axis.vertical, gap: 20);
    await _pump(tester, session, data: data);

    // When a borrowed Settings shell shows the unavailable preference.
    final context = tester.element(find.byType(ResourceListDetail));
    final route = showSettings(
      context,
      view: session.view,
      capabilities: SettingsCapabilities(),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(
      ValueKey('settings-control:${CommonSettings.hingePreference.id}'),
    );

    // Then its value stays visible with a disabled control and an explanation.
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('折り目をまたいで表示\nこの環境では利用できません'),
      ),
      findsOneWidget,
    );
    expect(tester.widget<ListTile>(row).onTap, isNull);
    Navigator.of(tester.element(row)).pop();
    await tester.pumpAndSettle();
    await route;
    expect(find.byKey(const Key('fold-separation')), findsOneWidget);

    // When capability returns, a toolbar session choice and layout changes follow.
    session.binding.updateCapabilities(
      SettingsCapabilities(supported: {'hinge'}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fold-separation')), findsNothing);
    await tester.tap(find.byKey(const Key('resource-hinge-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-hinge-avoid')));
    await tester.pumpAndSettle();
    final routesBeforeEnvironment = (
      session.observer.pushes,
      session.observer.pops,
    );
    session.binding.updateCapabilities(SettingsCapabilities());
    await _pump(tester, session, size: const Size(400, 900));
    session.binding.updateCapabilities(
      SettingsCapabilities(supported: {'hinge'}),
    );
    await _pump(tester, session, data: data);

    // Then session and stored choices return independently without global writes.
    expect(find.byKey(const Key('fold-separation')), findsOneWidget);
    expect(
      session.displays[0].hingePolicyOverride,
      ResourceListDetailHingePolicy.avoid,
    );
    expect(
      session.displays[1].resolveHingePolicy(hasOcclusion: true),
      ResourceListDetailHingePolicy.span,
    );
    expect(session.view.snapshot, same(saved));
    expect(
      session.view.value(CommonSettings.hingePreference),
      SettingsHingePreference.span,
    );
    expect(session.storage.readCount, 1);
    expect(session.storage.writeCount, 0);
    expect(session.sources[0].listCalls, 1);
    expect(session.sources[0].getCalls, 0);
    expect(session.sources[0].actionCalls, 0);
    expect(routesBeforeEnvironment, (3, 2));
    expect((
      session.observer.pushes,
      session.observer.pops,
    ), routesBeforeEnvironment);
  });
}

_Composition _session(WidgetTester tester) {
  final session = _Composition();
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  return session;
}

Future<void> _pump(
  WidgetTester tester,
  _Composition session, {
  Size size = const Size(1000, 900),
  MediaQueryData? data,
  bool allowFocus = true,
  double topOffset = 0,
}) async {
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [session.observer],
      home: MediaQuery(
        data: data ?? MediaQueryData(size: size),
        child: Padding(
          padding: EdgeInsets.only(top: topOffset),
          child: ApplicationNavigationShell(
            configuration: session.navigation,
            pages: {
              for (var index = 0; index < 2; index++)
                (index == 0 ? 'a' : 'b'): ResourceListDetail(
                  key: ValueKey('page-$index'),
                  configuration: ResourceListDetailConfiguration(
                    listTitle: 'Resources',
                    detailTitle: 'Detail',
                    primaryField: 'name',
                    detailFields: const [
                      ResourceFieldConfiguration(
                        key: 'summary',
                        label: 'Summary',
                      ),
                    ],
                    allowDetailFocus: allowFocus,
                  ),
                  viewModel: session.models[index],
                  displayModel: session.displays[index],
                ),
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MediaQueryData _feature({
  required Axis axis,
  required double gap,
  Size size = const Size(1000, 900),
  double? coordinate,
}) => MediaQueryData(
  size: size,
  padding: const EdgeInsets.only(left: 20, right: 30),
  displayFeatures: [
    DisplayFeature(
      bounds: axis == Axis.vertical
          ? Rect.fromLTWH(coordinate ?? 490, 0, gap, size.height)
          : Rect.fromLTWH(0, coordinate ?? 440, size.width, gap),
      type: gap == 0 ? DisplayFeatureType.fold : DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

Rect _bodyRect(WidgetTester tester, Size size) => Rect.fromLTRB(
  20,
  tester.getRect(find.byType(AppBar)).bottom,
  size.width - 30,
  tester.getRect(find.byType(NavigationBar)).top,
);

Rect _listRect(WidgetTester tester, ResourceViewModel model) =>
    tester.getRect(find.byKey(PageStorageKey<ResourceViewModel>(model)));

Rect _detailRect(WidgetTester tester) =>
    tester.getRect(find.byType(ListView).last);

class _Composition {
  _Composition() {
    controller = SettingsController(storage: storage);
    view = SettingsView.fromService(service: controller);
    for (final source in sources) {
      final collection = ResourceCollectionView(dataSource: source);
      final detail = ResourceDetailView(
        dataSource: source,
        actionHandler: source,
      );
      models.add(
        ResourceViewModel.fromViews(
          collectionView: collection,
          detailView: detail,
        ),
      );
    }
    binding = ResourceListDetailSettingsBinding(
      view: view,
      displayModels: displays,
      capabilities: SettingsCapabilities(supported: {'hinge'}),
    );
  }

  final storage = ControllableSettingsStorage();
  late final SettingsController controller;
  late final SettingsView view;
  late final ResourceListDetailSettingsBinding binding;
  final sources = [_Resources('A'), _Resources('B')];
  final models = <ResourceViewModel>[];
  final displays = [
    ResourceListDetailDisplayModel(),
    ResourceListDetailDisplayModel(),
  ];
  final observer = _Routes();
  final navigation = ApplicationNavigationConfiguration(
    initialDestinationId: 'a',
    destinations: const [
      NavigationDestinationConfiguration(
        id: 'a',
        label: 'Tab A',
        symbol: NavigationSymbol.folder,
      ),
      NavigationDestinationConfiguration(
        id: 'b',
        label: 'Tab B',
        symbol: NavigationSymbol.lightbulb,
      ),
    ],
  );

  void dispose() {
    binding.dispose();
    view.dispose();
    controller.dispose();
    for (final model in models) {
      model.dispose();
      model.collectionView.dispose();
      model.detailView.dispose();
    }
    for (final display in displays) {
      display.dispose();
    }
  }
}

class _Resources implements ResourceDataSource, ResourceActionHandler {
  _Resources(String prefix)
    : first = ResourceRecord(
        id: '$prefix-first',
        values: {'name': '$prefix first', 'summary': '$prefix detail'},
      ),
      second = ResourceRecord(
        id: '$prefix-second',
        values: {'name': '$prefix second', 'summary': '$prefix other detail'},
      );

  final ResourceRecord first;
  final ResourceRecord second;
  int listCalls = 0;
  int getCalls = 0;
  int actionCalls = 0;

  @override
  Future<List<ResourceRecord>> listResources() async {
    listCalls++;
    return [first, second];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    getCalls++;
    return id == first.id
        ? first
        : id == second.id
        ? second
        : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) => const [
    ResourceAction(id: 'review', label: 'Review'),
  ];

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    actionCalls++;
  }
}

class _Routes extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}
