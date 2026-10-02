import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/display_presentation_fixture.dart';

void main() {
  group('Owned presentation inputs and semantic commands', () {
    test('ED01-idle-ownership', () {
      // Given a pristine public Core session and immutable registrations.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      // When ownership is transferred by construction and snapshots are retained.
      final state = f.controller.state;
      // Then construction is idle and crosses no source or Operation port.
      expect(f.controller.session, same(f.session));
      expect(state.session, same(f.session.state));
      expect(state.busy, isFalse);
      expect(state.draft, isNull);
      expect(f.source.callCount, 0);
      expect(f.source.operationCallCount, 0);
      expect(f.controller.displayModel.compactDetailRequested, isFalse);
      expect(() => state.fieldErrors.clear(), throwsUnsupportedError);
      expect(
        () => state.session.minimumRevisions.clear(),
        throwsUnsupportedError,
      );
    });
    test('ED02-scoped-input', () async {
      // Given independent neutral source/controller ownership.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      // When loading, selecting and beginning edit through public actions.
      await openController(f, edit: true);
      // Then exact scoped writable inputs and immutable initial revision are retained in metadata order.
      final draft = f.controller.state.draft!;
      expect(draft.resourceId, 'doc:1');
      expect(draft.definition, definition());
      expect(draft.definitionKey, definitionKey());
      expect(draft.bindings.map((binding) => binding.locator), [
        locator('title'),
        locator('description'),
      ]);
      expect(draft.values[locator('stage')], isNull);
      expect(draft.hasUnsavedChanges, isFalse);
      expect(draft.generation, 1);
      expect(
        f.source.resources.first.fields['name'],
        draft.values[locator('title')],
      );
    });
    test('ED03-duplicate-scope', () async {
      // Given two writable sections sharing a field ID but different complete locators.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      f.port.readTransform = duplicateSection;
      await openController(f, edit: true);
      // When only the second title becomes locally invalid and Save is attempted.
      setDraftValue(
        f.controller,
        locator('title', section: 'other'),
        const TextDisplayValue(' '),
      );
      await f.controller.save();
      // Then the error belongs only to that section, with no command/source effect.
      expect(
        f.controller.state.fieldErrors.single.locator,
        locator('title', section: 'other'),
      );
      expect(
        f.controller.state.draft!.values[locator('title')],
        const TextDisplayValue('First document'),
      );
      expect(f.session.state.command.sequence, 0);
      expect(f.source.resources.first.sourceRevision, 1);
      // Given one stale scoped error and the other input still unchanged.
      // When the errored second input is corrected.
      setDraftValue(
        f.controller,
        locator('title', section: 'other'),
        const TextDisplayValue('Other fixed'),
      );
      // Then only its error clears and the first scoped input is retained.
      expect(f.controller.state.fieldErrors, isEmpty);
      expect(
        f.controller.state.draft!.values[locator('title')],
        const TextDisplayValue('First document'),
      );
    });
    test('ED04-input-not-display', () async {
      // Given a producer input value that differs from the human-readable Display title.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      f.port.readTransform = (wire) =>
          duplicateSection(wire, differentInput: true);
      // When coherent Detail editing starts.
      await openController(f, edit: true);
      // Then the semantic input is copied and the Display title is not reverse converted.
      expect(
        f.controller.state.draft!.values[locator('title')],
        const TextDisplayValue('Semantic input'),
      );
      expect(
        f.session.state.detail.data!.model.sections.first.fields.first.value,
        const TextDisplayValue('First document'),
      );
      expect(
        f.source.resources.first.fields['name'],
        const TextDisplayValue('First document'),
      );
    });
    for (final entry in [
      ('ED05-read-only', 'stage'),
      ('ED05-unknown', 'unknown'),
    ]) {
      test(entry.$1, () async {
        // Given a scoped draft and an unowned/read-only input coordinate.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        final before = f.controller.state;
        final calls = f.port.requests.length;
        // When mutation is attempted at that exact locator.
        expect(
          () => f.controller.setValue(
            locator(entry.$2),
            const TextDisplayValue('forbidden'),
          ),
          throwsArgumentError,
        );
        // Then draft/snapshot/source/ports remain unchanged.
        expect(f.controller.state, same(before));
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, 1);
        expect(f.session.state.command.sequence, 0);
      });
    }
    final invalids = <(String, DisplayValue?)>[
      ('ED06-null', null),
      ('ED06-missing', const MissingDisplayValue()),
      ('ED06-number', NumberDisplayValue(3)),
      ('ED06-bool', const BoolDisplayValue(true)),
      ('ED06-timestamp', TimestampDisplayValue(DateTime.utc(2026, 10, 3))),
    ];
    for (final entry in invalids) {
      test(entry.$1, () async {
        // Given a writable semantic Text binding and exact unsupported input type.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        final calls = f.port.requests.length;
        // When typed input is assigned and Save validates the draft.
        setDraftValue(f.controller, locator('title'), entry.$2);
        await f.controller.save();
        // Then local scoped invalid-type is visible without sequence, port or semantic change.
        expect(f.controller.state.draft!.values[locator('title')], entry.$2);
        expect(f.controller.state.fieldErrors.single.code, 'invalid-type');
        expect(f.controller.state.fieldErrors.single.locator, locator('title'));
        expect(f.port.requests, hasLength(calls));
        expect(f.session.state.command.sequence, 0);
        expect(f.source.resources.first.sourceRevision, 1);
      });
    }
    test('ED07-unicode-blank', () async {
      // Given a required title and explicit Unicode blank variants.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final calls = f.port.requests.length;
      for (final text in ['', ' \n\t ', '\u0085', '\u3000', '\u0085\u3000\n']) {
        // Given the same editable required binding and one exact blank input.
        // When Save validates that input without normalizing it.
        setDraftValue(f.controller, locator('title'), TextDisplayValue(text));
        await f.controller.save();
        // Then every blank variant is rejected locally and preserves its bytes.
        expect(f.controller.state.fieldErrors.single.code, 'required-nonblank');
        expect(
          f.controller.state.draft!.values[locator('title')],
          TextDisplayValue(text),
        );
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, 1);
      }
      expect(f.session.state.command.sequence, 0);
    });
    test('ED07-valid-unicode-empty-description', () async {
      // Given required title and optional description in their source order.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      const text = ' \u0085Ω 日本\n second line \u3000';
      // When multiline Unicode title and empty optional description are saved.
      setDraftValue(
        f.controller,
        locator('title'),
        const TextDisplayValue(text),
      );
      setDraftValue(
        f.controller,
        locator('description'),
        const TextDisplayValue(''),
      );
      await f.controller.save();
      // Then the real semantic source preserves bytes and ordered update inputs exactly.
      expect(
        f.source.resources.first.fields['name'],
        const TextDisplayValue(text),
      );
      expect(
        f.source.resources.first.fields['description'],
        const TextDisplayValue(''),
      );
      final request = f.port.requests.whereType<DisplayUpdateRequest>().single;
      expect(request.fields.map((input) => input.locator), [
        locator('title'),
        locator('description'),
      ]);
      expect(request.fields.first.value, const TextDisplayValue(text));
      expect(request.metadata.observedRevision, 1);
      expect(f.controller.state.draft, isNull);
      expect(f.session.state.canMutate, isTrue);
    });
    test('ED08-receipt-before-held-refresh', () async {
      // Given a submitted generation and a refresh read held by a Completer.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      setDraftValue(
        f.controller,
        locator('title'),
        const TextDisplayValue('Changed'),
      );
      final submitted = f.controller.state.draft!;
      final gate = Completer<void>();
      f.port.readGate = gate;
      // When Save commits and Core enters the held refresh.
      final save = f.controller.save();
      await f.port.readArrived.future;
      // Then matching receipt already clears exactly the submitted draft before refresh completes.
      expect(f.controller.state.draft, isNull);
      expect(f.controller.state.busy, isTrue);
      expect(f.session.state.command.mutation!.committedRevision, 2);
      expect(f.source.resources.first.sourceRevision, 2);
      expect(
        submitted.values[locator('title')],
        const TextDisplayValue('Changed'),
      );
      expect(submitted.observedRevision, 1);
      // Given a committed update whose only remaining activity is safe refresh.
      // When held refresh is explicitly released.
      gate.complete();
      await save;
      // Then coherence returns without a duplicate update or draft resurrection.
      expect(f.session.state.canMutate, isTrue);
      expect(f.controller.state.draft, isNull);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
    });
    test('ED09-noop', () async {
      // Given an unchanged draft from an accepted current Detail.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      // When the unchanged draft is saved through common metadata construction.
      await f.controller.save();
      // Then noOp clears the draft while revision/context stay producer-owned.
      expect(
        f.session.state.command.mutation!.outcome,
        DisplayCommandOutcome.noOp,
      );
      expect(f.source.resources.first.sourceRevision, 1);
      expect(f.controller.state.draft, isNull);
      expect(
        f.port.requests
            .whereType<DisplayUpdateRequest>()
            .single
            .metadata
            .observedRevision,
        1,
      );
      expect(
        f.port.requests.every(
          (request) =>
              request.metadata.context == f.fixture.contexts.values.single,
        ),
        isTrue,
      );
      expect(f.session.state.detail.data!.sourceRevision, 1);
    });
    test('ED10-server-constraint', () async {
      // Given a coherent draft and an authoritative rejecting response with scoped/global errors.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      f.port.updateOverride = rejectUpdate;
      setDraftValue(
        f.controller,
        locator('title'),
        const TextDisplayValue('Rejected input'),
      );
      final draft = f.controller.state.draft!;
      // When the otherwise valid typed draft reaches the controllable server port.
      await f.controller.save();
      // Then server constraints preserve revision and draft and keep global errors separate.
      expect(f.controller.state.draft, same(draft));
      expect(f.controller.state.draft!.needsReconciliation, isFalse);
      expect(f.controller.state.fieldErrors.map((error) => error.locator), [
        locator('title'),
        null,
      ]);
      expect(
        f.session.state.command.mutation!.outcome,
        DisplayCommandOutcome.rejected,
      );
      expect(f.source.resources.first.sourceRevision, 1);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      // Given one scoped and one global server error.
      // When the errored field changes locally.
      setDraftValue(
        f.controller,
        locator('title'),
        const TextDisplayValue('Corrected'),
      );
      // Then only the matching scoped error is removed.
      expect(f.controller.state.fieldErrors.single.locator, isNull);
      expect(f.controller.state.canSave, isTrue);
    });
    for (final changed in [false, true]) {
      test(changed ? 'ED11-stale-changed' : 'ED11-stale-equal', () async {
        // Given a revision-one draft and a real competing revision-two source update.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        if (changed) {
          // Given the retained old revision is still editable before the concurrent source change.
          // When its text is locally changed.
          setDraftValue(
            f.controller,
            locator('title'),
            const TextDisplayValue('My change'),
          );
          // Then only local input changes and revision stays one.
          expect(f.controller.state.draft!.observedRevision, 1);
          expect(f.source.resources.first.sourceRevision, 1);
        }
        await competingUpdate(f, 'Concurrent');
        final draft = f.controller.state.draft!;
        // When the old equal or changed draft is saved at its exact observed revision.
        await f.controller.save();
        // Then conflict preserves values/revision and requires explicit reconciliation.
        expect(
          f.session.state.command.mutation!.outcome,
          DisplayCommandOutcome.conflict,
        );
        expect(f.controller.state.draft!.values, draft.values);
        expect(f.controller.state.draft!.observedRevision, 1);
        expect(f.controller.state.draft!.needsReconciliation, isTrue);
        expect(f.controller.state.canSave, isFalse);
        expect(
          f.source.resources.first.fields['name'],
          const TextDisplayValue('Concurrent'),
        );
        expect(
          f.port.requests
              .whereType<DisplayUpdateRequest>()
              .last
              .metadata
              .observedRevision,
          1,
        );
      });
    }
    for (final variant in ['held', 'omitted', 'read-failed', 'query-failed']) {
      test('ED12-$variant', () async {
        // Given a coherent editable source and one explicitly controlled refresh failure/staleness.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        if (variant == 'held' || variant == 'omitted') {
          f.source.holdProjection();
        }
        if (variant == 'omitted') {
          f.source.omitNextMutationProjection();
        }
        if (variant == 'read-failed') {
          f.source.failNextDisplay(
            DisplayRequestKind.read,
            FixtureTransportFault.unavailable,
          );
        }
        if (variant == 'query-failed') {
          f.source.failNextDisplay(
            DisplayRequestKind.query,
            FixtureTransportFault.unavailable,
          );
        }
        setDraftValue(
          f.controller,
          locator('title'),
          const TextDisplayValue('Committed'),
        );
        // When one update commits with incomplete projection evidence.
        await f.controller.save();
        // Then commit is separate from pending projection and the submitted draft is consumed once.
        expect(f.source.resources.first.sourceRevision, 2);
        expect(f.session.state.command.mutation!.committedRevision, 2);
        expect(f.controller.state.draft, isNull);
        expect(f.session.state.projectionPending, isTrue);
        expect(f.controller.state.canEdit, isFalse);
        if (variant == 'omitted') {
          expect(f.session.state.command.mutation!.display, isNull);
        }
        if (variant == 'read-failed') {
          expect(
            f.session.state.detail.failure!.kind,
            DisplaySessionFailureKind.unavailable,
          );
        }
        if (variant == 'query-failed') {
          expect(
            f.session.state.list.failure!.kind,
            DisplaySessionFailureKind.unavailable,
          );
        }
        final calls = f.port.requests.length;
        // Given a settled committed attempt and no resubmittable draft.
        // When a duplicate Save is attempted before safe recovery.
        expect(() => f.controller.save(), throwsStateError);
        // Then no source or port duplication occurs.
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, 2);
        // Given explicit release makes fresh source projection available.
        f.source.releaseProjection();
        // When safe Reload is explicitly requested.
        await f.controller.reload();
        // Then both projections reconcile to two and historical command remains committed once.
        expect(f.session.state.detail.data!.sourceRevision, 2);
        expect(f.session.state.list.data!.model.items.first.sourceRevision, 2);
        expect(f.session.state.projectionPending, isFalse);
        expect(f.controller.state.canEdit, isTrue);
        expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
        expect(f.controller.state.draft, isNull);
      });
    }
    for (final variant in ['unavailable', 'ambiguous', 'malformed']) {
      test('ED13-$variant', () async {
        // Given a typed changed draft and an explicit dispatched delivery/codec failure.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        setDraftValue(
          f.controller,
          locator('title'),
          const TextDisplayValue('Uncertain text'),
        );
        if (variant == 'unavailable') {
          f.source.failNextDisplay(
            DisplayRequestKind.update,
            FixtureTransportFault.unavailable,
          );
        }
        if (variant == 'ambiguous') {
          f.source.failNextDisplay(
            DisplayRequestKind.update,
            FixtureTransportFault.ambiguousAfterCommit,
          );
        }
        if (variant == 'malformed') {
          f.port.updateTransform = (wire) => {...wire, 'data': 'malformed'};
        }
        final draft = f.controller.state.draft!;
        // When the one changed draft is explicitly submitted.
        await f.controller.save();
        // Then failure history retains exact input/revision and asserts no rollback or automatic replay.
        expect(
          f.session.state.command.phase,
          DisplaySessionCommandPhase.failed,
        );
        expect(f.session.state.commandUncertain, isTrue);
        expect(f.controller.state.draft!.values, draft.values);
        expect(f.controller.state.draft!.observedRevision, 1);
        expect(f.controller.state.draft!.needsReconciliation, isTrue);
        expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
        expect(
          f.source.resources.first.sourceRevision,
          variant == 'unavailable' ? 1 : 2,
        );
        final history = f.session.state.command;
        final calls = f.port.requests.length;
        // Given failure disables a potentially dispatched old draft.
        // When automatic replay is prohibited and old Save is attempted.
        expect(() => f.controller.save(), throwsStateError);
        // Then this failed attempt produces no new port call.
        expect(f.port.requests, hasLength(calls));
        // Given the semantic source is now safely readable and the old failure still exists.
        // When explicit Reload reconciles current values.
        await f.controller.reload();
        // Then failure history remains and safe reads do not rebase the old draft.
        expect(f.session.state.command, same(history));
        expect(f.session.state.commandUncertain, isFalse);
        expect(f.controller.state.draft!.values, draft.values);
        expect(f.controller.state.draft!.needsReconciliation, isTrue);
        expect(f.controller.state.canSave, isFalse);
        expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
        // Given coherent current Detail permits explicit replacement input.
        // When the user discards and edits current values.
        f.controller.discardAndEdit();
        // Then only explicit reconciliation creates a new generation at the current accepted revision.
        expect(
          f.controller.state.draft!.generation,
          greaterThan(draft.generation),
        );
        expect(f.controller.state.draft!.needsReconciliation, isFalse);
        expect(
          f.controller.state.draft!.observedRevision,
          f.source.resources.first.sourceRevision,
        );
        expect(f.controller.state.canSave, isTrue);
      });
    }
    test('ED14-old-history', () async {
      for (final rejected in [false, true]) {
        // Given an independent Core session before presentation ownership transfer.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        final next = f.newSession(f.session.state.context);
        // When that common consumer explicitly loads and selects source revision one.
        await next.query();
        await next.read('doc:1');
        // Then it owns coherent accepted Detail before any controller is constructed.
        expect(next.state.canMutate, isTrue);
        expect(next.state.command.sequence, 0);
        // Given one old explicit committed or rejected command precedes construction.
        // When the independent common session submits its typed command.
        await next.update(
          observedRevision: 1,
          fields: [
            DisplayFieldInput(
              locator: locator('title'),
              value: rejected
                  ? NumberDisplayValue(1)
                  : const TextDisplayValue('Old commit'),
            ),
          ],
        );
        // Then historical receipt is settled at its own unchanged/committed source revision.
        expect(
          next.state.command.mutation!.outcome,
          rejected
              ? DisplayCommandOutcome.rejected
              : DisplayCommandOutcome.changed,
        );
        final history = next.state.command;
        final calls = f.port.requests.length;
        // Given the session now transfers ownership with settled command history.
        // When a public controller is constructed and explicitly begins a new edit.
        final owner = DisplayPresentationController(
          session: next,
          registry: registry(),
        );
        owner.beginEdit();
        // Then no old receipt consumes this unsubmitted generation or dispatches another port.
        expect(owner.state.draft, isNotNull);
        expect(owner.state.draft!.observedRevision, rejected ? 1 : 2);
        expect(next.state.command, same(history));
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, rejected ? 1 : 2);
        // Given the temporary owner has finished its observation.
        // When it explicitly disposes its transferred session.
        owner.dispose();
        // Then independent original fixture ownership is unaffected.
        expect(next.isDisposed, isTrue);
        expect(f.session.isDisposed, isFalse);
      }
    });
    test('ED14-external-command', () async {
      // Given a draft which has never been submitted by this controller.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final draft = f.controller.state.draft!;
      // When an external explicit Core update publishes a settled receipt.
      await f.session.update(
        observedRevision: 1,
        fields: [
          DisplayFieldInput(
            locator: locator('title'),
            value: const TextDisplayValue('External'),
          ),
        ],
      );
      // Then external command cannot consume the unsubmitted draft or change its observed revision.
      expect(f.controller.state.draft, same(draft));
      expect(draft.observedRevision, 1);
      expect(
        f.source.resources.first.fields['name'],
        const TextDisplayValue('External'),
      );
      expect(f.session.state.detail.data!.sourceRevision, 2);
    });
    test('ED15-explicit-switch', () async {
      // Given an accepted edited resource and retained adaptive focus.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final draft = f.controller.state.draft!;
      final calls = f.port.requests.length;
      // When the same accepted resource is selected again.
      expect(
        await f.controller.select('doc:1'),
        DisplayNavigationOutcome.selected,
      );
      // Then current Detail opens with no extra read and the same draft.
      expect(f.port.requests, hasLength(calls));
      expect(f.controller.state.draft, same(draft));
      // Given a different resource would require losing the retained draft.
      // When it is selected without explicit discard.
      expect(
        await f.controller.select('doc:2'),
        DisplayNavigationOutcome.discardRequired,
      );
      // Then focus, pane, draft and ports remain unchanged.
      expect(f.session.state.selectedResourceId, 'doc:1');
      expect(f.controller.state.draft, same(draft));
      expect(f.port.requests, hasLength(calls));
      // Given the user explicitly permits draft discard and the flow can switch.
      // When the second resource is selected with explicit discard.
      expect(
        await f.controller.select('doc:2', discardDraft: true),
        DisplayNavigationOutcome.selected,
      );
      // Then one read adopts only the second identity and clears the old draft.
      expect(f.controller.state.draft, isNull);
      expect(f.session.state.selectedResourceId, 'doc:2');
      expect(f.port.requests, hasLength(calls + 1));
      expect(f.source.resources.first.sourceRevision, 1);
      expect(f.controller.displayModel.compactDetailRequested, isTrue);
    });
    test('ED16-failed-switch', () async {
      // Given an old draft/focus and a failed next target read.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      f.source.failNextDisplay(
        DisplayRequestKind.read,
        FixtureTransportFault.unavailable,
      );
      final old = f.session.state.detail.data;
      // When selection explicitly discards before the failed target read.
      expect(
        await f.controller.select('doc:2', discardDraft: true),
        DisplayNavigationOutcome.failed,
      );
      // Then accepted focus/pane remain old while explicit discard is not rolled back.
      expect(f.controller.state.draft, isNull);
      expect(f.session.state.selectedResourceId, 'doc:1');
      expect(f.session.state.detail.data, same(old));
      expect(f.session.state.detail.phase, DisplaySessionReadPhase.failed);
      expect(f.controller.displayModel.compactDetailRequested, isTrue);
      expect(f.source.resources.map((resource) => resource.sourceRevision), [
        1,
        1,
      ]);
    });
    test('ED17-pane-preservation', () async {
      // Given one edited resource and its retained generation.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final draft = f.controller.state.draft!;
      final calls = f.port.requests.length;
      for (final action in [
        f.controller.showList,
        f.controller.focusDetail,
        f.controller.restoreSplit,
      ]) {
        // Given only presentation navigation is about to change.
        // When one explicit pane action is applied.
        action();
        // Then semantic identity, input and ports remain unchanged.
        expect(f.controller.state.draft, same(draft));
        expect(f.session.state.selectedResourceId, 'doc:1');
        expect(f.port.requests, hasLength(calls));
      }
      expect(
        f.controller.displayModel.preference,
        ResourceListDetailDisplayPreference.split,
      );
    });
    for (final unavailable in [false, true]) {
      test(unavailable ? 'ED18-unavailable-registry' : 'ED18-unknown-registry', () async {
        // Given an accepted displayed definition and edited resource.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: true);
        final draft = f.controller.state.draft!;
        final displayed = f.controller.state.displayedDefinition;
        final calls = f.port.requests.length;
        final replacement = unavailable
            ? registry(a: definition(available: false))
            : DisplayDefinitionRegistry(
                registrations: [],
                neutralDefinition: definition(id: 'neutral'),
              );
        // When an incompatible explicit registry replaces the old lookup data.
        f.controller.updateRegistry(replacement);
        // Then old display/draft/focus are pinned while editing is visibly blocked without a port.
        expect(f.controller.registry, same(replacement));
        expect(f.controller.state.displayedDefinition, same(displayed));
        expect(f.controller.state.draft, same(draft));
        expect(f.controller.state.canEdit, isFalse);
        expect(
          f.controller.state.resolution.failure!.kind,
          unavailable
              ? DisplayDefinitionFailureKind.unavailableDefinition
              : DisplayDefinitionFailureKind.unknownArm,
        );
        expect(f.port.requests, hasLength(calls));
        expect(f.session.state.selectedResourceId, 'doc:1');
        // Given incompatibility still allows explicit nonbusy draft disposal.
        // When the user discards the retained draft.
        f.controller.discardDraft();
        // Then the old input is cleared without silently adopting neutral.
        expect(f.controller.state.draft, isNull);
        expect(f.controller.state.resolution.isAvailable, isFalse);
        expect(f.port.requests, hasLength(calls));
      });
    }
    for (final changed in [true, false]) {
      test(
        changed ? 'ED19-changed-definition' : 'ED19-equal-definition',
        () async {
          // Given a retained draft tied to an immutable displayed definition.
          final f = PresentationFixture();
          addTearDown(f.dispose);
          await openController(f, edit: true);
          final draft = f.controller.state.draft!;
          final next = registry(
            a: changed
                ? definition(id: 'new', style: DisplayDefinitionStyle.cards)
                : definition(),
          );
          // When compatible replacement data is explicitly supplied.
          f.controller.updateRegistry(next);
          // Then structural equality retains editability while different data requires explicit discard.
          expect(f.controller.state.draft, same(draft));
          expect(f.controller.state.canSave, !changed);
          expect(
            f.controller.state.resolution.failure?.kind,
            changed
                ? DisplayDefinitionFailureKind.definitionChangeRequiresDiscard
                : isNull,
          );
          if (changed) {
            // Given the proposed compatible definition is pinned behind retained input.
            // When draft discard explicitly permits definition adoption.
            f.controller.discardDraft();
            // Then proposed cards definition is adopted without a raw port.
            expect(f.controller.state.displayedDefinition!.id, 'new');
            expect(
              f.controller.state.displayedDefinition!.style,
              DisplayDefinitionStyle.cards,
            );
            expect(f.controller.state.canEdit, isTrue);
            expect(f.source.callCount, 2);
          } else {
            // Given equal replacement has preserved the semantic generation.
            // When editing continues in that generation.
            setDraftValue(
              f.controller,
              locator('title'),
              const TextDisplayValue('Continued'),
            );
            // Then only input changes and the definition/revision stay fixed.
            expect(f.controller.state.draft!.generation, draft.generation);
            expect(f.controller.state.draft!.observedRevision, 1);
            expect(f.source.resources.first.sourceRevision, 1);
          }
        },
      );
    }
    test('ED20-context-latch-reset', () async {
      // Given an edited accepted resource and incompatible producer replacement on the next safe read.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final draft = f.controller.state.draft!;
      final displayed = f.controller.state.displayedDefinition;
      f.port.readTransform = incompatibleProducer;
      // When explicit Reload encounters a producer that is not admitted.
      await f.controller.reload();
      // Then Core latches context failure, retaining the displayed projection, draft and focus.
      expect(
        f.session.state.contextFailure!.kind,
        DisplaySessionFailureKind.context,
      );
      expect(f.controller.state.canEdit, isFalse);
      expect(f.controller.state.draft, same(draft));
      expect(f.controller.state.displayedDefinition, same(displayed));
      expect(f.session.state.selectedResourceId, 'doc:1');
      expect(f.source.resources.first.sourceRevision, 1);
      final calls = f.port.requests.length;
      // Given the latched flow cannot switch even with proposed explicit discard.
      // When a different resource is selected with discard requested.
      expect(
        () => f.controller.select('doc:2', discardDraft: true),
        throwsStateError,
      );
      // Then switching fails before discard or another port.
      expect(f.controller.state.draft, same(draft));
      expect(f.port.requests, hasLength(calls));
      // Given explicit draft discard is still allowed under context failure.
      // When the old draft is explicitly discarded.
      f.controller.discardDraft();
      // Then no hidden neutral fallback or source update occurs.
      expect(f.controller.state.draft, isNull);
      expect(f.controller.state.canEdit, isFalse);
      expect(f.port.requests, hasLength(calls));
      final supplied = presentationContext(arm: 'B', flow: 'new-flow');
      final fresh = PresentationFixture(context: supplied);
      addTearDown(fresh.dispose);
      final next = fresh.newSession(supplied);
      // Given a separate pristine source/session with a newly supplied fixed flow.
      // When the old owner explicitly resets into that exact new session/registry.
      f.controller.reset(nextSession: next, nextRegistry: registry());
      // Then old Core is disposed and new fixed context stays idle with no inherited focus/draft/activity.
      expect(f.session.isDisposed, isTrue);
      expect(next.isDisposed, isFalse);
      expect(next.state.list.phase, DisplaySessionReadPhase.idle);
      expect(next.state.selectedResourceId, isNull);
      expect(
        f.controller.state.displayedDefinition!.style,
        DisplayDefinitionStyle.cards,
      );
      expect(f.controller.state.draft, isNull);
      expect(next.state.context, supplied);
      expect(fresh.source.callCount, 0);
      // Given the reset session remains manual until explicitly loaded.
      // When the owner explicitly loads the new fixed flow.
      await f.controller.load();
      // Then only the new collection is queried without an inherited Detail selection.
      expect(next.state.list.phase, DisplaySessionReadPhase.ready);
      expect(next.state.selectedResourceId, isNull);
      expect(fresh.source.callCount, 1);
      expect(fresh.source.calls.single.request.metadata.context, supplied);
    });
    test('ED21-reset-no-effect-table', () async {
      // Given an old editable draft and several distinct invalid reset candidates.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      final pristine = f.newSession(f.session.state.context);
      final used = f.newSession(f.session.state.context);
      // When a candidate is explicitly queried before reset admission.
      await used.query();
      // Then that candidate is already nonpristine while old draft remains untouched.
      expect(used.state.list.phase, DisplaySessionReadPhase.ready);
      expect(f.controller.state.draft, isNotNull);
      final disposed = f.newSession(f.session.state.context);
      // Given one candidate will be intentionally disposed.
      // When candidate disposal occurs before reset.
      disposed.dispose();
      // Then it is ineligible and old ownership stays alive.
      expect(disposed.isDisposed, isTrue);
      expect(f.session.isDisposed, isFalse);
      final attempts = <(String, DisplaySession, bool)>[
        ('missing-discard', pristine, false),
        ('same', f.session, true),
        ('nonpristine', used, true),
        ('disposed', disposed, true),
      ];
      final before = f.controller.state;
      final calls = f.port.requests.length;
      for (final attempt in attempts) {
        // Given one exact invalid ownership/reset precondition.
        // When that reset is attempted.
        expect(
          () => f.controller.reset(
            nextSession: attempt.$2,
            nextRegistry: registry(),
            discardDraft: attempt.$3,
          ),
          throwsStateError,
        );
        // Then neither ownership nor retained input nor any port changes.
        expect(f.controller.state, same(before));
        expect(f.session.isDisposed, isFalse);
        expect(pristine.isDisposed, isFalse);
        expect(used.isDisposed, isFalse);
        expect(f.port.requests, hasLength(calls));
      }
      final gate = Completer<void>();
      f.port.readGate = gate;
      // Given an old draft and an active safe refresh prevent reset.
      // When Reload reserves the old owner and holds its read.
      final reload = f.controller.reload();
      await f.port.readArrived.future;
      // Then activity is busy and reset admission cannot discard the old generation.
      expect(f.controller.state.busy, isTrue);
      final busyDraft = f.controller.state.draft;
      // Given the owner is still busy with a pristine distinct candidate.
      // When reset is attempted with explicit discard during that activity.
      expect(
        () => f.controller.reset(
          nextSession: pristine,
          nextRegistry: registry(),
          discardDraft: true,
        ),
        throwsStateError,
      );
      // Then both sessions remain alive and draft is retained.
      expect(f.controller.state.draft, same(busyDraft));
      expect(pristine.isDisposed, isFalse);
      expect(f.session.isDisposed, isFalse);
      // Given the pending read is under explicit test control.
      // When its continuation is released.
      gate.complete();
      await reload;
      // Then the old owner completes normally without any reset.
      expect(f.controller.session, same(f.session));
      expect(f.controller.state.draft, same(busyDraft));
      // Given unused candidates are independently caller-owned.
      // When their cleanup explicitly disposes them.
      pristine.dispose();
      used.dispose();
      // Then both candidate owners are disposed and the active owner is still alive.
      expect(pristine.isDisposed, isTrue);
      expect(used.isDisposed, isTrue);
      expect(f.session.isDisposed, isFalse);
    });
    test('ED22-valid-operation', () async {
      // Given an accepted enabled descriptor and exact Detail revision, without a draft.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f);
      final calls = f.port.requests.length;
      // When the ordinary Operation is explicitly executed.
      await f.controller.executeOperation('advance');
      // Then only the Operation port changes semantic source, with no implicit Display.
      expect(f.source.operationCallCount, 1);
      expect(f.source.operationCalls.single.metadata.observedRevision, 1);
      expect(f.source.operationCalls.single.operationId, 'advance');
      expect(f.port.requests, hasLength(calls));
      expect(
        f.source.resources.first.fields['state'],
        const TextDisplayValue('review'),
      );
      expect(f.source.resources.first.sourceRevision, 2);
      expect(f.session.state.detail.data!.sourceRevision, 1);
      expect(f.session.state.command.operation!.committedRevision, 2);
      // Given Operation left explicit pending projection evidence.
      // When the owner explicitly Reloads.
      await f.controller.reload();
      // Then the changed projection removes the action without another Operation.
      expect(f.session.state.detail.data!.model.actions, isEmpty);
      expect(f.session.state.canMutate, isTrue);
      expect(f.source.operationCallCount, 1);
      expect(
        f.session.state.detail.data!.model.sections.first.fields.last.value,
        const TextDisplayValue('Review'),
      );
    });
    test('ED22-invalid-operation', () async {
      // Given a ready Detail with a disabled descriptor and no draft.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      f.port.readTransform = (wire) =>
          duplicateSection(wire, disabledAction: true);
      await openController(f);
      final calls = f.port.requests.length;
      for (final id in ['unknown', 'advance', ' ']) {
        // Given an unknown, disabled or blank Operation identifier.
        // When that exact Operation is attempted.
        expect(() => f.controller.executeOperation(id), throwsArgumentError);
        // Then no Operation/source/Display effect is produced.
        expect(f.source.operationCallCount, 0);
        expect(f.port.requests, hasLength(calls));
        expect(f.source.resources.first.sourceRevision, 1);
      }
      // Given a valid current Detail can hold an explicit draft independently of descriptor availability.
      // When editing begins.
      f.controller.beginEdit();
      // Then draft gates Operation eligibility.
      expect(f.controller.state.canOperate, isFalse);
      // Given an active draft is retained.
      // When an Operation is attempted even by descriptor identity.
      expect(() => f.controller.executeOperation('advance'), throwsStateError);
      // Then input is retained and no Operation occurs.
      expect(f.controller.state.draft, isNotNull);
      expect(f.source.operationCallCount, 0);
      expect(f.port.requests, hasLength(calls));
    });
    for (final create in [true, false]) {
      test(create ? 'ED23-create' : 'ED23-delete', () async {
        // Given an eligible collection/Detail with no draft and bounded unsupported capabilities.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f);
        final resources = f.source.resources;
        // When unsupported create or delete is explicitly dispatched.
        if (create) {
          await f.controller.createUnsupported();
        } else {
          await f.controller.deleteUnsupported();
        }
        // Then unsupported receipt never claims success or a changed semantic revision.
        expect(
          f.session.state.command.mutation!.outcome,
          DisplayCommandOutcome.unsupported,
        );
        expect(f.session.state.command.mutation!.committedRevision, isNull);
        expect(f.source.resources.first.fields, resources.first.fields);
        expect(f.source.resources.map((resource) => resource.sourceRevision), [
          1,
          1,
        ]);
        expect(
          f.port.requests.last.kind,
          create ? DisplayRequestKind.create : DisplayRequestKind.delete,
        );
        if (create) {
          expect(
            (f.port.requests.last as DisplayCreateRequest).fields,
            isEmpty,
          );
        }
        if (!create) {
          expect(f.port.requests.last.metadata.observedRevision, 1);
        }
        expect(f.source.operationCallCount, 0);
        expect(f.controller.state.draft, isNull);
      });
    }
    for (final save in [false, true]) {
      test(save ? 'ED24-pending-save-dispose' : 'ED24-pending-read-dispose', () async {
        // Given a real source activity held after the raw port has run.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f, edit: save);
        final gate = Completer<void>();
        if (save) {
          setDraftValue(
            f.controller,
            locator('title'),
            const TextDisplayValue('Committed before dispose'),
          );
          f.port.updateGate = gate;
        } else {
          f.port.readGate = gate;
        }
        // When the pending Save or different-resource read starts.
        final Future<void> activity = save
            ? f.controller.save()
            : f.controller.select('doc:2').then<void>((_) {});
        await (save ? f.port.updateArrived.future : f.port.readArrived.future);
        // Then raw source effects already exist independently of UI continuation.
        expect(f.source.resources.first.sourceRevision, save ? 2 : 1);
        expect(f.controller.state.busy, isTrue);
        final retained = f.controller.state;
        final calls = f.port.requests.length;
        var late = 0;
        f.controller.addListener(() => late++);
        // Given an active port does not grant rollback or cancellation semantics.
        // When owner disposal repeats before that port is released.
        f.controller.dispose();
        f.controller.dispose();
        // Then owned Core is immediately disposed and public calls fail before effects.
        expect(f.controller.isDisposed, isTrue);
        expect(f.session.isDisposed, isTrue);
        expect(() => f.controller.showList(), throwsStateError);
        expect(() => f.controller.load(), throwsStateError);
        // Given raw activity remains held but controller continuations are invalidated.
        // When the started raw response is released.
        gate.complete();
        await activity;
        await Future<void>.value();
        // Then no late publication, pane adoption, refresh or rollback occurs.
        expect(f.controller.state, same(retained));
        expect(late, 0);
        expect(f.port.requests, hasLength(calls));
        expect(f.session.state.selectedResourceId, 'doc:1');
        expect(f.source.resources.first.sourceRevision, save ? 2 : 1);
      });
    }
    for (final origin in ['controller', 'core', 'model']) {
      test('ED24-$origin-notification-dispose', () async {
        // Given an accepted owner and a disposal callback inside one notification stack.
        final f = PresentationFixture();
        addTearDown(f.dispose);
        await openController(f);
        final calls = f.port.requests.length;
        if (origin == 'controller') {
          f.controller.addListener(f.controller.dispose);
        }
        if (origin == 'core') {
          f.session.addListener(f.controller.dispose);
        }
        if (origin == 'model') {
          f.controller.displayModel.addListener(f.controller.dispose);
        }
        // When the selected notifier publishes inside an explicit public action.
        if (origin == 'controller') {
          f.controller.beginEdit();
        }
        if (origin == 'core') {
          await f.controller.reload();
        }
        if (origin == 'model') {
          f.controller.focusDetail();
        }
        // Then disposal is immediate even within nested notifier stacks and no raw continuation starts.
        expect(f.controller.isDisposed, isTrue);
        expect(f.session.isDisposed, isTrue);
        expect(f.port.requests, hasLength(calls));
        final retained = f.controller.state;
        // Given notifier release is deferred exactly beyond active stacks.
        // When the queued microtask has an opportunity to release owned notifiers.
        await Future<void>.value();
        // Then retained snapshots stay readable with no late source effects or state publication.
        expect(f.controller.state, same(retained));
        expect(f.source.resources.first.sourceRevision, 1);
        expect(() => f.controller.beginEdit(), throwsStateError);
      });
    }
    test('ED25-reservation-reentry', () async {
      // Given an edited owner and one held update port with a synchronous reentry observer.
      final f = PresentationFixture();
      addTearDown(f.dispose);
      await openController(f, edit: true);
      setDraftValue(
        f.controller,
        locator('title'),
        const TextDisplayValue('One save'),
      );
      final gate = Completer<void>();
      f.port.updateGate = gate;
      var reentries = 0;
      f.controller.addListener(() {
        if (!f.controller.state.busy) {
          return;
        }
        // Given the synchronous reservation is already visible in a notification.
        // When a listener tries a semantic reentrant load.
        expect(() => f.controller.load(), throwsStateError);
        reentries++;
        // Then the observer has no source authority or duplicate request.
        expect(f.controller.state.busy, isTrue);
      });
      // When Save synchronously reserves before crossing the public Core port.
      final save = f.controller.save();
      // Then immediate duplicate Save is rejected before any second activity.
      expect(f.controller.state.busy, isTrue);
      // Given the first Save remains reserved.
      // When another Save is called synchronously.
      expect(() => f.controller.save(), throwsStateError);
      // Then only the first update can reach the source.
      await f.port.updateArrived.future;
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      expect(reentries, greaterThan(0));
      // Given raw source has committed once and response is held.
      // When its continuation is explicitly released.
      gate.complete();
      await save;
      // Then one coherent revision-two result completes without duplicate update.
      expect(f.source.resources.first.sourceRevision, 2);
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      expect(f.controller.state.draft, isNull);
      expect(f.session.state.canMutate, isTrue);
    });
    test('ED25-isolated-immutable', () async {
      // Given two independent owners, semantic sources and immutable snapshot generations.
      final a = PresentationFixture();
      final b = PresentationFixture();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await openController(a, edit: true);
      await openController(b, edit: true);
      final snapshot = a.controller.state;
      final draft = snapshot.draft!;
      final other = b.controller.state;
      // When one owner's input changes and attempts are made to mutate retained collections.
      setDraftValue(
        a.controller,
        locator('title'),
        const TextDisplayValue('Only A'),
      );
      expect(
        () =>
            draft.values[locator('title')] = const TextDisplayValue('Illegal'),
        throwsUnsupportedError,
      );
      expect(() => draft.initialValues.clear(), throwsUnsupportedError);
      expect(() => draft.bindings.clear(), throwsUnsupportedError);
      expect(() => snapshot.fieldErrors.clear(), throwsUnsupportedError);
      expect(
        () => snapshot.session.committedRevisions.clear(),
        throwsUnsupportedError,
      );
      // Then old snapshots/input maps remain immutable and independent owner/source stay unchanged.
      expect(
        draft.values[locator('title')],
        const TextDisplayValue('First document'),
      );
      expect(draft.hasUnsavedChanges, isFalse);
      expect(a.controller.state.draft!.hasUnsavedChanges, isTrue);
      expect(b.controller.state, same(other));
      expect(b.source.resources.first.sourceRevision, 1);
      expect(
        b.controller.state.draft!.values[locator('title')],
        const TextDisplayValue('First document'),
      );
      expect(a.source.resources.first.sourceRevision, 1);
    });
  });
}
