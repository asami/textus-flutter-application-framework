import 'dart:async';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/resource_list_detail_configuration.dart';
import '../display/cncf_display_mutation_controller.dart';
import '../resource/resource_view_model.dart';
import '../view/resource_list_detail_display_model.dart';
import 'resource_list_detail.dart';

/// Adds the common modal Editor to the existing standard List/Detail.
class CncfDisplayResourceView extends StatefulWidget {
  const CncfDisplayResourceView({
    required this.configuration,
    required this.viewModel,
    required this.mutationController,
    this.displayModel,
    super.key,
  });
  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;
  final CncfDisplayMutationController mutationController;
  final ResourceListDetailDisplayModel? displayModel;

  @override
  State<CncfDisplayResourceView> createState() =>
      _CncfDisplayResourceViewState();
}

class _CncfDisplayResourceViewState extends State<CncfDisplayResourceView> {
  int _session = 0;
  bool _routeOpen = false;
  MaterialPageRoute<void>? _editorRoute;

  @override
  void initState() {
    super.initState();
    widget.mutationController.addListener(_changed);
  }

  @override
  void didUpdateWidget(CncfDisplayResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  void _edit() {
    final controller = widget.mutationController;
    if (_routeOpen ||
        controller.busy ||
        controller.isDisposed ||
        controller.needsReconciliation ||
        controller.editorOpen) {
      return;
    }
    final session = ++_session;
    _routeOpen = true;
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _Editor(
        controller: controller,
        isCurrent: () =>
            mounted &&
            session == _session &&
            identical(widget.mutationController, controller),
      ),
    );
    _editorRoute = route;
    // Pushing first protects selection before the Editor starts descriptor I/O.
    unawaited(
      Navigator.of(context).push(route).then((_) {
        if (identical(_editorRoute, route)) {
          _editorRoute = null;
          if (mounted && session == _session) {
            setState(() {
              _routeOpen = false;
            });
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.mutationController;
    return ResourceListDetail(
      configuration: widget.configuration,
      viewModel: widget.viewModel,
      displayModel: widget.displayModel,
      detailSupplementBuilder: (_, record) => Column(
        children: [
          _Result(controller: controller),
          TextButton(
            key: const Key('cncf-display-edit'),
            onPressed:
                controller.busy ||
                    controller.isDisposed ||
                    controller.needsReconciliation ||
                    controller.editorOpen ||
                    _routeOpen
                ? null
                : _edit,
            child: const Text('Edit'),
          ),
        ],
      ),
      // Keep reconciliation reachable even when the existing Detail shows failure.
      additionalActions: [
        if (controller.receipt != null && widget.viewModel.detailFailed)
          Center(
            child: Text(
              'Committed ${controller.receipt!.outcome}, revision ${controller.receipt!.revision}',
            ),
          ),
        if (controller.needsReconciliation)
          IconButton(
            key: const Key('cncf-display-reload'),
            tooltip: 'Reload',
            onPressed: controller.busy || controller.isDisposed
                ? null
                : controller.reload,
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.controller});
  final CncfDisplayMutationController controller;
  @override
  Widget build(BuildContext context) {
    final receipt = controller.receipt;
    final failure = controller.failure?.failure;
    return Column(
      children: [
        if (receipt != null)
          Text('Committed ${receipt.outcome}, revision ${receipt.revision}'),
        if (controller.needsReconciliation)
          const Text('Reload required. Do not repeat Save.'),
        if (controller.needsReconciliation && receipt?.reloadRequired == true)
          const Text('Committed; projection pending'),
        if (controller.failure != null)
          Text(
            failure?.isEditableRejection == true
                ? 'Check the marked value.'
                : failure?.isConflict == true
                ? 'The resource changed. Reload required.'
                : 'Could not complete the operation.',
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
          title: const Text('Discard changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
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
          title: const Text('Edit'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              key: const Key('cncf-display-cancel'),
              onPressed: _active && controller.busy ? null : _cancel,
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            ),
            if (controller.needsReconciliation)
              TextButton(
                key: const Key('cncf-display-reload'),
                onPressed: controller.busy || !_active ? null : _reload,
                child: const Text('Reload'),
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
      child: TextField(
        key: ValueKey((
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
