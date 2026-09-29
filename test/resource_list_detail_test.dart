import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

class _Resources implements ResourceDataSource {
  final record = ResourceRecord(
    id: 'one',
    values: {'name': 'First resource', 'summary': 'Visible from configuration'},
  );

  @override
  Future<List<ResourceRecord>> listResources() async => [record];

  @override
  Future<ResourceRecord?> getResource(String id) async =>
      id == record.id ? record : null;
}

class _FailingResources implements ResourceDataSource {
  _FailingResources({required this.failList});

  final bool failList;

  @override
  Future<List<ResourceRecord>> listResources() {
    if (failList) throw StateError('internal list diagnostic');
    return Future.value([
      ResourceRecord(id: 'one', values: {'name': 'First resource'}),
    ]);
  }

  @override
  Future<ResourceRecord?> getResource(String id) async =>
      throw StateError('internal detail diagnostic');
}

const _configuration = ResourceListDetailConfiguration(
  listTitle: 'Resources',
  detailTitle: 'Detail',
  primaryField: 'name',
  detailFields: [ResourceFieldConfiguration(key: 'summary', label: 'Summary')],
);

void main() {
  test('configuration round-trips through JSON', () {
    // Given a serializable standard List/Detail configuration.
    final configuration = _configuration;

    // When it is encoded and decoded through the public contract.
    final restored = ResourceListDetailConfiguration.fromJson(
      configuration.toJson(),
    );

    // Then every visible choice remains unchanged.
    expect(restored.toJson(), configuration.toJson());
  });

  test('configuration keeps the legacy fold-height default and rejects invalid layout values', () {
    const legacy = <String, dynamic>{
      'listTitle': 'Resources',
      'detailTitle': 'Detail',
      'primaryField': 'name',
      'detailFields': [
        {'key': 'summary', 'label': 'Summary'},
      ],
    };
    final restored = ResourceListDetailConfiguration.fromJson(legacy);

    expect(restored.minimumFoldPaneHeight, 180);
    expect(restored.toJson()['minimumFoldPaneHeight'], 180);
    for (final value in <double>[0, -1, double.infinity, double.nan]) {
      expect(
        () => ResourceListDetailConfiguration.fromJson({
          ...legacy,
          'minimumFoldPaneHeight': value,
        }),
        throwsFormatException,
      );
    }
  });

  testWidgets('compact selection navigates to configured detail', (
    tester,
  ) async {
    // Given a compact viewport and one Resource from an application binding.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceListDetail(
          configuration: _configuration,
          viewModel: ResourceViewModel(dataSource: _Resources()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // When the user selects that Resource.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then the configured detail opens as a navigated page.
    expect(find.text('Detail'), findsOneWidget);
    expect(find.text('Visible from configuration'), findsOneWidget);
  });

  testWidgets('expanded selection updates the detail pane', (tester) async {
    // Given an expanded viewport and one Resource.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceListDetail(
          configuration: _configuration,
          viewModel: ResourceViewModel(dataSource: _Resources()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a resource'), findsOneWidget);
    // When the user selects that Resource.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then detail replaces the pane placeholder without navigation.
    expect(find.text('Visible from configuration'), findsOneWidget);
    expect(find.text('Select a resource'), findsNothing);
  });

  testWidgets('detail fields change through configuration alone', (
    tester,
  ) async {
    // Given a detail configuration selecting the name instead of summary.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const alternate = ResourceListDetailConfiguration(
      listTitle: 'Resources',
      detailTitle: 'Detail',
      primaryField: 'name',
      detailFields: [ResourceFieldConfiguration(key: 'name', label: 'Name')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceListDetail(
          configuration: alternate,
          viewModel: ResourceViewModel(dataSource: _Resources()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // When the same standard Widget receives a Resource selection.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then only the configured detail field is presented.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Visible from configuration'), findsNothing);
  });

  testWidgets('list failures hide internal diagnostics', (tester) async {
    // Given a data source that fails with an internal diagnostic.
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceListDetail(
          configuration: _configuration,
          viewModel: ResourceViewModel(
            dataSource: _FailingResources(failList: true),
          ),
        ),
      ),
    );

    // When the list request completes with an error.
    await tester.pumpAndSettle();

    // Then the user receives a safe message without the internal detail.
    expect(find.text('Could not load resources'), findsOneWidget);
    expect(find.textContaining('internal list diagnostic'), findsNothing);
  });

  testWidgets('detail failures hide internal diagnostics', (tester) async {
    // Given a data source whose list loads but detail request fails.
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceListDetail(
          configuration: _configuration,
          viewModel: ResourceViewModel(
            dataSource: _FailingResources(failList: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // When the user selects a Resource.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then the detail error does not reveal the internal diagnostic.
    expect(find.text('Could not load resource'), findsOneWidget);
    expect(find.textContaining('internal detail diagnostic'), findsNothing);
  });

  testWidgets('vertical hinge creates two panes below the normal breakpoint', (
    tester,
  ) async {
    // Given a 640-pixel view whose Core-recognized hinge separates two panes.
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            viewModel: ResourceViewModel(dataSource: _Resources()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // When the user selects a resource at a width normally considered compact.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then detail stays beside the list and the physical hinge is unpainted.
    expect(find.text('Visible from configuration'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('fold-separation'))).width, 20);
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('undersized fold panes fall back to compact navigation', (
    tester,
  ) async {
    // Given a hinge with less than the configured minimum width per pane.
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(500, 800),
            displayFeatures: [
              DisplayFeature(
                bounds: Rect.fromLTWH(240, 0, 20, 800),
                type: DisplayFeatureType.hinge,
                state: DisplayFeatureState.postureFlat,
              ),
            ],
          ),
          child: ResourceListDetail(
            configuration: _configuration,
            viewModel: ResourceViewModel(dataSource: _Resources()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // When the user selects a resource.
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then the detail opens by navigation instead of squeezing across the hinge.
    expect(find.text('Detail'), findsOneWidget);
    expect(find.byKey(const Key('fold-separation')), findsNothing);
  });
}
