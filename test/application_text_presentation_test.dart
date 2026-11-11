import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

class _Nonlinear extends TextScaler {
  const _Nonlinear();
  @override
  double scale(double fontSize) => fontSize + math.min(fontSize, 16) / 2;
  // SDK compatibility estimate only; rendered text uses nonlinear scale(size).
  @override
  double get textScaleFactor => scale(14) / 14;
}

class _Resources implements ResourceDataSource, ResourceActionHandler {
  _Resources(this.index, {this.long = false});
  final int index;
  final bool long;
  String get name => long
      ? 'Resource $index with a long fully readable collection label'
      : 'Resource $index';
  String get action => long
      ? 'Perform the complete long resource action without shrinking its text'
      : 'Act $index';
  late final record = ResourceRecord(
    id: 'item-$index',
    values: {
      'name': name,
      'summary': long
          ? 'A long field value that remains readable and wraps across the resource detail presentation'
          : 'Summary $index',
    },
  );
  int listCalls = 0;
  int readCalls = 0;
  int commandCalls = 0;
  @override
  Future<List<ResourceRecord>> listResources() async {
    listCalls++;
    return [record];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    readCalls++;
    return id == record.id ? record : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) => [
    ResourceAction(id: 'act', label: action),
  ];
  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    commandCalls++;
  }
}

class _Driver {
  _Driver({
    bool long = false,
    List<SettingDefinition<Object>> extensions = const [],
  }) {
    controller = SettingsController(
      storage: storage,
      registry: CommonSettings.registry(extensions: extensions),
    );
    settings = SettingsView.fromService(service: controller);
    sources = [for (var i = 0; i < 2; i++) _Resources(i, long: long)];
    collections = [
      for (final source in sources) ResourceCollectionView(dataSource: source),
    ];
    details = [
      for (var i = 0; i < 2; i++)
        ResourceDetailView(
          dataSource: sources[i],
          actionHandler: sources[i],
          onActionSucceeded: collections[i].load,
        ),
    ];
    models = [
      for (var i = 0; i < 2; i++)
        ResourceViewModel.fromViews(
          collectionView: collections[i],
          detailView: details[i],
        ),
    ];
    displays = [
      ResourceListDetailDisplayModel(),
      ResourceListDetailDisplayModel(),
    ];
    binding = ResourceListDetailSettingsBinding(
      view: settings,
      displayModels: displays,
      capabilities: SettingsCapabilities(supported: {'hinge'}),
    );
    application = ApplicationViewModel({
      'settings': settings,
      for (var i = 0; i < 2; i++) 'collection-$i': collections[i],
      for (var i = 0; i < 2; i++) 'detail-$i': details[i],
    });
    configuration = ApplicationNavigationConfiguration(
      initialDestinationId: 'tab-0',
      destinations: [
        for (var i = 0; i < 2; i++)
          NavigationDestinationConfiguration(
            id: 'tab-$i',
            symbol: i == 0
                ? NavigationSymbol.folder
                : NavigationSymbol.lightbulb,
            label: long
                ? 'Destination $i with a complete long navigation label that must wrap and remain reachable throughout enlargement'
                : 'Tab $i',
          ),
      ],
    );
    pages = {
      for (var i = 0; i < 2; i++)
        'tab-$i': _Tab(driver: this, index: i, long: long),
    };
  }
  final storage = ControllableSettingsStorage();
  late final SettingsController controller;
  late final SettingsView settings;
  late final List<_Resources> sources;
  late final List<ResourceCollectionView> collections;
  late final List<ResourceDetailView> details;
  late final List<ResourceViewModel> models;
  late final List<ResourceListDetailDisplayModel> displays;
  late final ResourceListDetailSettingsBinding binding;
  late final ApplicationViewModel application;
  late final ApplicationNavigationConfiguration configuration;
  late final Map<String, Widget> pages;
  void dispose() {
    binding.dispose();
    for (final model in models) {
      model.dispose();
    }
    for (final display in displays) {
      display.dispose();
    }
    application.dispose();
    controller.dispose();
  }

  List<int> get counts => [
    for (final source in sources) ...[
      source.listCalls,
      source.readCalls,
      source.commandCalls,
    ],
  ];
}

class _Tab extends StatelessWidget {
  const _Tab({required this.driver, required this.index, required this.long});
  final _Driver driver;
  final int index;
  final bool long;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IconButton(
            key: ValueKey('open-settings-$index'),
            tooltip: 'Open Settings',
            icon: const Icon(Icons.settings, size: 24),
            onPressed: () => unawaited(
              showSettings(
                context,
                view: driver.settings,
                capabilities: SettingsCapabilities(supported: {'hinge'}),
              ),
            ),
          ),
          const RawImage(key: Key('fixed-image'), width: 64, height: 64),
        ],
      ),
      Expanded(
        child: ResourceListDetail(
          key: ValueKey('resource-tab-$index'),
          configuration: ResourceListDetailConfiguration(
            listTitle: long
                ? 'Resource list $index with a long full toolbar title that wraps over many lines while preserving all words for accessible scrolling'
                : 'List $index',
            detailTitle: long
                ? 'Resource detail $index with a long full toolbar title that wraps over many lines while preserving all words for accessible scrolling'
                : 'Detail $index',
            primaryField: 'name',
            minimumFoldPaneWidth: 220,
            minimumFoldPaneHeight: 100,
            detailFields: [
              ResourceFieldConfiguration(
                key: 'summary',
                label: long
                    ? 'Complete long field label that wraps at its full logical role size'
                    : 'Field $index',
              ),
            ],
          ),
          viewModel: driver.models[index],
          displayModel: driver.displays[index],
        ),
      ),
    ],
  );
}

