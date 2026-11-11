import 'dart:async';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/resource_list_detail_configuration.dart';
import '../display/cncf_display_mutation_controller.dart';
import '../display/cncf_display_presentation_registry.dart';
import '../resource/resource_view_model.dart';
import '../view/resource_list_detail_display_model.dart';
import 'resource_list_detail.dart';
import 'voice_text_field.dart';

String _displayText(BuildContext context, String english, String japanese) =>
    Localizations.localeOf(context).languageCode == 'ja' ? japanese : english;

/// Adds shared Text editing and trusted ordinary Business to standard List/Detail.
class CncfDisplayResourceView extends StatefulWidget {
  const CncfDisplayResourceView({
    required this.configuration,
    required this.viewModel,
    required this.mutationController,
    this.displayModel,
    this.presentationRegistry,
    super.key,
  });
  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;
  final CncfDisplayMutationController mutationController;
  final ResourceListDetailDisplayModel? displayModel;
  final CncfDisplayPresentationRegistry? presentationRegistry;

  @override
  State<CncfDisplayResourceView> createState() =>
      _CncfDisplayResourceViewState();
}

class _CncfDisplayResourceViewState extends State<CncfDisplayResourceView> {
  int _session = 0;
  bool _routeOpen = false;
  MaterialPageRoute<void>? _editorRoute;
  ResourceListDetailConfiguration? _lastAvailableConfiguration;

  @override
  void initState() {
    super.initState();
    widget.mutationController.addListener(_changed);
    widget.viewModel.addListener(_changed);
  }

