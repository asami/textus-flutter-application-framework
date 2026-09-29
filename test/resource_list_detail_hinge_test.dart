import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

const _configuration = ResourceListDetailConfiguration(
  listTitle: 'Resources',
  detailTitle: 'Detail',
  primaryField: 'name',
  detailFields: [ResourceFieldConfiguration(key: 'summary', label: 'Summary')],
);

void main() {
  testWidgets(
    'horizontal hinge stacks complete list and detail panes around its screen gap',
    (tester) async {
      _setView(tester, const Size(640, 900));
      final source = _HingeResources();
      final model = ResourceViewModel(dataSource: source);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(data: _horizontalMedia(const Size(640, 900)), model: model),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      final list = find.byKey(PageStorageKey<ResourceViewModel>(model));
      final detail = find.byType(ListView).last;
      expect(tester.getRect(list), const Rect.fromLTRB(0, 56, 640, 440));
      expect(tester.getRect(detail), const Rect.fromLTRB(0, 460, 640, 900));
      expect(
        tester.getRect(find.byKey(const Key('fold-separation'))),
        const Rect.fromLTRB(0, 440, 640, 460),
      );
    },
  );

  testWidgets(
    'horizontal focused detail remains in the trailing pane and restores selection',
    (tester) async {
      _setView(tester, const Size(640, 900));
      final model = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(data: _horizontalMedia(const Size(640, 900)), model: model),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fold-separation')), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(
        tester.getRect(find.byType(ListView)),
        const Rect.fromLTRB(0, 460, 640, 900),
      );
      expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
      await tester.tap(find.byKey(const Key('resource-restore-split')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(PageStorageKey<ResourceViewModel>(model)),
        findsOneWidget,
      );
      expect(find.text('Detail for list resource'), findsOneWidget);
      expect(model.selectedId, 'list');
    },
  );

  testWidgets(
    'actual body measurement honors ancestor, safe-area, and navigation offsets',
    (tester) async {
      _setView(tester, const Size(640, 900));
      final model = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(
            const Size(640, 900),
            padding: const EdgeInsets.only(top: 24),
          ),
          model: model,
          wrap: (child) => Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: child,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      final listRect = tester.getRect(
        find.byKey(PageStorageKey<ResourceViewModel>(model)),
      );
      final detailRect = tester.getRect(find.byType(ListView).last);
      expect(listRect.top, greaterThan(80));
      expect(listRect.bottom, 440);
      expect(detailRect.top, 460);
      expect(detailRect.bottom, lessThanOrEqualTo(820));
      expect(
        tester.getRect(find.byKey(const Key('fold-separation'))),
        const Rect.fromLTRB(0, 440, 640, 460),
      );
    },
  );

  testWidgets(
    'undersized upper horizontal pane uses the largest lower compact region',
    (tester) async {
      _setView(tester, const Size(640, 800));
      final model = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(const Size(640, 800), top: 140, height: 20),
          model: model,
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(PageStorageKey<ResourceViewModel>(model));
      expect(tester.getRect(list).top, 160);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      final detailRect = tester.getRect(find.byType(ListView));
      expect(detailRect.top, 160);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('fold-separation')), findsNothing);
    },
  );

  testWidgets(
    'zero-height horizontal folds permit avoiding then spanning the crease',
    (tester) async {
      // Given a zero-height fold with an explicit in-session avoid choice.
      _setView(tester, const Size(640, 800));
      final model = ResourceViewModel(dataSource: _HingeResources());
      final displayModel = ResourceListDetailDisplayModel()
        ..setHingePolicy(ResourceListDetailHingePolicy.avoid);
      addTearDown(model.dispose);
      addTearDown(displayModel.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(
            const Size(640, 800),
            top: 440,
            height: 0,
            type: DisplayFeatureType.fold,
          ),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();
      // When the selected detail is focused while avoidance remains selected.
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(PageStorageKey<ResourceViewModel>(model)))
            .bottom,
        440,
      );
      expect(tester.getRect(find.byType(ListView).last).top, 440);
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      // Then focus uses the trailing logical region despite the zero gap.
      expect(
        tester.getRect(find.byType(ListView)),
        const Rect.fromLTRB(0, 440, 640, 800),
      );
      expect(find.byKey(const Key('fold-separation')), findsNothing);

      // When the user explicitly changes the treatment to span.
      await tester.tap(find.byKey(const Key('resource-hinge-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-hinge-span')));
      await tester.pumpAndSettle();

      // Then focused detail fills the safe body without changing selection.
      expect(
        tester.getRect(find.byType(ListView)),
        const Rect.fromLTRB(0, 56, 640, 800),
      );
      expect(model.selectedId, 'list');
      expect(
        displayModel.preference,
        ResourceListDetailDisplayPreference.detailFocused,
      );
    },
  );

  testWidgets(
    'feature orientation changes preserve focus and do not reload resources',
    (tester) async {
      _setView(tester, const Size(640, 900));
      final source = _HingeResources();
      final model = ResourceViewModel(dataSource: source);
      final displayModel = ResourceListDetailDisplayModel();
      addTearDown(model.dispose);
      addTearDown(displayModel.dispose);
      await tester.pumpWidget(
        _app(
          data: _verticalMedia(const Size(640, 900), left: 310),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(const Size(640, 900)),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
      expect(tester.getRect(find.byType(ListView)).top, 460);
      expect(model.selectedId, 'list');
      expect(source.listCalls, 1);
      expect(source.getCalls, 1);
    },
  );

  testWidgets(
    'too-small vertical panes use one compact region without crossing the gap',
    (tester) async {
      _setView(tester, const Size(500, 800));
      final model = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(data: _verticalMedia(const Size(500, 800)), model: model),
      );
      await tester.pumpAndSettle();
      final listRect = tester.getRect(
        find.byKey(PageStorageKey<ResourceViewModel>(model)),
      );
      expect(listRect.right, lessThanOrEqualTo(240));
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(ListView)).right,
        lessThanOrEqualTo(240),
      );
      expect(find.byKey(const Key('fold-separation')), findsNothing);
    },
  );

  testWidgets(
    'features outside the body use ordinary layout and all-gap bodies remain empty',
    (tester) async {
      _setView(tester, const Size(1000, 800));
      final outsideModel = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(outsideModel.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(const Size(1000, 800), top: 100, height: 20),
          model: outsideModel,
          wrap: (child) =>
              Padding(padding: const EdgeInsets.only(top: 200), child: child),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fold-separation')), findsNothing);
      expect(find.byType(ListView), findsNWidgets(2));

      _setView(tester, const Size(640, 800));
      final allGapModel = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(allGapModel.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(const Size(640, 800), top: 200, height: 400),
          model: allGapModel,
          wrap: (child) => Padding(
            padding: const EdgeInsets.only(top: 144, bottom: 200),
            child: child,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a horizontal hinge touching the body top uses ordinary wide layout',
    (tester) async {
      // Given an ancestor offset whose body starts where the hinge ends.
      _setView(tester, const Size(1000, 800));
      final model = ResourceViewModel(dataSource: _HingeResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(
          data: _horizontalMedia(const Size(1000, 800), top: 100, height: 20),
          model: model,
          wrap: (child) =>
              Padding(padding: const EdgeInsets.only(top: 64), child: child),
        ),
      );
      await tester.pumpAndSettle();

      // When a resource is selected in the measured body below that hinge.
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      // Then ordinary width-based panes and detail focus remain available.
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byKey(const Key('resource-detail-focus')), findsOneWidget);
      expect(find.byKey(const Key('fold-separation')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing before a hinge viewport report is harmless', (
    tester,
  ) async {
    _setView(tester, const Size(640, 900));
    final model = ResourceViewModel(dataSource: _HingeResources());
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _app(data: _horizontalMedia(const Size(640, 900)), model: model),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  required MediaQueryData data,
  required ResourceViewModel model,
  ResourceListDetailDisplayModel? displayModel,
  Widget Function(Widget child)? wrap,
}) {
  Widget child = ResourceListDetail(
    configuration: _configuration,
    viewModel: model,
    displayModel: displayModel,
  );
  if (wrap != null) child = wrap(child);
  return MaterialApp(
    home: MediaQuery(data: data, child: child),
  );
}

MediaQueryData _horizontalMedia(
  Size size, {
  double top = 440,
  double height = 20,
  DisplayFeatureType type = DisplayFeatureType.hinge,
  EdgeInsets padding = EdgeInsets.zero,
}) => MediaQueryData(
  size: size,
  padding: padding,
  displayFeatures: [
    DisplayFeature(
      bounds: Rect.fromLTWH(0, top, size.width, height),
      type: type,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

MediaQueryData _verticalMedia(Size size, {double left = 240}) => MediaQueryData(
  size: size,
  displayFeatures: [
    DisplayFeature(
      bounds: Rect.fromLTWH(left, 0, 20, size.height),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

class _HingeResources implements ResourceDataSource {
  int listCalls = 0;
  int getCalls = 0;

  final list = ResourceRecord(
    id: 'list',
    values: {'name': 'List resource', 'summary': 'Detail for list resource'},
  );
  final other = ResourceRecord(
    id: 'other',
    values: {'name': 'Other resource', 'summary': 'Detail for other resource'},
  );

  @override
  Future<List<ResourceRecord>> listResources() async {
    listCalls++;
    return [list, other];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    getCalls++;
    return switch (id) {
      'list' => list,
      'other' => other,
      _ => null,
    };
  }
}