_Driver _driver(
  WidgetTester tester, {
  bool long = false,
  List<SettingDefinition<Object>> extensions = const [],
}) {
  final driver = _Driver(long: long, extensions: extensions);
  // testWidgets owns the semantics handle and disposes it before verification.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    driver.dispose();
    for (final read in driver.storage.reads) {
      if (!read.isCompleted) read.succeed(null);
    }
    for (final write in driver.storage.writes) {
      if (!write.isCompleted) write.succeed();
    }
  });
  return driver;
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  _Driver driver, {
  TextScaler system = TextScaler.noScaling,
  List<DisplayFeature> features = const [],
}) => MaterialApp(
  theme: ThemeData(useMaterial3: false),
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: system, displayFeatures: features),
    child: ApplicationTextScaling(view: driver.settings, child: navigator!),
  ),
  home: ApplicationNavigationShell(
    configuration: driver.configuration,
    pages: driver.pages,
  ),
);

Finder _textParagraph(String text) {
  final modalText = find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is SimpleDialog ||
          widget is AlertDialog ||
          widget is CupertinoActionSheet ||
          widget is CupertinoAlertDialog,
    ),
    matching: find.text(text),
  );
  return find.descendant(
    of: modalText.evaluate().isNotEmpty ? modalText : find.text(text),
    matching: find.byType(RichText),
  );
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(_textParagraph(text).first);

void _scaled(
  WidgetTester tester,
  String text,
  TextScaler system,
  double multiplier, {
  double? logicalSize,
}) {
  // Then actual rendered text keeps its logical role and applies m * OS(role).
  final paragraph = _paragraph(tester, text);
  final style = (paragraph.text as TextSpan).style!;
  final size = style.fontSize!;
  if (logicalSize != null) expect(size, logicalSize);
  expect(
    paragraph.textScaler.scale(size),
    closeTo(multiplier * system.scale(size), 1e-8),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
}

Future<void> _destination(
  WidgetTester tester,
  _Driver driver,
  int index,
) async {
  final label = driver.configuration.destinations[index].label;
  // When the destination is activated through the screen reader tap action.
  final target = tester.getSemantics(find.bySemanticsLabel(label).first);
  expect(target.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
    target.id,
    SemanticsAction.tap,
  );
  await tester.pumpAndSettle();
  // Then the destination has selected semantics and its retained framework page.
  final semantics = tester.getSemantics(find.bySemanticsLabel(label).first);
  expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  expect(find.byKey(ValueKey('resource-tab-$index')), findsOneWidget);
}

Future<void> _select(WidgetTester tester, _Driver driver, int index) async {
  final list = find.byKey(
    PageStorageKey<ResourceViewModel>(driver.models[index]),
  );
  final rect = tester.getRect(list);
  // When the reachable collection row is tapped in its current safe viewport.
  await tester.tapAt(
    Offset(rect.center.dx, rect.top + math.min(24, rect.height / 2)),
  );
  await tester.pumpAndSettle();
  // Then selection belongs to the existing Resource detail View.
  expect(driver.models[index].selectedId, 'item-$index');
}

Future<void> _reach(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  await tester.scrollUntilVisible(
    target,
    80,
    scrollable: scrollable ?? find.byType(Scrollable).last,
    maxScrolls: 50,
  );
  await tester.pumpAndSettle();
}

final _extension = SettingDefinition<String>(
  id: 'example.long-choice',
  groupId: 'application',
  label: 'A complete long application setting definition label that remains readable',
  defaultValue: 'first',
  choices: [
    SettingChoice(
      value: 'first',
      label: 'First complete extended choice with a long readable label',
      storedValue: 'first',
    ),
    SettingChoice(
      value: 'second',
      label: 'Second complete extended choice with a long readable label',
      storedValue: 'second',
    ),
  ],
);

class _Routes extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

Widget _settingsApp(
  _Driver driver,
  bool cupertino, {
  TextScaler system = const TextScaler.linear(2),
  _Routes? outer,
  _Routes? inner,
}) {
  Widget launch(BuildContext context) {
    void open() => unawaited(
      showSettings(
        context,
        view: driver.settings,
        presentation: cupertino
            ? SettingsPresentation.cupertino
            : SettingsPresentation.material,
      ),
    );
    return cupertino
        ? CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                key: const Key('launch'),
                onPressed: open,
                child: const Text('Open Settings'),
              ),
            ),
          )
        : Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('launch'),
                onPressed: open,
                child: const Text('Open Settings'),
              ),
            ),
          );
  }

  final home = inner == null
      ? Builder(builder: launch)
      : Navigator(
          key: const Key('nearest-navigator'),
          observers: [inner],
          onGenerateRoute: (_) => cupertino
              ? CupertinoPageRoute<void>(builder: launch)
              : MaterialPageRoute<void>(builder: launch),
        );
  Widget boundary(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: system),
    child: ApplicationTextScaling(view: driver.settings, child: child!),
  );
  return cupertino
      ? CupertinoApp(
          navigatorObservers: [?outer],
          builder: boundary,
          home: home,
        )
      : MaterialApp(
          theme: ThemeData(useMaterial3: false),
          navigatorObservers: [?outer],
          builder: boundary,
          home: home,
        );
}

