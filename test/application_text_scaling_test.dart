import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

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

class _Session {
  _Session() {
    controller = SettingsController(storage: storage);
    view = _ObservedView(controller);
  }
  final storage = ControllableSettingsStorage();
  late final SettingsController controller;
  late final _ObservedView view;
  void dispose() {
    view.dispose();
    controller.dispose();
  }
}

class _ObservedView extends SettingsView {
  _ObservedView(SettingsService service) : super.fromService(service: service);
  bool get isObserved => hasListeners;
}

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text('Probe'), matching: find.byType(RichText)),
    );

Widget _root(
  SettingsView view, {
  TextScaler scaler = const _Nonlinear(),
  Widget? child,
}) => MaterialApp(
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: ApplicationTextScaling(view: view, child: navigator!),
  ),
  home: Scaffold(
    body: child ?? const Text('Probe', style: TextStyle(fontSize: 16)),
  ),
);

class _CatalogService extends ChangeNotifier implements SettingsService {
  _CatalogService(this.registry);
  @override
  final SettingsRegistry registry;
  @override
  SettingsSnapshot get snapshot => SettingsSnapshot(registry: registry);
  @override
  Future<void> load() async => throw StateError('Unexpected I/O');
  @override
  Future<void> retryLoad() => load();
  @override
  Future<void> retrySave() => load();
  @override
  void resetCommon() => throw StateError('Unexpected reset');
  @override
  void setValue(String id, Object value) => throw StateError('Unexpected edit');
}

