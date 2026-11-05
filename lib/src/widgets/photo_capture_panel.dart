import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/photo_capture_controller.dart';
import 'application_text_scaling.dart';
import 'recognition_comparison_view.dart';

String _settingsReadLabel(SettingsReadState state) => switch (state) {
  SettingsReadState.notLoaded => '未読込',
  SettingsReadState.loading => '読込中',
  SettingsReadState.ready => '読込済み',
  SettingsReadState.failed => '読込失敗',
  SettingsReadState.unsupported => '利用不可',
};

String _settingsSaveLabel(SettingsSaveState state) => switch (state) {
  SettingsSaveState.idle => '待機中',
  SettingsSaveState.saving => '保存中',
  SettingsSaveState.failed => '保存失敗',
};

String _providerStateLabel(RecognitionProviderState state) => switch (state) {
  RecognitionProviderState.available => '利用可能',
  RecognitionProviderState.unavailable => '利用不可',
  RecognitionProviderState.downloadable => 'ダウンロード可能',
  RecognitionProviderState.preparing => '準備中',
};

String _configurationLabel(RecognitionConfiguration configuration) {
  if (configuration.id == RecognitionSettings.androidStandard &&
      configuration.label == 'Standard Android') {
    return '標準認識';
  }
  if (configuration.id == RecognitionSettings.pixelEnhanced &&
      configuration.label == 'Pixel enhanced') {
    return '端末内AIで補完（対応端末）';
  }
  return configuration.label;
}

/// Embeddable interaction UI borrowing a controller initialized by its owner.
/// It neither starts restoration on mount nor owns any service lifetime.
class PhotoCapturePanel extends StatefulWidget {
  /// Borrows the owner controller and optional operation-result callback.
  const PhotoCapturePanel({
    required this.controller,
    this.onComparison,
    this.interactionAllowed,
    super.key,
  });

  /// Controller identity guards every asynchronous completion.
  final PhotoCaptureController controller;

  /// Captured at operation start so a rebuild cannot redirect the result.
  final ValueChanged<RecognitionComparison>? onComparison;

