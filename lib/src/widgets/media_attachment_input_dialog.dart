import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/media_attachment_input.dart';

/// Records an explicitly retained attachment, separately from voice field input.
class MediaAttachmentInputDialog extends StatefulWidget {
  const MediaAttachmentInputDialog({
    required this.session,
    this.allowedAcquisitions,
    this.allowAudio = true,
    this.title = '注釈へ資料を追加',
    super.key,
  });
  final MediaAttachmentInputSession session;
  final Set<MediaAttachmentAcquisition>? allowedAcquisitions;
  final bool allowAudio;
  final String title;
  @override
  State<MediaAttachmentInputDialog> createState() =>
      _MediaAttachmentInputDialogState();
}

class _MediaAttachmentInputDialogState
    extends State<MediaAttachmentInputDialog> {
  bool _busy = false, _closing = false;
  Object? _error;
  CaptureMaterialReference? _original;
  PendingVideoCapture? _pendingVideo;
  bool _recoveryReadFailed = false;
  bool get _allowsVideo =>
      widget.allowedAcquisitions == null ||
      widget.allowedAcquisitions!.any(
        (action) =>
            action == MediaAttachmentAcquisition.captureVideo ||
            action == MediaAttachmentAcquisition.importVideo,
      );

  @override
  void initState() {
    super.initState();
    if (widget.session.recoveryTarget != null) {
      _run(() async => null, requireCurrentRoute: false);
    }
  }

  Future<void> _run(
    Future<CaptureMaterialReference?> Function() action, {
    bool requireCurrentRoute = true,
  }) async {
    if (!mounted ||
        _busy ||
        _closing ||
        (requireCurrentRoute && ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await action();
      if (mounted && !_closing && value != null) _original = value;
    } catch (error) {
      if (mounted && !_closing) _error = error;
    } finally {
      if (mounted && !_closing && widget.session.recoveryTarget != null) {
        try {
          _pendingVideo = await widget.session.pendingVideo();
          _recoveryReadFailed = false;
        } catch (error) {
          _recoveryReadFailed = true;
          _error ??= error;
        }
      }
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _finish(CaptureMaterialReference? original) async {
    final route = ModalRoute.of(context);
    if (_closing || route == null || !route.isCurrent) return;
    setState(() => _closing = true);
    try {
      await widget.session.close();
      _dismissOwn(route, original);
    } catch (error) {
      if (mounted) {
        if (original == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('資料入力の終了処理に失敗しました。注釈への追加は行っていません。')),
          );
          _dismissOwn(route, null);
          return;
        }
        setState(() {
          _error = error;
          _closing = false;
        });
      }
    }
  }

  void _dismissOwn(
    ModalRoute<dynamic> route,
    CaptureMaterialReference? original,
  ) {
    if (!mounted || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop(original);
    } else {
      route.navigator?.removeRoute(route, original);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) _finish(null);
    },
    child: AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_allowsVideo)
              const Text('撮影した動画は最大30秒、取込は64 MiBまでです。原本は端末に保存します。'),
            if (widget.allowAudio)
              const Text('対象の動作音・環境音などを最大120秒録音し、音声原本として保存します。'),
            if (_busy || _closing) const LinearProgressIndicator(),
            if (_error != null) Text('資料の追加に失敗しました: $_error'),
            if (_recoveryReadFailed)
              TextButton(
                onPressed: _busy || _closing
                    ? null
                    : () => _run(() async => null),
                child: const Text('復元状態を再確認'),
              ),
            if (_pendingVideo case final pending?) ...[
              Text('未完了の動画：${pending.label}'),
              if (pending.target == widget.session.recoveryTarget) ...[
                if (!_allowsVideo)
                  const Text('動画の復元は「動画を追加」から確認してください。')
                else if (!widget.session.canRecoverVideo(pending))
                  const Text(
                    'この端末では未保存の撮影結果を自動復元できません。復元を取り消し、再撮影または取り込みを行ってください。',
                  ),
                if (_allowsVideo)
                  TextButton(
                    onPressed:
                        _busy ||
                            _closing ||
                            !widget.session.canRecoverVideo(pending)
                        ? null
                        : () => _run(() async {
                            final result = await widget.session.recoverVideo(
                              pending.id,
                            );
                            if (result == null) {
                              throw StateError(
                                '撮影結果が見つかりません。復元を取り消すと新しく撮影できます。',
                              );
                            }
                            return result;
                          }),
                    child: const Text('中断した動画を復元'),
                  ),
                TextButton(
                  onPressed: _busy || _closing
                      ? null
                      : () => _run(() async {
                          await widget.session.discardVideo(pending.id);
                          _original = null;
                          return null;
                        }),
                  child: const Text('この動画の復元を取り消す'),
                ),
              ] else
                const Text('元の下書きと注釈を開いて復元してください。別の注釈には追加しません。'),
            ],
            if (_original != null)
              Text(
                '原本を保存しました: ${_original!.originalName ?? _original!.mediaType}',
              ),
            for (final action in MediaAttachmentAcquisition.values.where(
              (action) => widget.allowedAcquisitions?.contains(action) ?? true,
            ))
              TextButton(
                onPressed:
                    _busy ||
                        _closing ||
                        _recoveryReadFailed ||
                        _pendingVideo != null ||
                        widget.session.recording ||
                        !widget.session.canAcquire(action)
                    ? null
                    : () => _run(() => widget.session.acquire(action)),
                child: Text(switch (action) {
                  MediaAttachmentAcquisition.capturePhoto => '写真を撮る',
                  MediaAttachmentAcquisition.importPhoto => '写真を取り込む',
                  MediaAttachmentAcquisition.captureVideo => '動画を撮る',
                  MediaAttachmentAcquisition.importVideo => '動画を取り込む',
                }),
              ),
            if (widget.allowAudio)
              TextButton(
                onPressed:
                    _busy ||
                        _closing ||
                        _recoveryReadFailed ||
                        _pendingVideo != null ||
                        !widget.session.canRecordAudio
                    ? null
                    : () => _run(() async {
                        if (widget.session.recording) {
                          return widget.session.stopAudio();
                        }
                        await widget.session.startAudio();
                        return null;
                      }),
                child: Text(widget.session.recording ? '録音を停止して保存' : '対象の音を録音'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => _finish(null),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed:
              _original == null || _busy || _closing || widget.session.recording
              ? null
              : () => _finish(_original),
          child: const Text('この注釈に追加'),
        ),
      ],
    ),
  );
}
