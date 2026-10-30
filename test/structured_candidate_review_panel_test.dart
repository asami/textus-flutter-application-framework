import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

StructuredCandidateWorkspace workspace() => StructuredCandidateWorkspace(
  sources: [
    StructuredTextSource(
      id: 's',
      materialId: 'voice',
      kind: StructuredSourceKind.transcript,
      text: '日本語のコメント',
      transcriptRevisionIndex: 2,
    ),
  ],
  proposals: [
    StructuredFieldProposal(
      id: 'p',
      fieldId: 'annotationText',
      value: '日本語のコメント',
      sourceId: 's',
      start: 0,
      end: 8,
      providerId: 'transcript',
      method: 'annotation',
    ),
  ],
);

void main() {
  for (final kind in ['accept', 'discard']) {
    for (final replacement in ['owner', 'source']) {
      testWidgets('retained $kind cannot target a replacement $replacement', (
        tester,
      ) async {
        // Given a rendered action for one Book and its exact retained source.
        var owner = 'book-a';
        var current = workspace();
        var calls = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: StructuredCandidateReviewPanel(
                    ownerId: owner,
                    workspace: current,
                    fieldLabels: const {},
                    currentValues: const {},
                    onDecision: (_, _, _) => calls++,
                  ),
                );
              },
            ),
          ),
        );
        final action = find.byKey(ValueKey('structured-$kind-p'));
        final old = tester.widget<ButtonStyleButton>(action).onPressed!;
        // When the old callback survives equivalent IDs in a new owner or changed source.
        rebuild(() {
          if (replacement == 'owner') {
            owner = 'book-b';
            current = StructuredCandidateWorkspace.fromJson(current.toJson());
          } else {
            final wire = current.toJson();
            (wire['sources'] as List).single['text'] = '別言語のコメント';
            current = StructuredCandidateWorkspace.fromJson(wire);
          }
        });
        await tester.pump();
        old();
        // Then neither the old nor replacement consumer receives a decision.
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('retained edit action cannot open a replacement owner dialog', (
    tester,
  ) async {
    // Given an edit button belonging to the departing Book.
    var owner = 'book-a';
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: StructuredCandidateReviewPanel(
                ownerId: owner,
                workspace: workspace(),
                fieldLabels: const {},
                currentValues: const {},
                onDecision: (_, _, _) => fail('A stale editor must not decide'),
              ),
            );
          },
        ),
      ),
    );
    final old = tester
        .widget<TextButton>(find.byKey(const ValueKey('structured-edit-p')))
        .onPressed!;
    // When a new Book has the same sequential proposal ID and source data.
    rebuild(() => owner = 'book-b');
    await tester.pump();
    old();
    await tester.pumpAndSettle();
    // Then the old gesture neither opens an editor nor acquires the new Book.
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final changedSource in [false, true]) {
    testWidgets(
      'same-owner reconstruction during edit, changedSource=$changedSource',
      (tester) async {
        // Given an active editor for one Book and its exact source snapshot.
        var current = workspace();
        var count = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: StructuredCandidateReviewPanel(
                    ownerId: 'book',
                    workspace: current,
                    fieldLabels: const {},
                    currentValues: const {},
                    onDecision: (_, kind, value) {
                      expect(kind, StructuredDecisionKind.edit);
                      expect(value, '確認した訂正');
                      count++;
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('structured-edit-p')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '確認した訂正');
        // When the parent re-decodes equivalent data or replaces that source.
        rebuild(() {
          final wire = current.toJson();
          if (changedSource) {
            (wire['sources'] as List).single['text'] = '別言語のコメント';
          }
          current = StructuredCandidateWorkspace.fromJson(wire);
        });
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, '採用').last);
        await tester.pumpAndSettle();
        // Then equivalent reconstruction preserves the edit, but source replacement denies it.
        expect(count, changedSource ? 0 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'visible current value and conflict; source navigation does not accept',
    (tester) async {
      // Given a proposal that conflicts with an existing human value.
      final w = workspace();
      final decisions = <StructuredDecisionKind>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructuredCandidateReviewPanel(
                ownerId: 'book',
                workspace: w,
                fieldLabels: const {'annotationText': '注釈'},
                currentValues: const {'annotationText': '人の修正'},
                onDecision: (_, kind, _) => decisions.add(kind),
              ),
            ),
          ),
        ),
      );
      expect(find.text('現在値：人の修正'), findsOneWidget);
      expect(find.textContaining('異なる値があります'), findsOneWidget);
      // When the user opens the source disclosure.
      await tester.tap(find.text('出典を見る'));
      await tester.pumpAndSettle();
      // Then the source is visible without emitting a decision.
      expect(find.textContaining('音声 voice'), findsOneWidget);
      expect(decisions, isEmpty);
      // When the user explicitly accepts that still-pending proposal.
      await tester.ensureVisible(
        find.byKey(const ValueKey('structured-accept-p')),
      );
      await tester.tap(find.byKey(const ValueKey('structured-accept-p')));
      // Then only the explicit callback fires; rendering never mutates the workspace.
      expect(decisions, [StructuredDecisionKind.accept]);
      expect(w.decisions, isEmpty);
    },
  );
  testWidgets('edit can explicitly clear while discard carries no value', (
    tester,
  ) async {
    // Given a pending proposal and a consumer observing exact decision payloads.
    final decisions = <(StructuredDecisionKind, String?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructuredCandidateReviewPanel(
              ownerId: 'book',
              workspace: workspace(),
              fieldLabels: const {'annotationText': '注釈'},
              currentValues: const {},
              onDecision: (_, kind, value) => decisions.add((kind, value)),
            ),
          ),
        ),
      ),
    );
    // When the editor explicitly adopts an empty value.
    await tester.tap(find.byKey(const ValueKey('structured-edit-p')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.widgetWithText(FilledButton, '採用').last);
    await tester.pumpAndSettle();
    // Then the empty edit is a clear, not a cancelled/absent result.
    expect(decisions, [(StructuredDecisionKind.edit, '')]);
    // When a discard callback is requested from the unchanged test consumer.
    await tester.tap(find.byKey(const ValueKey('structured-discard-p')));
    // Then discard carries no replacement field value.
    expect(decisions.last, (StructuredDecisionKind.discard, null));
  });
  testWidgets('live denial blocks callbacks rendered while enabled', (
    tester,
  ) async {
    // Given an enabled rendered action and a separately evaluated live policy.
    var allowed = true;
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StructuredCandidateReviewPanel(
            ownerId: 'book',
            workspace: workspace(),
            fieldLabels: const {},
            currentValues: const {},
            interactionAllowed: () => allowed,
            onDecision: (_, _, _) => count++,
          ),
        ),
      ),
    );
    final callback = tester
        .widget<FilledButton>(find.byKey(const ValueKey('structured-accept-p')))
        .onPressed!;
    // When the policy is revoked before the retained callback executes.
    allowed = false;
    callback();
    // Then the former visual enabled state grants no decision authority.
    expect(count, 0);
  });
  testWidgets(
    'replacing owner while edit dialog is open cannot publish into replacement',
    (tester) async {
      // Given an open dialog holding edits for Book A.
      var owner = 'book-a';
      var count = 0;
      late StateSetter rebuild;
      final w = workspace();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: StructuredCandidateReviewPanel(
                  ownerId: owner,
                  workspace: w,
                  fieldLabels: const {},
                  currentValues: const {},
                  onDecision: (_, _, _) => count++,
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('structured-edit-p')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '別の入力');
      // When Book B replaces A before the dialog confirms.
      rebuild(() => owner = 'book-b');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '採用').last);
      await tester.pumpAndSettle();
      // Then the old input is never published into B.
      expect(count, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
