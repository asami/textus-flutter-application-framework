import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../capture/image_region_viewport.dart';
import 'capture_image_preview.dart';

/// Source-space area selection with explicit draw and viewport-move modes.
class ImageRegionSelector extends StatefulWidget {
  /// Borrows a trusted Core frame and, optionally, a viewport controller.
  const ImageRegionSelector({required this.frame, required this.onChanged,
    this.selection, this.enabled = true, this.transformationController, super.key});

  /// Exact canonical upright source raster from Core.
  final ImageRegionFrame frame;
  /// Normalized source geometry, independent of viewport state.
  final ImageRegionGeometry? selection;
  /// Explicit completed positive-area gesture; drawing performs no IO.
  final ValueChanged<ImageRegionGeometry> onChanged;
  /// Pure current caller admission, also rechecked at gesture completion.
  final bool enabled;
  /// Optional borrowed transient zoom/pan state, never serialized.
  final TransformationController? transformationController;

  @override
  State<ImageRegionSelector> createState() => _ImageRegionSelectorState();
}

class _ImageRegionSelectorState extends State<ImageRegionSelector> {
  late TransformationController _transform;
  bool _ownsTransform = false;
  bool _move = false;
  ImageRegionTool _tool = ImageRegionTool.rectangle;
  Offset? _start;
  ImageRegionGeometry? _drawing;
  int _generation = 0;
  int? _gestureGeneration;
  (Size, Rect)? _layout;
  (Size, Rect)? _gestureLayout;
  int _layoutEpoch = 0;

