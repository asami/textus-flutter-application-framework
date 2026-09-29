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
  for (final axis in Axis.values) {
    for (final gap in [20.0, 0.0]) {
      testWidgets(
        '${axis.name} ${gap == 0 ? 'zero-fold' : 'occluding'} policy switches retain focused selection',
        (tester) async {
          // Given a full-body recognized feature with both policy options viable.
          const size = Size(1000, 900);
          _setView(tester, size);
          final source = _PolicyResources();
          final model = ResourceViewModel(dataSource: source);
          final displayModel = ResourceListDetailDisplayModel();
          addTearDown(model.dispose);
          addTearDown(displayModel.dispose);
          await tester.pumpWidget(
            _app(
              data: _featureMedia(size, axis: axis, gap: gap),
              model: model,
              displayModel: displayModel,
            ),
          );
          await tester.pumpAndSettle();

          // When the automatic treatment is inspected then changed to avoid.
          expect(displayModel.hingePolicyOverride, isNull);
          expect(
            find.byKey(const Key('resource-hinge-policy')),
            findsOneWidget,
          );
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
          expect(avoid.checked, gap > 0);
          expect(span.checked, gap == 0);
          expect(avoid.enabled, isTrue);
          expect(span.enabled, isTrue);
          expect(
            find.text('ヒンジ部分では内容が隠れる場合があります'),
            gap > 0 ? findsOneWidget : findsNothing,
          );
          if (gap == 0) {
            await tester.tap(find.byKey(const Key('resource-hinge-avoid')));
            await tester.pumpAndSettle();
          } else {
            await tester.tapAt(Offset.zero);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('List resource'));
          await tester.pumpAndSettle();

          // Then avoid lays out complete orientation-specific panes and focus.
          final expected = _avoidRects(axis, gap);
          expect(_listRect(tester, model), expected.list);
          expect(_detailRect(tester), expected.detail);
          await tester.tap(find.byKey(const Key('resource-detail-focus')));
          await tester.pumpAndSettle();
          expect(_detailRect(tester), expected.focusedDetail);
          expect(model.selectedId, 'list');
          expect(
            displayModel.preference,
            ResourceListDetailDisplayPreference.detailFocused,
          );

          // When the focused presentation changes from avoid to span.
          await tester.tap(find.byKey(const Key('resource-hinge-policy')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('resource-hinge-span')));
          await tester.pumpAndSettle();

          // Then the detail spans the safe body without changing focus or selection.
          expect(_detailRect(tester), const Rect.fromLTRB(0, 56, 1000, 900));
          expect(model.selectedId, 'list');
          expect(
            displayModel.preference,
            ResourceListDetailDisplayPreference.detailFocused,
          );
          expect(
            displayModel.hingePolicyOverride,
            ResourceListDetailHingePolicy.span,
          );
          final menu = tester
              .widget<PopupMenuButton<ResourceListDetailHingePolicy>>(
                find.byKey(const Key('resource-hinge-policy')),
              );
          expect(menu.tooltip, contains('ヒンジの扱い'));
          expect(
            menu.tooltip,
            gap > 0
                ? contains('ヒンジ部分では内容が隠れる場合があります')
                : isNot(contains('ヒンジ部分では内容が隠れる場合があります')),
          );
          await tester.tap(find.byKey(const Key('resource-restore-split')));
          await tester.pumpAndSettle();
          expect(
            displayModel.hingePolicyOverride,
            ResourceListDetailHingePolicy.span,
          );
          expect(find.byKey(const Key('fold-separation')), findsNothing);
          expect(source.listCalls, 1);
          expect(source.getCalls, 1);
        },
      );
    }
  }

  testWidgets('configured policy works while the switch is disabled', (
    tester,
  ) async {
    // Given two configurations that hide the user policy switch.
    const size = Size(1000, 900);
    _setView(tester, size);
    for (final policy in [
      ResourceListDetailHingePolicy.avoid,
      ResourceListDetailHingePolicy.span,
    ]) {
      final model = ResourceViewModel(dataSource: _PolicyResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(
          data: _featureMedia(size, axis: Axis.horizontal, gap: 20),
          model: model,
          configuration: ResourceListDetailConfiguration(
            listTitle: 'Resources',
            detailTitle: 'Detail',
            primaryField: 'name',
            detailFields: const [
              ResourceFieldConfiguration(key: 'summary', label: 'Summary'),
            ],
            defaultHingePolicy: policy,
            allowHingePolicySwitch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When the configured initial treatment resolves.
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      // Then its layout applies although the policy menu remains hidden.
      expect(find.byKey(const Key('resource-hinge-policy')), findsNothing);
      expect(
        find.byKey(const Key('fold-separation')),
        policy == ResourceListDetailHingePolicy.avoid
            ? findsOneWidget
            : findsNothing,
      );
    }
  });

  testWidgets(
    'latent override survives compact no-feature and orientation changes',
    (tester) async {
      // Given a selected resource with an explicit span override on a vertical hinge.
      const wide = Size(1000, 900);
      _setView(tester, wide);
      final source = _PolicyResources();
      final model = ResourceViewModel(dataSource: source);
      final displayModel = ResourceListDetailDisplayModel()
        ..setHingePolicy(ResourceListDetailHingePolicy.span);
      addTearDown(model.dispose);
      addTearDown(displayModel.dispose);
      await tester.pumpWidget(
        _app(
          data: _featureMedia(wide, axis: Axis.horizontal, gap: 20),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();

      // When the body shrinks, loses the feature, then gains a horizontal feature.
      const compact = Size(400, 900);
      _setView(tester, compact);
      await tester.pumpWidget(
        _app(
          data: _featureMedia(compact, axis: Axis.horizontal, gap: 20),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-hinge-policy')), findsNothing);
      await tester.pumpWidget(
        _app(
          data: const MediaQueryData(size: wide),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-hinge-policy')), findsNothing);
      _setView(tester, wide);
      await tester.pumpWidget(
        _app(
          data: _featureMedia(wide, axis: Axis.vertical, gap: 20),
          model: model,
          displayModel: displayModel,
        ),
      );
      await tester.pumpAndSettle();

      // Then the override becomes active again without another domain load.
      expect(find.byKey(const Key('resource-hinge-policy')), findsOneWidget);
      expect(
        displayModel.hingePolicyOverride,
        ResourceListDetailHingePolicy.span,
      );
      expect(find.byKey(const Key('fold-separation')), findsNothing);
      expect(model.selectedId, 'list');
      expect(source.listCalls, 1);
      expect(source.getCalls, 1);
    },
  );

  testWidgets('asymmetric avoid compactness still exposes viable span', (
    tester,
  ) async {
    // Given a horizontal hinge whose upper safe region is below the avoid minimum.
    const size = Size(1000, 900);
    _setView(tester, size);
    final model = ResourceViewModel(dataSource: _PolicyResources());
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _app(
        data: _featureMedia(
          size,
          axis: Axis.vertical,
          gap: 20,
          coordinate: 140,
        ),
        model: model,
      ),
    );
    await tester.pumpAndSettle();

    // When the policy menu is opened from the avoid-compact presentation.
    expect(find.byType(BackButton), findsNothing);
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

    // Then span remains enabled and can escape compactness.
    expect(avoid.enabled, isFalse);
    expect(span.enabled, isTrue);
    await tester.tap(find.byKey(const Key('resource-hinge-span')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List resource'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNWidgets(2));
    expect(find.byKey(const Key('fold-separation')), findsNothing);
  });

  testWidgets(
    'narrow horizontal body disables span while focused avoid stays safe',
    (tester) async {
      // Given a narrow but vertically stackable horizontal hinge layout.
      const size = Size(400, 900);
      _setView(tester, size);
      final model = ResourceViewModel(dataSource: _PolicyResources());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(
          data: _featureMedia(size, axis: Axis.vertical, gap: 20),
          model: model,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List resource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-detail-focus')));
      await tester.pumpAndSettle();

      // When the available policy choices are inspected while detail is focused.
      await tester.tap(find.byKey(const Key('resource-hinge-policy')));
      await tester.pumpAndSettle();
      final span = tester
          .widget<CheckedPopupMenuItem<ResourceListDetailHingePolicy>>(
            find.byKey(const Key('resource-hinge-span')),
          );

      // Then span is disabled and focused avoidance retains its trailing region.
      expect(span.enabled, isFalse);
      expect(_detailRect(tester), const Rect.fromLTRB(0, 460, 400, 900));
      expect(model.selectedId, 'list');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending geometry observer remains harmless after disposal', (
    tester,
  ) async {
    // Given a widget that has observed but not yet approved a fold viewport.
    const size = Size(1000, 900);
    _setView(tester, size);
    final model = ResourceViewModel(dataSource: _PolicyResources());
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _app(
        data: _featureMedia(size, axis: Axis.horizontal, gap: 20),
        model: model,
      ),
    );

    // When it is removed before the pending measurement callback is used.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // Then the observer reports no disposal-time exception.
    expect(tester.takeException(), isNull);
  });
}

class _AvoidRects {
  const _AvoidRects({
    required this.list,
    required this.detail,
    required this.focusedDetail,
  });

  final Rect list;
  final Rect detail;
  final Rect focusedDetail;
}

_AvoidRects _avoidRects(Axis axis, double gap) => axis == Axis.horizontal
    ? _AvoidRects(
        list: const Rect.fromLTRB(0, 56, 490, 900),
        detail: Rect.fromLTRB(510 - (20 - gap), 56, 1000, 900),
        focusedDetail: Rect.fromLTRB(510 - (20 - gap), 56, 1000, 900),
      )
    : _AvoidRects(
        list: const Rect.fromLTRB(0, 56, 1000, 440),
        detail: Rect.fromLTRB(0, 460 - (20 - gap), 1000, 900),
        focusedDetail: Rect.fromLTRB(0, 460 - (20 - gap), 1000, 900),
      );

Rect _listRect(WidgetTester tester, ResourceViewModel model) =>
    tester.getRect(find.byKey(PageStorageKey<ResourceViewModel>(model)));

Rect _detailRect(WidgetTester tester) =>
    tester.getRect(find.byType(ListView).last);

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  required MediaQueryData data,
  required ResourceViewModel model,
  ResourceListDetailConfiguration configuration = _configuration,
  ResourceListDetailDisplayModel? displayModel,
}) => MaterialApp(
  home: MediaQuery(
    data: data,
    child: ResourceListDetail(
      configuration: configuration,
      viewModel: model,
      displayModel: displayModel,
    ),
  ),
);

MediaQueryData _featureMedia(
  Size size, {
  required Axis axis,
  required double gap,
  double? coordinate,
}) => MediaQueryData(
  size: size,
  displayFeatures: [
    DisplayFeature(
      bounds: axis == Axis.horizontal
          ? Rect.fromLTWH(coordinate ?? 490, 0, gap, size.height)
          : Rect.fromLTWH(0, coordinate ?? 440, size.width, gap),
      type: gap == 0 ? DisplayFeatureType.fold : DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

class _PolicyResources implements ResourceDataSource {
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
