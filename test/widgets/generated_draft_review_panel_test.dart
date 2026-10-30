import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  testWidgets('mount and selection do no IO and a missing source explains the next action', (
    tester,
  ) async {
    // Given a borrowed controller without a selected source.
    final provider = _Provider();
    final controller = _controller(provider);
    addTearDown(controller.dispose);
    // When the common panel mounts without a caller command.
    await _mount(tester, controller);
    // Then it explains source selection and performs no probe, preparation or inference.
    expect(find.text('画像の説明・文章の要約'), findsOneWidget);
    expect(find.text('先に出典を選んでください。'), findsOneWidget);
    expect(provider.probes, 0);
    expect(provider.preparations, 0);
    expect(provider.requests, isEmpty);
    // When the caller selects exact text and rebuilds through the subscription.
    controller.selectSource(_text());
    await tester.pump();
    // Then the original is visible and selection still performs no hidden IO.
    expect(find.text('原文'), findsOneWidget);
    expect(find.text(_original), findsOneWidget);
    expect(provider.probes, 0);
    expect(provider.requests, isEmpty);
  });

  for (final image in [false, true]) {
    testWidgets('connected ${image ? "image" : "text"} commands show exact source, raw and model', (
      tester,
    ) async {
      // Given a real service connected to a ready fake provider and an exact selected source.
      final provider = _Provider();
      final controller = _controller(provider);
      addTearDown(controller.dispose);
      controller.selectSource(image ? _image() : _text(), imageBytes: image ? _png : null);
      await _mount(tester, controller);
      expect(provider.probes, 0);
      if (image) {
        final preview = tester.widget<Image>(find.byType(Image));
        expect((preview.image as MemoryImage).bytes, orderedEquals(_png));
        expect(find.text('出典：image-source'), findsOneWidget);
      } else {
        expect(find.text(_original), findsOneWidget);
      }
      // When the user explicitly probes and generates through the common panel.
      await _tap(tester, 'generated-draft-probe');
      await _tap(tester, 'generated-draft-generate');
      // Then the pending product is labeled derived, with its exact original/raw and real operation.
      expect(provider.requests.single.operation, image
        ? GeneratedDraftOperation.imageDescription : GeneratedDraftOperation.textSummary);
      expect(find.text(image ? '画像の説明（生成下書き）'
          : '文章の要約（生成下書き）'), findsWidgets);
      expect(find.text('生成された未編集の下書き'), findsOneWidget);
      expect(find.text(_raw), findsOneWidget);
      expect(controller.workspace.decisions, isEmpty);
      await tester.ensureVisible(find.text('出典・生成情報').last);
      await tester.tap(find.text('出典・生成情報').last);
      await tester.pumpAndSettle();
      expect(find.text('プロバイダー：widget-fake'), findsWidgets);
      expect(find.text('モデル：widget-model'), findsWidgets);
      expect(find.text('処理：${provider.requests.single.operation.name} / ja'), findsWidgets);
      expect(controller.workspace.attempts.single.source.text, image ? isNull : _original);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in [
    GeneratedDraftAvailabilityState.unavailable,
    GeneratedDraftAvailabilityState.unsupported,
    GeneratedDraftAvailabilityState.preparing,
    GeneratedDraftAvailabilityState.downloadable,
  ]) {
    testWidgets('${state.name} preserves reason and manual editing; preparation is explicit', (
      tester,
    ) async {
      // Given a selected original and a provider reporting one non-ready state.
      final provider = _Provider()..state = state;
      final controller = _controller(provider)..selectSource(_text());
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      // When the user checks availability and edits an independent manual field.
      await _tap(tester, 'generated-draft-probe');
      await tester.ensureVisible(find.byKey(const ValueKey('manual-sibling')));
      await tester.enterText(find.byKey(const ValueKey('manual-sibling')), '手入力の注釈');
      // Then the truthful reason is visible, generation is disabled and manual editing still works.
      expect(find.text('利用状態：${state.name}'), findsOneWidget);
      expect(find.text('実際の状態：${state.name}'), findsOneWidget);
      final manual = tester.widget<EditableText>(find.descendant(
        of: find.byKey(const ValueKey('manual-sibling')),
        matching: find.byType(EditableText)));
      expect(manual.controller.text, '手入力の注釈');
      expect(tester.widget<FilledButton>(find.byKey(
        const ValueKey('generated-draft-generate'))).onPressed, isNull);
      expect(provider.preparations, 0);
      expect(provider.requests, isEmpty);
      if (state == GeneratedDraftAvailabilityState.downloadable) {
        // When the explicit preparation button is pressed for downloadable availability.
        await _tap(tester, 'generated-draft-prepare');
        // Then exactly one model preparation occurs and the refreshed state becomes available.
        expect(provider.preparations, 1);
        expect(find.text('利用状態：available'), findsOneWidget);
      } else {
        expect(find.byKey(const ValueKey('generated-draft-prepare')), findsNothing);
      }
      expect(controller.source!.text, _original);
    });
  }

  for (final intent in ['accept', 'edit', 'clear', 'discard']) {
    testWidgets('explicit $intent changes only derived history and adopted display', (
      tester,
    ) async {
      // Given an exact pending draft beside its original source and a manual sibling field.
      final provider = _Provider();
      final controller = await _pending(provider);
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      expect(find.text(_raw), findsOneWidget);
      expect(find.text(_original), findsWidgets);
      // When the user explicitly accepts, edits, clears or discards that pending draft.
      final action = intent == 'clear' ? 'edit' : intent;
      await _tap(tester, 'generated-draft-$action-draft-0');
      if (action == 'edit') {
        expect(find.text('採用する下書き（空欄で消去）'), findsOneWidget);
        expect(tester.widget<TextFormField>(find.byType(TextFormField)).initialValue, _raw);
        await tester.enterText(find.byType(TextFormField), intent == 'clear' ? '' : '確認した下書き');
        await tester.tap(find.widgetWithText(FilledButton, '採用').last);
        await tester.pumpAndSettle();
      }
      // Then raw/original remain exact while the explicit derived result and discard count are shown.
      expect(controller.workspace.attempts.single.rawText, _raw);
      expect(controller.workspace.attempts.single.source.text, _original);
      expect(controller.workspace.pending, isEmpty);
      expect(controller.workspace.decisions.length, 1);
      if (intent == 'discard') {
        expect(find.text('採用済みの生成下書き'), findsNothing);
        expect(find.textContaining('破棄 1件'), findsOneWidget);
      } else {
        expect(find.text('採用済みの生成下書き'), findsOneWidget);
        expect(find.text(intent == 'clear' ? '消去済み'
          : intent == 'edit' ? '確認した下書き' : _raw), findsOneWidget);
        expect(find.text('処理：textSummary'), findsOneWidget);
        expect(controller.workspace.decisions.single.editedText,
          intent == 'clear' ? '' : intent == 'edit' ? '確認した下書き' : null);
      }
      expect(find.byKey(const ValueKey('manual-sibling')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in ['accept', 'edit', 'discard']) {
    for (final change in ['controller', 'selection', 'context', 'enabled', 'admission']) {
      testWidgets('retained $action closure is fenced after $change changes', (
        tester,
      ) async {
        // Given a rendered action holding the original controller, source and human context.
        var revision = 1;
        var allowed = true;
        var enabled = true;
        final original = await _pending(_Provider(), revision: () => revision,
          admitted: () => allowed);
        final replacement = await _pending(_Provider(), owner: 'replacement');
        addTearDown(original.dispose);
        addTearDown(replacement.dispose);
        var selected = original;
        late StateSetter rebuild;
        await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return _body(selected, enabled: enabled);
          },
        )));
        final oldAction = tester.widget<ButtonStyleButton>(find.byKey(
          ValueKey('generated-draft-$action-draft-0'))).onPressed!;
        // When the captured action survives a controller, selection, context or live-policy change.
        rebuild(() {
          if (change == 'controller') selected = replacement;
          if (change == 'selection') original.selectSource(_text(id: 'new-source'));
          if (change == 'context') revision++;
          if (change == 'enabled') enabled = false;
          if (change == 'admission') allowed = false;
        });
        await tester.pump();
        oldAction();
        await tester.pumpAndSettle();
        // Then neither owner adopts/discards and an obsolete edit closure cannot open a dialog.
        expect(original.workspace.decisions, isEmpty);
        expect(replacement.workspace.decisions, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final change in ['controller', 'selection', 'context', 'enabled', 'admission']) {
    testWidgets('opened edit dialog cannot adopt after $change changes', (
      tester,
    ) async {
      // Given an open editor with raw text captured from the original exact owner/render.
      var revision = 1;
      var allowed = true;
      var enabled = true;
      final original = await _pending(_Provider(), revision: () => revision,
        admitted: () => allowed);
      final replacement = await _pending(_Provider(), owner: 'replacement');
      addTearDown(original.dispose);
      addTearDown(replacement.dispose);
      var selected = original;
      late StateSetter rebuild;
      await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
        builder: (_, setState) {
          rebuild = setState;
          return _body(selected, enabled: enabled);
        },
      )));
      await _tap(tester, 'generated-draft-edit-draft-0');
      await tester.enterText(find.byType(TextFormField), '古いダイアログの入力');
      // When the owner/render/policy changes while the old dialog remains open and then confirms.
      rebuild(() {
        if (change == 'controller') selected = replacement;
        if (change == 'selection') original.selectSource(_text(id: 'new-source'));
        if (change == 'context') revision++;
        if (change == 'enabled') enabled = false;
        if (change == 'admission') allowed = false;
      });
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '採用').last);
      await tester.pumpAndSettle();
      // Then the edited intent reaches neither owner, while both original raw histories remain intact.
      expect(original.workspace.decisions, isEmpty);
      expect(replacement.workspace.decisions, isEmpty);
      expect(original.workspace.attempts.single.rawText, _raw);
      expect(replacement.workspace.attempts.single.rawText, _raw);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('live admission denies a previously enabled action without rebuilding', (
    tester,
  ) async {
    // Given a visibly enabled accept action and a separately checked human admission policy.
    var allowed = true;
    final controller = await _pending(_Provider(), admitted: () => allowed);
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    final retained = tester.widget<FilledButton>(find.byKey(
      const ValueKey('generated-draft-accept-draft-0'))).onPressed!;
    // When admission is revoked without any widget rebuild and the retained closure fires.
    allowed = false;
    retained();
    await tester.pump();
    // Then the controller's live guard blocks adoption despite the former enabled appearance.
    expect(controller.workspace.decisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete source disables accept/edit, explains why and allows discard', (
    tester,
  ) async {
    // Given a successful pending draft whose independently resolved source is later retired.
    var current = true;
    final controller = await _pending(_Provider(), current: (_) => current);
    addTearDown(controller.dispose);
    current = false;
    await _mount(tester, controller);
    // When the panel presents that retained obsolete-source attempt.
    final accept = tester.widget<FilledButton>(find.byKey(
      const ValueKey('generated-draft-accept-draft-0')));
    final edit = tester.widget<TextButton>(find.byKey(
      const ValueKey('generated-draft-edit-draft-0')));
    // Then it explains source retirement and permits only an explicit discard decision.
    expect(accept.onPressed, isNull);
    expect(edit.onPressed, isNull);
    expect(find.textContaining('出典が更新または削除されています'), findsOneWidget);
    await _tap(tester, 'generated-draft-discard-draft-0');
    expect(controller.workspace.decisions.single.kind, GeneratedDraftDecisionKind.discard);
    expect(controller.workspace.attempts.single.rawText, _raw);
  });

  testWidgets('cancel survives external action disabling and busy lasts through cleanup', (
    tester,
  ) async {
    // Given connected generation with delayed inference and independently delayed cleanup.
    var allowed = true;
    var enabled = true;
    final provider = _Provider();
    final output = Completer<GeneratedDraftProviderOutput>();
    final cleanup = Completer<bool>();
    provider.output = output.future;
    provider.cancellation = cleanup.future;
    final controller = _controller(provider, admitted: () => allowed)..selectSource(_text());
    addTearDown(controller.dispose);
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (_, setState) {
        rebuild = setState;
        return _body(controller, enabled: enabled);
      },
    )));
    await _tap(tester, 'generated-draft-probe');
    await _tap(tester, 'generated-draft-generate', settle: false);
    // When external interaction is disabled, then the user explicitly cancels.
    rebuild(() { allowed = false; enabled = false; });
    await tester.pump();
    expect(tester.widget<TextButton>(find.byKey(
      const ValueKey('generated-draft-cancel'))).onPressed, isNotNull);
    await _tap(tester, 'generated-draft-cancel', settle: false);
    output.complete(_success());
    await tester.pump();
    expect(controller.busy, isTrue);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    cleanup.complete(true);
    await tester.pumpAndSettle();
    // Then cleanup settlement ends busy and shows the exact canceled raw outcome without adoption.
    expect(provider.cancelIds, [provider.requests.single.id]);
    expect(controller.busy, isFalse);
    expect(find.text('canceled / canceled'), findsOneWidget);
    expect(find.text(_raw), findsOneWidget);
    expect(controller.workspace.pending, isEmpty);
    expect(controller.workspace.decisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old command closures never launch or cancel a replacement controller', (
    tester,
  ) async {
    // Given a generate closure rendered for one ready controller and a ready replacement.
    final oldProvider = _Provider();
    final newProvider = _Provider();
    final original = _controller(oldProvider)..selectSource(_text());
    final replacement = _controller(newProvider, owner: 'replacement')..selectSource(_text());
    addTearDown(original.dispose);
    addTearDown(replacement.dispose);
    await original.checkAvailability();
    await replacement.checkAvailability();
    var selected = original;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (_, setState) {
        rebuild = setState;
        return _body(selected);
      },
    )));
    final generate = tester.widget<FilledButton>(find.byKey(
      const ValueKey('generated-draft-generate'))).onPressed!;
    // When replacement occurs before the old generate closure fires.
    rebuild(() => selected = replacement);
    await tester.pump();
    generate();
    await tester.pumpAndSettle();
    // Then no generation starts on either controller from the old closure.
    expect(oldProvider.requests, isEmpty);
    expect(newProvider.requests, isEmpty);
    // Given a cancel closure for a now-running original owner.
    final oldOutput = Completer<GeneratedDraftProviderOutput>();
    final newOutput = Completer<GeneratedDraftProviderOutput>();
    oldProvider.output = oldOutput.future;
    newProvider.output = newOutput.future;
    rebuild(() => selected = original);
    await tester.pump();
    await _tap(tester, 'generated-draft-generate', settle: false);
    final cancel = tester.widget<TextButton>(find.byKey(
      const ValueKey('generated-draft-cancel'))).onPressed!;
    final newRunning = replacement.generate();
    // When another controller is bound while both providers hold their own inference.
    rebuild(() => selected = replacement);
    await tester.pump();
    cancel();
    await tester.pump();
    // Then the old cancel closure reaches neither active owner, especially the replacement.
    expect(oldProvider.cancelIds, isEmpty);
    expect(newProvider.cancelIds, isEmpty);
    oldOutput.complete(_success());
    newOutput.complete(_success());
    await newRunning;
    await tester.pumpAndSettle();
    expect(original.workspace.attempts.length, 1);
    expect(replacement.workspace.attempts.length, 1);
  });

  for (final status in [GeneratedDraftStatus.failed, GeneratedDraftStatus.canceled]) {
    testWidgets('$status shows actual code, reason, raw and cleanup provenance', (
      tester,
    ) async {
      // Given a provider terminal response carrying actual failure/cancellation evidence.
      final provider = _Provider();
      provider.terminal = GeneratedDraftProviderOutput(status: status,
        text: '失敗しても残す生出力', modelName: 'reported-model',
        errorCode: 'native-${status.name}', errorMessage: '実際の終了理由',
        cleanupFailures: ['実際の解放診断']);
      final controller = _controller(provider)..selectSource(_text());
      addTearDown(controller.dispose);
      // When explicit generation finishes and the panel displays its retained terminal history.
      await controller.generate();
      await _mount(tester, controller);
      // Then raw is visible without pending adoption, and provenance exposes actual cleanup/model.
      expect(find.text('${status.name} / native-${status.name}'), findsOneWidget);
      expect(find.text('実際の終了理由'), findsOneWidget);
      expect(find.text('失敗しても残す生出力'), findsOneWidget);
      expect(find.byKey(const ValueKey('generated-draft-accept-draft-0')), findsNothing);
      await tester.ensureVisible(find.text('出典・生成情報').last);
      await tester.tap(find.text('出典・生成情報').last);
      await tester.pumpAndSettle();
      expect(find.text('モデル：reported-model'), findsOneWidget);
      expect(find.text('実際の解放診断'), findsOneWidget);
    });
  }

  testWidgets('command and callback errors are visible and do not escape widget futures', (
    tester,
  ) async {
    // Given a provider probe that fails once and a persistence callback that always throws.
    final provider = _Provider()..probeError = StateError('probe failed');
    final controller = _controller(provider,
      onChanged: (_) => throw StateError('persistence failed'))..selectSource(_text());
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    // When an explicit check fails, then a later check/generate reaches the failing callback.
    await _tap(tester, 'generated-draft-probe');
    expect(find.textContaining('probe failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    provider.probeError = null;
    await _tap(tester, 'generated-draft-probe');
    await _tap(tester, 'generated-draft-generate');
    // Then callback failure makes no save claim and loses neither local raw nor idle recovery.
    expect(find.textContaining('persistence failed'), findsOneWidget);
    expect(find.textContaining('保存完了を示すものではありません'), findsOneWidget);
    expect(find.text(_raw), findsOneWidget);
    expect(controller.workspace.pending.single.rawText, _raw);
    expect(controller.busy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount borrows controller and does not retire its retained history', (
    tester,
  ) async {
    // Given a mounted panel borrowing a controller with pending generation evidence.
    final controller = await _pending(_Provider());
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    // When the host removes that panel and continues owning the controller.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final next = await controller.generate();
    // Then the borrowed controller remains live, retaining its old and new attempts.
    expect(controller.isDetached, isFalse);
    expect(controller.isDisposed, isFalse);
    expect(controller.workspace.attempts.length, 2);
    expect(controller.workspace.attempts.last.id, next.id);
    expect(tester.takeException(), isNull);
  });
}

const _original = '原文・手入力の注釈を保持する。';
const _raw = '生成された生の下書き😀。';
final _time = DateTime.utc(2026, 10, 30, 2);
final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));

