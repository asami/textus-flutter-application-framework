import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

void main() {
  test(
    'idle construction borrows source and admits scoped ordered Text only',
    () async {
      // Given a real Core client and genuine producer baseline, with no selected read.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      final controller = fixture.controller;
      expect(fixture.requests, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.editorOpen, isFalse);
      expect(controller.canSave, isFalse);
      await controller.beginEdit();
      expect(fixture.requests, isEmpty);
      final other = CncfDisplayMutationFixture();
      addTearDown(other.dispose);
      expect(
        () => CncfDisplayMutationController(
          source: fixture.source,
          viewModel: other.viewModel,
        ),
        throwsArgumentError,
      );
      // When the selected formal Detail is captured and descriptor is held.
      await fixture.select();
      final observation = fixture.source.lastDetail;
      final gate = fixture.hold('descriptor');
      final opening = controller.beginEdit();
      expect(controller.editorOpen, isTrue);
      expect(controller.busy, isTrue);
      expect(controller.observation, same(observation));
      await gate.entered.future;
      await controller.beginEdit();
      gate.release();
      await opening;
      // Then producer order/metadata survives, while stage is never an input.
      expect(
        controller.descriptor!.fields.map((field) => field.locator.fieldId),
        ['title', 'stage', 'description'],
      );
      expect(controller.draftValues.keys, [mutationTitle, mutationDescription]);
      expect(controller.initialValues[mutationTitle], '日本の民話');
      expect(controller.canSave, isTrue);
      expect(fixture.puts, isEmpty);
      expect(
        () => controller.draftValues[mutationTitle] = 'changed',
        throwsUnsupportedError,
      );
      expect(() => controller.initialValues.clear(), throwsUnsupportedError);
      controller.setText(
        const CncfDisplayFieldLocator('other', 'title'),
        'bad',
      );
      controller.setText(const CncfDisplayFieldLocator('main', 'stage'), 'bad');
      expect(controller.draftValues.keys, [mutationTitle, mutationDescription]);
    },
  );

  test(
    'receipt is observable before held safe reads and exact revisions cohere',
    () async {
      // Given a current revision1 observation and exact Text changes made in reverse order.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      await fixture.edit();
      final controller = fixture.controller;
      final original = controller.observation;
      const exact = '  日本語\t\n😀  ';
      controller.setText(mutationDescription, ' description ');
      controller.setText(mutationTitle, exact);
      final savedSnapshot = controller.draftValues;
      final gate = fixture.hold('read');
      final evidence = <String>[];
      controller.addListener(() {
        if (controller.receipt != null &&
            fixture.requests.last.method == 'PUT') {
          evidence.add(controller.receipt!.revision);
          // A listener cannot dispatch a reentrant command or mutate the snapshot.
          controller.setText(mutationTitle, 'reentrant');
          controller.discard();
        }
      });
      // When Save starts, every competing mutation is blocked until read/query settle.
      final saving = controller.save();
      await gate.entered.future;
      expect(evidence, ['2']);
      expect(controller.receipt!.revision, '2');
      expect(controller.observation, same(original));
      expect(controller.needsReconciliation, isTrue);
      expect(await controller.save(), isFalse);
      expect(await controller.reload(), isFalse);
      await controller.beginEdit();
      controller.discard();
      controller.setText(mutationTitle, 'late');
      expect(controller.draftValues, same(savedSnapshot));
      expect(fixture.puts, hasLength(1));
      final request = fixture.puts.single;
      expect(request.headers['If-Match'], '"revision-1"');
      expect(
        request.body.indexOf('"fieldId":"title"'),
        lessThan(request.body.indexOf('"fieldId":"description"')),
      );
      expect(request.body, contains(r'\ud83d\ude00'));
      gate.release();
      expect(await saving, isTrue);
      // Then one PUT preceded safe read/query; authoritative receipt outlives editor.
      expect(controller.receipt!.revision, '2');
      expect(controller.editorOpen, isFalse);
      expect(controller.draftValues, isEmpty);
      expect(controller.needsReconciliation, isFalse);
      expect(fixture.source.lastDetail!.resources.single.revision, '2');
      expect(fixture.source.lastQuery!.resources.first.revision, '2');
      expect(fixture.viewModel.selectedResource!.value('title'), exact);
      expect(fixture.puts, hasLength(1));
    },
  );

  test('equal draft sends all writable fields once and unchanged revision1', () async {
    // Given an unchanged selected producer Detail and admitted Text descriptor.
    final fixture = CncfDisplayMutationFixture();
    addTearDown(fixture.dispose);
    await fixture.edit();
    // When the explicit Save is submitted without local changes.
    expect(await fixture.controller.save(), isTrue);
    // Then the server, rather than the controller, supplies unchanged evidence.
    expect(fixture.puts, hasLength(1));
    expect(fixture.puts.single.body, contains('"fieldId":"title"'));
    expect(fixture.puts.single.body, contains('"fieldId":"description"'));
    expect(fixture.puts.single.body, isNot(contains('"fieldId":"stage"')));
    expect(fixture.controller.receipt!.outcome, 'unchanged');
    expect(fixture.controller.receipt!.revision, '1');
  });

  test('exact UTF16 including isolated surrogates remains in draft and wire', () async {
    // Given an editable Text value and a controlled domain rejection.
    final fixture = CncfDisplayMutationFixture();
    addTearDown(fixture.dispose);
    await fixture.edit();
    fixture.updateResponse = (_) async => fixture.failureReply();
    final exact = String.fromCharCodes([32, 0x65e5, 9, 0xd800, 32]);
    // When that exact code-unit sequence is entered and explicitly submitted.
    fixture.controller.setText(mutationTitle, exact);
    await fixture.controller.save();
    // Then no trimming, surrogate replacement, or automatic retry has occurred.
    expect(
      fixture.controller.draftValues[mutationTitle]!.codeUnits,
      exact.codeUnits,
    );
    expect(fixture.puts.single.body, contains(r'\ud800'));
    expect(fixture.puts, hasLength(1));
  });

  test(
    'approved scoped rejection stays editable and next Save is explicit',
    () async {
      // Given a domain-invalid title and a Conclusion with private prose.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      await fixture.edit();
      fixture.updateResponse = (_) async => fixture.failureReply();
      fixture.controller.setText(mutationTitle, 'invalid');
      // When Core admits the exact diagnostic code and scoped path.
      expect(await fixture.controller.save(), isFalse);
      // Then only that field gets a fixed error, and the draft is retained/editable.
      expect(fixture.controller.failure!.failure!.isEditableRejection, isTrue);
      expect(fixture.controller.fieldErrors, {
        mutationTitle: 'Invalid value (DSP96_MUTATION_VALUE_INVALID)',
      });
      expect(fixture.controller.draftValues[mutationTitle], 'invalid');
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.controller.canSave, isTrue);
      expect(fixture.puts, hasLength(1));
      // When the field changes, only explicit Save issues the next command.
      fixture.controller.setText(mutationTitle, 'corrected');
      expect(fixture.controller.fieldErrors, isEmpty);
      expect(fixture.puts, hasLength(1));
      fixture.updateResponse = null;
      expect(await fixture.controller.save(), isTrue);
      expect(fixture.puts, hasLength(2));
    },
  );

  for (final kind in [
    'conflict',
    'unknown',
    'malformed',
    'timeout',
    'wrong-scope',
  ]) {
    test(
      '$kind retires draft and reconciles only through explicit safe reads',
      () async {
        // Given one attempted change with a controlled structured/unknown outcome.
        final fixture = CncfDisplayMutationFixture(
          timeout: const Duration(milliseconds: 30),
        );
        addTearDown(fixture.dispose);
        await fixture.edit();
        final controller = fixture.controller;
        controller.setText(mutationTitle, 'pinned draft');
        MutationGate? gate;
        if (kind == 'conflict') {
          // Deliberately not HTTP409: taxonomy alone identifies this conflict.
          fixture.updateResponse = (_) async =>
              fixture.failureReply(conflict: true, status: 400);
        } else if (kind == 'wrong-scope') {
          fixture.updateResponse = (_) async =>
              fixture.failureReply(path: 'capture-detail/other/title');
        } else if (kind == 'unknown') {
          fixture.updateResponse = (_) async =>
              throw StateError('PRIVATE connection');
        } else if (kind == 'malformed') {
          fixture.updateResponse = (_) async => mutationRawReply('{"data":{}}');
        } else {
          gate = fixture.hold('update');
        }
        // When one explicit command fails or its delivery becomes unknown.
        expect(await controller.save(), isFalse);
        gate?.release();
        if (gate != null) {
          await gate.settled.future;
        }
        // Then draft remains pinned, stale Save is blocked, and no replay is made.
        expect(controller.draftValues[mutationTitle], 'pinned draft');
        expect(controller.needsReconciliation, isTrue);
        expect(controller.canSave, isFalse);
        if (kind == 'conflict') {
          expect(controller.failure!.failure!.isConflict, isTrue);
        }
        expect(await controller.save(), isFalse);
        fixture.failRead = true;
        expect(await controller.reload(), isFalse);
        expect(controller.needsReconciliation, isTrue);
        fixture.failRead = false;
        expect(await controller.reload(), isFalse);
        // Then coherent reads resolve uncertainty but cannot revive the retired draft.
        expect(controller.needsReconciliation, isFalse);
        expect(controller.canSave, isFalse);
        expect(controller.draftValues[mutationTitle], 'pinned draft');
        expect(fixture.puts, hasLength(1));
        await controller.beginEdit();
        expect(controller.canSave, isFalse);
        // When explicitly discarded, a fresh observation/descriptor can be selected.
        controller.discard();
        await controller.beginEdit();
        expect(controller.canSave, isTrue);
        expect(controller.draftValues[mutationTitle], fixture.values['title']);
        expect(fixture.puts, hasLength(1));
      },
    );
  }

  for (final pending in [false, true]) {
    for (final failure in ['read', 'query', 'stale']) {
      test(
        '${pending ? 'pending' : 'ready'} receipt survives $failure refresh and discard',
        () async {
          // Given a committed revision2 receipt and controlled stale or failed reads.
          final fixture = CncfDisplayMutationFixture();
          addTearDown(fixture.dispose);
          await fixture.edit();
          final controller = fixture.controller;
          fixture.pending = pending;
          fixture.failRead = failure == 'read';
          fixture.failQuery = failure == 'query';
          if (failure == 'stale') {
            fixture.updateResponse = (_) async {
              fixture.revision = '2';
              final response = mutationRawReply(fixture.resultWire());
              fixture.revision = '1';
              return response;
            };
          }
          controller.setText(mutationTitle, 'committed');
          // When Save returns a receipt, pending never starts reads automatically.
          expect(await controller.save(), isFalse);
          final receipt = controller.receipt;
          expect(receipt!.revision, '2');
          expect(controller.canSave, isFalse);
          if (pending) {
            expect(fixture.requests.last.method, 'PUT');
            expect(await controller.reload(), isFalse);
          }
          // Then failed reads retain the receipt and reconciliation obligation across discard.
          expect(controller.needsReconciliation, isTrue);
          controller.discard();
          expect(controller.editorOpen, isFalse);
          expect(controller.receipt, same(receipt));
          await controller.beginEdit();
          expect(controller.editorOpen, isFalse);
          fixture.failRead = false;
          fixture.failQuery = false;
          fixture.revision = '2';
          expect(await controller.reload(), isTrue);
          expect(controller.receipt, same(receipt));
          expect(controller.needsReconciliation, isFalse);
          expect(fixture.puts, hasLength(1));
        },
      );
    }
  }

  test('pending receipt requires Reload then closes accepted draft after coherence', () async {
    // Given a genuine baseline with a controlled committed-pending response.
    final fixture = CncfDisplayMutationFixture();
    addTearDown(fixture.dispose);
    await fixture.edit();
    fixture.pending = true;
    fixture.controller.setText(mutationTitle, 'pending commit');
    // When Save returns pending, then known commit is retained with no eager read.
    expect(await fixture.controller.save(), isFalse);
    expect(fixture.requests.last.method, 'PUT');
    expect(fixture.controller.receipt!.pendingReason, 'view-not-current');
    expect(fixture.controller.editorOpen, isTrue);
    expect(fixture.controller.needsReconciliation, isTrue);
    // When explicit Reload obtains coherent current reads, then only safe GETs follow.
    expect(await fixture.controller.reload(), isTrue);
    expect(fixture.controller.editorOpen, isFalse);
    expect(fixture.controller.receipt!.revision, '2');
    expect(fixture.puts, hasLength(1));
  });

  test(
    'safe reads at different revisions cannot resolve an accepted receipt',
    () async {
      // Given a committed revision2 receipt and a query showing a different newer revision.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      await fixture.edit();
      fixture.queryRevision = '3';
      fixture.controller.setText(mutationTitle, 'updated');
      // When the ready command's safe Detail2 and List3 return successfully.
      expect(await fixture.controller.save(), isFalse);
      // Then successful transports alone cannot stand in for List/Detail coherence.
      expect(fixture.controller.receipt!.revision, '2');
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.controller.canSave, isFalse);
      fixture.queryRevision = null;
      // When explicit Reload reads matching revision2, then the accepted editor closes.
      expect(await fixture.controller.reload(), isTrue);
      expect(fixture.controller.editorOpen, isFalse);
      expect(fixture.puts, hasLength(1));
    },
  );

  for (final restriction in [
    'unsupported',
    'hidden',
    'system',
    'readonly',
    'multiple',
    'missing',
    'number-kind',
  ]) {
    test('$restriction cannot authorize or coerce a Text input', () async {
      // Given one producer field with a controlled unsupported state or value kind.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      if (restriction == 'unsupported') {
        (fixture.descriptorData['capabilities']! as Map)['update'] =
            'unsupported';
      } else if (restriction == 'missing') {
        fixture.missingTitle = true;
      } else if (restriction == 'number-kind') {
        ((fixture.descriptorData['fields']! as List).first
            as Map)['acceptedKinds'] = [
          'number',
        ];
      } else {
        final field = (fixture.descriptorData['fields']! as List).first as Map;
        (field['web'] as Map)[restriction] = true;
      }
      // When the formal Detail and descriptor are admitted.
      await fixture.edit();
      // Then unavailable/missing/restricted title never becomes a coerced input.
      expect(
        fixture.controller.draftValues.containsKey(mutationTitle),
        isFalse,
      );
      fixture.controller.setText(mutationTitle, 'not admitted');
      expect(
        fixture.controller.draftValues.containsKey(mutationTitle),
        isFalse,
      );
      expect(fixture.puts, isEmpty);
    });
  }

  test(
    'mismatched scoped descriptor field fails without editable fallback',
    () async {
      // Given the same flat title ID under a different descriptor section.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      ((fixture.descriptorData['fields']! as List).first as Map)['sectionId'] =
          'other';
      // When descriptor fields are matched against captured read sections.
      await fixture.edit();
      // Then the controller fails safely rather than binding by the flat field name.
      expect(fixture.controller.failure, isNotNull);
      expect(fixture.controller.draftValues, isEmpty);
      expect(fixture.controller.canSave, isFalse);
      expect(fixture.puts, isEmpty);
    },
  );

  for (final operation in ['descriptor', 'update', 'read']) {
    test('dispose during held $operation retires publication and borrows owners', () async {
      // Given a selected formal source with exactly one finite held operation.
      final fixture = CncfDisplayMutationFixture();
      addTearDown(fixture.dispose);
      await fixture.select();
      if (operation != 'descriptor') {
        await fixture.controller.beginEdit();
      }
      final gate = fixture.hold(operation);
      var notifications = 0;
      fixture.controller.addListener(() => notifications++);
      // When disposal retires the controller while its asynchronous work is held.
      final Future<void> activity = operation == 'descriptor'
          ? fixture.controller.beginEdit()
          : fixture.controller.save().then((_) {});
      await gate.entered.future;
      fixture.controller.dispose();
      final retiredNotifications = notifications;
      gate.release();
      await activity;
      // Then no late publication or next refresh/query occurs, and owners still work.
      expect(fixture.controller.isDisposed, isTrue);
      expect(notifications, retiredNotifications);
      if (operation == 'update') {
        expect(fixture.controller.needsReconciliation, isTrue);
      }
      expect(fixture.requests.last.url.path, isNot(endsWith('query.json')));
      await fixture.viewModel.load();
      await fixture.viewModel.select(fixture.id);
      expect(fixture.viewModel.selectedId, fixture.id);
      expect((await fixture.client.query()).resources, isNotEmpty);
    });
  }

  test('descriptor availability and source identity never create fallback inputs', () async {
    // Given update support with disabled availability, independent of field hints.
    final fixture = CncfDisplayMutationFixture();
    addTearDown(fixture.dispose);
    (fixture.descriptorData['availability']! as Map)['update'] = 'disabled';
    await fixture.edit();
    // When descriptor admission completes, then no writable inputs or command exists.
    expect(fixture.controller.draftValues, isEmpty);
    expect(fixture.controller.canSave, isFalse);
    expect(fixture.puts, isEmpty);
    fixture.controller.discard();
    (fixture.descriptorData['availability']! as Map)['update'] = 'enabled';
    // Given a held descriptor, when a new formal read replaces its capture.
    final gate = fixture.hold('descriptor');
    final opening = fixture.controller.beginEdit();
    await gate.entered.future;
    gate.release();
    // Mutate selection synchronously before descriptor continuation publishes.
    final refresh = fixture.viewModel.detailView.refresh();
    await opening;
    await refresh;
    // Then the obsolete observation cannot become an editable fallback.
    expect(fixture.controller.canSave, isFalse);
    expect(fixture.controller.descriptor, isNull);
    expect(fixture.puts, isEmpty);
  });
}
