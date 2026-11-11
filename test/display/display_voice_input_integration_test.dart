import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../support/cncf_display_mutation_fixture.dart' as cncf;
import '../support/display_presentation_fixture.dart' as generic;
import '../support/voice_input_fixture.dart';

const titleText = '音声入力から確認した書名';
const descriptionText = '別の音声入力から確認した説明';
const configuration = ResourceListDetailConfiguration(
  listTitle: 'Collecting Resources',
  detailTitle: 'Capture Detail',
  primaryField: 'title',
  secondaryField: 'stage',
  detailFields: [
    ResourceFieldConfiguration(key: 'title', label: 'Title'),
    ResourceFieldConfiguration(key: 'stage', label: 'Capture stage'),
    ResourceFieldConfiguration(key: 'description', label: 'Description'),
  ],
);

Widget voiceApp(Widget view, VoiceInputFixture providers) => MaterialApp(
  builder: (_, navigator) =>
      VoiceTextInputScope(createSession: providers.session, child: navigator!),
  home: view,
);

void largeViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1100, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> applyReviewedVoice(
  WidgetTester tester,
  Key fieldKey,
  String reviewed,
  void Function() beforeApply,
) async {
  // Given the exact standard field and a selected replacement range.
  final field = find.byKey(fieldKey);
  await tester.ensureVisible(field);
  final editor = tester.widget<TextField>(field).controller!;
  final initial = editor.text;
  editor.selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  final voice = find.ancestor(of: field, matching: find.byType(VoiceTextField));
  final microphone = find.descendant(
    of: voice,
    matching: find.byTooltip('Voice input'),
  );
  expect(microphone, findsOneWidget);
  // When the actual common action records, transcribes and explicitly converts.
  await tester.tap(microphone);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start speaking'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Stop and transcribe'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Convert'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('voice-cleaned-text')), reviewed);
  // Then review edits remain a proposal, without changing the field or source.
  expect(editor.text, initial);
  beforeApply();
  // When Apply is explicitly selected.
  await tester.tap(find.text('Apply to field'));
  await tester.pumpAndSettle();
  // Then only this field receives the review and its dialog closes.
  expect(editor.text, reviewed);
  expect(find.byType(VoiceTextInputDialog), findsNothing);
}

void main() {
  testWidgets(
    'CNCF standard fields apply independently and update only on Save',
    (tester) async {
      // Given the actual CNCF List/Detail/editor with controlled local HTTP and voice.
      largeViewport(tester);
      final f = cncf.CncfDisplayMutationFixture();
      final providers = VoiceInputFixture();
      addTearDown(() async {
        f.releaseAll();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        f.dispose();
      });
      final initial = Map<String, String>.from(f.values);
      await tester.pumpWidget(
        voiceApp(
          CncfDisplayResourceView(
            configuration: configuration,
            viewModel: f.viewModel,
            mutationController: f.controller,
          ),
          providers,
        ),
      );
      await tester.pumpAndSettle();
      // When the selected resource is opened in its editor.
      await tester.tap(find.text('日本の民話'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cncf-display-edit')));
      await tester.pumpAndSettle();
      // Then both writable fields offer voice by default; readonly stage has no editor.
      expect(find.byTooltip('Voice input'), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('収集中'), findsOneWidget);
      const title = ValueKey(('cncf-display-field', 'main', 'title'));
      const description = ValueKey((
        'cncf-display-field',
        'main',
        'description',
      ));
      // When the first field is converted, reviewed and applied.
      await applyReviewedVoice(tester, title, titleText, () {
        expect(f.values, initial);
        expect(f.puts, isEmpty);
      });
      // Then only its draft changes and no HTTP write has occurred.
      expect(f.controller.draftValues[cncf.mutationTitle], titleText);
      expect(
        tester.widget<TextField>(find.byKey(description)).controller!.text,
        initial['description'],
      );
      expect(f.values, initial);
      expect(f.puts, isEmpty);
      // When the second independent field is applied.
      await applyReviewedVoice(tester, description, descriptionText, () {
        expect(f.controller.draftValues[cncf.mutationTitle], titleText);
        expect(f.values, initial);
        expect(f.puts, isEmpty);
      });
      // Then both drafts retain their independent text without changing the source.
      expect(
        f.controller.draftValues[cncf.mutationDescription],
        descriptionText,
      );
      expect(f.controller.draftValues[cncf.mutationTitle], titleText);
      expect(f.values, initial);
      expect(f.puts, isEmpty);
      // When ordinary Save is explicitly pressed.
      final save = find.byKey(const Key('cncf-display-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // Then exactly one HTTP update persists both values.
      expect(f.puts, hasLength(1));
      expect(f.values['title'], titleText);
      expect(f.values['description'], descriptionText);
      expect(providers.sessions, 2);
      expect(providers.generations, 2);
      expect(providers.audioDisposals, 2);
      expect(providers.cleanupDisposals, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic Display standard fields keep voice Apply separate from Save',
    (tester) async {
      // Given the actual generic view, Core session/source and independent voice lifetimes.
      largeViewport(tester);
      final f = generic.PresentationFixture();
      final providers = VoiceInputFixture();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        f.dispose();
      });
      await tester.pumpWidget(
        voiceApp(DisplaySessionView(controller: f.controller), providers),
      );
      await tester.pumpAndSettle();
      // When the selected generic resource is opened in its editor.
      await tester.tap(
        find.byKey(const ValueKey(('display-resource', 'doc:1'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // Then writable fields have default voice actions; stage remains readonly.
      expect(find.byTooltip('Voice input'), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Collecting'), findsOneWidget);
      const title = ValueKey(('display-field', 'detail', 'main', 'title'));
      const description = ValueKey((
        'display-field',
        'detail',
        'main',
        'description',
      ));
      final originalDescription = tester
          .widget<TextField>(find.byKey(description))
          .controller!
          .text;
      void sourceUnchanged() {
        expect(f.source.resources.first.sourceRevision, 1);
        expect(f.port.requests.whereType<DisplayUpdateRequest>(), isEmpty);
        expect(f.session.state.command.sequence, 0);
      }

      // When one field is applied.
      await applyReviewedVoice(tester, title, titleText, sourceUnchanged);
      // Then only its draft changes and the source receives no command.
      expect(
        f.controller.state.draft!.values[generic.locator('title')],
        const TextDisplayValue(titleText),
      );
      expect(
        tester.widget<TextField>(find.byKey(description)).controller!.text,
        originalDescription,
      );
      sourceUnchanged();
      // When the other field is applied.
      await applyReviewedVoice(
        tester,
        description,
        descriptionText,
        sourceUnchanged,
      );
      // Then both independent draft values survive without a source command.
      expect(
        f.controller.state.draft!.values[generic.locator('description')],
        const TextDisplayValue(descriptionText),
      );
      expect(
        f.controller.state.draft!.values[generic.locator('title')],
        const TextDisplayValue(titleText),
      );
      sourceUnchanged();
      // When ordinary Save runs.
      await generic.tapKey(tester, 'display-save');
      // Then one session update advances the source revision and retains both values.
      expect(f.port.requests.whereType<DisplayUpdateRequest>(), hasLength(1));
      expect(f.source.resources.first.sourceRevision, 2);
      expect(find.text(titleText), findsWidgets);
      expect(find.text(descriptionText), findsWidgets);
      expect(providers.sessions, 2);
      expect(providers.generations, 2);
      expect(providers.audioDisposals, 2);
      expect(providers.cleanupDisposals, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
