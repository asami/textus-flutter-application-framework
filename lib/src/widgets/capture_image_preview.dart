import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Displays a detached snapshot of an immutable original with bounded decoding.
///
/// The caller owns the source lifecycle and supplies already validated bytes.
/// This widget performs no acquisition, storage IO or recognition work and never
/// disposes the borrowed owner. Flutter owns active decoder and frame lifetimes.
class CaptureImagePreview extends StatefulWidget {
  /// Reads synchronously once per available owner/material identity.
  const CaptureImagePreview({
    required this.materialId,
    required this.sourceIdentity,
    required this.readBytes,
    this.imageKey,
    this.errorBuilder,
    this.semanticLabel,
    this.maxDecodeDimension = 2048,
    super.key,
  }) : assert(maxDecodeDimension > 0);

  /// Immutable original token, compared by value within the borrowed owner.
  final String materialId;

  /// Borrowed opaque owner token, compared with [identical].
  final Object sourceIdentity;

  /// Returns validated encoded bytes, or null until available on a later update.
  /// Callback replacement alone does not invalidate a successful snapshot.
  /// Synchronous failures propagate to the caller's Flutter error boundary.
  final Uint8List? Function() readBytes;

  /// Key forwarded to the actual [Image], distinct from this widget's key.
  final Key? imageKey;

  /// Receives real Flutter decode failures without synthesizing a valid image.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Accessible description forwarded to the actual [Image].
  final String? semanticLabel;

  /// Positive bound on both decoded axes, preserving aspect without upscaling.
  /// The default is a display bound, not a device memory acceptance threshold.
  final int maxDecodeDimension;

  @override
  State<CaptureImagePreview> createState() => _CaptureImagePreviewState();
}

class _CaptureImagePreviewState extends State<CaptureImagePreview> {
  Uint8List? _snapshot;
  ResizeImage? _provider;

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void didUpdateWidget(CaptureImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceIdentity, widget.sourceIdentity) ||
        oldWidget.materialId != widget.materialId) {
      _release();
      _acquire();
    } else if (_snapshot == null) {
      _acquire();
    } else if (oldWidget.maxDecodeDimension != widget.maxDecodeDimension) {
      _evictProvider();
      _createProvider();
    }
  }

  void _acquire() {
    final bytes = widget.readBytes();
    if (bytes == null) return;
    _snapshot = Uint8List.fromList(bytes).asUnmodifiableView();
    _createProvider();
  }

  void _createProvider() {
    _provider = ResizeImage(
      MemoryImage(_snapshot!),
      width: widget.maxDecodeDimension,
      height: widget.maxDecodeDimension,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }

  void _evictProvider() {
    final provider = _provider;
    _provider = null;
    if (provider != null) unawaited(provider.evict());
  }

  void _release() {
    _evictProvider();
    _snapshot = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();
    return Image(
      key: widget.imageKey,
      image: provider,
      fit: BoxFit.contain,
      semanticLabel: widget.semanticLabel,
      errorBuilder: widget.errorBuilder,
    );
  }
}
