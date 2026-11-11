import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/audio_capture_controller.dart';
import 'application_text_scaling.dart';

/// Embeddable audio controls borrowing an explicitly managed controller.
class AudioCapturePanel extends StatefulWidget {
  /// Mounting performs no provider work and claims no controller lifetime.
  const AudioCapturePanel({
    required this.controller,
    this.onReviewChanged,
    this.interactionAllowed,
    super.key,
  });

  /// One original's caller-owned interaction.
  final AudioCaptureController controller;

  /// Receives durable stop/retry or recognition success from the start-time owner.
  final ValueChanged<AudioTranscriptReview>? onReviewChanged;

  /// Borrowed pure caller admission, evaluated again at each user command.
  /// Null preserves controller rules; false or a thrown evaluation denies entry.
  /// Already admitted work still settles under its original owner fences.
  final bool Function()? interactionAllowed;

  @override
  State<AudioCapturePanel> createState() => _AudioCapturePanelState();
}

class _AudioCapturePanelState extends State<AudioCapturePanel> {
  int _generation = 0;

  @override
  void didUpdateWidget(AudioCapturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _generation++;
    }
  }

  bool _allows(AudioCaptureController controller, int generation) {
    // Given a callback's render-time owner and generation.
    // When entry is requested, reject stale or terminal ownership before policy.
    if (!mounted ||
        generation != _generation ||
        !identical(controller, widget.controller) ||
        controller.isDetached ||
        controller.isDisposed) {
      return false;
    }
    try {
      // Then only the current pure caller policy can admit this user command.
      return widget.interactionAllowed?.call() ?? true;
    } catch (_) {
      // Then a policy failure denies entry without launching controller work.
      return false;
    }
  }

  Future<void> _run(
    AudioCaptureController controller,
    int generation,
    Future<Object?> Function() action, {
    bool report = false,
  }) async {
    // Given the owner captured when this action was rendered.
    // When user intent arrives, check live admission before any action effects.
    if (!_allows(controller, generation)) {
      return;
    }
    final callback = widget.onReviewChanged;
    Object? result;
    try {
      result = await action();
    } catch (_) {
      return;
    } // Controller retains the actual failure for presentation.
    // Then accepted work publishes only to its original live owner, even if
    // the caller temporarily denies further user commands during settlement.
    if (report &&
        result is AudioTranscriptReview &&
        mounted &&
        generation == _generation &&
        identical(widget.controller, controller) &&
        !controller.isDetached &&
        !controller.isDisposed) {
      callback?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      // Given this render's borrowed owner, callbacks retain its generation.
      final generation = _generation;
      // When pure admission is evaluated for enabled presentation, no IO starts.
      final interactionAllowed = _allows(controller, generation);
      final original = controller.review?.original;
      Widget button(
        String suffix,
        String label,
        Future<Object?> Function() action,
        bool allowed, {
        bool report = false,
      }) => ElevatedButton(
        key: ValueKey('audio-capture-$suffix'),
        // Then bind this owner/generation to _run, which rechecks current
        // admission when the user invokes the callback.
        onPressed: allowed && interactionAllowed
            ? () => _run(controller, generation, action, report: report)
            : null,
        child: Text(label),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('音声'),
          if (!controller.facade.isSupported)
            const Text('この端末では録音を利用できません'),
          if (controller.state == AudioCaptureState.recording)
            Text('録音中: ${controller.elapsedSeconds}秒'),
          if (controller.state == AudioCaptureState.saving)
            const Text('音声を保存しています'),
          if (controller.state == AudioCaptureState.preparing)
            const Text('文字起こしの準備を確認しています'),
          if (controller.state == AudioCaptureState.transcribing)
            const Text('文字起こし中'),
          if (controller.state == AudioCaptureState.playing)
            const Text('音声を再生しています'),
          if (controller.facade.pendingOriginal != null)
            const Text('音声が未保存です'),
          if (original != null)
            Text(
              '保存済み音声: ${original.durationMilliseconds / 1000}秒',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (original == null && controller.facade.pendingOriginal == null)
                button(
                  'record',
                  '録音する',
                  controller.startRecording,
                  controller.canStartRecording,
                ),
              if (controller.state == AudioCaptureState.recording) ...[
                button(
                  'stop',
                  '録音を停止',
                  controller.stopRecording,
                  controller.canStopRecording,
                  report: true,
                ),
                button(
                  'cancel',
                  '録音を取り消す',
                  controller.cancelRecording,
                  controller.canCancelRecording,
                ),
              ],
              if (controller.facade.pendingOriginal != null)
                button(
                  'retry-save',
                  '保存を再試行',
                  controller.retryPendingOriginal,
                  controller.canRetryPendingOriginal,
                  report: true,
                ),
              if (original != null) ...[
                button(
                  'play',
                  '再生',
                  controller.playOriginal,
                  controller.canPlayOriginal,
                ),
                if (controller.state == AudioCaptureState.playing)
                  button(
                    'stop-playback',
                    '再生を停止',
                    controller.stopPlayback,
                    controller.canStopPlayback,
                  ),
                button(
                  'transcribe',
                  '文字起こし',
                  controller.transcribe,
                  controller.canTranscribe,
                  report: true,
                ),
              ],
              button(
                'check-transcription',
                '文字起こしの利用可否を確認',
                controller.refreshAvailability,
                !controller.isDetached &&
                    !controller.busy &&
                    controller.state == AudioCaptureState.idle &&
                    controller.facade.pendingOriginal == null,
              ),
              if (controller.availability?.state ==
                  AudioProviderState.downloadable)
                button(
                  'prepare-model',
                  '文字起こしを準備',
                  controller.prepareTranscription,
                  controller.canPrepareTranscription,
                ),
              if (controller.canCancelTranscription)
                button(
                  'cancel-transcription',
                  '文字起こしを取り消す',
                  controller.cancelTranscription,
                  true,
                ),
            ],
          ),
          if (controller.availability != null) ...[
            Text('文字起こし: ${controller.availability!.state.name}'),
            if (controller.availability!.reason != null)
              Text(controller.availability!.reason!),
          ],
          if (controller.error != null)
            Text('音声エラー: ${controller.error}'),
          ExpansionTile(
            key: const ValueKey('audio-capture-details'),
            title: const Text('音声の詳細'),
            children: [
              if (original != null) Text('音声原本: ${original.material.id}'),
              if (controller.availability != null)
                Text(
                  '認識処理: ${controller.availability!.providerId}; 言語: ${controller.availability!.locale}',
                ),
            ],
          ),
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