  @override
  void initState() {
    super.initState();
    _adoptTransform();
  }
  void _adoptTransform() {
    _ownsTransform = widget.transformationController == null;
    _transform = widget.transformationController ?? TransformationController();
  }
  void _cancel() {
    _generation++;
    _start = null;
    _drawing = null;
    _gestureGeneration = null;
    _gestureLayout = null;
  }
  @override
  void didUpdateWidget(ImageRegionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frame, widget.frame) ||
        oldWidget.onChanged != widget.onChanged || !widget.enabled) { _cancel(); }
    if (!identical(oldWidget.transformationController, widget.transformationController)) {
      _cancel();
      if (_ownsTransform) _transform.dispose();
      _adoptTransform();
    } else if (!identical(oldWidget.frame, widget.frame)) {
      // Source replacement retires this widget's own transient viewport only.
      if (_ownsTransform) _transform.value = Matrix4.identity();
    }
  }
  @override
  void dispose() {
    _cancel();
    if (_ownsTransform) _transform.dispose();
    super.dispose();
  }
  bool _admits(int generation) => mounted && widget.enabled &&
      generation == _generation && !_move;
  void _zoom(double factor) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(1.0, 8.0);
    _transform.value = _transform.value.clone()..scaleByDouble(next / scale, next / scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final move in [false, true])
          ChoiceChip(label: Text(move ? '画像を動かす' : '範囲を選ぶ'),
            selected: _move == move, onSelected: widget.enabled ? (_) {
              if (generation != _generation) return;
              setState(() { _cancel(); _move = move; });
            } : null),
        for (final tool in ImageRegionTool.values)
          ChoiceChip(label: Text(switch (tool) { ImageRegionTool.rectangle => '長方形', ImageRegionTool.ellipse => '楕円', ImageRegionTool.circle => '円' }), selected: tool == _tool,
            onSelected: widget.enabled ? (_) {
              if (generation != _generation) return;
              setState(() { _cancel(); _tool = tool; _move = false; });
            } : null),
        IconButton(tooltip: '拡大', onPressed: widget.enabled ? () {
          if (generation == _generation) { _cancel(); _zoom(1.5); setState(() {}); }
        } : null, icon: const Icon(Icons.zoom_in)),
        IconButton(tooltip: '縮小', onPressed: widget.enabled ? () {
          if (generation == _generation) { _cancel(); _zoom(1 / 1.5); setState(() {}); }
        } : null, icon: const Icon(Icons.zoom_out)),
        TextButton(onPressed: widget.enabled ? () {
          if (generation == _generation) {
            setState(() { _cancel(); _transform.value = Matrix4.identity(); });
          }
        } : null, child: const Text('表示倍率を戻す')),
      ]),
      SizedBox(height: 320, child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
          _layoutEpoch++;
          _start = null;
          _drawing = null;
          _gestureGeneration = null;
          _gestureLayout = null;
          _layout = null;
          return const Text('画像の表示領域を確保できませんでした。');
        }
        final imageRect = ImageRegionViewport.containRect(pixelWidth: widget.frame.pixelWidth,
          pixelHeight: widget.frame.pixelHeight, viewportSize: size);
        final layout = (size, imageRect);
        if (_layout != layout) {
          // Layout can change without replacing the frame or callback owner.
          _layoutEpoch++;
          _start = null;
          _drawing = null;
          _gestureGeneration = null;
          _gestureLayout = null;
          _layout = layout;
        }
        final layoutGeneration = _generation;
        final layoutEpoch = _layoutEpoch;
        final callback = widget.onChanged;
        final frame = widget.frame;
        void update(Offset position) {
          if (_start == null || _gestureGeneration != layoutGeneration ||
              _gestureLayout != layout || _layout != layout || layoutEpoch != _layoutEpoch ||
              !_admits(layoutGeneration)) { return; }
          // Exactly one viewport inverse, followed by the contain offset mapping.
          final scene = _transform.toScene(position);
          setState(() { _drawing = ImageRegionViewport.fromDrag(start: _start!, end: scene,
            imageRect: imageRect, tool: _tool); });
        }
        return ClipRect(child: GestureDetector(
          key: const ValueKey('image-region-draw-surface'),
          dragStartBehavior: DragStartBehavior.down,
          behavior: HitTestBehavior.opaque,
          onPanStart: !_move && widget.enabled ? (details) {
            if (!_admits(layoutGeneration) || _layout != layout || layoutEpoch != _layoutEpoch ||
                !identical(frame, widget.frame)) { return; }
            final scene = _transform.toScene(details.localPosition);
            if (!imageRect.contains(scene)) return;
            setState(() { _start = scene; _gestureGeneration = layoutGeneration;
              _gestureLayout = layout; _drawing = null; });
          } : null,
          onPanUpdate: !_move && widget.enabled ? (details) => update(details.localPosition) : null,
          onPanCancel: () { if (mounted) setState(_cancel); },
          onPanEnd: !_move && widget.enabled ? (_) {
            if (!_admits(layoutGeneration) || _layout != layout || layoutEpoch != _layoutEpoch ||
                !identical(frame, widget.frame) || callback != widget.onChanged) { return; }
            final value = _drawing;
            final admitted = _admits(layoutGeneration) && _gestureGeneration == layoutGeneration &&
              _gestureLayout == layout && _layout == layout && layoutEpoch == _layoutEpoch &&
              identical(frame, widget.frame) && callback == widget.onChanged;
            setState(() { _start = null; _drawing = null; _gestureGeneration = null; _gestureLayout = null; });
            if (admitted && value != null) callback(value);
          } : null,
          child: IgnorePointer(ignoring: !_move, child: InteractiveViewer(
            transformationController: _transform, minScale: 1, maxScale: 8,
            panEnabled: _move && widget.enabled, scaleEnabled: _move && widget.enabled,
            child: SizedBox.fromSize(size: size, child: Stack(children: [
              Positioned.fromRect(rect: imageRect, child: CaptureImagePreview(
                materialId: frame.source.id, sourceIdentity: frame,
                readBytes: () => frame.pngBytes,
                semanticLabel: '範囲選択用の原画像',
                errorBuilder: (_, error, _) => const Text('画像を表示できませんでした。'),
              )),
              Positioned.fill(child: IgnorePointer(child: CustomPaint(
                key: const ValueKey('image-region-overlay'),
                painter: _SelectionPainter(_drawing ?? widget.selection, imageRect),
              ))),
            ])),
          )),
        ));
      })),
    ]);
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter(this.geometry, this.imageRect);
  final ImageRegionGeometry? geometry;
  final Rect imageRect;
  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    if (g == null) return;
    final rect = ImageRegionViewport.selectionRect(g, imageRect);
    final paint = Paint()..color = const Color(0xff1565c0)..style = PaintingStyle.stroke..strokeWidth = 2;
    if (g.shape == ImageRegionShape.rectangle) { canvas.drawRect(rect, paint); }
    else { canvas.drawOval(rect, paint); }
  }
  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      geometry != oldDelegate.geometry || imageRect != oldDelegate.imageRect;
}
