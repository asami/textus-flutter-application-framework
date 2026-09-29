import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

class _AdaptiveResources implements ResourceDataSource {
  const _AdaptiveResources();

  static final first = ResourceRecord(
    id: 'first',
    values: {'name': 'First resource', 'summary': 'First detail summary'},
  );
  static final second = ResourceRecord(
    id: 'second',
    values: {'name': 'Second resource', 'summary': 'Second detail summary'},
  );

  @override
  Future<List<ResourceRecord>> listResources() async => [first, second];

  @override
  Future<ResourceRecord?> getResource(String id) async => switch (id) {
    'first' => first,
    'second' => second,
    _ => null,
  };
}

const _configuration = ResourceListDetailConfiguration(
  listTitle: 'Resources',
  detailTitle: 'Detail',
  primaryField: 'name',
  detailFields: [ResourceFieldConfiguration(key: 'summary', label: 'Summary')],
);

void main() {
  group('ResourceListDetail adaptive presentation', () {
    testWidgets(
      'should reveal list and selected detail when compact detail gains space',
      (tester) async {
        // Given a compact viewport with two distinct Resources and summaries.
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        final model = ResourceViewModel(dataSource: const _AdaptiveResources());
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When the first Resource detail is opened and the same app gains space.
        await tester.tap(find.text('First resource'));
        await tester.pumpAndSettle();
        expect(find.text('Detail'), findsOneWidget);
        tester.view.physicalSize = const Size(1000, 800);
        await tester.pumpAndSettle();

        // Then the list and the unchanged selected detail are visible together.
        expect(find.text('Resources'), findsOneWidget);
        expect(find.text('Second resource'), findsOneWidget);
        expect(find.text('First detail summary'), findsOneWidget);
        expect(model.selectedId, 'first');
      },
    );

    testWidgets('should focus and restore split while keeping selection', (
      tester,
    ) async {
      // Given a selected Resource in a split-capable viewport.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: _configuration,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // When detail focus is requested and then split is restored.
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();
      expect(find.text('Second resource'), findsNothing);
      expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
      await tester.tap(find.byKey(const Key('resource-restore-split')));
      await tester.pumpAndSettle();

      // Then the list and unchanged selected detail are shown side by side.
      expect(find.text('Second resource'), findsOneWidget);
      expect(find.text('First detail summary'), findsOneWidget);
      expect(model.selectedId, 'first');
    });

    testWidgets('should retain explicit focus across compact space changes', (
      tester,
    ) async {
      // Given an explicitly focused selected detail in ample space.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: _configuration,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      // When space shrinks and then returns.
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
      expect(find.byKey(const Key('resource-restore-split')), findsNothing);
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();

      // Then the remembered focus is restored with the same detail.
      expect(find.byKey(const Key('resource-restore-split')), findsOneWidget);
      expect(find.text('Second resource'), findsNothing);
      expect(find.text('First detail summary'), findsOneWidget);
    });

    testWidgets('should show compact list from both back controls', (
      tester,
    ) async {
      // Given a compact selected detail.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: _configuration,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // When the visible back button and then system back are invoked.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Second resource'), findsOneWidget);
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Then each returns to the compact list without clearing selection.
      expect(find.text('Second resource'), findsOneWidget);
      expect(model.selectedId, 'first');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'should retain selected detail when split space becomes compact',
      (tester) async {
        // Given a selected Resource in a split-capable viewport.
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        final model = ResourceViewModel(dataSource: const _AdaptiveResources());
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('First resource'));
        await tester.pumpAndSettle();

        // When the usable width becomes compact.
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpAndSettle();

        // Then the selected detail remains in compact sequential presentation.
        expect(find.text('Detail'), findsOneWidget);
        expect(find.text('First detail summary'), findsOneWidget);
        expect(model.selectedId, 'first');
      },
    );

    testWidgets('should keep no-selection split and disabled focus valid', (
      tester,
    ) async {
      // Given focus-disabled configuration in split-capable space.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: const ResourceListDetailConfiguration(
              listTitle: 'Resources',
              detailTitle: 'Detail',
              primaryField: 'name',
              detailFields: [
                ResourceFieldConfiguration(key: 'summary', label: 'Summary'),
              ],
              allowDetailFocus: false,
            ),
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When there is no selection and then the first Resource is selected.
      expect(find.text('Select a resource'), findsOneWidget);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // Then split detail remains valid without a focus control.
      expect(find.text('First detail summary'), findsOneWidget);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
    });

    testWidgets('should use the trailing region for focused hinge detail', (
      tester,
    ) async {
      // Given a hinge-separated layout with two eligible display regions.
      tester.view.physicalSize = const Size(640, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(640, 800),
              displayFeatures: [
                DisplayFeature(
                  bounds: Rect.fromLTWH(310, 0, 20, 800),
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureFlat,
                ),
              ],
            ),
            child: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // When focused detail is requested.
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      // Then only the trailing contiguous region presents the detail.
      expect(find.byKey(const Key('fold-separation')), findsNothing);
      expect(
        tester.getTopLeft(find.text('First detail summary')).dx,
        greaterThanOrEqualTo(330),
      );
    });

    testWidgets(
      'should use full safe content width for focused zero-width fold detail',
      (tester) async {
        // Given an adjoining zero-width fold with a selected Resource.
        tester.view.physicalSize = const Size(640, 800);
        tester.view.devicePixelRatio = 1;
        final model = ResourceViewModel(dataSource: const _AdaptiveResources());
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(640, 800),
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(320, 0, 0, 800),
                    type: DisplayFeatureType.fold,
                    state: DisplayFeatureState.postureHalfOpened,
                  ),
                ],
              ),
              child: ResourceListDetail(
                configuration: _configuration,
                viewModel: model,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('First resource'));
        await tester.pumpAndSettle();

        // When focused detail is requested.
        await tester.tap(find.byKey(const Key('resource-detail-focus')));
        await tester.pumpAndSettle();

        // Then detail uses the full adjoining SafeArea and retains selection.
        expect(tester.getSize(find.byType(ListView)).width, 640);
        expect(find.text('Second resource'), findsNothing);
        expect(model.selectedId, 'first');
      },
    );

    testWidgets('should use horizontal safe insets for compact capability', (
      tester,
    ) async {
      // Given a raw wide viewport whose safe content is below the breakpoint.
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 800),
              padding: EdgeInsets.symmetric(horizontal: 60),
            ),
            child: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When the first Resource is opened within its 680-pixel safe content.
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // Then compact detail is used and no expanded focus control is exposed.
      expect(find.text('Detail'), findsOneWidget);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
    });

    testWidgets('should fit a no-fold split inside horizontal safe insets', (
      tester,
    ) async {
      // Given a split-capable viewport with horizontal SafeArea insets.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1000, 800),
              padding: EdgeInsets.symmetric(horizontal: 60),
            ),
            child: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When a selected Resource is rendered in the safe split region.
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // Then both panes render without a layout overflow.
      expect(find.text('First detail summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('should make an inset-reduced hinge pane compact', (
      tester,
    ) async {
      // Given a hinged viewport whose leading safe pane is below the minimum.
      tester.view.physicalSize = const Size(640, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(640, 800),
              padding: EdgeInsets.only(left: 40),
              displayFeatures: [
                DisplayFeature(
                  bounds: Rect.fromLTWH(310, 0, 20, 800),
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureFlat,
                ),
              ],
            ),
            child: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When the first Resource is selected.
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // Then the unusable hinge split resolves as compact detail.
      expect(find.text('Detail'), findsOneWidget);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
    });

    testWidgets('should align viable hinge panes to their safe geometry', (
      tester,
    ) async {
      // Given a hinge whose inset-adjusted panes remain eligible for a split.
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 800),
              padding: EdgeInsets.only(left: 30, right: 40),
              displayFeatures: [
                DisplayFeature(
                  bounds: Rect.fromLTWH(380, 0, 20, 800),
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureFlat,
                ),
              ],
            ),
            child: ResourceListDetail(
              configuration: _configuration,
              viewModel: model,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();

      // When the selected Resource is shown in its split presentation.
      final list = find.byKey(PageStorageKey<ResourceViewModel>(model));

      // Then the leading pane and physical gap match safe-region geometry.
      expect(tester.getSize(list).width, 350);
      expect(
        tester.getSize(find.byKey(const Key('fold-separation'))).width,
        20,
      );
      expect(tester.getTopLeft(list).dx, 30);
    });

    testWidgets('should leave an unavailable focused Resource in safe split', (
      tester,
    ) async {
      // Given a focused selected Resource backed by a mutable source.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      final source = _MutableAdaptiveResources();
      final model = ResourceViewModel(dataSource: source);
      final displayModel = ResourceListDetailDisplayModel();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(model.dispose);
      addTearDown(displayModel.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: _configuration,
            viewModel: model,
            displayModel: displayModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      // When the selected record disappears and detail is refreshed.
      source.isAvailable = false;
      await model.detailView.refresh();
      await tester.pumpAndSettle();

      // Then split list and not-found detail remain safe without semantic loss.
      expect(find.text('Second resource'), findsOneWidget);
      expect(find.text('Resource not found'), findsOneWidget);
      expect(find.byKey(const Key('resource-detail-focus')), findsNothing);
      expect(find.byKey(const Key('resource-restore-split')), findsNothing);
      expect(model.selectedId, 'first');
      expect(
        displayModel.preference,
        ResourceListDetailDisplayPreference.detailFocused,
      );
    });

    testWidgets(
      'should restore independent list offsets by view model identity',
      (tester) async {
        // Given two separately-owned long resource models sharing one bucket.
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        final modelA = ResourceViewModel(
          dataSource: const _ScrollableAdaptiveResources('A'),
        );
        final modelB = ResourceViewModel(
          dataSource: const _ScrollableAdaptiveResources('B'),
        );
        final displayA = ResourceListDetailDisplayModel();
        final bucket = PageStorageBucket();
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(modelA.dispose);
        addTearDown(modelB.dispose);
        addTearDown(displayA.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: PageStorage(
              bucket: bucket,
              child: ResourceListDetail(
                key: const ValueKey('model-a'),
                configuration: _configuration,
                viewModel: modelA,
                displayModel: displayA,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final listA = find.byKey(PageStorageKey<ResourceViewModel>(modelA));
        await tester.drag(listA, const Offset(0, -600));
        await tester.pumpAndSettle();
        final listAOffset = tester
            .state<ScrollableState>(
              find.descendant(of: listA, matching: find.byType(Scrollable)),
            )
            .position
            .pixels;
        final listAKey = tester.widget<ListView>(listA).key;
        await tester.tap(find.text('A resource 12'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resource-detail-focus')));
        await tester.pumpAndSettle();

        // When focused A is removed, B is used, and A is restored.
        await tester.pumpWidget(
          MaterialApp(
            home: PageStorage(
              bucket: bucket,
              child: ResourceListDetail(
                key: const ValueKey('model-b'),
                configuration: _configuration,
                viewModel: modelB,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final listB = find.byKey(PageStorageKey<ResourceViewModel>(modelB));
        final listBKey = tester.widget<ListView>(listB).key;
        await tester.drag(listB, const Offset(0, -240));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            home: PageStorage(
              bucket: bucket,
              child: ResourceListDetail(
                key: const ValueKey('model-a'),
                configuration: _configuration,
                viewModel: modelA,
                displayModel: displayA,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resource-restore-split')));
        await tester.pumpAndSettle();

        // Then A retains its offset and its storage identity differs from B.
        final restoredA = find.byKey(PageStorageKey<ResourceViewModel>(modelA));
        final restoredAOffset = tester
            .state<ScrollableState>(
              find.descendant(of: restoredA, matching: find.byType(Scrollable)),
            )
            .position
            .pixels;
        expect(listAOffset, greaterThan(0));
        expect(restoredAOffset, closeTo(listAOffset, 1));
        expect(listAKey, isNot(equals(listBKey)));
      },
    );

    testWidgets('should not dispose an application supplied display model', (
      tester,
    ) async {
      // Given a Resource List + Detail with app-owned presentation state.
      final model = ResourceViewModel(dataSource: const _AdaptiveResources());
      final displayModel = _TrackingDisplayModel();
      addTearDown(model.dispose);
      addTearDown(displayModel.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListDetail(
            configuration: _configuration,
            viewModel: model,
            displayModel: displayModel,
          ),
        ),
      );

      // When the framework Widget is removed.
      await tester.pumpWidget(const SizedBox.shrink());

      // Then the application remains responsible for disposing that state.
      expect(displayModel.wasDisposed, isFalse);
    });
  });
}

class _TrackingDisplayModel extends ResourceListDetailDisplayModel {
  bool wasDisposed = false;

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

class _MutableAdaptiveResources implements ResourceDataSource {
  bool isAvailable = true;

  @override
  Future<List<ResourceRecord>> listResources() async => [
    _AdaptiveResources.first,
    _AdaptiveResources.second,
  ];

  @override
  Future<ResourceRecord?> getResource(String id) async =>
      isAvailable && id == _AdaptiveResources.first.id
      ? _AdaptiveResources.first
      : id == _AdaptiveResources.second.id
      ? _AdaptiveResources.second
      : null;
}

class _ScrollableAdaptiveResources implements ResourceDataSource {
  const _ScrollableAdaptiveResources(this.prefix);

  final String prefix;

  List<ResourceRecord> get _resources => List.generate(
    30,
    (index) => ResourceRecord(
      id: '$prefix-$index',
      values: {
        'name': '$prefix resource $index',
        'summary': '$prefix detail $index',
      },
    ),
  );

  @override
  Future<List<ResourceRecord>> listResources() async => _resources;

  @override
  Future<ResourceRecord?> getResource(String id) async {
    for (final resource in _resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }
}