  @override
  void didUpdateWidget(CncfDisplayResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentationRegistry != widget.presentationRegistry ||
        oldWidget.configuration != widget.configuration ||
        oldWidget.mutationController != widget.mutationController ||
        oldWidget.viewModel != widget.viewModel) {
      _lastAvailableConfiguration = null;
    }
    if (oldWidget.mutationController != widget.mutationController ||
        oldWidget.viewModel != widget.viewModel) {
      ++_session;
      _routeOpen = false;
      _retireRoute();
    }
    if (oldWidget.mutationController != widget.mutationController) {
      oldWidget.mutationController.removeListener(_changed);
      widget.mutationController.addListener(_changed);
    }
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_changed);
      widget.viewModel.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ++_session;
    _retireRoute();
    widget.mutationController.removeListener(_changed);
    widget.viewModel.removeListener(_changed);
    super.dispose();
  }

  void _retireRoute() {
    final route = _editorRoute;
    _editorRoute = null;
    if (route == null) {
      return;
    }
    // Retirement may occur during a sibling build, and the opener may unmount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) {
        route.changedExternalState();
      }
    });
  }

  CncfDisplayPresentationResolution? get _presentationResolution => widget
      .presentationRegistry
      ?.resolve(widget.mutationController.source.lastDisplay);

  bool get _presentationAvailable =>
      _presentationResolution?.isAvailable ?? true;

  bool _allowsBusiness(CncfDisplayBusinessBinding binding) {
    final resolution = _presentationResolution;
    if (resolution != null && !resolution.isAvailable) return false;
    final configuration = resolution?.configuration ?? widget.configuration;
    final actions = configuration.detailActions;
    return actions == null ||
        actions.any((action) => action.id == binding.actionId);
  }

  void _edit(
    CncfDisplayMutationController controller,
    ResourceViewModel viewModel,
    int session,
  ) {
    if (!mounted ||
        session != _session ||
        !identical(widget.mutationController, controller) ||
        !identical(widget.viewModel, viewModel) ||
        !identical(viewModel, controller.viewModel) ||
        !_presentationAvailable ||
        _routeOpen ||
        controller.busy ||
        controller.isDisposed ||
        controller.needsReconciliation ||
        controller.editorOpen) {
      return;
    }
    final editorSession = ++_session;
    _routeOpen = true;
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _Editor(
        controller: controller,
        isCurrent: () =>
            mounted &&
            editorSession == _session &&
            identical(widget.mutationController, controller),
      ),
    );
    _editorRoute = route;
    // Pushing first protects selection before the Editor starts descriptor I/O.
    unawaited(
      Navigator.of(context).push(route).then((_) {
        if (identical(_editorRoute, route)) {
          _editorRoute = null;
          if (mounted && editorSession == _session) {
            setState(() {
              _routeOpen = false;
            });
          }
        }
      }),
    );
  }

  Future<void> _executeBusiness(
    CncfDisplayMutationController controller,
    CncfDisplayBusinessBinding binding,
    int session,
  ) async {
    if (!mounted ||
        session != _session ||
        !identical(widget.mutationController, controller) ||
        !identical(widget.viewModel, controller.viewModel) ||
        controller.isDisposed ||
        !_allowsBusiness(binding)) {
      return;
    }
    final accepted = await controller.executeBusiness(binding);
    if (!accepted ||
        !mounted ||
        session != _session ||
        !identical(widget.mutationController, controller) ||
        !identical(widget.viewModel, controller.viewModel) ||
        controller.isDisposed) {
      return;
    }
    await controller.reload();
  }

  Future<void> _reloadPresentation(
    CncfDisplayMutationController controller,
    ResourceViewModel viewModel,
    int session,
  ) async {
    if (!mounted ||
        session != _session ||
        !identical(widget.mutationController, controller) ||
        !identical(widget.viewModel, viewModel) ||
        !identical(viewModel, controller.viewModel) ||
        controller.isDisposed ||
        controller.busy ||
        viewModel.listLoading ||
        viewModel.detailLoading) {
      return;
    }
    if (controller.needsReconciliation) {
      await controller.reload();
    } else {
      await viewModel.load();
    }
  }

  List<Widget> _businessButtons(
    CncfDisplayMutationController controller,
    ResourceListDetailConfiguration configuration,
    bool available,
    int session,
  ) {
    final configured = configuration.detailActions;
    return [
      for (final binding in controller.businessBindings)
        if (controller.businessAvailability(binding) case final availability?)
          if (availability != 'hidden' &&
              (configured == null ||
                  configured.any((action) => action.id == binding.actionId)))
            TextButton(
              key: Key('cncf-display-business-${binding.actionId}'),
              onPressed: available && controller.canInvokeBusiness(binding)
                  ? () => _executeBusiness(controller, binding, session)
                  : null,
              child: Text(
                configured == null
                    ? ((controller.source.lastDetail!.model['actions']! as List)
                              .cast<Map>()
                              .singleWhere(
                                (action) =>
                                    action['id'] == binding.actionId &&
                                    action['bindingId'] == binding.bindingId,
                              )['label']
                          as String)
                    : configured
                          .firstWhere((action) => action.id == binding.actionId)
                          .label,
              ),
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.mutationController;
    final viewModel = widget.viewModel;
    final session = _session;
    final resolution = _presentationResolution;
    final available = resolution?.isAvailable ?? true;
    if (available) {
      _lastAvailableConfiguration =
          resolution?.configuration ?? widget.configuration;
    }
    // This retained configuration only keeps the common State mounted beneath
    // an opaque unavailable surface; it never substitutes a visible variant.
    final configuration =
        _lastAvailableConfiguration ??
        widget.presentationRegistry?.neutralConfiguration ??
        widget.configuration;
    final running = controller.businessRunning && !controller.isDisposed;
    return PopScope<Object?>(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop ||
            !mounted ||
            ModalRoute.of(context)?.isCurrent != true ||
            !identical(widget.mutationController, controller) ||
            !controller.isDisposed ||
            !controller.businessRunning) {
          return;
        }
        // Disposal emits no notifier. Only an explicit Back on this current
        // route retires stale busy UI, and a root route must remain visible.
        setState(() {});
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(
            absorbing: running || !available,
            child: ExcludeSemantics(
              excluding: !available,
              child: ExcludeFocus(
                excluding: !available,
                // The existing compact Back scope must not change presentation
                // while the outer command owner protects this route.
                child: TickerMode(
                  enabled: !running,
                  child: ResourceListDetail(
                    configuration: configuration,
                    viewModel: widget.viewModel,
                    displayModel: widget.displayModel,
                    detailSupplementBuilder: (_, record) => Column(
                      children: [
                        _Result(controller: controller),
                        ..._businessButtons(
                          controller,
                          configuration,
                          available,
                          session,
                        ),
                        TextButton(
                          key: const Key('cncf-display-edit'),
                          onPressed:
                              !available ||
                                  controller.busy ||
                                  controller.isDisposed ||
                                  controller.needsReconciliation ||
                                  controller.editorOpen ||
                                  _routeOpen
                              ? null
                              : () => _edit(controller, viewModel, session),
                          child: Text(_displayText(context, 'Edit', '編集')),
                        ),
                      ],
                    ),
                    additionalActions: [
                      if ((controller.businessOperation != null ||
                              controller.receipt != null) &&
                          widget.viewModel.detailFailed)
                        SizedBox(
                          width: 260,
                          child: FittedBox(
                            child: _Result(controller: controller),
                          ),
                        ),
                      if (controller.needsReconciliation)
                        IconButton(
                          key: const Key('cncf-display-reload'),
                          tooltip: _displayText(context, 'Reload', '再読込'),
                          onPressed: controller.busy || controller.isDisposed
                              ? null
                              : controller.reload,
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!available)
            Positioned.fill(
              child: BlockSemantics(
                child: Material(
                  color: Theme.of(context).colorScheme.surface.withAlpha(255),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayText(
                            context,
                            'This screen configuration is unavailable.',
                            'この画面は現在利用できません。',
                          ),
                        ),
                        TextButton(
                          key: const Key('cncf-display-presentation-reload'),
                          onPressed:
                              controller.busy ||
                                  controller.isDisposed ||
                                  viewModel.listLoading ||
                                  viewModel.detailLoading
                              ? null
                              : () => _reloadPresentation(
                                  controller,
                                  viewModel,
                                  session,
                                ),
                          child: Text(_displayText(context, 'Reload', '再読込')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (running)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                key: Key('cncf-display-business-progress'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.controller});
  final CncfDisplayMutationController controller;

  String? get _affectedResource {
    final observed = controller.observation;
    if (observed == null || observed.resources.length != 1) return null;
    final id = observed.resources.single.entityId;
    for (final field in observed.resources.single.fields) {
      final value = field['value'];
      if (field['role'] == 'title' && value is Map && value['type'] == 'text') {
        final text = value['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final business = controller.businessOperation != null;
    final receipt = business ? null : controller.receipt;
    final businessReceipt = business ? controller.businessReceipt : null;
    final failure = controller.failure?.failure;
    final affected = _affectedResource;
    final mismatch =
        business &&
        controller.needsReconciliation &&
        controller.viewModel.selectedId !=
            controller.observation?.resources.single.entityId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (businessReceipt != null)
          Text(
            _displayText(
              context,
              'Committed ${businessReceipt.outcome}, revision ${businessReceipt.revision}',
              '受付済み ${businessReceipt.outcome}、更新番号 ${businessReceipt.revision}',
            ),
          ),
        if (business && affected != null)
          Text(
            _displayText(
              context,
              'Affected resource: $affected',
              '対象の資料: $affected',
            ),
          ),
        if (mismatch)
          Text(
            _displayText(
              context,
              'Select the affected resource before Reload.',
              '対象の資料を選んでから再読込してください。',
            ),
          ),
        if (receipt != null)
          Text(
            _displayText(
              context,
              'Committed ${receipt.outcome}, revision ${receipt.revision}',
              '受付済み ${receipt.outcome}、更新番号 ${receipt.revision}',
            ),
          ),
        if (controller.needsReconciliation)
          Text(
            _displayText(
              context,
              business
                  ? 'Reload required. Do not repeat the command.'
                  : 'Reload required. Do not repeat Save.',
              business
                  ? '再読込が必要です。同じ操作を繰り返さないでください。'
                  : '再読込が必要です。保存を繰り返さないでください。',
            ),
          ),
        if (!business &&
            controller.needsReconciliation &&
            receipt?.reloadRequired == true)
          Text(
            _displayText(
              context,
              'Committed; projection pending',
              '受付済み（表示への反映待ち）',
            ),
          ),
        if (controller.failure != null)
          Text(
            _displayText(
              context,
              !business && failure?.isEditableRejection == true
                  ? 'Check the marked value.'
                  : failure?.isConflict == true
                  ? 'The resource changed. Reload required.'
                  : 'Could not complete the operation.',
              !business && failure?.isEditableRejection == true
                  ? '入力内容を確認してください。'
                  : failure?.isConflict == true
                  ? '資料が変更されました。再読込してください。'
                  : '操作を完了できませんでした。',
            ),
          ),
      ],
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.controller, required this.isCurrent});
  final CncfDisplayMutationController controller;
  final bool Function() isCurrent;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _texts = <CncfDisplayFieldLocator, TextEditingController>{};
  bool _confirming = false;
  bool _allowPop = false;
  bool get _active =>
      mounted && widget.isCurrent() && !widget.controller.isDisposed;
  bool get _currentRoute =>
      mounted && ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active) {
        unawaited(widget.controller.beginEdit());
      }
    });
  }

  void _changed() {
    if (!_active) {
      return;
    }
    for (final entry in widget.controller.draftValues.entries) {
      _texts.putIfAbsent(
        entry.key,
        () => TextEditingController(text: entry.value),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    for (final text in _texts.values) {
      text.dispose();
    }
    super.dispose();
  }

  void _pop() {
    if (!_currentRoute || (_active && widget.controller.busy)) {
      return;
    }
    setState(() {
      _allowPop = true;
    });
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    final controller = widget.controller;
    if (!_currentRoute) {
      return;
    }
    if (!_active) {
      _pop();
      return;
    }
    if (controller.busy || _confirming) {
      return;
    }
    final dirty = controller.draftValues.entries.any(
      (entry) => controller.initialValues[entry.key] != entry.value,
    );
    if (dirty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_displayText(context, 'Discard changes?', '変更を破棄しますか？')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_displayText(context, 'Keep editing', '編集を続ける')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_displayText(context, 'Discard', '破棄')),
            ),
          ],
        ),
      );
      _confirming = false;
      if (!_active || discard != true || controller.busy) {
        return;
      }
    }
    controller.discard();
    _pop();
  }

  Future<void> _save() async {
    if (!_active) {
      return;
    }
    final closed = await widget.controller.save();
    if (_active && closed) {
      _pop();
    }
  }

  Future<void> _reload() async {
    if (!_active) {
      return;
    }
    final closed = await widget.controller.reload();
    if (_active && closed) {
      _pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final descriptor = controller.descriptor;
    final fields = <CncfDisplayFieldLocator, Map<String, Object?>>{};
    final observation = controller.observation;
    if (observation != null) {
      for (final section in observation.model['sections']! as List) {
        final map = section as Map<String, Object?>;
        for (final item in map['fields']! as List) {
          final field = item as Map<String, Object?>;
          fields[CncfDisplayFieldLocator(
                map['id']! as String,
                field['id']! as String,
              )] =
              field;
        }
      }
    }
    return PopScope(
      canPop: _allowPop && (!_active || !controller.busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_cancel());
        }
      },
      child: Scaffold(
        key: const Key('cncf-display-editor'),
        appBar: AppBar(
          title: Text(_displayText(context, 'Edit', '編集')),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              key: const Key('cncf-display-cancel'),
              onPressed: _active && controller.busy ? null : _cancel,
              child: Text(_displayText(context, 'Cancel', 'キャンセル')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_active && controller.busy) const LinearProgressIndicator(),
            _Result(controller: controller),
            if (descriptor != null)
              for (final field in descriptor.fields)
                if (fields.containsKey(field.locator))
                  _field(field, fields[field.locator]!),
            FilledButton(
              key: const Key('cncf-display-save'),
              onPressed: _active && controller.canSave ? _save : null,
              child: Text(_displayText(context, 'Save', '保存')),
            ),
            if (controller.needsReconciliation)
              TextButton(
                key: const Key('cncf-display-reload'),
                onPressed: controller.busy || !_active ? null : _reload,
                child: Text(_displayText(context, 'Reload', '再読込')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(CncfDisplayMutationField field, Map<String, Object?> read) {
    final controller = widget.controller;
    final label = read['label']! as String;
    final text = _texts[field.locator];
    if (text == null) {
      final value = read['value']! as Map<String, Object?>;
      return ListTile(
        title: Text(label),
        subtitle: Text(
          value['type'] == 'text' ? value['text']! as String : '—',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: VoiceTextField(
        key: ValueKey(('voice-cncf-display', field.locator)),
        owner: controller,
        textFieldKey: ValueKey((
          'cncf-display-field',
          field.locator.sectionId,
          field.locator.fieldId,
        )),
        controller: text,
        maxLines: null,
        enabled: _active && controller.canSave,
        decoration: InputDecoration(
          labelText: field.web['required'] == true ? '$label *' : label,
          hintText: field.web['placeholder'] as String?,
          helperText: field.web['help'] as String?,
          errorText: controller.fieldErrors[field.locator],
        ),
        onChanged: (value) {
          if (_active) {
            controller.setText(field.locator, value);
          }
        },
      ),
    );
  }
}
