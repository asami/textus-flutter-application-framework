import 'dart:async';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../display/display_definition_registry.dart';
import '../display/display_presentation_controller.dart';
import '../view/resource_list_detail_display_model.dart';
import 'application_text_scaling.dart';
import 'application_text_toolbar.dart';

/// Generic adaptive Display UI borrowing its controller and inherited Settings.
class DisplaySessionView extends StatefulWidget {
  DisplaySessionView({
    required this.controller,
    this.compactBreakpoint = 700,
    this.autoLoad = true,
    super.key,
  }) {
    if (!compactBreakpoint.isFinite || compactBreakpoint <= 0) {
      throw ArgumentError.value(compactBreakpoint, 'compactBreakpoint');
    }
  }
  final DisplayPresentationController controller;
  final double compactBreakpoint;
  final bool autoLoad;
  @override
  State<DisplaySessionView> createState() => DisplaySessionViewState();
}

/// Retains scoped editor controllers across adaptive pane changes.
class DisplaySessionViewState extends State<DisplaySessionView> {
  final Set<DisplaySession> scheduledSessions = Set.identity();
  final Map<DisplayFieldLocator, TextEditingController> textControllers = {};
  (String, int)? editorIdentity;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  @override
  void didUpdateWidget(DisplaySessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
      clearTextControllers();
    }
  }

  void changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void clearTextControllers() {
    for (final controller in textControllers.values) {
      controller.dispose();
    }
    textControllers.clear();
    editorIdentity = null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    clearTextControllers();
    super.dispose();
  }

  bool current(
    DisplayPresentationController controller, [
    DisplaySession? session,
  ]) =>
      mounted &&
      identical(widget.controller, controller) &&
      !controller.isDisposed &&
      (session == null || identical(controller.session, session));
  void autoLoad() {
    final controller = widget.controller;
    final session = controller.session;
    final core = session.state;
    if (!widget.autoLoad ||
        controller.isDisposed ||
        core.busy ||
        controller.state.busy ||
        core.list.phase != DisplaySessionReadPhase.idle ||
        core.detail.phase != DisplaySessionReadPhase.idle ||
        core.command.sequence != 0 ||
        core.selectedResourceId != null ||
        !scheduledSessions.add(session)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!current(controller) ||
          !widget.autoLoad ||
          !identical(controller.session, session)) {
        return;
      }
      final latest = session.state;
      if (!controller.state.busy &&
          latest.list.phase == DisplaySessionReadPhase.idle &&
          latest.detail.phase == DisplaySessionReadPhase.idle &&
          latest.command.sequence == 0 &&
          latest.selectedResourceId == null) {
        unawaited(controller.load());
      }
    });
  }

  String chrome(String english, String japanese) {
    final locales = widget.controller.state.session.context.families.where(
      (family) => family.namespace == 'textus.presentation.locale',
    );
    final payload = locales.isEmpty ? null : locales.single.payload;
    return payload is LocalePresentationPayload &&
            payload.localeTag.toLowerCase().split('-').first == 'ja'
        ? japanese
        : english;
  }

  VoidCallback? callback(
    DisplayPresentationController controller,
    bool enabled,
    void Function() action,
  ) {
    final session = controller.session;
    return enabled
        ? () {
            if (current(controller, session)) {
              action();
            }
          }
        : null;
  }

  Widget button(
    String key,
    String english,
    String japanese,
    bool enabled,
    void Function() action,
  ) {
    final controller = widget.controller;
    return TextButton(
      key: ValueKey(key),
      onPressed: callback(controller, enabled, action),
      child: Text(chrome(english, japanese)),
    );
  }

  Future<void> selectResource(
    DisplayPresentationController controller,
    String id,
  ) async {
    final session = controller.session;
    if (!current(controller, session)) {
      return;
    }
    final outcome = await controller.select(id);
    if (!mounted ||
        !current(controller, session) ||
        outcome != DisplayNavigationOutcome.discardRequired) {
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chrome('Discard draft?', '下書きを破棄しますか？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(chrome('Keep draft', '下書きを保持')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(chrome('Discard', '破棄')),
          ),
        ],
      ),
    );
    if (discard == true &&
        current(controller, session) &&
        !controller.state.busy) {
      await controller.select(id, discardDraft: true);
    }
  }

  void syncEditors(DisplayDraft? draft) {
    final identity = draft == null
        ? null
        : (draft.resourceId, draft.generation);
    if (identity != editorIdentity) {
      clearTextControllers();
      editorIdentity = identity;
    }
    if (draft == null) {
      return;
    }
    for (final entry in draft.values.entries) {
      final value = entry.value;
      if (value is TextDisplayValue) {
        final controller = textControllers.putIfAbsent(
          entry.key,
          () => TextEditingController(text: value.value),
        );
        if (controller.text != value.value) {
          controller.value = TextEditingValue(
            text: value.value,
            selection: TextSelection.collapsed(offset: value.value.length),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    autoLoad();
    final controller = widget.controller;
    final state = controller.state;
    syncEditors(state.draft);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final presentation = controller.displayModel.resolve(
            splitCapable: constraints.maxWidth >= widget.compactBreakpoint,
            hasSelection: state.session.selectedResourceId != null,
          );
          final title =
              state.session.list.data?.model.title ?? chrome('Display', '表示');
          final appBar =
              ApplicationTextScaling.maybeTextScalerOf(context) == null
              ? AppBar(title: Text(title))
              : applicationTextAppBar(
                  context,
                  title: title,
                  width: constraints.maxWidth,
                );
          final showList =
              presentation == ResourceListDetailPresentation.compactList ||
              presentation == ResourceListDetailPresentation.split;
          final showDetail =
              !showList || presentation == ResourceListDetailPresentation.split;
          return Scaffold(
            appBar: appBar,
            body: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .32,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: status(state),
                    ),
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: state.displayedDefinition == null
                        ? null
                        : ValueKey((
                            'display-style',
                            state.displayedDefinition!.style.name,
                          )),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showList) Expanded(child: listPane(state)),
                        if (showList && showDetail)
                          const VerticalDivider(width: 1),
                        if (showDetail) Expanded(child: detailPane(state)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget status(DisplayPresentationState state) {
    final controller = widget.controller;
    final core = state.session;
    final command = core.command;
    final receipt = command.mutation;
    final operation = command.operation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.busy) Text(chrome('Loading', '読み込み中')),
        if (state.resolution.failure != null)
          Text(
            state.resolution.failure!.message,
            key: const ValueKey('display-definition-failure'),
          ),
        if (core.contextFailure != null)
          Text('Context: ${core.contextFailure!.message}'),
        for (final diagnostic in core.diagnostics)
          Text('${diagnostic.namespace}: ${diagnostic.message}'),
        if (receipt != null)
          Text(
            '${command.kind!.name}: ${receipt.outcome.name}; commit ${receipt.committedRevision ?? '—'}; current ${receipt.currentRevision ?? '—'}',
          ),
        if (operation != null)
          Text(
            'operation: ${operation.outcome.name}; commit ${operation.committedRevision ?? '—'}; current ${operation.currentRevision ?? '—'}',
          ),
        if (command.failure != null)
          Text('Command: ${command.failure!.message}'),
        if (core.projectionPending)
          Text(
            chrome('Projection pending', '表示の更新待ち'),
            key: const ValueKey('display-projection-pending'),
          ),
        if (core.commandUncertain)
          Text(
            chrome('Outcome unknown', '結果不明'),
            key: const ValueKey('display-command-uncertain'),
          ),
        if (core.list.failure != null)
          Text('List: ${core.list.failure!.message}'),
        if (core.detail.failure != null)
          Text('Detail: ${core.detail.failure!.message}'),
        for (final error in state.fieldErrors.where(
          (error) => error.locator == null,
        ))
          Text(error.message),
        Wrap(
          children: [
            button(
              'display-reload',
              'Reload',
              '再読み込み',
              !state.busy,
              () => unawaited(controller.reload()),
            ),
            if (core.list.phase == DisplaySessionReadPhase.failed ||
                core.list.phase == DisplaySessionReadPhase.idle)
              button(
                'display-retry-list',
                'Retry list',
                '一覧を再試行',
                !state.busy,
                () => unawaited(controller.retryList()),
              ),
            if (core.detail.phase == DisplaySessionReadPhase.failed &&
                core.selectedResourceId != null)
              button(
                'display-retry-detail',
                'Retry detail',
                '詳細を再試行',
                !state.busy,
                () => unawaited(controller.retryDetail()),
              ),
            button(
              'display-back',
              'Back to list',
              '一覧へ',
              true,
              controller.showList,
            ),
            button(
              'display-focus',
              'Focus detail',
              '詳細に集中',
              core.selectedResourceId != null,
              controller.focusDetail,
            ),
            button(
              'display-split',
              'Restore split',
              '分割表示',
              true,
              controller.restoreSplit,
            ),
            button(
              'display-create',
              'Create',
              '作成',
              !state.busy &&
                  state.resolution.isAvailable &&
                  core.canCreate &&
                  state.draft == null,
              () => unawaited(controller.createUnsupported()),
            ),
          ],
        ),
      ],
    );
  }

  Widget listPane(DisplayPresentationState state) {
    final data = state.displayedDefinition == null
        ? null
        : state.session.list.data;
    final controller = widget.controller;
    return ListView(
      key: const ValueKey('display-list'),
      padding: const EdgeInsets.all(8),
      children: [
        if (data != null)
          ...data.model.items.map((row) {
            final label = row.fields
                .map((field) => '${field.label}: ${readValue(field.value)}')
                .join('\n');
            final enabled =
                !state.busy &&
                (!state.session.projectionPending &&
                        !state.session.commandUncertain &&
                        state.session.contextFailure == null ||
                    row.resourceId == state.session.selectedResourceId);
            final tap = callback(
              controller,
              enabled,
              () => unawaited(selectResource(controller, row.resourceId)),
            );
            final key = ValueKey(('display-resource', row.resourceId));
            final tile = ListTile(
              key: key,
              title: Text(label),
              selected: state.session.selectedResourceId == row.resourceId,
              onTap: tap,
            );
            return switch (state.displayedDefinition?.style) {
              DisplayDefinitionStyle.cards => Card(child: tile),
              DisplayDefinitionStyle.sections => ExpansionTile(
                key: key,
                title: Text(label),
                children: [
                  TextButton(
                    onPressed: tap,
                    child: Text(chrome('Open detail', '詳細を開く')),
                  ),
                ],
              ),
              _ => tile,
            };
          }),
      ],
    );
  }

  Widget detailPane(DisplayPresentationState state) {
    final data = state.displayedDefinition == null
        ? null
        : state.session.detail.data;
    final controller = widget.controller;
    return ListView(
      key: const ValueKey('display-detail'),
      padding: const EdgeInsets.all(8),
      children: [
        if (data != null) ...[
          Text(data.model.title, style: Theme.of(context).textTheme.titleLarge),
          Text(
            '${data.resourceId}; revision ${data.sourceRevision}; ${data.provenance.producerId}; ${data.provenance.sourceId}; ${data.provenance.revision}',
          ),
          for (final section in data.model.sections)
            sectionView(state, data, section),
          if (state.draft != null)
            const SizedBox(key: ValueKey('display-editor')),
          Wrap(
            children: [
              TextButton(
                onPressed: callback(
                  controller,
                  state.canEdit && state.draft == null,
                  controller.beginEdit,
                ),
                child: Text(chrome('Edit', '編集')),
              ),
              button(
                'display-save',
                'Save',
                '保存',
                state.canSave,
                () => unawaited(controller.save()),
              ),
              button(
                'display-cancel',
                'Cancel / Discard',
                '取消 / 破棄',
                state.draft != null && !state.busy,
                controller.discardDraft,
              ),
              button(
                'display-reconcile',
                'Discard and edit current',
                '破棄して現在値を編集',
                state.draft != null && state.canEdit,
                controller.discardAndEdit,
              ),
              button(
                'display-delete',
                'Delete',
                '削除',
                state.canOperate,
                () => unawaited(controller.deleteUnsupported()),
              ),
              for (final action in data.model.actions)
                TextButton(
                  key: ValueKey(('display-operation', action.id)),
                  onPressed: callback(
                    controller,
                    state.canOperate && action.enabled,
                    () => unawaited(controller.executeOperation(action.id)),
                  ),
                  child: Text(action.label),
                ),
            ],
          ),
        ] else
          Text(chrome('Select a resource', '資料を選択')),
      ],
    );
  }

  Widget sectionView(
    DisplayPresentationState state,
    DisplayDetailData data,
    DisplaySection section,
  ) {
    final fields = section.fields
        .map((field) => fieldView(state, data, section.id, field))
        .toList();
    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text(section.id), ...fields],
    );
    return switch (state.displayedDefinition?.style) {
      DisplayDefinitionStyle.cards => Card(
        child: Padding(padding: const EdgeInsets.all(8), child: group),
      ),
      DisplayDefinitionStyle.sections => ExpansionTile(
        title: Text(section.id),
        initiallyExpanded: true,
        children: fields,
      ),
      _ => group,
    };
  }

  Widget fieldView(
    DisplayPresentationState state,
    DisplayDetailData data,
    String sectionId,
    DisplayField field,
  ) {
    final locator = DisplayFieldLocator(
      screenId: data.model.screenId,
      sectionId: sectionId,
      fieldId: field.id,
    );
    final draft = state.draft;
    final errors = state.fieldErrors
        .where((error) => error.locator == locator)
        .map((error) => error.message)
        .join('\n');
    final editor = textControllers[locator];
    final controller = widget.controller;
    final session = controller.session;
    if (draft != null && draft.values.containsKey(locator)) {
      if (draft.values[locator] is! TextDisplayValue) {
        return ListTile(
          title: Text(field.label),
          subtitle: Text(errors.isEmpty ? 'invalid-type' : errors),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          key: ValueKey((
            'display-field',
            locator.screenId,
            locator.sectionId,
            locator.fieldId,
          )),
          controller: editor,
          enabled: state.canSave,
          maxLines: null,
          decoration: InputDecoration(
            labelText: field.label,
            errorText: errors.isEmpty ? null : errors,
          ),
          onChanged: (text) {
            if (current(controller, session) && controller.state.canSave) {
              controller.setValue(locator, TextDisplayValue(text));
            }
          },
        ),
      );
    }
    return ListTile(
      title: Text(field.label),
      subtitle: Text(readValue(field.value)),
    );
  }
}

String readValue(DisplayValue value) => switch (value) {
  TextDisplayValue() => value.value,
  NumberDisplayValue() => value.value.toString(),
  BoolDisplayValue() => value.value ? 'true' : 'false',
  TimestampDisplayValue() => value.value.toIso8601String(),
  MissingDisplayValue() => '—',
};
