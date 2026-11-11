import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../support/voice_input_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Voice input').first);
    await tester.pumpAndSettle();
  }

  Future<void> dictate(WidgetTester tester) async {
    await tester.tap(find.text('Start speaking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop and transcribe'));
    await tester.pumpAndSettle();
  }

  Widget app(
    Widget child,
    VoiceInputFixture providers, {
    bool enabled = true,
  }) => MaterialApp(
    home: VoiceTextInputScope(
      enabled: enabled,
      createSession: providers.session,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('dictation and explicit conversion do not edit until Apply', (
    tester,
  ) async {
    // Given a selected insertion range and an ordinary onChanged path.
    final target = TextEditingController(text: '前[置換]後')
      ..selection = const TextSelection(baseOffset: 1, extentOffset: 5);
    addTearDown(target.dispose);
    final providers = VoiceInputFixture();
    final edits = <String>[];
    await tester.pumpWidget(
      app(
        VoiceTextField(
          controller: target,
          maxLines: null,
          onChanged: edits.add,
        ),
        providers,
      ),
    );
    // When speech stops, final text appears automatically, without generating.
    await open(tester);
    await dictate(tester);
    // Then the transcript is shown without changing or generating the field text.
    expect(find.widgetWithText(TextField, 'ええと第7巻です。あと8巻も。'), findsOneWidget);
    expect(providers.generations, 0);
    expect(target.text, '前[置換]後');
    // When explicit conversion is requested.
    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle();
    // Then the field still waits for explicit Apply.
    expect(target.text, '前[置換]後');
    // When the suggestion is manually edited and explicitly applied.
    await tester.enterText(
      find.byKey(const Key('voice-cleaned-text')),
      '第7巻です。あと第8巻も。',
    );
    await tester.tap(find.text('Apply to field'));
    await tester.pumpAndSettle();
    // Then only explicit Apply replaces the selection and calls onChanged once.
    expect(target.text, '前第7巻です。あと第8巻も。後');
    expect(edits, [target.text]);
    expect(providers.audioDisposals, 1);
    expect(providers.cleanupDisposals, 1);
  });

  testWidgets(
    'retired launch callbacks respect current scope opt-out and factory replacement',
    (tester) async {
      // Given an eligible field and its retained launch action.
      final target = TextEditingController();
      addTearDown(target.dispose);
      final original = VoiceInputFixture(), replacement = VoiceInputFixture();
      final field = VoiceTextField(controller: target);
      await tester.pumpWidget(app(field, original));
      final oldLaunch = tester
          .widget<IconButton>(find.byType(IconButton))
          .onPressed!;
      // When the application disables voice input and that old action fires.
      await tester.pumpWidget(app(field, original, enabled: false));
      oldLaunch();
      await tester.pumpAndSettle();
      // Then no session or dialog is acquired despite the field remaining eligible.
      expect(original.sessions, 0);
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      // When the enabled scope changes its session factory and the old action fires.
      await tester.pumpWidget(app(field, replacement));
      oldLaunch();
      await tester.pumpAndSettle();
      // Then neither the old nor new provider is acquired by a retired action.
      expect(original.sessions, 0);
      expect(replacement.sessions, 0);
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      // When the current visible action is used.
      await open(tester);
      // Then only the current provider creates a session.
      expect(original.sessions, 0);
      expect(replacement.sessions, 1);
      // When the current dialog is canceled.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // Then the target field remains unchanged.
      expect(target.text, isEmpty);
    },
  );

  testWidgets(
    'unavailable cleanup allows explicit unconverted text and preserves single-line formatting',
    (tester) async {
      // Given an unavailable cleanup engine and a normal single-line field.
      final target = TextEditingController(text: '前');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture()..cleanupAvailable = false;
      await tester.pumpWidget(
        app(
          VoiceTextField(
            controller: target,
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
          ),
          providers,
        ),
      );
      await open(tester);
      await dictate(tester);
      await tester.enterText(
        find.byKey(const Key('voice-transcript')),
        'あ\nいうえおかき',
      );
      // When the user explicitly applies raw text.
      await tester.tap(find.text('Apply transcript'));
      await tester.pumpAndSettle();
      // Then ordinary field constraints apply, without claiming conversion.
      expect(target.text, '前あいうえ');
      expect(providers.generations, 0);
    },
  );

  testWidgets(
    'transcription has an explicit stop action and late speech cannot edit the field',
    (tester) async {
      // Given native speech is still processing after recording was stopped.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture()
        ..speechGate = Completer<AudioProviderTranscript>();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      await open(tester);
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop and transcribe'));
      await tester.pump();
      expect(find.text('Transcribing…'), findsOneWidget);
      // When the user uses the visible stop control during recognition.
      await tester.tap(find.text('Stop transcription and close'));
      await tester.pumpAndSettle();
      // Then the owned native provider is released; no late text is applied.
      expect(providers.audioDisposals, 1);
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      providers.speechGate!.complete(AudioProviderTranscript(text: '遅い認識結果'));
      await tester.pumpAndSettle();
      expect(target.text, '既存');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel during inference releases work and cannot apply a late result',
    (tester) async {
      // Given pending cleanup after a complete transcript.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture()
        ..gate = Completer<VoiceTextCleanupResult>();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      await open(tester);
      await dictate(tester);
      await tester.tap(find.text('Convert'));
      await tester.pump();
      // When Cancel retires this dialog before generation finishes.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      providers.gate!.complete(
        const VoiceTextCleanupResult(
          source: 'old',
          text: '遅い結果',
          providerId: 'controlled',
          modelName: 'controlled',
        ),
      );
      await tester.pumpAndSettle();
      // Then no calling field or later dialog receives that completion.
      expect(target.text, '既存');
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external edits invalidate Apply even when the old text is restored',
    (tester) async {
      // Given a voice dialog whose caller remains mounted.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      await open(tester);
      await dictate(tester);
      // When another edit changes and restores the original string.
      target.text = '別の編集';
      target.text = '既存';
      await tester.pumpAndSettle();
      // Then equality alone cannot revive a stale insertion target.
      expect(find.textContaining('The field changed'), findsOneWidget);
      final apply = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Apply transcript'),
      );
      expect(apply.onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(target.text, '既存');
    },
  );

  testWidgets(
    'explicit target reselection retains the dialog text and uses the new selection',
    (tester) async {
      // Given actual dialog text and a field edited by another owner action.
      final target = TextEditingController(text: '旧');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      await open(tester);
      await dictate(tester);
      target.value = const TextEditingValue(
        text: '新[範囲]後',
        selection: TextSelection(baseOffset: 1, extentOffset: 5),
      );
      await tester.pumpAndSettle();
      // When the user explicitly accepts the current target without losing speech text.
      await tester.tap(find.text('Use current field selection'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'ええと第7巻です。あと8巻も。'), findsOneWidget);
      await tester.tap(find.text('Apply transcript'));
      await tester.pumpAndSettle();
      // Then the new selection alone is replaced; the changed surrounding text survives.
      expect(target.text, '新ええと第7巻です。あと8巻も。後');
    },
  );

  testWidgets(
    'replacing a field owner closes its old dialog and releases its session',
    (tester) async {
      // Given an open field belonging to account A.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target, owner: 'A'), providers),
      );
      await open(tester);
      await dictate(tester);
      // When the same controller is rebound to account B.
      await tester.pumpWidget(
        app(VoiceTextField(controller: target, owner: 'B'), providers),
      );
      await tester.pumpAndSettle();
      // Then A's result cannot enter B's field.
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      expect(target.text, '既存');
      expect(providers.audioDisposals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'independent fields retain independent text and use fresh lifetimes',
    (tester) async {
      // Given two independent fields, one multiline.
      final first = TextEditingController(text: '一');
      final second = TextEditingController(text: '二');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              VoiceTextField(controller: first),
              VoiceTextField(controller: second, maxLines: null),
            ],
          ),
          providers,
        ),
      );
      // When dictation is applied to the first, then another dialog is canceled.
      await open(tester);
      await dictate(tester);
      await tester.tap(find.text('Apply transcript'));
      await tester.pumpAndSettle();
      final retained = first.text;
      await tester.tap(find.byTooltip('Voice input').last);
      await tester.pumpAndSettle();
      await dictate(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // Then the second field remains unchanged and both native lifetimes close.
      expect(first.text, retained);
      expect(second.text, '二');
      expect(providers.sessions, 2);
      expect(providers.audioDisposals, 2);
    },
  );

  testWidgets(
    'opt-out and secret fields hide voice; disabled and readonly cannot launch',
    (tester) async {
      // Given all four ineligible standard-field cases.
      final controllers = List.generate(4, (_) => TextEditingController());
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              VoiceTextField(controller: controllers[0], voiceInput: false),
              VoiceTextField(controller: controllers[1], obscureText: true),
              VoiceTextField(controller: controllers[2], enabled: false),
              VoiceTextField(controller: controllers[3], readOnly: true),
            ],
          ),
          providers,
        ),
      );
      // When the standard actions are inspected.
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      // Then only disabled actions remain and no provider has been created.
      expect(buttons.length, 2);
      expect(buttons.every((button) => button.onPressed == null), isTrue);
      expect(providers.sessions, 0);
      await tester.pumpWidget(
        app(
          VoiceTextField(controller: controllers[0]),
          providers,
          enabled: false,
        ),
      );
      expect(find.byTooltip('Voice input'), findsNothing);
    },
  );

  testWidgets(
    'a retained field action cannot open voice input behind another route',
    (tester) async {
      // Given an eligible field and its then-current action.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      final launch = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.mic_outlined),
          )
          .onPressed!;
      final navigator = Navigator.of(
        tester.element(find.byType(VoiceTextField)),
      );
      // When a foreign route covers the field before the old action is invoked.
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('foreign')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      launch();
      await tester.pumpAndSettle();
      // Then no microphone/provider lifetime or dialog is acquired.
      expect(providers.sessions, 0);
      expect(find.byType(VoiceTextInputDialog), findsNothing);
      expect(find.text('foreign'), findsOneWidget);
    },
  );

  testWidgets('a covered dialog rejects its retained Cancel action', (
    tester,
  ) async {
    // Given an open dialog and its own Cancel action.
    final target = TextEditingController(text: '既存');
    addTearDown(target.dispose);
    final providers = VoiceInputFixture();
    await tester.pumpWidget(app(VoiceTextField(controller: target), providers));
    final navigator = Navigator.of(tester.element(find.byType(VoiceTextField)));
    await open(tester);
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
        .onPressed!;
    // When another route covers it and the old Cancel callback runs.
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('foreign')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    cancel();
    await tester.pumpAndSettle();
    // Then the foreign route and the original dialog remain independently owned.
    expect(find.text('foreign'), findsOneWidget);
    expect(providers.audioDisposals, 0);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(target.text, '既存');
    expect(providers.audioDisposals, 1);
  });

  testWidgets(
    'an accepted Apply dismisses only its own route if cleanup overlaps another route',
    (tester) async {
      // Given an accepted Apply waiting for owned provider cleanup.
      final target = TextEditingController();
      addTearDown(target.dispose);
      final providers = VoiceInputFixture()..closeGate = Completer<void>();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      final navigator = Navigator.of(
        tester.element(find.byType(VoiceTextField)),
      );
      await open(tester);
      await dictate(tester);
      await tester.tap(find.text('Apply transcript'));
      await tester.pump();
      // When another route is pushed during native cleanup.
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('foreign')),
          ),
        ),
      );
      await tester.pump();
      providers.closeGate!.complete();
      await tester.pumpAndSettle();
      // Then the accepted field edit finishes without popping the foreign route.
      expect(find.text('foreign'), findsOneWidget);
      expect(target.text, 'ええと第7巻です。あと8巻も。');
      expect(
        find.byType(VoiceTextInputDialog, skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conversion failure preserves transcript and cannot apply an earlier suggestion',
    (tester) async {
      // Given a completed conversion followed by an edited transcript.
      final target = TextEditingController(text: '既存');
      addTearDown(target.dispose);
      final providers = VoiceInputFixture();
      await tester.pumpWidget(
        app(VoiceTextField(controller: target), providers),
      );
      await open(tester);
      await dictate(tester);
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('voice-transcript')),
        'あと7冊はありません',
      );
      providers.failure = true;
      // When the next conversion fails.
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle();
      // Then original text is retained, stale output is cleared and the caller stays untouched.
      expect(find.widgetWithText(TextField, 'あと7冊はありません'), findsOneWidget);
      expect(find.byKey(const Key('voice-error')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('voice-cleaned-text')))
            .controller!
            .text,
        isEmpty,
      );
      expect(target.text, '既存');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
}