void main() {
  group('Borrowed app-wide text presentation', () {
    testWidgets(
      'TB01 nested same View scales once and preserves nontext metrics',
      (tester) async {
        // Given one View with Largest and ambient physical/inset/feature metrics.
        final session = _Session();
        addTearDown(session.dispose);
        session.view.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
        const feature = DisplayFeature(
          bounds: Rect.fromLTWH(390, 0, 20, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.unknown,
        );
        const ambient = MediaQueryData(
          size: Size(800, 800),
          padding: EdgeInsets.all(12),
          viewInsets: EdgeInsets.only(bottom: 30),
          displayFeatures: [feature],
          textScaler: _Nonlinear(),
        );
        MediaQueryData? observed;
        TextScaler? effective;
        final child = Builder(
          builder: (context) {
            observed = MediaQuery.of(context);
            effective = ApplicationTextScaling.maybeTextScalerOf(context);
            return Column(
              children: [
                const Text('Probe', style: TextStyle(fontSize: 16)),
                const Icon(Icons.home, size: 24),
                const RawImage(width: 64, height: 64, key: Key('image')),
              ],
            );
          },
        );
        // When an inner boundary sees the already-scaled ambient MediaQuery.
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: ambient,
              child: ApplicationTextScaling(
                view: session.view,
                child: ApplicationTextScaling(view: session.view, child: child),
              ),
            ),
          ),
        );
        await tester.pump();
        // Then rendered text is once-only while all physical metrics stay exact.
        expect(_paragraph(tester).textScaler.scale(16), closeTo(31.2, 1e-10));
        expect(effective!.scale(32), closeTo(52, 1e-10));
        expect(observed!.size, ambient.size);
        expect(observed!.padding, ambient.padding);
        expect(observed!.viewInsets, ambient.viewInsets);
        expect(observed!.displayFeatures, ambient.displayFeatures);
        expect(tester.getSize(find.byType(Icon)), const Size(24, 24));
        expect(
          tester.getSize(find.byKey(const Key('image'))),
          const Size(64, 64),
        );
        expect(session.storage.readCount, 0);
        expect(session.storage.writeCount, 0);
        // When the borrowed boundary detaches.
        await tester.pumpWidget(const SizedBox.shrink());
        // Then its isolated View has no remaining presentation listener.
        expect(session.view.isObserved, isFalse);
      },
    );

    testWidgets('TB01 different nested Views reject authority', (tester) async {
      // Given two separately owned app Settings authorities.
      final one = _Session();
      final two = _Session();
      addTearDown(one.dispose);
      addTearDown(two.dispose);
      // When one boundary nests the other View.
      await tester.pumpWidget(
        _root(
          one.view,
          child: ApplicationTextScaling(
            view: two.view,
            child: const Text('Probe'),
          ),
        ),
      );
      // Then a second app authority is rejected before issuing any I/O.
      expect(tester.takeException(), isArgumentError);
      expect(one.storage.readCount + two.storage.readCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TB02 live OS and explicit edits update actual paragraphs', (
      tester,
    ) async {
      // Given Standard under nonlinear OS scaling and no restoration activity.
      final session = _Session();
      addTearDown(session.dispose);
      await tester.pumpWidget(_root(session.view));
      final initialSnapshot = session.view.snapshot;
      // Then Standard renders the OS result at the original logical role size.
      expect(_paragraph(tester).textScaler.scale(16), 24);
      expect((_paragraph(tester).text as TextSpan).style!.fontSize, 16);
      // When only the root OS scaler changes to linear two.
      await tester.pumpWidget(
        _root(session.view, scaler: const TextScaler.linear(2)),
      );
      // Then rendered output changes without a preference/revision or I/O mutation.
      expect(_paragraph(tester).textScaler.scale(16), 32);
      expect(session.view.snapshot, same(initialSnapshot));
      expect(session.view.snapshot.revision, 0);
      expect(session.view.snapshot.lastIntent, isNull);
      expect(session.storage.readCount, 0);
      expect(session.storage.writeCount, 0);
      // When the same borrowed View explicitly selects Larger.
      session.view.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
      await tester.pump();
      // Then the actual paragraph recomputes once and retains its logical size.
      expect(_paragraph(tester).textScaler.scale(16), closeTo(36.8, 1e-10));
      expect((_paragraph(tester).text as TextSpan).style!.fontSize, 16);
      // When live OS nonlinearity returns with the same app choice.
      await tester.pumpWidget(_root(session.view));
      // Then that unchanged preference follows the new OS function.
      expect(_paragraph(tester).textScaler.scale(16), closeTo(27.6, 1e-10));
      expect(session.view.snapshot.revision, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TB03 root View swap and unmount only rebind observation', (
      tester,
    ) async {
      // Given two isolated borrowed Views with distinct effective choices.
      final one = _Session();
      final two = _Session();
      addTearDown(one.dispose);
      addTearDown(two.dispose);
      two.view.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
      await tester.pumpWidget(_root(one.view));
      // Then only the mounted View is observed and mount creates no intent/I/O.
      expect(one.view.isObserved, isTrue);
      expect(two.view.isObserved, isFalse);
      expect(one.view.snapshot.revision, 0);
      // When app composition swaps the root borrowed View.
      await tester.pumpWidget(_root(two.view));
      // Then old observation detaches and the new effective text appears.
      expect(one.view.isObserved, isFalse);
      expect(two.view.isObserved, isTrue);
      expect(_paragraph(tester).textScaler.scale(16), closeTo(31.2, 1e-10));
      // When a detached View changes and the mounted widget rebuilds.
      one.view.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
      await tester.pumpWidget(_root(two.view));
      // Then the current authority remains unchanged without restoration or save.
      expect(_paragraph(tester).textScaler.scale(16), closeTo(31.2, 1e-10));
      expect(one.storage.readCount + two.storage.readCount, 0);
      expect(one.storage.writeCount + two.storage.writeCount, 0);
      expect(two.view.snapshot.revision, 1);
      // When the final boundary unmounts.
      await tester.pumpWidget(const SizedBox.shrink());
      // Then both View/service lifetimes remain usable with no presentation listener.
      expect(two.view.isObserved, isFalse);
      two.view.setValue(CommonSettings.textSizeMultiplier.id, 1.0);
      expect(two.view.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(one.controller.snapshot.revision, 1);
    });

    for (final forged in [false, true]) {
      testWidgets(
        'TB03 ${forged ? 'forged same-ID' : 'missing'} common definition rejects',
        (tester) async {
          // Given a service whose catalog lacks the actual common text definition.
          final service = _CatalogService(
            SettingsRegistry(
              groups: CommonSettings.groups,
              definitions: [
                if (forged)
                  SettingDefinition<double>(
                    id: CommonSettings.textSizeMultiplier.id,
                    groupId: 'appearance',
                    label: 'Forged',
                    defaultValue: 1.0,
                    choices: [
                      SettingChoice(
                        value: 1.0,
                        label: 'Standard',
                        storedValue: 1.0,
                      ),
                    ],
                  ),
              ],
            ),
          );
          final view = _ObservedView(service);
          addTearDown(service.dispose);
          addTearDown(view.dispose);
          // When the app text boundary attempts to borrow that catalog.
          await tester.pumpWidget(_root(view));
          // Then registration identity is rejected without attaching observation.
          expect(tester.takeException(), isArgumentError);
          expect(view.isObserved, isFalse);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'TB04 explicit invalid wire load renders OS fallback and retains siblings',
      (tester) async {
        // Given invalid text wire data plus valid sibling and unknown retained data.
        final session = _Session();
        addTearDown(session.dispose);
        final wire = SettingsRecord.empty().withUpdates({
          CommonSettings.textSizeMultiplier.id: 1.2,
          CommonSettings.panePreference.id: 'preferSinglePane',
          'unknown.future': {'kept': true},
        }).encode();
        await tester.pumpWidget(_root(session.view));
        // When composition explicitly loads that record through the real controller.
        final load = session.view.load();
        session.storage.reads.single.succeed(wire);
        await load;
        await tester.pump();
        // Then text uses Standard OS fallback with the valid sibling and no default write.
        expect(_paragraph(tester).textScaler.scale(16), 24);
        expect(session.view.value(CommonSettings.textSizeMultiplier), 1.0);
        expect(
          session.view.value(CommonSettings.panePreference),
          SettingsPanePreference.preferSinglePane,
        );
        expect(
          session.view.snapshot.hasExplicitValue(
            CommonSettings.textSizeMultiplier.id,
          ),
          isFalse,
        );
        expect(session.view.snapshot.revision, 0);
        expect(session.storage.readCount, 1);
        expect(session.storage.writeCount, 0);
        // When an unrelated valid text edit is explicitly saved in the fixture.
        session.view.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
        await tester.pump();
        final submitted = SettingsRecord.decode(
          session.storage.writes.single.record,
        );
        // Then the retained unknown and sibling payload survive the ordinary overlay.
        expect(submitted.values['unknown.future'], {'kept': true});
        expect(
          submitted.values[CommonSettings.panePreference.id],
          'preferSinglePane',
        );
        session.storage.writes.single.succeed();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
