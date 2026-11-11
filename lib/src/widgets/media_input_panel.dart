import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Common explicit input controls. Core owns support/permission observations;
/// the caller owns Book association, retained originals and submission intent.
class MediaInputPanel extends StatefulWidget {
  const MediaInputPanel({
    required this.service,
    required this.onImageConfirmed,
    this.onRecord,
    this.onPlay,
    this.enabled = true,
    this.onPendingChanged,
    this.controller,
    super.key,
  });
  final MediaInputService service;
  final Future<void> Function(CapturedPhoto photo) onImageConfirmed;
  final Future<void> Function()? onRecord;
  final Future<void> Function()? onPlay;
  final bool enabled;
  final ValueChanged<bool>? onPendingChanged;
  final MediaInputPanelController? controller;
  @override
  State<MediaInputPanel> createState() => _MediaInputPanelState();
}

class _MediaInputPanelState extends State<MediaInputPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  CapturedPhoto? _preview;
  Uint8List? _previewBytes;
  bool _attaching = false;
  bool _decoded = false;
  bool _decodeFailed = false;
  String? _message;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MediaInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_changed);
      widget.service.addListener(_changed);
      _generation++;
      _attaching = false;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }
  void _discard() {
    if (_attaching || widget.service.busy) return;
    setState(() { _preview=null; _previewBytes=null; });
    _pending();
  }

  void _pending() => widget.onPendingChanged?.call(
    _preview != null || _attaching || widget.service.busy,
  );
  Future<void> _acquire(bool camera) async {
    if (_attaching || widget.service.busy || !widget.enabled) return;
    final generation = _generation;
    setState(() => _message = null);
    final work = camera
        ? widget.service.captureImage()
        : widget.service.importImage();
    _pending();
    try {
      final image = await work;
      if (!mounted || generation != _generation) return;
      if (image != null) {
        setState(() {
          _preview = image;
          _previewBytes = image.bytes;
          _decoded = false;
          _decodeFailed = false;
        });
      }
    } on MediaInputException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _message = _mediaFailure(error.failure));
      }
    } finally {
      if (mounted && generation == _generation) _pending();
    }
  }

  Future<bool> _confirm() async {
    final image = _preview;
    if (image == null ||
        !_decoded ||
        _decodeFailed ||
        _attaching ||
        !widget.enabled) {
      return false;
    }
    final generation = _generation;
    setState(() {
      _attaching = true;
      _message = null;
    });
    _pending();
    try {
      await widget.onImageConfirmed(image);
      if (mounted && generation == _generation && identical(_preview, image)) {
        setState(() {
          _preview = null;
          _previewBytes = null;
        });
      }
      return mounted && generation == _generation;
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _message = '画像を添付できませんでした。プレビューと編集中の内容は保持しています。');
      }
      return false;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _attaching = false);
        _pending();
      }
    }
  }

  Future<void> _other(Future<void> Function()? action) async {
    if (action == null || !widget.enabled || _attaching || widget.service.busy) {
      return;
    }
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _message = '操作を完了できませんでした。編集中の内容は保持しています。');
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.controller?._detach(this);
    widget.service.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locked =
        !widget.enabled ||
        widget.service.busy ||
        _attaching ||
        widget.service.isClosed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in MediaInputAction.values)
              _action(action, locked),
          ],
        ),
        for (final action in MediaInputAction.values)
          if (!widget.service.capability(action).canAttempt ||
              (action == MediaInputAction.audioRecording &&
                  widget.onRecord == null) ||
              (action == MediaInputAction.audioPlayback &&
                  widget.onPlay == null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_mediaLabel(action)}: ${_mediaReason(widget.service.capability(action), callbackMissing: (action == MediaInputAction.audioRecording && widget.onRecord == null) || (action == MediaInputAction.audioPlayback && widget.onPlay == null))}',
              ),
            ),
        TextButton(
          onPressed: locked
              ? null
              : () => unawaited(
                  widget.service.inspect().catchError((Object _) {
                    if (mounted) setState(() => _message = '利用状態を確認できませんでした。');
                  }),
                ),
          child: const Text('利用状態を再確認'),
        ),
        if (widget.service.busy || _attaching) const LinearProgressIndicator(),
        if (_message != null)
          Text(_message!, key: const ValueKey('media-input-message')),
        if (_preview case final image?) ...[
          const Text('画像のプレビュー', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('選択しただけでは添付・送信されません。'),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.memory(
              _previewBytes!,
              key: ObjectKey(image),
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, synchronous) {
                if ((frame != null || synchronous) && !_decoded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && identical(_preview, image)) {
                      setState(() => _decoded = true);
                    }
                  });
                }
                return child;
              },
              errorBuilder: (_, _, _) {
                if (!_decodeFailed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && identical(_preview, image)) {
                      setState(() => _decodeFailed = true);
                    }
                  });
                }
                return const Text('この画像を表示できません。別のJPEG・PNG・WebP画像を選択してください。');
              },
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: locked || !_decoded || _decodeFailed
                    ? null
                    : () => unawaited(_confirm().then<void>((_) {})),
                child: const Text('この画像を添付'),
              ),
              TextButton(
                onPressed: locked
                    ? null
                    : () {
                        setState(() {
                          _preview = null;
                          _previewBytes = null;
                        });
                        _pending();
                      },
                child: const Text('画像の選択を取り消す'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _action(MediaInputAction action, bool locked) {
    final cap = widget.service.capability(action);
    final callbackMissing =
        (action == MediaInputAction.audioRecording &&
            widget.onRecord == null) ||
        (action == MediaInputAction.audioPlayback && widget.onPlay == null);
    final VoidCallback? invoke = locked || !cap.canAttempt || callbackMissing
        ? null
        : () {
            switch (action) {
              case MediaInputAction.imageImport:
                unawaited(_acquire(false));
              case MediaInputAction.cameraCapture:
                unawaited(_acquire(true));
              case MediaInputAction.audioRecording:
                unawaited(_other(widget.onRecord));
              case MediaInputAction.audioPlayback:
                unawaited(_other(widget.onPlay));
            }
          };
    final label = cap.needsConfirmation
        ? '利用を確認して${_mediaLabel(action)}'
        : _mediaLabel(action);
    return action == MediaInputAction.imageImport
        ? FilledButton(onPressed: invoke, child: Text(label))
        : OutlinedButton(onPressed: invoke, child: Text(label));
  }
}

/// Borrows only temporary preview disposition; never owns media/provider/domain state.
final class MediaInputPanelController {
  _MediaInputPanelState? _state;
  void _attach(_MediaInputPanelState state) {
    if (_state != null && _state != state) {
      throw StateError('Media preview controller already attached');
    }
    _state = state;
  }

  void _detach(_MediaInputPanelState state) {
    if (identical(_state, state)) _state = null;
  }

  bool get hasSelection => _state?._preview != null;
  Future<bool> confirmSelection() async => await _state?._confirm() ?? true;
  void discardSelection() {
    _state?._discard();
  }
}

String _mediaLabel(MediaInputAction action) => switch (action) {
  MediaInputAction.imageImport => '画像を取り込む',
  MediaInputAction.cameraCapture => '撮影する',
  MediaInputAction.audioRecording => '録音する',
  MediaInputAction.audioPlayback => '再生する',
};
String _mediaReason(MediaInputCapability cap, {bool callbackMissing = false}) {
  if (cap.support == MediaAdapterSupport.unsupported || callbackMissing) {
    return 'この構成では対応していません。';
  }
  if (cap.busy) return '現在使用中です。';
  if (cap.device == MediaDeviceAvailability.absent) return '利用できる機器がありません。';
  return switch (cap.permission) {
    MediaPermissionState.denied => 'アクセスが許可されていません。端末・ブラウザの設定を確認してください。',
    MediaPermissionState.policyBlocked => '実行環境の設定で利用が制限されています。',
    _ => '利用状態を確認してください。',
  };
}

String _mediaFailure(MediaInputFailure failure) => switch (failure) {
  MediaInputFailure.permissionDenied => 'アクセスが許可されませんでした。画像取込みと編集は引き続き利用できます。',
  MediaInputFailure.policyBlocked => '実行環境の設定で利用が制限されています。',
  MediaInputFailure.invalidImage => 'JPEG・PNG・WebPの画像を選択してください。',
  MediaInputFailure.tooLarge => '画像が大きすぎます。16MB以下の画像を選択してください。',
  MediaInputFailure.busy => '処理が終わってから操作してください。',
  MediaInputFailure.retired => '入力操作は終了しています。',
  MediaInputFailure.unsupported => 'この構成では利用できません。',
  MediaInputFailure.unavailable => '入力を完了できませんでした。編集中の内容は保持しています。',
};