  /// Borrowed pure caller admission, reevaluated before every user command.
  /// Null preserves controller rules; false or evaluation failure denies entry.
  /// Accepted work settles without transferring or cancelling borrowed lifetime.
  final bool Function()? interactionAllowed;

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
    int generation,
    Future<Object?> Function() command, {
    bool reportResult = false,
    String? preparingProvider,
  }) async {
    // Given the render-time owner and generation of this user command.
    // When invoked, deny before local preparation state or controller effects.
    if (!_allows(controller, generation)) {
      return;
    }
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
      // Given preparation was admitted before any later policy suspension.
      // When it settles, require its original live owner and generation.
      if (mounted &&
          generation == _generation &&
          identical(widget.controller, controller) &&
          preparingProvider != null) {
        // Then clear accepted preparation state even after later user denial.
        setState(() => _preparingProvider = null);
      }
    }
    // Then the same live start-time owner receives durable accepted completion,
    // independently of later denial of new user commands.
    if (reportResult &&
        result is RecognitionComparison &&
        mounted &&
        generation == _generation &&
        identical(widget.controller, controller)) {
      onComparison?.call(result);
    }
  }

  bool _allows(PhotoCaptureController controller, int generation) {
    // Given an action captured during rendering, ownership may have retired.
    // When admission is requested, reject stale identity/generation first.
    if (!mounted ||
        generation != _generation ||
        !identical(controller, widget.controller)) {
      return false;
    }
    try {
      // Then only the current caller's pure policy admits user interaction.
      return widget.interactionAllowed?.call() ?? true;
    } catch (_) {
      // Then evaluation failure denies settings, camera and provider effects.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      // Given this render's borrowed owner, retain its generation in all actions.
      final generation = _generation;
      // When pure admission determines enabled presentation, no commands start.
      final interactionAllowed = _allows(controller, generation);
      final snapshot = controller.settings.snapshot;
      final ready = snapshot.readState == SettingsReadState.ready;
      final enabled = ready && !controller.busy;
      final report = controller.comparison;
      Widget button(
        String id,
        String label,
        Future<Object?> Function() action, {
        bool allowed = true,
        bool reportResult = false,
      }) => ElevatedButton(
        key: ValueKey('photo-capture-$id'),
        // Then bind this owner/generation to _run, which rechecks current
        // admission when the user invokes the callback.
        onPressed: !controller.busy && allowed && interactionAllowed
            ? () => _run(
                controller,
                generation,
                action,
                reportResult: reportResult,
              )
            : null,
        child: Text(label),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('希望する認識構成'),
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
                    child: Text(
                      _configurationLabel(
                        controller.configurations.firstWhere(
                          (configuration) => configuration.id == choice.value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            onChanged: controller.busy || !interactionAllowed
                ? null
                : (id) {
                    // Given configuration intent was rendered for this owner.
                    // When the dropdown callback arrives, reevaluate admission first.
                    if (!_allows(controller, generation)) {
                      return;
                    }
                    // Then only an admitted non-null intent reaches common settings.
                    if (id != null) {
                      controller.selectConfiguration(id);
                    }
                  },
          ),
          Text('設定の読込: ${_settingsReadLabel(snapshot.readState)}'),
          if (snapshot.readError != null) const Text('設定を読み込めませんでした。'),
          if (snapshot.readState == SettingsReadState.notLoaded ||
              snapshot.readState == SettingsReadState.failed ||
              snapshot.readState == SettingsReadState.unsupported)
            button('retry-load', '設定の読込を再試行', controller.retrySettingsLoad),
          Text('設定の保存: ${_settingsSaveLabel(snapshot.saveState)}'),
          Text(snapshot.hasUnsavedChanges ? '未保存の設定があります' : '設定は保存済みです'),
          if (snapshot.saveError != null) const Text('設定を保存できませんでした。'),
          if (snapshot.hasUnsavedChanges ||
              snapshot.saveState == SettingsSaveState.failed)
            button('retry-save', '設定の保存を再試行', controller.retrySettingsSave),
          if (!controller.isSupported) const Text('この端末では撮影を利用できません'),
          for (final provider in controller.availability) ...[
            Text(
              '認識処理 ${provider.providerId}: ${_providerStateLabel(provider.state)}',
            ),
            if (provider.modelName != null)
              Text('利用モデル: ${provider.modelName}'),
            if (provider.reason != null) Text('理由: ${provider.reason}'),
            if (provider.state == RecognitionProviderState.preparing)
              Text('利用準備中 ${provider.providerId}'),
            if (provider.state == RecognitionProviderState.downloadable)
              ElevatedButton(
                key: ValueKey('photo-capture-prepare-${provider.providerId}'),
                onPressed: controller.busy || !interactionAllowed
                    ? null
                    : () => _run(
                        controller,
                        generation,
                        () => controller.prepareProvider(provider.providerId),
                        preparingProvider: provider.providerId,
                      ),
                child: Text('利用準備 ${provider.providerId}'),
              ),
          ],
          if (_preparingProvider != null) Text('利用準備中 $_preparingProvider'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              button('refresh', '利用可否を再確認', controller.refreshAvailability),
              button(
                'capture',
                '撮影',
                controller.capture,
                allowed: enabled && controller.isSupported,
                reportResult: true,
              ),
              button(
                'recover',
                '撮影結果を復元',
                controller.recover,
                allowed: enabled && controller.isSupported,
                reportResult: true,
              ),
              button(
                'recognize',
                '保存済み画像を読み取る',
                controller.recognizeCurrent,
                allowed: enabled && report != null,
                reportResult: true,
              ),
              button(
                'compare',
                '同じ画像の認識結果を比較',
                controller.compareCurrent,
                allowed: enabled && report != null,
                reportResult: true,
              ),
            ],
          ),
          if (controller.busy) const Text('撮影・認識の処理中です'),
          if (controller.error != null) const Text('撮影・認識の処理を完了できませんでした。'),
          if (report != null) RecognitionComparisonView(comparison: report),
        ],
      );
      final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
      return scaler == null
          ? content
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: content,
            );
    },
  );
}