GeneratedDraftSource _text({String id = 'text-source'}) => GeneratedDraftSource(
  id: id, materialId: 'original', revision: 'r1',
  kind: GeneratedDraftSourceKind.text, text: _original);
GeneratedDraftSource _image() => GeneratedDraftSource(id: 'image-source',
  materialId: 'image-material', revision: 'r1', kind: GeneratedDraftSourceKind.image);

GeneratedDraftController _controller(_Provider provider, {
  String owner = 'owner', Object? Function()? revision, bool Function()? admitted,
  bool Function(GeneratedDraftSource)? current,
  void Function(GeneratedDraftWorkspace)? onChanged,
}) {
  var next = 0;
  return GeneratedDraftController(
    service: GeneratedDraftService(provider: provider, clock: () => _time), ownerId: owner,
    contextRevision: revision, interactionAllowed: admitted, sourceIsCurrent: current,
    onWorkspaceChanged: onChanged, now: () => _time.add(const Duration(seconds: 1)),
    idGenerator: () => 'draft-${next++}');
}

Future<GeneratedDraftController> _pending(_Provider provider, {
  String owner = 'owner', Object? Function()? revision, bool Function()? admitted,
  bool Function(GeneratedDraftSource)? current,
}) async {
  final controller = _controller(provider, owner: owner, revision: revision,
    admitted: admitted, current: current)..selectSource(_text());
  await controller.generate();
  return controller;
}

