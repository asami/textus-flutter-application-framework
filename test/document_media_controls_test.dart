import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  void view(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'navigation waits for one draft disposition and denial preserves the selected page',
    (tester) async {
      // Given an active page and a pending caller-owned unsaved-change guard.
      view(tester, const Size(900, 700));
      var guard = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationNavigationShell(
            configuration: ApplicationNavigationConfiguration(
              initialDestinationId: 'a',
              destinations: const [
                NavigationDestinationConfiguration(
                  id: 'a',
                  label: '資料',
                  symbol: NavigationSymbol.folder,
                ),
                NavigationDestinationConfiguration(
                  id: 'b',
                  label: '候補',
                  symbol: NavigationSymbol.lightbulb,
                ),
              ],
            ),
            beforeDestinationChange: (_, _) {
              calls++;
              return guard.future;
            },
            pages: const {'a': Text('入力中'), 'b': Text('候補一覧')},
          ),
        ),
      );
      // When the destination is clicked twice and the guard refuses.
      await tester.tap(find.text('候補'));
      await tester.pump();
      await tester.tap(find.text('候補'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('入力中'), findsOneWidget);
      guard.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('入力中'), findsOneWidget);
      // Then only a later explicit accepted decision changes the page; resize never asks again.
      guard = Completer();
      await tester.tap(find.text('候補'));
      await tester.pump();
      guard.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('候補一覧'), findsOneWidget);
      tester.view.physicalSize = const Size(420, 700);
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
  testWidgets(
    'actual hinge geometry keeps both document panes clear and posture requires explicit edit reentry',
    (tester) async {
      // Given caller-owned draft text and a full-height physical hinge.
      view(tester, const Size(1000, 900));
      final text = TextEditingController(text: '第7巻の未保存メモ');
      addTearDown(text.dispose);
      var changes = 0;
      var saves = 0;
      var hinge = true;
      Widget app() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(1000, 900),
            displayFeatures: hinge
                ? const [
                    DisplayFeature(
                      bounds: Rect.fromLTWH(490, 0, 20, 900),
                      type: DisplayFeatureType.hinge,
                      state: DisplayFeatureState.postureFlat,
                    ),
                  ]
                : [],
          ),
          child: DocumentEditingWorkspace(
            title: '資料',
            navigation: const Text('参照一覧'),
            source: const ColoredBox(
              key: ValueKey('source-pane'),
              color: Colors.white,
            ),
            editing: true,
            onEditingChanged: (_) => changes++,
            onSave: () => saves++,
            status: '未保存',
            editorBuilder: (_, editable) => TextField(
              key: const ValueKey('editor-pane'),
              controller: text,
              readOnly: !editable,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      // When the actual measured body is laid out around the separator.
      final gap = tester.getRect(
        find.byKey(const ValueKey('workspace-fold-separation')),
      );
      expect(gap.left, 490);
      expect(gap.right, 510);
      expect(
        tester.getRect(find.byKey(const ValueKey('source-pane'))).right,
        lessThanOrEqualTo(490),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('editor-pane'))).left,
        greaterThanOrEqualTo(510),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('editor-pane')))
            .readOnly,
        isTrue,
      );
      // Then removing the hinge retains the draft and still cannot save or edit implicitly.
      hinge = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(text.text, '第7巻の未保存メモ');
      expect(saves, 0);
      expect(changes, 0);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('editor-pane')))
            .readOnly,
        isTrue,
      );
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(saves, 0);
    },
  );
  testWidgets(
    'rejected explicit mode change stays suspended after narrowing and reopening',
    (tester) async {
      // Given a wide workspace which has been narrowed and reopened without losing its model.
      view(tester, const Size(1200, 900));
      var changes = 0;
      var guards = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentEditingWorkspace(
            title: '資料',
            navigation: const Text('一覧'),
            source: const Text('原本'),
            editing: true,
            status: '未保存',
            onEditingChanged: (_) => changes++,
            beforeEditingChange: (_) async {
              guards++;
              return false;
            },
            editorBuilder: (_, editable) =>
                TextField(key: const ValueKey('editor'), readOnly: !editable),
          ),
        ),
      );
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();
      // When the domain guard declines an explicit return to editing.
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      // Then the framework cannot clear suspension behind that rejected decision.
      expect(guards, 1);
      expect(changes, 0);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('editor'))).readOnly,
        isTrue,
      );
    },
  );
  testWidgets(
    'media reasons remain accessible and mounting or resizing never invokes acquisition',
    (tester) async {
      // Given denied camera access and unsupported recording, with unknown hardware.
      view(tester, const Size(900, 700));
      final provider = _Media();
      final service = MediaInputService(provider: provider);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaInputPanel(
                service: service,
                onImageConfirmed: (_) async {},
              ),
            ),
          ),
        ),
      );
      // When the viewport narrows and a participant passively rechecks availability.
      tester.view.physicalSize = const Size(390, 700);
      await tester.pumpAndSettle();
      await tester.tap(find.text('利用状態を再確認'));
      await tester.pumpAndSettle();
      // Then denial and configuration limits are visible, with no camera/audio/file request.
      expect(find.textContaining('アクセスが許可されていません'), findsOneWidget);
      expect(find.textContaining('録音する: この構成では対応していません'), findsOneWidget);
      expect(provider.calls, 0);
      expect(provider.inspections, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await service.close();
    },
  );
}

class _Media implements MediaInputProvider {
  int calls = 0, inspections = 0;
  @override
  Map<MediaInputAction, MediaInputCapability> get capabilities => {
    MediaInputAction.imageImport: const MediaInputCapability(
      support: MediaAdapterSupport.supported,
      device: MediaDeviceAvailability.available,
      permission: MediaPermissionState.allowed,
    ),
    MediaInputAction.cameraCapture: const MediaInputCapability(
      support: MediaAdapterSupport.supported,
      device: MediaDeviceAvailability.unknown,
      permission: MediaPermissionState.denied,
    ),
  };
  @override
  Future<Map<MediaInputAction, MediaInputCapability>> inspect() async {
    inspections++;
    return capabilities;
  }

  @override
  Future<CapturedPhoto?> importImage() async {
    calls++;
    return null;
  }

  @override
  Future<CapturedPhoto?> captureImage() => importImage();
  @override
  Future<void> close() async {}
}
