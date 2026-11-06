import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cncf_display_mutation_fixture.dart';
import 'cncf_display_presentation_resource_view_test.dart' as presentation;
import 'cncf_display_resource_view_test.dart' as common;

class _BorrowedDelegate<T> extends LocalizationsDelegate<T> {
  const _BorrowedDelegate(this.value);
  final T value;

  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(value);
  @override
  bool shouldReload(_BorrowedDelegate<T> old) => old.value != value;
}

Future<void> _mount(WidgetTester tester, Widget home, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => Localizations.override(
        context: context,
        locale: locale,
        delegates: [
          _BorrowedDelegate<MaterialLocalizations>(
            MaterialLocalizations.of(context),
          ),
          _BorrowedDelegate<WidgetsLocalizations>(
            WidgetsLocalizations.of(context),
          ),
        ],
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
  expect(
    Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
    locale,
  );
}

void main() {
  for (final width in [400.0, 1000.0]) {
    testWidgets('Japanese editor preserves draft, discard and save at $width', (
      tester,
    ) async {
      // Given a real reference fixture and Japanese locale at compact or wide width.
      final fixture = common.session(tester);
      tester.view.physicalSize = Size(width, 800);
      await _mount(tester, common.view(fixture), const Locale('ja'));
      await tester.tap(find.text('日本の民話'));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsOneWidget);
      // When the actual editor opens and a dirty draft is kept through Cancel.
      await tester.tap(find.byKey(common.editKey));
      await tester.pumpAndSettle();
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      const exact = '  日本の民話・改訂\t\n😀  ';
      await tester.enterText(find.byKey(common.titleKey), exact);
      await tester.tap(find.byKey(common.cancelKey));
      await tester.pumpAndSettle();
      expect(find.text('変更を破棄しますか？'), findsOneWidget);
      await tester.tap(find.text('編集を続ける'));
      await tester.pumpAndSettle();
      // Then the exact draft survives and no command was sent.
      expect(
        tester.widget<TextField>(find.byKey(common.titleKey)).controller!.text,
        exact,
      );
      expect(fixture.controller.draftValues[mutationTitle], exact);
      expect(fixture.puts, isEmpty);
      // When Back is confirmed as discard and the editor is opened again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('変更を破棄しますか？'), findsOneWidget);
      await tester.tap(find.text('破棄'));
      await tester.pumpAndSettle();
      expect(find.byKey(common.editorKey), findsNothing);
      expect(fixture.puts, isEmpty);
      await tester.tap(find.byKey(common.editKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(common.titleKey), exact);
      final read = fixture.hold('read');
      await tester.ensureVisible(find.byKey(common.saveKey));
      await tester.tap(find.byKey(common.saveKey));
      await tester.pump();
      await read.entered.future;
      // Then the opaque receipt values and reconciliation warning remain visible.
      expect(find.text('受付済み updated、更新番号 2'), findsOneWidget);
      expect(find.text('再読込が必要です。保存を繰り返さないでください。'), findsOneWidget);
      expect(fixture.puts, hasLength(1));
      // When the real read completes.
      read.release();
      await tester.pumpAndSettle();
      // Then the editor closes and the exact view model value returns without replay.
      expect(find.byKey(common.editorKey), findsNothing);
      expect(fixture.viewModel.selectedResource!.value('title'), exact);
      expect(fixture.source.lastDetail!.resources.single.revision, '2');
      expect(fixture.puts, hasLength(1));
    });
  }

  testWidgets(
    'non-Japanese locale retains English controls and producer data',
    (tester) async {
      // Given the same genuine fixture with a non-Japanese presentation locale.
      final fixture = common.session(tester);
      tester.view.physicalSize = const Size(1000, 800);
      await _mount(tester, common.view(fixture), const Locale('en'));
      // When the Japanese row is selected.
      await tester.tap(find.text('日本の民話'));
      await tester.pumpAndSettle();
      // Then its existing English Edit control remains visible.
      expect(find.text('Edit'), findsOneWidget);
      // When the editor is opened.
      await tester.tap(find.byKey(common.editKey));
      await tester.pumpAndSettle();
      // Then English controls and producer values remain unchanged.
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Title *'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(common.titleKey)).controller!.text,
        '日本の民話',
      );
      expect(fixture.puts, isEmpty);
    },
  );

  testWidgets('Japanese unavailable presentation reloads without commands', (
    tester,
  ) async {
    // Given an actual registry and an uninstalled controlled presentation variant.
    final fixture = presentation.session(
      tester,
      presentationContext: presentation.context('uninstalled'),
    );
    // When the unavailable surface is mounted.
    await _mount(
      tester,
      presentation.view(
        fixture,
        presentationRegistry: presentation.registry(fixture),
      ),
      const Locale('ja'),
    );
    // Then its fixed message hides the unavailable variant.
    expect(find.text('この画面は現在利用できません。'), findsOneWidget);
    expect(find.text('再読込'), findsOneWidget);
    expect(find.text('uninstalled'), findsNothing);
    fixture.presentationContext = presentation.context('reference-variant');
    // When explicit Reload obtains the installed variant.
    await tester.tap(find.byKey(presentation.reloadKey));
    await tester.pumpAndSettle();
    // Then the surface clears without mutation.
    expect(find.text('この画面は現在利用できません。'), findsNothing);
    expect(find.text('Reference list'), findsOneWidget);
    expect(fixture.puts, isEmpty);
    expect(fixture.posts, isEmpty);
  });

  testWidgets(
    'Japanese business receipt preserves outcome and affected resource',
    (tester) async {
      // Given a selected real reference resource and a failing subsequent safe read.
      final fixture = presentation.session(
        tester,
        presentationContext: presentation.context('reference-variant'),
      );
      await _mount(
        tester,
        presentation.view(
          fixture,
          presentationRegistry: presentation.registry(fixture),
        ),
        const Locale('ja'),
      );
      await presentation.select(tester);
      fixture.failRead = true;
      // When the configured business command commits and its read fails.
      await tester.ensureVisible(find.byKey(presentation.businessKey));
      await tester.tap(find.byKey(presentation.businessKey));
      await tester.pumpAndSettle();
      // Then opaque receipt values and the captured title appear with safe guidance.
      expect(find.text('受付済み review-requested、更新番号 2'), findsOneWidget);
      expect(find.text('対象の資料: 日本の民話'), findsOneWidget);
      expect(find.text('再読込が必要です。同じ操作を繰り返さないでください。'), findsOneWidget);
      expect(fixture.posts, hasLength(1));
      // When the safe reload succeeds.
      fixture.failRead = false;
      await tester.tap(find.byKey(common.reloadKey));
      await tester.pumpAndSettle();
      // Then the command is not repeated and reconciliation is cleared.
      expect(fixture.posts, hasLength(1));
      expect(fixture.controller.needsReconciliation, isFalse);
    },
  );

  for (final kind in ['rejection', 'conflict', 'unknown']) {
    testWidgets('Japanese $kind presents a safe failure', (tester) async {
      // Given an editor with a controlled scoped rejection, conflict, or transport failure.
      final fixture = common.session(tester);
      tester.view.physicalSize = const Size(1000, 800);
      await _mount(tester, common.view(fixture), const Locale('ja'));
      await common.openEditor(tester);
      fixture.updateResponse = (_) async => kind == 'unknown'
          ? throw StateError('PRIVATE network detail')
          : fixture.failureReply(
              conflict: kind == 'conflict',
              status: kind == 'conflict' ? 400 : 422,
            );
      await tester.enterText(find.byKey(common.titleKey), ' 日本語 draft ');
      // When one explicit Save fails.
      await tester.tap(find.byKey(common.saveKey));
      await tester.pumpAndSettle();
      // Then the appropriate fixed Japanese message, redaction, draft, and single PUT remain observable.
      expect(
        find.text(
          kind == 'rejection'
              ? '入力内容を確認してください。'
              : kind == 'conflict'
              ? '資料が変更されました。再読込してください。'
              : '操作を完了できませんでした。',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(fixture.controller.draftValues[mutationTitle], ' 日本語 draft ');
      expect(fixture.puts, hasLength(1));
    });
  }

  testWidgets('Japanese pending receipt permits safe reload without replay', (
    tester,
  ) async {
    // Given a controlled pending receipt from the real fixture.
    final fixture = common.session(tester);
    tester.view.physicalSize = const Size(1000, 800);
    await _mount(tester, common.view(fixture), const Locale('ja'));
    await common.openEditor(tester);
    fixture.pending = true;
    await tester.enterText(find.byKey(common.titleKey), ' 保留 ');
    // When Save returns pending.
    await tester.tap(find.byKey(common.saveKey));
    await tester.pumpAndSettle();
    // Then the Japanese receipt and reload guidance appear.
    expect(find.text('受付済み updated、更新番号 2'), findsOneWidget);
    expect(find.text('受付済み（表示への反映待ち）'), findsOneWidget);
    expect(find.text('再読込が必要です。保存を繰り返さないでください。'), findsOneWidget);
    // When Reload reconciles.
    await tester.ensureVisible(find.byKey(common.reloadKey));
    await tester.tap(find.byKey(common.reloadKey));
    await tester.pumpAndSettle();
    // Then the original command is not repeated and the projected value is retained.
    expect(fixture.puts, hasLength(1));
    expect(fixture.viewModel.selectedResource!.value('title'), ' 保留 ');
  });
}
