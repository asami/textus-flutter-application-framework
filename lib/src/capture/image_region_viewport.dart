import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Transient drawing intent; a circle is stored as Core's elliptical mask.
enum ImageRegionTool { rectangle, ellipse, circle }

/// Pure conversion between a contained upright raster and scene coordinates.
abstract final class ImageRegionViewport {
  /// The same contain rectangle used to display the canonical raster.
  static Rect containRect({
    required int pixelWidth,
    required int pixelHeight,
    required Size viewportSize,
  }) {
    if (pixelWidth <= 0 || pixelHeight <= 0 ||
        !viewportSize.width.isFinite || !viewportSize.height.isFinite ||
        viewportSize.width <= 0 || viewportSize.height <= 0) {
      throw ArgumentError('Positive finite image and viewport dimensions required');
    }
    final scale = math.min(viewportSize.width / pixelWidth,
        viewportSize.height / pixelHeight);
    final size = Size(pixelWidth * scale, pixelHeight * scale);
    return Rect.fromLTWH((viewportSize.width - size.width) / 2,
        (viewportSize.height - size.height) / 2, size.width, size.height);
  }

  /// Ignores letterbox starts, clamps ends, and rejects zero-area gestures.
  /// Inputs are already scene coordinates; this method never applies a matrix.
  static ImageRegionGeometry? fromDrag({
    required Offset start,
    required Offset end,
    required Rect imageRect,
    ImageRegionTool tool = ImageRegionTool.rectangle,
  }) {
    if (!start.dx.isFinite || !start.dy.isFinite ||
        !end.dx.isFinite || !end.dy.isFinite ||
        imageRect.width <= 0 || imageRect.height <= 0 ||
        !imageRect.contains(start)) {
      return null;
    }
    var dx = end.dx.clamp(imageRect.left, imageRect.right) - start.dx;
    var dy = end.dy.clamp(imageRect.top, imageRect.bottom) - start.dy;
    if (tool == ImageRegionTool.circle) {
      // Contain uses a single raster scale, so equal scene axes are pixel axes.
      final side = math.min(dx.abs(), dy.abs());
      dx = side * dx.sign;
      dy = side * dy.sign;
    }
    if (dx == 0 || dy == 0) return null;
    final left = math.min(start.dx, start.dx + dx);
    final top = math.min(start.dy, start.dy + dy);
    final x = ((left - imageRect.left) / imageRect.width).clamp(0.0, 1.0);
    final y = ((top - imageRect.top) / imageRect.height).clamp(0.0, 1.0);
    final width = (dx.abs() / imageRect.width).clamp(0.0, 1.0 - x);
    final height = (dy.abs() / imageRect.height).clamp(0.0, 1.0 - y);
    if (width <= 0 || height <= 0) return null;
    return ImageRegionGeometry(
      shape: tool == ImageRegionTool.rectangle
          ? ImageRegionShape.rectangle : ImageRegionShape.ellipse,
      x: x, y: y, width: width, height: height,
    );
  }

  /// Reprojects retained source geometry onto the current display rectangle.
  static Rect selectionRect(ImageRegionGeometry geometry, Rect imageRect) =>
      Rect.fromLTWH(imageRect.left + geometry.x * imageRect.width,
        imageRect.top + geometry.y * imageRect.height,
        geometry.width * imageRect.width, geometry.height * imageRect.height);
}