Widget _body(GeneratedDraftController controller, {bool enabled = true}) => Scaffold(
  body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12),
    child: Column(children: [
      GeneratedDraftReviewPanel(controller: controller, enabled: enabled),
      const TextField(key: ValueKey('manual-sibling'),
        decoration: InputDecoration(labelText: '手入力の注釈')),
    ]),
  )),
);

Future<void> _mount(WidgetTester tester, GeneratedDraftController controller) async {
  await tester.pumpWidget(MaterialApp(home: _body(controller)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

GeneratedDraftProviderOutput _success() => GeneratedDraftProviderOutput(
  status: GeneratedDraftStatus.success, text: _raw, modelName: 'widget-model');

final class _Provider implements GeneratedDraftProvider {
  @override
  String get id => 'widget-fake';
  @override
  String get promptTemplate => 'widget-template-v1';
  GeneratedDraftAvailabilityState state = GeneratedDraftAvailabilityState.available;
  int probes = 0;
  int preparations = 0;
  Object? probeError;
  Future<GeneratedDraftProviderOutput>? output;
  Future<bool>? cancellation;
  GeneratedDraftProviderOutput? terminal;
  final List<GeneratedDraftRequest> requests = [];
  final List<String> cancelIds = [];

  @override
  Future<GeneratedDraftAvailability> availability({
    required GeneratedDraftOperation operation, required String language,
  }) async {
    probes++;
    final error = probeError;
    if (error != null) throw error;
    return GeneratedDraftAvailability(providerId: id, operation: operation,
      language: language, state: state,
      modelName: state == GeneratedDraftAvailabilityState.available ? 'widget-model' : null,
      reason: state == GeneratedDraftAvailabilityState.available ? null : '実際の状態：${state.name}');
  }

  @override
  Future<void> prepare() async {
    preparations++;
    state = GeneratedDraftAvailabilityState.available;
  }

  @override
  String promptFor(GeneratedDraftRequest request) =>
      '実際の生成指示：${request.source.text ?? request.source.id}';

  @override
  Future<GeneratedDraftProviderOutput> generate(GeneratedDraftRequest request, {
    required String prompt, String? expectedModelName,
  }) {
    requests.add(request);
    return output ?? Future.value(terminal ?? _success());
  }

  @override
  Future<bool> cancel(String requestId) {
    cancelIds.add(requestId);
    return cancellation ?? Future.value(true);
  }
}
