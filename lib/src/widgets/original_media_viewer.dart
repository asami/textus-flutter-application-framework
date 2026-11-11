import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:video_player/video_player.dart';

/// Reads only the explicitly selected original; never accepts an external URL.
class OriginalMediaViewer extends StatefulWidget {
  const OriginalMediaViewer({
    required this.original,
    required this.readOriginal,
    super.key,
  });
  final CaptureMaterialReference original;
  final Future<Uint8List> Function(CaptureMaterialReference) readOriginal;
  @override
  State<OriginalMediaViewer> createState() => _OriginalMediaViewerState();
}

class _OriginalMediaViewerState extends State<OriginalMediaViewer>
    with WidgetsBindingObserver {
  Uint8List? _image;
  LocalMediaPlayback? _playback;
  Object? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final token = ++_generation;
    try {
      if (widget.original.byteLength > 67108864) {
        throw const FormatException(
          'Original exceeds the 64 MiB playback limit',
        );
      }
      final bytes = await widget.readOriginal(widget.original);
      if (!mounted || token != _generation) return;
      if (bytes.length != widget.original.byteLength) {
        throw const FormatException('Original byte length mismatch');
      }
      if (widget.original.mediaType.startsWith('image/')) {
        setState(() => _image = bytes);
      } else {
        final handle = await LocalMediaPlayback.open(
          bytes,
          widget.original.mediaType,
        );
        if (!mounted || token != _generation) {
          await handle.close();
          return;
        }
        setState(() => _playback = handle);
      }
    } catch (error) {
      if (mounted && token == _generation) setState(() => _error = error);
    }
  }

  @override
  void didUpdateWidget(OriginalMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.original != widget.original ||
        oldWidget.readOriginal != widget.readOriginal) {
      final handle = _playback;
      _playback = null;
      _image = null;
      _error = null;
      if (handle != null) unawaited(_close(handle));
      unawaited(_open());
    }
  }

  Future<void> _close(LocalMediaPlayback handle) async {
    try {
      await handle.close();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'textus media playback cleanup',
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playback != null) {
      unawaited(_pause());
    }
  }

  Future<void> _pause() async {
    final token = _generation;
    try {
      await _playback?.controller.pause();
    } catch (error) {
      if (mounted && token == _generation) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    if (_playback case final handle?) unawaited(_close(handle));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text('原本を表示・再生できません: $_error');
    if (_image case final bytes?) {
      return Image.memory(
        bytes,
        cacheWidth: 1280,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('この画像の形式は表示できません'),
      );
    }
    final controller = _playback?.controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.hasError) Text('再生エラー: ${value.errorDescription}'),
          if (widget.original.mediaType.startsWith('video/'))
            Flexible(
              fit: FlexFit.loose,
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          Text('${value.position.inSeconds} / ${value.duration.inSeconds} 秒'),
          IconButton(
            tooltip: value.isPlaying ? '一時停止' : '再生',
            onPressed: value.hasError
                ? null
                : () async {
                    if (!mounted ||
                        !identical(_playback?.controller, controller)) {
                      return;
                    }
                    try {
                      if (value.isPlaying) {
                        await controller.pause();
                      } else {
                        if (value.position >= value.duration) {
                          await controller.seekTo(Duration.zero);
                        }
                        if (!mounted ||
                            !identical(_playback?.controller, controller)) {
                          return;
                        }
                        await controller.play();
                      }
                    } catch (error) {
                      if (mounted &&
                          identical(_playback?.controller, controller)) {
                        setState(() => _error = error);
                      }
                    }
                  },
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