Finder _settingsScroll() => find
    .ancestor(
      of: find.byKey(
        ValueKey('settings-control:${CommonSettings.textSizeMultiplier.id}'),
      ),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapReachable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final scrollable = find.ancestor(
    of: target,
    matching: find.byType(Scrollable),
  );
  var visible = tester.getRect(target);
  if (scrollable.evaluate().isNotEmpty) {
    visible = visible.intersect(tester.getRect(scrollable.first));
  }
  visible = visible.intersect(
    Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio),
  );
  // Then the physical tap lies inside the action, its viewport and the screen.
  expect(visible.width, greaterThan(0));
  expect(visible.height, greaterThan(0));
  await tester.tapAt(visible.center);
  await tester.pumpAndSettle();
}

Future<void> _openChoice(WidgetTester tester, String id) async {
  final control = find.byKey(ValueKey('settings-control:$id'));
  // When the native Settings body is scrolled to the registered chooser.
  await _reach(tester, control, scrollable: _settingsScroll());
  await _tapReachable(tester, control);
}

void _untruncated(WidgetTester tester, String text) {
  // Then every logical word has a laid-out box without native one-line truncation.
  final paragraph = _paragraph(tester, text);
  expect(paragraph.text.toPlainText(), text);
  expect(paragraph.didExceedMaxLines, isFalse);
  final span = paragraph.text as TextSpan;
  // Trailing whitespace can extend past paint width. Native negative spacing
  // also contributes a half-spacing bearing; neither removes painted letters.
  final horizontalAllowance =
      math.max(0.0, -(span.style!.letterSpacing ?? 0) / 2) + 0.01;
  final words = RegExp(r'\S+').allMatches(text).toList();
  expect(words, isNotEmpty);
  for (final word in words) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-horizontalAllowance));
      expect(
        box.right,
        lessThanOrEqualTo(paragraph.size.width + horizontalAllowance),
      );
      expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
    }
  }
}

