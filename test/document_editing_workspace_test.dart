import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

void main() {
  testWidgets(
    'width changes preserve the draft and require explicit editing reentry without saving',
    (tester) async {
      // Given an explicitly chosen editing mode and a caller-owned input buffer.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '編集中の内容');
      addTearDown(controller.dispose);
      var saves = 0;
      var changes = 0;
      var editing = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => DocumentEditingWorkspace(
              title: '資料の編集',
              navigation: const Text('資料一覧'),
              source: const Text('元の資料'),
              status: '未保存',
              editing: editing,
              onEditingChanged: (value) {
                changes++;
                update(() => editing = value);
              },
              onSave: () => saves++,
              editorBuilder: (_, editable) => TextField(
                key: const ValueKey('draft'),
                controller: controller,
                readOnly: !editable,
              ),
            ),
          ),
        ),
      );
      // When the viewport narrows, then widens without a participant command.
      tester.view.physicalSize = const Size(420, 900);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      // Then the buffer is retained, no mode/save callback ran and editing is suspended.
      expect(controller.text, '編集中の内容');
      expect(changes, 0);
      expect(saves, 0);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('draft'))).readOnly,
        isTrue,
      );
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('draft'))).readOnly,
        isFalse,
      );
      expect(changes, 1);
      expect(saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'keyboard save uses the supplied command only in explicitly editable mode',
    (tester) async {
      // Given a wide document in reference mode with a caller-owned save command.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var editing = false;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => DocumentEditingWorkspace(
              title: '資料の編集',
              navigation: const Text('資料一覧'),
              source: const Text('元の資料'),
              status: '未保存',
              editing: editing,
              onEditingChanged: (value) => update(() => editing = value),
              onSave: () => saves++,
              editorBuilder: (_, editable) => const TextField(),
            ),
          ),
        ),
      );
      // When Ctrl+S is pressed in reference mode, then after explicit editing entry.
      Future<void> saveKey() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }

      await tester.tap(find.byType(TextField));
      await saveKey();
      // Then reference mode does not write; editing forwards exactly one command.
      expect(saves, 0);
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await saveKey();
      expect(saves, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
