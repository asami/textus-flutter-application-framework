import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/photo_capture_controller.dart';
import 'application_text_scaling.dart';
import 'recognition_comparison_view.dart';

/// Embeddable interaction UI borrowing a controller initialized by its owner.
/// It neither starts restoration on mount nor owns any service lifetime.
class PhotoCapturePanel extends StatefulWidget {
  /// Borrows the owner controller and optional operation-result callback.
  const PhotoCapturePanel({required this.controller, this.onComparison, super.key});

  /// Controller identity guards every asynchronous completion.
  final PhotoCaptureController controller;
  /// Captured at operation start so a rebuild cannot redirect the result.
  final ValueChanged<RecognitionComparison>? onComparison;

  @override
  State<PhotoCapturePanel> createState() => _PhotoCapturePanelState();
}

class _PhotoCapturePanelState extends State<PhotoCapturePanel> {
  int _generation = 0;
  String? _preparingProvider;

  @override
  void didUpdateWidget(PhotoCapturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _generation++;
      _preparingProvider = null;
    }
  }

  Future<void> _run(
    PhotoCaptureController controller,
    Future<Object?> Function() command, {
    bool reportResult = false,
    String? preparingProvider,
  }) async {
    final generation = _generation;
    final onComparison = widget.onComparison;
    if (preparingProvider != null) {
      setState(() => _preparingProvider = preparingProvider);
    }
    Object? result;
    try {
      result = await command();
    } catch (_) {
      // The controller records the actual operation failure for presentation.
      return;
    } finally {
      if (mounted && generation == _generation &&
          identical(widget.controller, controller) && preparingProvider != null) {
        setState(() => _preparingProvider = null);
      }
    }
    if (reportResult && result is RecognitionComparison && mounted &&
        generation == _generation && identical(widget.controller, controller)) {
      onComparison?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final snapshot = controller.settings.snapshot;
      final ready = snapshot.readState == SettingsReadState.ready;
      final enabled = ready && !controller.busy;
      final report = controller.comparison;
      Widget button(String id, String label, Future<Object?> Function() action, {
        bool allowed = true, bool reportResult = false,
      }) => ElevatedButton(
        key: ValueKey('photo-capture-$id'),
        onPressed: !controller.busy && allowed
            ? () => _run(controller, action, reportResult: reportResult) : null,
        child: Text(label),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Desired recognition configuration'),
          DropdownButton<String>(
            key: const ValueKey('photo-capture-configuration'),
            value: controller.desiredConfigurationId,
            isExpanded: true,
            itemHeight: null,
            items: [
              for (final choice in RecognitionSettings.configuration.choices)
                DropdownMenuItem(
                  value: choice.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(controller.configurations.firstWhere(
                      (configuration) => configuration.id == choice.value,
                    ).label),
                  ),
                ),
            ],
            onChanged: controller.busy ? null : (id) {
              if (id != null) controller.selectConfiguration(id);
            },
          ),
          Text('Settings read: ${snapshot.readState.name}'),
          if (snapshot.readError != null) Text('Settings read error: ${snapshot.readError}'),
          if (snapshot.readState == SettingsReadState.notLoaded ||
              snapshot.readState == SettingsReadState.failed ||
              snapshot.readState == SettingsReadState.unsupported)
            button('retry-load', 'Retry settings load', controller.retrySettingsLoad),
          Text('Settings save: ${snapshot.saveState.name}'),
          Text(snapshot.hasUnsavedChanges ? 'Settings unsaved' : 'No unsaved settings'),
          if (snapshot.saveError != null) Text('Settings save error: ${snapshot.saveError}'),
          if (snapshot.hasUnsavedChanges || snapshot.saveState == SettingsSaveState.failed)
            button('retry-save', 'Retry settings save', controller.retrySettingsSave),
          if (!controller.isSupported) const Text('Camera acquisition unsupported'),
          for (final provider in controller.availability) ...[
            Text('Provider ${provider.providerId}: ${provider.state.name}'),
            if (provider.modelName != null) Text('Model: ${provider.modelName}'),
            if (provider.reason != null) Text('Reason: ${provider.reason}'),
            if (provider.state == RecognitionProviderState.preparing)
              Text('Preparing ${provider.providerId}'),
            if (provider.state == RecognitionProviderState.downloadable)
              ElevatedButton(
                key: ValueKey('photo-capture-prepare-${provider.providerId}'),
                onPressed: controller.busy ? null : () => _run(
                  controller, () => controller.prepareProvider(provider.providerId),
                  preparingProvider: provider.providerId,
                ),
                child: Text('Prepare ${provider.providerId}'),
              ),
          ],
          if (_preparingProvider != null) Text('Preparing $_preparingProvider'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              button('refresh', 'Refresh availability', controller.refreshAvailability),
              button('capture', 'Capture', controller.capture,
                allowed: enabled && controller.isSupported, reportResult: true),
              button('recover', 'Recover capture', controller.recover,
                allowed: enabled && controller.isSupported, reportResult: true),
              button('recognize', 'Recognize saved image', controller.recognizeCurrent,
                allowed: enabled && report != null, reportResult: true),
              button('compare', 'Compare same image', controller.compareCurrent,
                allowed: enabled && report != null, reportResult: true),
            ],
          ),
          if (controller.busy) const Text('Photo operation in progress'),
          if (controller.error != null) Text('Photo operation error: ${controller.error}'),
          if (report != null) RecognitionComparisonView(comparison: report),
        ],
      );
      final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
      return scaler == null ? content : MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler), child: content,
      );
    },
  );
}