void main() {
  group('Actual framework text across resource tabs and Settings', () {
    for (final system in [
      TextScaler.noScaling,
      const TextScaler.linear(2),
      const _Nonlinear(),
    ]) {
      for (final multiplier in [1.0, 1.15, 1.30]) {
        testWidgets(
          'TP01 $system and $multiplier reach framework resources and Settings',
          (tester) async {
            // Given actual configured tabs, retained Views, S04 binding and borrowed Settings.
            _size(tester, const Size(1000, 800));
            final driver = _driver(tester);
            driver.settings.setValue(
              CommonSettings.textSizeMultiplier.id,
              multiplier,
            );
            await tester.pumpWidget(_app(driver, system: system));
            await tester.pumpAndSettle();
            // Then framework list/title/destination paragraphs render full role scaling.
            _scaled(tester, 'List 0', system, multiplier, logicalSize: 20);
            _scaled(tester, 'Resource 0', system, multiplier);
            _scaled(tester, 'Tab 0', system, multiplier, logicalSize: 12);
            // When selection opens actual Resource detail.
            await _select(tester, driver, 0);
            // Then fields and actions use the same nonlinear-aware text function.
            _scaled(tester, 'Summary 0', system, multiplier);
            _scaled(tester, 'Act 0', system, multiplier);
            // When the second retained tab is visited and selected.
            await _destination(tester, driver, 1);
            await _select(tester, driver, 1);
            // Then its independent resource details are rendered from its own Views.
            _scaled(tester, 'Summary 1', system, multiplier);
            expect(driver.models[0].selectedId, 'item-0');
            // When the real showSettings route is opened from the active tab.
            await tester.tap(find.byKey(const ValueKey('open-settings-1')));
            await tester.pumpAndSettle();
            // Then the same borrowed native shell receives the full effective scaler.
            expect(
              tester.widget<SettingsShell>(find.byType(SettingsShell)).view,
              same(driver.settings),
            );
            _scaled(tester, '設定', system, multiplier, logicalSize: 20);
            _scaled(tester, '文字サイズ', system, multiplier);
            expect(driver.storage.readCount, 0);
            expect(driver.storage.writeCount, 0);
          },
        );
      }
    }

    testWidgets(
      'TP02 compact and expanded live text transitions retain all tab state',
      (tester) async {
        // Given two visited/selected compact tabs and independent session overrides.
        _size(tester, const Size(320, 640));
        final driver = _driver(tester);
        await tester.pumpWidget(_app(driver));
        await tester.pumpAndSettle();
        await _select(tester, driver, 0);
        await _destination(tester, driver, 1);
        await _select(tester, driver, 1);
        driver.displays[0].focusDetail();
        driver.displays[0].setHingePolicy(ResourceListDetailHingePolicy.avoid);
        driver.displays[1].restoreSplit();
        driver.displays[1].setHingePolicy(ResourceListDetailHingePolicy.span);
        final identities = [
          for (final model in driver.models) ...[
            model.collectionView,
            model.detailView,
          ],
        ];
        final states = [
          for (var i = 0; i < 2; i++)
            tester.state(
              find.byKey(ValueKey('resource-tab-$i'), skipOffstage: false),
            ),
        ];
        final counts = driver.counts;
        // When app text edits and live OS changes rebuild a compact active tab.
        driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
        await tester.pumpWidget(_app(driver, system: const _Nonlinear()));
        await tester.pumpAndSettle();
        // Then neither session dimension, compact intent nor semantic identities change.
        expect(driver.displays.map((d) => d.preferenceOverride), [
          ResourceListDetailDisplayPreference.detailFocused,
          ResourceListDetailDisplayPreference.split,
        ]);
        expect(driver.displays.map((d) => d.hingePolicyOverride), [
          ResourceListDetailHingePolicy.avoid,
          ResourceListDetailHingePolicy.span,
        ]);
        expect(
          driver.displays.map((d) => d.compactDetailRequested),
          everyElement(isTrue),
        );
        expect(driver.models.map((m) => m.selectedId), ['item-0', 'item-1']);
        expect(driver.counts, counts);
        // When usable size expands and the first tab returns under a live enlarged OS.
        tester.view.physicalSize = const Size(1000, 800);
        await tester.pumpWidget(
          _app(driver, system: const TextScaler.linear(2)),
        );
        await tester.pumpAndSettle();
        await _destination(tester, driver, 0);
        // Then focused presentation and inactive-page state survive without reloading.
        expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
        expect(driver.counts, counts);
        for (var i = 0; i < 2; i++) {
          expect(driver.models[i].collectionView, same(identities[i * 2]));
          expect(driver.models[i].detailView, same(identities[i * 2 + 1]));
          expect(
            tester.state(
              find.byKey(ValueKey('resource-tab-$i'), skipOffstage: false),
            ),
            same(states[i]),
          );
        }
        // When the user restores split and returns to compact detail/back.
        await tester.tap(find.byKey(const Key('resource-restore-split')));
        await tester.pumpAndSettle();
        // Then expanded split restores the same selected detail.
        expect(
          find.byKey(PageStorageKey<ResourceViewModel>(driver.models[0])),
          findsOneWidget,
        );
        expect(driver.models[0].selectedId, 'item-0');
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        // When compact back is pressed.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        // Then only compact intent changes; text rebuilds never caused queries/actions.
        expect(driver.displays[0].compactDetailRequested, isFalse);
        expect(driver.displays[1].compactDetailRequested, isTrue);
        expect(driver.counts, counts);
      },
    );

    for (final size in [const Size(320, 568), const Size(640, 360)]) {
      testWidgets('TP03 enlarged long controls wrap and scroll at $size', (
        tester,
      ) async {
        // Given largest app text, OS linear two, and long configured text roles.
        _size(tester, size);
        final driver = _driver(tester, long: true);
        driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
        await tester.pumpWidget(
          _app(driver, system: const TextScaler.linear(2)),
        );
        await tester.pumpAndSettle();
        // Then measured headers/bottom labels grow within the viewport bounds.
        final bar = tester.widget<AppBar>(find.byType(AppBar).first);
        expect(bar.toolbarHeight, greaterThan(56));
        expect(
          bar.toolbarHeight,
          lessThanOrEqualTo(math.max(56.0, size.height * 0.35)),
        );
        final nav = find.byKey(const Key('application-text-destinations'));
        expect(
          tester.getSize(nav).height,
          lessThanOrEqualTo(math.max(48.0, size.height * 0.35)),
        );
        expect(tester.getSize(find.byType(RawImage).first), const Size(64, 64));
        for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
          if (icon.size != null) expect(icon.size, 24);
        }
        for (var i = 0; i < 2; i++) {
          // When each reachable destination and resource row are selected.
          await _destination(tester, driver, i);
          await _select(tester, driver, i);
          // Then long full detail text remains laid out at the original role size.
          _scaled(
            tester,
            driver.sources[i].record.value('summary'),
            const TextScaler.linear(2),
            1.30,
          );
          _scaled(
            tester,
            driver.configuration.destinations[i].label,
            const TextScaler.linear(2),
            1.30,
            logicalSize: 12,
          );
          final resource = tester.widget<ResourceListDetail>(
            find.byKey(ValueKey('resource-tab-$i')),
          );
          _scaled(
            tester,
            resource.configuration.detailTitle,
            const TextScaler.linear(2),
            1.30,
            logicalSize: 20,
          );
          _untruncated(tester, resource.configuration.detailTitle);
          _untruncated(tester, driver.sources[i].record.value('summary'));
          _untruncated(tester, driver.configuration.destinations[i].label);
          final titleScroll = find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Scrollable),
              )
              .first;
          final scrollState = tester.state<ScrollableState>(titleScroll);
          expect(scrollState.position.maxScrollExtent, greaterThan(0));
          // When a header is scrolled, its complete title can be reached.
          await tester.drag(titleScroll, const Offset(0, -500));
          await tester.pumpAndSettle();
          // Then the header moved without shrinking or truncating the paragraph.
          expect(scrollState.position.pixels, greaterThan(0));
          expect(
            _paragraph(
              tester,
              resource.configuration.detailTitle,
            ).didExceedMaxLines,
            isFalse,
          );
          final action = find.text(driver.sources[i].action);
          final detailBody = find
              .descendant(
                of: find.byKey(ValueKey('resource-tab-$i')),
                matching: find.byType(ListView),
              )
              .last;
          final detailScroll = find
              .descendant(of: detailBody, matching: find.byType(Scrollable))
              .first;
          // When the detail viewport scrolls to its full action label.
          await _reach(tester, action, scrollable: detailScroll);
          // Then the complete action text retains its native role and painted words.
          _scaled(
            tester,
            driver.sources[i].action,
            const TextScaler.linear(2),
            1.30,
          );
          _untruncated(tester, driver.sources[i].action);
          final button = find.ancestor(
            of: action,
            matching: find.byType(FilledButton),
          );
          // When the native action is tapped inside its actual body viewport.
          await _tapReachable(tester, button);
          // Then the reachable action executes through the existing handler exactly once.
          expect(driver.sources[i].commandCalls, 1);
          expect(tester.takeException(), isNull);
          // When native compact back returns to the collection.
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          // Then selected data remains while the compact list is reachable again.
          expect(
            find.byKey(PageStorageKey<ResourceViewModel>(driver.models[i])),
            findsOneWidget,
          );
          expect(driver.models[i].selectedId, 'item-$i');
        }
        // When the destination viewport scrolls to its full labels.
        final navScroll = find.descendant(
          of: nav,
          matching: find.byType(Scrollable),
        );
        final navState = tester.state<ScrollableState>(navScroll);
        await tester.drag(navScroll, const Offset(0, -500));
        await tester.pumpAndSettle();
        // Then scrolling, not font fitting, exposes the remainder of both labels.
        expect(navState.position.maxScrollExtent, greaterThan(0));
        expect(navState.position.pixels, greaterThan(0));
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Native Settings remains reachable at the full app and OS text output', () {
    for (final cupertino in [false, true]) {
      testWidgets(
        'TP04 ${cupertino ? 'Cupertino without Material' : 'Material'} can return to Standard and reset',
        (tester) async {
          // Given Largest, enlarged OS text and an actual long extension catalog.
          _size(tester, const Size(320, 568));
          final driver = _driver(tester, extensions: [_extension]);
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
          await tester.pumpWidget(_settingsApp(driver, cupertino));
          await tester.pumpAndSettle();
          // When showSettings opens its native borrowed route.
          await tester.tap(find.byKey(const Key('launch')));
          await tester.pumpAndSettle();
          // Then native title and rows retain full size with a growing toolbar.
          _scaled(
            tester,
            '設定',
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 17 : 20,
          );
          _scaled(tester, '文字サイズ', const TextScaler.linear(2), 1.30);
          if (cupertino) expect(find.byType(Material), findsNothing);
          // When the scrollable native shell reaches its status text.
          await _reach(
            tester,
            find.text('設定をまだ読み込んでいません'),
            scrollable: _settingsScroll(),
          );
          // Then the current read/unsaved status remains readable without a save claim.
          _scaled(tester, '設定をまだ読み込んでいません', const TextScaler.linear(2), 1.30);
          _untruncated(tester, '設定をまだ読み込んでいません');
          expect(find.text('設定を保存しました'), findsNothing);
          // When the common chooser is opened and Standard is reached.
          await _openChoice(tester, CommonSettings.textSizeMultiplier.id);
          final standard = find.byKey(
            ValueKey(
              'settings-choice:${CommonSettings.textSizeMultiplier.id}:0',
            ),
          );
          await _tapReachable(tester, standard);
          // Then the same authoritative View returns exactly to OS text output.
          expect(driver.settings.value(CommonSettings.textSizeMultiplier), 1.0);
          _scaled(
            tester,
            '設定',
            const TextScaler.linear(2),
            1.0,
            logicalSize: cupertino ? 17 : 20,
          );
          // When Largest is restored and the long extension chooser is reached.
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
          await tester.pumpAndSettle();
          await _openChoice(tester, _extension.id);
          // Then complete definition/choice labels wrap at their native logical roles.
          _scaled(
            tester,
            _extension.label,
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 13 : 20,
          );
          _untruncated(tester, _extension.label);
          if (!cupertino) {
            // Given the complete long title in the native Material chooser.
            final titleViewport = find.byKey(
              const Key('settings-choice-title-viewport'),
            );
            final titleScroll = find.descendant(
              of: titleViewport,
              matching: find.byType(Scrollable),
            );
            final titleState = tester.state<ScrollableState>(titleScroll);
            final media = MediaQuery.of(tester.element(titleViewport));
            final available = math.max(
              0.0,
              media.size.height -
                  media.padding.vertical -
                  media.viewInsets.vertical -
                  48,
            );
            // When the actual title viewport and complete paragraph are measured.
            final viewport = tester.getRect(titleViewport);
            final titleBefore = tester.getRect(
              _textParagraph(_extension.label).first,
            );
            // Then full-size title content exceeds its bounded, scrollable viewport.
            expect(viewport.height, lessThanOrEqualTo(available * 0.35));
            expect(titleBefore.height, greaterThan(viewport.height));
            expect(titleState.position.maxScrollExtent, greaterThan(0));
            // When the native title viewport is dragged to the later title words.
            await tester.drag(titleScroll, const Offset(0, -2000));
            await tester.pumpAndSettle();
            // Then scrolling exposes the last full word without changing its role.
            expect(titleState.position.pixels, greaterThan(0));
            final paragraph = _paragraph(tester, _extension.label);
            final lastWord = RegExp(r'\S+').allMatches(_extension.label).last;
            final lastBox = paragraph
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: lastWord.start,
                    extentOffset: lastWord.end,
                  ),
                )
                .last;
            final lastWordRect = Rect.fromLTRB(
              lastBox.left,
              lastBox.top,
              lastBox.right,
              lastBox.bottom,
            ).shift(paragraph.localToGlobal(Offset.zero));
            expect(lastWordRect.intersect(viewport).height, greaterThan(0));
            expect(lastWordRect.intersect(viewport).width, greaterThan(0));
            expect(
              lastWordRect.bottom,
              lessThanOrEqualTo(viewport.bottom + 0.01),
            );
            expect(
              tester.getRect(_textParagraph(_extension.label).first).bottom,
              lessThan(titleBefore.bottom),
            );
            _scaled(
              tester,
              _extension.label,
              const TextScaler.linear(2),
              1.30,
              logicalSize: 20,
            );
            _untruncated(tester, _extension.label);
          }
          final second = find.byKey(
            ValueKey('settings-choice:${_extension.id}:1'),
          );
          // When the independent option viewport reveals the second native choice.
          await tester.ensureVisible(second);
          await tester.pumpAndSettle();
          // Then the complete choice retains its full native role and painted words.
          _scaled(
            tester,
            _extension.choices[1].label,
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 21 : null,
          );
          _untruncated(tester, _extension.choices[1].label);
          final beforeChoice = driver.settings.snapshot.revision;
          // When a native extension action selects its typed catalog value.
          await _tapReachable(tester, second);
          // Then one intent changes only that extension through the borrowed View.
          expect(driver.settings.value(_extension), 'second');
          expect(driver.settings.snapshot.revision, beforeChoice + 1);
          // When Reset common settings is reached and its Cancel action is used.
          final reset = find.byKey(const ValueKey('settings-reset'));
          await _reach(tester, reset, scrollable: _settingsScroll());
          await _tapReachable(tester, reset);
          final baseline = driver.settings.snapshot.revision;
          // Then native reset title/content retain complete text at their full roles.
          _scaled(
            tester,
            '共通設定を初期値に戻しますか？',
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 17 : null,
          );
          _scaled(
            tester,
            '共通設定を初期値に戻します。アプリ固有の設定は保持されます。',
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 13 : null,
          );
          final cancel = find.byKey(const ValueKey('settings-reset-cancel'));
          _untruncated(tester, '共通設定を初期値に戻しますか？');
          _untruncated(tester, '共通設定を初期値に戻します。アプリ固有の設定は保持されます。');
          // When native Cancel is tapped inside its reachable screen intersection.
          await _tapReachable(tester, cancel);
          // Then native Cancel produces no intent or persistence inference.
          expect(driver.settings.snapshot.revision, baseline);
          expect(
            driver.settings.value(CommonSettings.textSizeMultiplier),
            1.30,
          );
          // When confirmation is reopened and its Reset action is reached.
          await _tapReachable(tester, reset);
          final confirm = find.byKey(const ValueKey('settings-reset-confirm'));
          await _tapReachable(tester, confirm);
          // Then confirmation creates exactly one reset and keeps extension intent.
          expect(driver.settings.snapshot.revision, baseline + 1);
          expect(
            driver.settings.snapshot.lastIntent!.kind,
            SettingsIntentKind.resetCommon,
          );
          expect(driver.settings.value(CommonSettings.textSizeMultiplier), 1.0);
          expect(driver.settings.value(_extension), 'second');
          expect(driver.storage.readCount, 0);
          expect(driver.storage.writeCount, 0);
          // When the native Settings back control returns to the launch route.
          if (cupertino) {
            await tester.tap(find.byType(CupertinoNavigationBarBackButton));
          } else {
            await tester.tap(find.byType(BackButton));
          }
          await tester.pumpAndSettle();
          // Then only the borrowed route detaches, leaving service lifetime usable.
          expect(find.byKey(const Key('launch')), findsOneWidget);
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
          expect(
            driver.settings.value(CommonSettings.textSizeMultiplier),
            1.15,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'TP05 ${cupertino ? 'Cupertino' : 'Material'} open modals follow live OS and app changes on nearest Navigator',
        (tester) async {
          // Given a nested Navigator and a live borrowed Settings route at Larger.
          _size(tester, const Size(640, 800));
          final driver = _driver(tester);
          final outer = _Routes();
          final inner = _Routes();
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
          await tester.pumpWidget(
            _settingsApp(
              driver,
              cupertino,
              system: const _Nonlinear(),
              outer: outer,
              inner: inner,
            ),
          );
          await tester.pumpAndSettle();
          // When native Settings and its nearest chooser are opened.
          await tester.tap(find.byKey(const Key('launch')));
          await tester.pumpAndSettle();
          await _openChoice(tester, CommonSettings.textSizeMultiplier.id);
          final chooserRoute = ModalRoute.of(
            tester.element(
              find.byKey(
                ValueKey(
                  'settings-choice:${CommonSettings.textSizeMultiplier.id}:0',
                ),
              ),
            ),
          );
          final pushes = inner.pushes;
          final revision = driver.settings.snapshot.revision;
          // Then the already-open role uses nonlinear OS math at its native font size.
          _scaled(
            tester,
            '標準',
            const _Nonlinear(),
            1.15,
            logicalSize: cupertino ? 21 : null,
          );
          // When live OS scaling changes while that chooser remains open.
          await tester.pumpWidget(
            _settingsApp(
              driver,
              cupertino,
              system: const TextScaler.linear(2),
              outer: outer,
              inner: inner,
            ),
          );
          await tester.pumpAndSettle();
          // Then its existing route updates rendered text without creating preference intent.
          _scaled(
            tester,
            '標準',
            const TextScaler.linear(2),
            1.15,
            logicalSize: cupertino ? 21 : null,
          );
          expect(driver.settings.snapshot.revision, revision);
          expect(inner.pushes, pushes);
          expect(
            ModalRoute.of(
              tester.element(
                find.byKey(
                  ValueKey(
                    'settings-choice:${CommonSettings.textSizeMultiplier.id}:0',
                  ),
                ),
              ),
            ),
            same(chooserRoute),
          );
          // When the same live View chooses Largest outside the still-open modal.
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
          await tester.pumpAndSettle();
          // Then existing modal text updates once and retains native action authority.
          _scaled(
            tester,
            '標準',
            const TextScaler.linear(2),
            1.30,
            logicalSize: cupertino ? 21 : null,
          );
          if (cupertino) {
            _scaled(
              tester,
              'キャンセル',
              const TextScaler.linear(2),
              1.30,
              logicalSize: 21,
            );
          }
          expect(inner.pushes, pushes);
          // When the native modal action closes only the nearest chooser.
          if (cupertino) {
            await _tapReachable(tester, find.text('キャンセル'));
          } else {
            await _tapReachable(
              tester,
              find.byKey(
                ValueKey(
                  'settings-choice:${CommonSettings.textSizeMultiplier.id}:0',
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          // Then the outer Navigator never popped and Settings still borrows the same View.
          expect(outer.pops, 0);
          expect(inner.pops, 1);
          expect(
            tester.widget<SettingsShell>(find.byType(SettingsShell)).view,
            same(driver.settings),
          );
          // When a reset confirmation opens and both live inputs change beneath it.
          final reset = find.byKey(const ValueKey('settings-reset'));
          await _reach(tester, reset, scrollable: _settingsScroll());
          await _tapReachable(tester, reset);
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
          await tester.pumpWidget(
            _settingsApp(
              driver,
              cupertino,
              system: const _Nonlinear(),
              outer: outer,
              inner: inner,
            ),
          );
          await tester.pumpAndSettle();
          // Then reset title/content/actions recompute using each original logical role.
          _scaled(
            tester,
            '共通設定を初期値に戻しますか？',
            const _Nonlinear(),
            1.15,
            logicalSize: cupertino ? 17 : null,
          );
          _scaled(
            tester,
            '共通設定を初期値に戻します。アプリ固有の設定は保持されます。',
            const _Nonlinear(),
            1.15,
            logicalSize: cupertino ? 13 : null,
          );
          _scaled(
            tester,
            'キャンセル',
            const _Nonlinear(),
            1.15,
            logicalSize: cupertino ? 16.8 : null,
          );
          _scaled(
            tester,
            '初期値に戻す',
            const _Nonlinear(),
            1.15,
            logicalSize: cupertino ? 16.8 : null,
          );
          final beforeCancel = driver.settings.snapshot.revision;
          // When native reset Cancel is pressed and Settings native back returns.
          await _tapReachable(
            tester,
            find.byKey(const ValueKey('settings-reset-cancel')),
          );
          // Then cancelling has no user intent, and only the modal route popped.
          expect(driver.settings.snapshot.revision, beforeCancel);
          expect(inner.pops, 2);
          expect(outer.pops, 0);
          // When the native Settings back control closes the borrowed route.
          if (cupertino) {
            await tester.tap(find.byType(CupertinoNavigationBarBackButton));
          } else {
            await tester.tap(find.byType(BackButton));
          }
          await tester.pumpAndSettle();
          // Then the nearest Settings route pops while root/service remain active.
          expect(inner.pops, 3);
          expect(outer.pops, 0);
          expect(find.byKey(const Key('launch')), findsOneWidget);
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
          expect(
            driver.settings.value(CommonSettings.textSizeMultiplier),
            1.30,
          );
          expect(driver.storage.readCount, 0);
          expect(driver.storage.writeCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Text-driven chrome preserves physical hinge regions', () {
    for (final horizontal in [false, true]) {
      testWidgets(
        'TP06 ${horizontal ? 'horizontal' : 'vertical'} gap remains excluded through text changes',
        (tester) async {
          // Given actual Core-compatible separator facts and two retained resource tabs.
          final size = horizontal
              ? const Size(800, 1000)
              : const Size(1200, 800);
          _size(tester, size);
          final driver = _driver(tester);
          final gap = horizontal
              ? const Rect.fromLTWH(0, 480, 800, 20)
              : const Rect.fromLTWH(590, 0, 20, 800);
          final features = [
            DisplayFeature(
              bounds: gap,
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ];
          await tester.pumpWidget(_app(driver, features: features));
          await tester.pumpAndSettle();
          await _select(tester, driver, 0);
          driver.displays[0].setHingePolicy(
            ResourceListDetailHingePolicy.avoid,
          );
          driver.displays[0].restoreSplit();
          await tester.pumpAndSettle();
          final baselineQueries = driver.counts;
          // Then safe split regions exclude the unchanged physical gap before scaling.
          final separation = find.byKey(const Key('fold-separation'));
          final baselineGap = tester.getRect(separation);
          expect(horizontal ? baselineGap.height : baselineGap.width, 20);
          expect(
            horizontal ? baselineGap.top : baselineGap.left,
            horizontal ? gap.top : gap.left,
          );
          // When Largest and enlarged OS text grow chrome above the measured body.
          driver.settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
          await tester.pumpWidget(
            _app(
              driver,
              system: const TextScaler.linear(2),
              features: features,
            ),
          );
          await tester.pumpAndSettle();
          // Then physical geometry and minimums stay independent of the text multiplier.
          final scaledGap = tester.getRect(separation);
          expect(horizontal ? scaledGap.height : scaledGap.width, 20);
          expect(
            horizontal ? scaledGap.top : scaledGap.left,
            horizontal ? gap.top : gap.left,
          );
          final list = tester.getRect(
            find.byKey(PageStorageKey<ResourceViewModel>(driver.models[0])),
          );
          final detail = tester.getRect(find.byType(ListView).last);
          expect(list.overlaps(gap), isFalse);
          expect(detail.overlaps(gap), isFalse);
          expect(list.top, greaterThanOrEqualTo(64 + 56));
          if (horizontal) {
            expect(list.bottom, gap.top);
            expect(detail.top, gap.bottom);
          } else {
            expect(list.right, gap.left);
            expect(detail.left, gap.right);
          }
          _scaled(tester, 'Summary 0', const TextScaler.linear(2), 1.30);
          expect(
            driver.displays[0].preferenceOverride,
            ResourceListDetailDisplayPreference.split,
          );
          expect(
            driver.displays[0].hingePolicyOverride,
            ResourceListDetailHingePolicy.avoid,
          );
          expect(driver.models[0].selectedId, 'item-0');
          expect(driver.counts, baselineQueries);
          // When focused detail consumes the same trailing Core region.
          driver.displays[0].focusDetail();
          await tester.pumpAndSettle();
          // Then no painted detail viewport crosses the excluded physical gap.
          expect(tester.getRect(find.byType(ListView)).overlaps(gap), isFalse);
          expect(driver.models[0].selectedId, 'item-0');
          expect(driver.counts, baselineQueries);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
