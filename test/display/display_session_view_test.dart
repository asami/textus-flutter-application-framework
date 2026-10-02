import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/display_presentation_fixture.dart';

void main() {
  group('Public generic Display view', () {
    for (final automatic in [true, false]) {
      testWidgets(automatic ? 'VW01-automatic' : 'VW01-manual', (tester) async {
        // Given a pristine caller-owned controller and explicit autoLoad preference.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        // When the public view mounts and rebuilds.
        await mountView(tester, f.controller, autoLoad: automatic);
        await tester.pump();
        // Then exactly one automatic query or zero manual ports occur, without eager Detail.
        expect(f.source.callCount, automatic ? 1 : 0);
        expect(f.session.state.selectedResourceId, isNull);
        expect(f.session.state.detail.phase, DisplaySessionReadPhase.idle);
        expect(f.source.operationCallCount, 0);
        expect(
          f.source.calls.where((call) => call.kind == DisplayRequestKind.read),
          isEmpty,
        );
      });
    }
    for (final width in [400.0, 1200.0]) {
      testWidgets(width == 400 ? 'VW02-compact' : 'VW02-expanded', (
        tester,
      ) async {
        // Given ordered typed source rows and ordinary compact/expanded capability.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        // When the public List loads.
        await mountView(tester, f.controller, width: width);
        // Then row order matches producer order rather than client resource semantics.
        final first = find.byKey(const ValueKey(('display-resource', 'doc:1')));
        final second = find.byKey(
          const ValueKey(('display-resource', 'doc:2')),
        );
        expect(
          tester.getTopLeft(first).dy,
          lessThan(tester.getTopLeft(second).dy),
        );
        expect(
          f.session.state.list.data!.model.items.map((row) => row.resourceId),
          ['doc:1', 'doc:2'],
        );
        // Given an accepted ordered row.
        // When that resource is explicitly selected.
        await tester.tap(first);
        await tester.pumpAndSettle();
        // Then Detail selection is accepted at the correct scope and layout.
        expect(f.session.state.selectedResourceId, 'doc:1');
        expect(find.text('Document detail'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('display-list')),
          width == 400 ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const ValueKey('display-detail')), findsOneWidget);
        expect(
          f.session.state.detail.data!.model.sections.first.fields.map(
            (field) => field.id,
          ),
          ['title', 'description', 'stage'],
        );
      });
    }
    for (final entry in [
      ('VW03-A', 'A', 'en', DisplayDefinitionStyle.standard),
      ('VW03-B', 'B', 'en', DisplayDefinitionStyle.cards),
      ('VW03-C', 'C', 'en', DisplayDefinitionStyle.sections),
      ('VW03-neutral-locale', null, 'ja', DisplayDefinitionStyle.standard),
    ]) {
      testWidgets(entry.$1, (tester) async {
        // Given declarative supplied style/locale data without a consumer arm branch.
        final f = PresentationFixture(
          context: presentationContext(arm: entry.$2, locale: entry.$3),
        );
        addTearDown(f.dispose);
        viewportCleanup(tester);
        // When the generic view renders the supplied definition.
        await mountView(tester, f.controller);
        // Then distinct presentation structure and admitted locale chrome are observable.
        expect(
          find.byKey(ValueKey(('display-style', entry.$4.name))),
          findsOneWidget,
        );
        expect(
          find.byType(Card),
          entry.$4 == DisplayDefinitionStyle.cards
              ? findsNWidgets(2)
              : findsNothing,
        );
        expect(
          find.byType(ExpansionTile),
          entry.$4 == DisplayDefinitionStyle.sections
              ? findsNWidgets(2)
              : findsNothing,
        );
        expect(
          find.byType(ListTile),
          entry.$4 == DisplayDefinitionStyle.sections
              ? findsNWidgets(2)
              : findsNWidgets(2),
        );
        expect(
          find.text(entry.$3 == 'ja' ? '再読み込み' : 'Reload'),
          findsOneWidget,
        );
        expect(f.session.state.context, f.fixture.contexts.values.single);
        expect(f.source.resources.first.sourceRevision, 1);
      });
    }
    testWidgets('VW04-scoped-edit-errors', (tester) async {
      // Given generic Detail with scoped repeated field IDs and read-only stage.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      f.port.readTransform = duplicateSection;
      await openView(tester, f);
      // When Edit is explicitly opened for that Detail.
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // Then three writable scoped fields exist and stage remains visible read-only.
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Collecting'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey(('display-field', 'detail', 'main', 'stage')),
        ),
        findsNothing,
      );
      // Given the repeated title in another section is independently writable.
      // When only that input is made blank and Save is explicitly selected.
      await typeTitle(tester, ' ', section: 'other');
      await tapKey(tester, 'display-save');
      // Then only the matching scoped editor receives required error, with no source mutation.
      final first = tester.widget<TextField>(
        find.byKey(
          const ValueKey(('display-field', 'detail', 'main', 'title')),
        ),
      );
      final other = tester.widget<TextField>(
        find.byKey(
          const ValueKey(('display-field', 'detail', 'other', 'title')),
        ),
      );
      expect(first.decoration!.errorText, isNull);
      expect(other.decoration!.errorText, 'required-nonblank');
      expect(f.source.resources.first.sourceRevision, 1);
      expect(f.session.state.command.sequence, 0);
    });
    testWidgets('VW05-valid-save', (tester) async {
      // Given editable current Detail from the real neutral semantic source.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      // When exact title input is entered and explicitly saved.
      await typeTitle(tester, ' Changed Ω\nnext ');
      await tapKey(tester, 'display-save');
      // Then real source and both public projections agree while editors clear.
      expect(
        f.source.resources.first.fields['name'],
        const TextDisplayValue(' Changed Ω\nnext '),
      );
      expect(f.source.resources.first.sourceRevision, 2);
      expect(f.session.state.detail.data!.sourceRevision, 2);
      expect(f.session.state.list.data!.model.items.first.sourceRevision, 2);
      expect(find.byType(TextField), findsNothing);
      expect(f.controller.state.draft, isNull);
      expect(find.textContaining('update: changed; commit 2'), findsOneWidget);
    });
    testWidgets('VW06-local-invalid', (tester) async {
      // Given a required title and no previous command effect.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      final calls = f.port.requests.length;
      // When Unicode blank input is explicitly saved.
      await typeTitle(tester, '\u0085\u3000');
      await tapKey(tester, 'display-save');
      // Then the visible local error retains exact text and crosses no command port.
      expect(find.text('required-nonblank'), findsOneWidget);
      expect(
        f.controller.state.draft!.values[locator('title')],
        const TextDisplayValue('\u0085\u3000'),
      );
      expect(f.port.requests, hasLength(calls));
      expect(f.source.resources.first.sourceRevision, 1);
      expect(f.session.state.command.sequence, 0);
    });
    for (final conflict in [false, true]) {
      testWidgets(conflict ? 'VW07-conflict' : 'VW07-noop', (tester) async {
        // Given a current unchanged draft, with an optional real concurrent source update.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        await openView(tester, f, edit: true);
        if (conflict) {
          await competingUpdate(f, 'Concurrent');
        }
        final draft = f.controller.state.draft!;
        // When the old draft is explicitly saved through the UI.
        await tapKey(tester, 'display-save');
        // Then the receipt is visible and noOp clears while conflict preserves exact old input/revision.
        expect(
          find.textContaining(conflict ? 'update: conflict' : 'update: noOp'),
          findsOneWidget,
        );
        expect(f.source.resources.first.sourceRevision, conflict ? 2 : 1);
        expect(
          f.controller.state.draft?.observedRevision,
          conflict ? 1 : isNull,
        );
        if (conflict) {
          expect(f.controller.state.draft!.values, draft.values);
          expect(f.controller.state.draft!.needsReconciliation, isTrue);
          expect(
            tester
                .widget<TextField>(
                  find.byKey(
                    const ValueKey((
                      'display-field',
                      'detail',
                      'main',
                      'title',
                    )),
                  ),
                )
                .enabled,
            isFalse,
          );
          // Given conflict leaves an old disabled generation and current source differs.
          // When explicit safe Reload reads coherent current projections.
          await tapKey(tester, 'display-reload');
          // Then old draft is retained rather than silently rebased by safe read.
          expect(f.controller.state.draft!.values, draft.values);
          expect(f.controller.state.draft!.observedRevision, 1);
          expect(f.controller.state.canSave, isFalse);
          expect(
            f.source.resources.first.fields['name'],
            const TextDisplayValue('Concurrent'),
          );
        } else {
          expect(find.byType(TextField), findsNothing);
        }
      });
    }
    for (final readFailure in [false, true]) {
      testWidgets(readFailure ? 'VW08-read-failed' : 'VW08-held', (
        tester,
      ) async {
        // Given one real update with held or unavailable automatic projection.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        await openView(tester, f, edit: true);
        if (readFailure) {
          f.source.failNextDisplay(
            DisplayRequestKind.read,
            FixtureTransportFault.unavailable,
          );
        } else {
          f.source.holdProjection();
        }
        // When changed title is explicitly saved.
        await typeTitle(tester, 'Committed');
        await tapKey(tester, 'display-save');
        // Then commit and pending projection are separately visible and Save is disabled.
        expect(find.textContaining('commit 2'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('display-projection-pending')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextButton>(find.byKey(const ValueKey('display-save')))
              .onPressed,
          isNull,
        );
        if (readFailure) {
          expect(
            find.textContaining('Detail: Simulated unavailable'),
            findsOneWidget,
          );
        }
        expect(f.source.resources.first.sourceRevision, 2);
        expect(f.controller.state.draft, isNull);
        // Given the held projection is explicitly released and source is safely current.
        f.source.releaseProjection();
        // When the user chooses explicit Reload.
        await tapKey(tester, 'display-reload');
        // Then pending clears, projections become coherent, and exactly one update remains in port history.
        expect(
          find.byKey(const ValueKey('display-projection-pending')),
          findsNothing,
        );
        expect(f.session.state.canMutate, isTrue);
        expect(f.session.state.detail.data!.sourceRevision, 2);
        expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      });
    }
    testWidgets('VW09-unknown-reconcile', (tester) async {
      // Given a source whose one update commits but returns an ambiguous delivery.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      f.source.failNextDisplay(
        DisplayRequestKind.update,
        FixtureTransportFault.ambiguousAfterCommit,
      );
      // When changed semantic input is saved once.
      await typeTitle(tester, 'Uncertain');
      await tapKey(tester, 'display-save');
      // Then outcome unknown is visible with retained disabled draft and real source commit.
      expect(
        find.byKey(const ValueKey('display-command-uncertain')),
        findsOneWidget,
      );
      expect(find.text('Outcome unknown'), findsOneWidget);
      expect(f.source.resources.first.sourceRevision, 2);
      expect(f.controller.state.draft!.observedRevision, 1);
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey(('display-field', 'detail', 'main', 'title')),
              ),
            )
            .enabled,
        isFalse,
      );
      final draft = f.controller.state.draft!;
      // Given only safe reads can reconcile source truth after uncertain delivery.
      // When explicit Reload is selected.
      await tapKey(tester, 'display-reload');
      // Then failure history remains and the old draft is still disabled with no command replay.
      expect(f.session.state.command.phase, DisplaySessionCommandPhase.failed);
      expect(f.controller.state.draft!.values, draft.values);
      expect(f.controller.state.canSave, isFalse);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      // Given current Detail is now coherent and replacement input is explicitly requested.
      // When the user chooses Discard and edit current.
      await tapKey(tester, 'display-reconcile');
      // Then a new generation uses current revision and typing resumes without another update.
      expect(
        f.controller.state.draft!.generation,
        greaterThan(draft.generation),
      );
      expect(f.controller.state.draft!.observedRevision, 2);
      expect(f.controller.state.canSave, isTrue);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
    });
    testWidgets('VW10-operation-reload', (tester) async {
      // Given enabled Detail descriptor and a coherent title update through the UI.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      await typeTitle(tester, 'Retained title');
      await tapKey(tester, 'display-save');
      final calls = f.port.requests.length;
      // When the separate Operation control is explicitly selected.
      final action = find.byKey(
        const ValueKey(('display-operation', 'advance')),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      // Then Operation commit three appears without an implicit Display query/read.
      expect(
        find.textContaining('operation: changed; commit 3'),
        findsOneWidget,
      );
      expect(f.port.requests, hasLength(calls));
      expect(f.source.operationCalls.single.metadata.observedRevision, 2);
      expect(f.source.resources.first.sourceRevision, 3);
      expect(f.session.state.detail.data!.sourceRevision, 2);
      // Given Operation left display refresh explicit.
      // When Reload is selected by the user.
      await tapKey(tester, 'display-reload');
      // Then changed semantic stage and retained title appear and the unavailable descriptor disappears.
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Retained title'), findsOneWidget);
      expect(
        find.byKey(const ValueKey(('display-operation', 'advance'))),
        findsNothing,
      );
      expect(f.session.state.detail.data!.sourceRevision, 3);
      expect(f.source.operationCallCount, 1);
    });
    for (final create in [true, false]) {
      testWidgets(create ? 'VW11-create' : 'VW11-delete', (tester) async {
        // Given eligible projections and explicit bounded unsupported controls.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        await openView(tester, f);
        final before = f.source.resources;
        // When Create or Delete is explicitly activated.
        await tapKey(tester, create ? 'display-create' : 'display-delete');
        // Then unsupported is visibly settled with no success or semantic revision change.
        expect(
          find.textContaining('${create ? 'create' : 'delete'}: unsupported'),
          findsOneWidget,
        );
        expect(f.session.state.command.mutation!.committedRevision, isNull);
        expect(f.source.resources.first.fields, before.first.fields);
        expect(f.source.resources.map((resource) => resource.sourceRevision), [
          1,
          1,
        ]);
        expect(f.source.operationCallCount, 0);
      });
    }
    for (final variant in ['unknown', 'unavailable', 'version']) {
      testWidgets('VW12-$variant', (tester) async {
        // Given accepted data and a retained semantic draft under the original definition.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        await openView(tester, f, edit: true);
        await typeTitle(tester, 'Retained draft');
        final draft = f.controller.state.draft!;
        final calls = f.port.requests.length;
        final replacement = switch (variant) {
          'unknown' => DisplayDefinitionRegistry(
            registrations: [],
            neutralDefinition: definition(id: 'neutral'),
          ),
          'unavailable' => registry(a: definition(available: false)),
          _ => DisplayDefinitionRegistry(
            registrations: [
              DisplayDefinitionRegistration(
                key: definitionKey(version: 2),
                definition: definition(version: 2),
              ),
            ],
          ),
        };
        // When replacement registry compatibility fails explicitly.
        f.controller.updateRegistry(replacement);
        await tester.pumpAndSettle();
        // Then a visible incompatibility pins old data/input and disables editing without source effects.
        expect(
          find.byKey(const ValueKey('display-definition-failure')),
          findsOneWidget,
        );
        expect(find.text('Document detail'), findsOneWidget);
        expect(
          find.byKey(const ValueKey(('display-style', 'standard'))),
          findsOneWidget,
        );
        expect(f.controller.state.draft, same(draft));
        expect(
          tester
              .widget<TextField>(
                find.byKey(
                  const ValueKey(('display-field', 'detail', 'main', 'title')),
                ),
              )
              .enabled,
          isFalse,
        );
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, 1);
        expect(f.session.state.selectedResourceId, 'doc:1');
      });
    }
    for (final discard in [false, true]) {
      testWidgets(discard ? 'VW13-confirm-switch' : 'VW13-cancel-switch', (
        tester,
      ) async {
        // Given a retained edited resource and compact List navigation.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        await openView(tester, f, edit: true);
        await typeTitle(tester, 'Retained');
        final draft = f.controller.state.draft!;
        await tapKey(tester, 'display-back');
        final calls = f.port.requests.length;
        // When the user selects a different resource with a draft still present.
        await tester.tap(
          find.byKey(const ValueKey(('display-resource', 'doc:2'))),
        );
        await tester.pumpAndSettle();
        // Then an explicit discard dialog is shown before any read or focus loss.
        expect(find.text('Discard draft?'), findsOneWidget);
        expect(f.controller.state.draft, same(draft));
        expect(f.port.requests, hasLength(calls));
        // Given the modal awaits an explicit cancel or confirmation.
        // When the user chooses that exact continuation.
        await tester.tap(find.text(discard ? 'Discard' : 'Keep draft'));
        await tester.pumpAndSettle();
        // Then cancel preserves all input/focus while confirmation performs one read and explicit discard.
        expect(f.controller.state.draft, discard ? isNull : same(draft));
        expect(f.session.state.selectedResourceId, discard ? 'doc:2' : 'doc:1');
        expect(f.port.requests, hasLength(calls + (discard ? 1 : 0)));
        expect(f.source.resources.first.sourceRevision, 1);
        expect(
          find.byKey(ValueKey(discard ? 'display-detail' : 'display-list')),
          findsOneWidget,
        );
      });
    }
    testWidgets('VW14-adaptive-input-identity', (tester) async {
      // Given one selected edited resource at width400 and exact retained Unicode input.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      await typeTitle(tester, ' Resize Ω ');
      final field = find.byKey(
        const ValueKey(('display-field', 'detail', 'main', 'title')),
      );
      final editor = tester.widget<TextField>(field).controller!;
      final generation = f.controller.state.draft!.generation;
      final calls = f.port.requests.length;
      // When compact Back is explicitly selected.
      await tapKey(tester, 'display-back');
      // Then List is visible without clearing the semantic draft or accepted resource.
      expect(find.byKey(const ValueKey('display-list')), findsOneWidget);
      expect(f.controller.state.draft!.generation, generation);
      expect(f.session.state.selectedResourceId, 'doc:1');
      // Given the same semantic owner now has expanded usable width.
      // When capability changes from400 to1200.
      tester.view.physicalSize = const Size(1200, 850);
      await tester.pumpAndSettle();
      // Then split panes reuse the exact TextEditingController and draft identity.
      expect(find.byKey(const ValueKey('display-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('display-detail')), findsOneWidget);
      expect(tester.widget<TextField>(field).controller, same(editor));
      expect(editor.text, ' Resize Ω ');
      // Given expanded split supports an explicit focus preference.
      // When Focus detail is selected.
      await tapKey(tester, 'display-focus');
      // Then only Detail is visible while the editor object is retained.
      expect(find.byKey(const ValueKey('display-list')), findsNothing);
      expect(tester.widget<TextField>(field).controller, same(editor));
      // Given focus preference is an explicit presentation choice.
      // When Restore split is selected.
      await tapKey(tester, 'display-split');
      // Then split returns without any semantic read or input reset.
      expect(find.byKey(const ValueKey('display-list')), findsOneWidget);
      expect(f.port.requests, hasLength(calls));
      // Given compact navigation and input belong to the same selected owner.
      // When usable width returns from1200 to400.
      tester.view.physicalSize = const Size(400, 850);
      await tester.pumpAndSettle();
      // Then compact Detail retains the exact cursor/controller/generation and no port changes.
      expect(find.byKey(const ValueKey('display-list')), findsNothing);
      expect(tester.widget<TextField>(field).controller, same(editor));
      expect(editor.text, ' Resize Ω ');
      expect(f.controller.state.draft!.generation, generation);
      expect(f.port.requests, hasLength(calls));
      expect(tester.takeException(), isNull);
    });
    testWidgets('VW15-context-reset-old-dialog', (tester) async {
      // Given one edited resource and an incompatible producer response on safe read.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      await openView(tester, f, edit: true);
      await typeTitle(tester, 'Old draft');
      final draft = f.controller.state.draft!;
      f.port.readTransform = incompatibleProducer;
      // When explicit Reload encounters incompatible context.
      await tapKey(tester, 'display-reload');
      // Then retained input is visible and disabled under latched Core context failure.
      expect(f.controller.state.draft, same(draft));
      expect(f.session.state.contextFailure, isNotNull);
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey(('display-field', 'detail', 'main', 'title')),
              ),
            )
            .enabled,
        isFalse,
      );
      // Given draft discard is explicit even under that incompatibility.
      // When the user chooses Cancel / Discard.
      await tapKey(tester, 'display-cancel');
      // Then old input is discarded without mutating or rewriting its context.
      expect(f.controller.state.draft, isNull);
      expect(f.source.resources.first.sourceRevision, 1);
      final supplied = presentationContext(arm: 'B', flow: 'view-new-flow');
      final fresh = PresentationFixture(context: supplied);
      addTearDown(fresh.dispose);
      final next = fresh.newSession(supplied);
      // Given an explicit pristine new session identity and supplied context.
      // When the existing owner resets while its borrowed view remains mounted.
      f.controller.reset(nextSession: next, nextRegistry: registry());
      // Then it is immediately idle with no inherited focus or eager port before the next frame.
      expect(next.state.list.phase, DisplaySessionReadPhase.idle);
      expect(next.state.selectedResourceId, isNull);
      expect(fresh.source.callCount, 0);
      // Given view autoLoad recognizes a new pristine session identity.
      // When the next frame performs its one automatic query.
      await tester.pumpAndSettle();
      // Then only the new collection loads and new cards style/context are visible.
      expect(fresh.source.callCount, 1);
      expect(next.state.selectedResourceId, isNull);
      expect(next.state.context, supplied);
      expect(
        find.byKey(const ValueKey(('display-style', 'cards'))),
        findsOneWidget,
      );
      // Given the new flow can explicitly select and edit its own resource.
      // When its first resource is selected and editing is opened.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:1'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // Then the new draft belongs only to the new flow's accepted resource/revision.
      expect(f.controller.state.draft!.resourceId, 'doc:1');
      expect(next.state.selectedResourceId, 'doc:1');
      await tapKey(tester, 'display-back');
      // Given a resource switch dialog captures the currently edited session identity.
      // When another row opens a discard confirmation.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:2'))),
      );
      await tester.pumpAndSettle();
      // Then the dialog is pending without target adoption.
      expect(find.text('Discard draft?'), findsOneWidget);
      expect(next.state.selectedResourceId, 'doc:1');
      final thirdContext = presentationContext(
        arm: null,
        flow: 'view-third-flow',
      );
      final third = PresentationFixture(context: thirdContext);
      addTearDown(third.dispose);
      final thirdSession = third.newSession(thirdContext);
      // Given that old dialog is still awaiting input while explicit reset is authorized.
      // When the owner discards old input and adopts another pristine flow.
      f.controller.reset(
        nextSession: thirdSession,
        nextRegistry: registry(),
        discardDraft: true,
      );
      await tester.pumpAndSettle();
      // Then new identity autoLoads exactly its own List and inherits no resource.
      expect(third.source.callCount, 1);
      expect(thirdSession.state.selectedResourceId, isNull);
      expect(next.isDisposed, isTrue);
      // Given the obsolete dialog still displays its old resource confirmation.
      // When that late old confirmation is selected.
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      // Then captured session guarding prevents any old ID read in the replacement flow.
      expect(third.source.callCount, 1);
      expect(thirdSession.state.selectedResourceId, isNull);
      expect(thirdSession.state.context, thirdContext);
      expect(f.controller.state.draft, isNull);
    });
    testWidgets('VW16-borrowed-common-pane-settings', (tester) async {
      // Given actual Common Settings, two new framework display models and an existing tab model.
      final f = PresentationFixture();
      final next = PresentationFixture();
      addTearDown(f.dispose);
      addTearDown(next.dispose);
      viewportCleanup(tester);
      final storage = MemorySettingsStorage();
      final service = SettingsController(storage: storage);
      final settings = SettingsView.fromService(service: service);
      final legacy = ResourceListDetailDisplayModel();
      final binding = ResourceListDetailSettingsBinding(
        view: settings,
        displayModels: [
          f.controller.displayModel,
          next.controller.displayModel,
          legacy,
        ],
      );
      addTearDown(binding.dispose);
      addTearDown(legacy.dispose);
      addTearDown(settings.dispose);
      addTearDown(service.dispose);
      // When the owner explicitly prefers a single pane in Common Settings.
      settings.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );
      await mountView(tester, f.controller, width: 1200, settings: settings);
      // Then the new view follows the borrowed pane preference without eager Detail.
      expect(find.byKey(const ValueKey('display-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('display-detail')), findsNothing);
      // Given single-pane List has one accepted selectable resource.
      // When that resource is selected and explicitly edited.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:1'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // Then selection/draft belong to the display controller while Settings owns preferences.
      expect(f.controller.state.draft, isNotNull);
      expect(find.byKey(const ValueKey('display-list')), findsNothing);
      final draft = f.controller.state.draft;
      final writes = storage.writes;
      // Given pane focus is a transient presentation override.
      // When the view explicitly focuses Detail.
      await tapKey(tester, 'display-focus');
      next.controller.focusDetail();
      await tester.pumpAndSettle();
      // Then focus creates no Settings write and preserves semantic input.
      expect(storage.writes, writes);
      expect(f.controller.state.draft, same(draft));
      expect(
        next.controller.displayModel.preferenceOverride,
        ResourceListDetailDisplayPreference.detailFocused,
      );
      // Given Common Settings reset should clear pane overrides in every borrowed model.
      // When that actual owner explicitly resets Common Settings.
      settings.resetCommon();
      await tester.pumpAndSettle();
      // Then split returns, both new models receive reset, and selection/draft survive.
      expect(find.byKey(const ValueKey('display-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('display-detail')), findsOneWidget);
      expect(f.controller.state.draft, same(draft));
      expect(f.session.state.selectedResourceId, 'doc:1');
      expect(next.controller.displayModel.preferenceOverride, isNull);
      expect(legacy.preferenceOverride, isNull);
      final afterResetWrites = storage.writes;
      // Given Settings has finished the explicit reset persistence activity.
      // When ordinary pane navigation runs again.
      await tapKey(tester, 'display-back');
      await tapKey(tester, 'display-split');
      // Then view navigation writes no additional Settings record and retains semantic input.
      expect(storage.writes, afterResetWrites);
      expect(storage.reads, 0);
      expect(f.controller.state.draft, same(draft));
      expect(next.source.callCount, 0);
    });
    for (final width in [400.0, 1200.0]) {
      testWidgets(width == 400 ? 'VW17-scale-compact' : 'VW17-scale-expanded', (
        tester,
      ) async {
        // Given inherited actual Common text multiplier and one borrowed controller.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        viewportCleanup(tester);
        final storage = MemorySettingsStorage();
        final service = SettingsController(storage: storage);
        final settings = SettingsView.fromService(service: service);
        addTearDown(settings.dispose);
        addTearDown(service.dispose);
        settings.setValue(CommonSettings.textSizeMultiplier.id, 1.30);
        // When the public view mounts beneath the existing ApplicationTextScaling boundary.
        await mountView(tester, f.controller, width: width, settings: settings);
        // Then the inherited multiplier applies once to ordinary UI content and causes no overflow.
        final context = tester.element(
          find.byKey(const ValueKey('display-list')),
        );
        expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, .0001));
        expect(tester.takeException(), isNull);
        // Given scaled ordered rows remain explicitly selectable.
        // When selected Detail is edited and receives multiline text.
        await tester.tap(
          find.byKey(const ValueKey(('display-resource', 'doc:1'))),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await typeTitle(tester, 'Large Ω\nsecond line');
        // Then scrolling/editor layout remains usable without duplicate scaling or source updates.
        final inputContext = tester.element(
          find.byKey(
            const ValueKey(('display-field', 'detail', 'main', 'title')),
          ),
        );
        expect(
          MediaQuery.textScalerOf(inputContext).scale(10),
          closeTo(13, .0001),
        );
        expect(tester.takeException(), isNull);
        expect(f.source.resources.first.sourceRevision, 1);
        expect(
          f.controller.state.draft!.values[locator('title')],
          const TextDisplayValue('Large Ω\nsecond line'),
        );
      });
    }
    testWidgets('VW18-neutral-continuation-diagnostic', (tester) async {
      // Given neutral locale/correlation context plus allowlisted hints and one optional omitted family.
      final f = PresentationFixture(
        context: presentationContext(
          arm: null,
          flow: 'neutral-flow',
          extensions: true,
        ),
      );
      addTearDown(f.dispose);
      viewportCleanup(tester);
      // When autoLoad admits the supplied neutral context.
      await mountView(tester, f.controller);
      // Then optional omission is visible and allowed hints/correlation remain presentation data.
      expect(find.textContaining('example.omitted:'), findsOneWidget);
      expect(
        f.session.state.context.families.any(
          (family) => family.namespace == 'textus.presentation.arm',
        ),
        isFalse,
      );
      final admitted = f.session.state.context;
      expect(
        admitted.families
            .singleWhere((family) => family.namespace == 'example.hints')
            .payload,
        OpaquePresentationPayload({'density': 'comfortable'}),
      );
      // Given neutral presentation owns no assignment/transport propagation code.
      // When UI selects, edits, saves, executes Operation and explicitly Reloads.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:1'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await typeTitle(tester, 'Neutral update');
      await tapKey(tester, 'display-save');
      // Then update ports carry only admitted producer context and source advances once.
      expect(f.source.resources.first.sourceRevision, 2);
      expect(
        f.port.requests.every(
          (request) => request.metadata.context == admitted,
        ),
        isTrue,
      );
      final operation = find.byKey(
        const ValueKey(('display-operation', 'advance')),
      );
      await tester.ensureVisible(operation);
      // Given the accepted separate Operation descriptor is still available.
      // When its UI control is explicitly activated.
      await tester.tap(operation);
      await tester.pumpAndSettle();
      // Then neutral context reaches the ordinary port unchanged and source advances to three.
      expect(f.source.operationCalls.single.metadata.context, admitted);
      expect(f.source.resources.first.sourceRevision, 3);
      // Given the Operation requires explicit Display refresh.
      // When Reload is selected.
      await tapKey(tester, 'display-reload');
      // Then neutral continuation and allowlisted hints remain unchanged through all UI actions.
      expect(f.session.state.context, admitted);
      expect(f.session.state.detail.data!.sourceRevision, 3);
      expect(
        f.port.requests.every(
          (request) => request.metadata.context == admitted,
        ),
        isTrue,
      );
    });
    testWidgets('VW19-replacement-unmount-old-events', (tester) async {
      // Given an edited old controller and a separately pristine replacement owner.
      final old = PresentationFixture();
      final next = PresentationFixture();
      addTearDown(old.dispose);
      addTearDown(next.dispose);
      viewportCleanup(tester);
      await openView(tester, old, edit: true);
      final oldSave = tester
          .widget<TextButton>(find.byKey(const ValueKey('display-save')))
          .onPressed!;
      final oldInput = tester
          .widget<TextField>(
            find.byKey(
              const ValueKey(('display-field', 'detail', 'main', 'title')),
            ),
          )
          .onChanged!;
      final oldCalls = old.port.requests.length;
      final draft = old.controller.state.draft;
      // When the same view position replaces its borrowed controller.
      await mountView(tester, next.controller);
      // Then old listener detaches without disposing either caller-owned controller.
      // Test-only lifecycle probe retains the exact inherited listener-detachment assertion.
      // ignore: invalid_use_of_protected_member
      expect(old.controller.hasListeners, isFalse);
      expect(old.controller.isDisposed, isFalse);
      expect(next.source.callCount, 1);
      // Given stale callback objects originated from the replaced UI.
      // When an old Save and old typing event arrive after replacement.
      oldSave();
      oldInput('Late old input');
      await tester.pumpAndSettle();
      // Then neither old source/draft nor new flow is operated by stale events.
      expect(old.port.requests, hasLength(oldCalls));
      expect(old.controller.state.draft, same(draft));
      expect(next.source.callCount, 1);
      expect(next.session.state.selectedResourceId, isNull);
      expect(next.session.state.command.sequence, 0);
      // Given the new view borrows its replacement owner.
      // When the view unmounts.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // Then replacement listener detaches and both owners remain alive.
      // Test-only lifecycle probe retains the exact inherited listener-detachment assertion.
      // ignore: invalid_use_of_protected_member
      expect(next.controller.hasListeners, isFalse);
      expect(next.controller.isDisposed, isFalse);
      expect(old.controller.isDisposed, isFalse);
      // Given the replacement owner remains independently usable after unmount.
      // When its owner explicitly loads again.
      await next.controller.load();
      // Then it safely queries without a borrowed view or command replay.
      expect(next.source.callCount, 2);
      expect(next.session.state.command.sequence, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('VW20-safe-retries', (tester) async {
      // Given a failed automatic List delivery and no command.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      viewportCleanup(tester);
      f.source.failNextDisplay(
        DisplayRequestKind.query,
        FixtureTransportFault.unavailable,
      );
      // When autoLoad runs once and fails.
      await mountView(tester, f.controller);
      // Then List retry is separate and failure does not auto-retry.
      expect(find.byKey(const ValueKey('display-retry-list')), findsOneWidget);
      expect(f.source.callCount, 1);
      expect(f.session.state.list.phase, DisplaySessionReadPhase.failed);
      // Given source List delivery is now available.
      // When the user explicitly chooses Retry list.
      await tapKey(tester, 'display-retry-list');
      // Then List recovers without any command.
      expect(f.session.state.list.phase, DisplaySessionReadPhase.ready);
      expect(f.session.state.command.sequence, 0);
      // Given accepted List can explicitly select its first Detail.
      // When the first resource row is selected.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:1'))),
      );
      await tester.pumpAndSettle();
      // Then Detail focus is accepted before a later read failure.
      expect(f.session.state.selectedResourceId, 'doc:1');
      expect(f.session.state.detail.phase, DisplaySessionReadPhase.ready);
      f.source.failNextDisplay(
        DisplayRequestKind.read,
        FixtureTransportFault.unavailable,
      );
      // Given safe Detail refresh has a single unavailable raw read.
      // When Reload encounters that failure.
      await tapKey(tester, 'display-reload');
      // Then Detail failure has its own retry while accepted data remains visible.
      expect(
        find.byKey(const ValueKey('display-retry-detail')),
        findsOneWidget,
      );
      expect(find.text('Document detail'), findsOneWidget);
      expect(f.session.state.detail.phase, DisplaySessionReadPhase.failed);
      // Given the accepted resource remains safe to reread.
      // When explicit Retry detail is activated.
      await tapKey(tester, 'display-retry-detail');
      // Then Detail recovers with no Operation/update and unchanged source truth.
      expect(f.session.state.detail.phase, DisplaySessionReadPhase.ready);
      expect(f.session.state.command.sequence, 0);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), isEmpty);
      expect(f.source.operationCallCount, 0);
      expect(f.source.resources.first.sourceRevision, 1);
    });
  });
}

void viewportCleanup(WidgetTester tester) {
  addTearDown(() {
    // Given the test owns only viewport overrides.
    // When those overrides are released after the widget case.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    // Then controller ownership is not involved in viewport cleanup.
    expect(tester.view.devicePixelRatio, greaterThan(0));
  });
}

class MemorySettingsStorage implements SettingsStorage {
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> read() async {
    reads++;
    return null;
  }

  @override
  Future<void> write(String record) async {
    writes++;
  }
}
