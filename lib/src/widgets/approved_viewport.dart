import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;

/// Suppresses painting until caller-approved global geometry matches this frame.
class ApprovedViewport extends SingleChildRenderObjectWidget {
  const ApprovedViewport({
    required this.approvedViewport,
    required this.requiresGeometry,
    required this.onViewport,
    required super.child,
    super.key,
  });

  final Rect? approvedViewport;
  final bool requiresGeometry;
  final ValueChanged<Rect> onViewport;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderApprovedViewport(approvedViewport, requiresGeometry, onViewport);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderApprovedViewport)
      ..approvedViewport = approvedViewport
      ..requiresGeometry = requiresGeometry
      ..onViewport = onViewport;
  }
}

class _RenderApprovedViewport extends RenderProxyBox {
  _RenderApprovedViewport(
    this._approvedViewport,
    this._requiresGeometry,
    this._onViewport,
  );

  Rect? _approvedViewport;
  bool _requiresGeometry;
  ValueChanged<Rect> _onViewport;
  Rect? _lastReportedViewport;

  set approvedViewport(Rect? value) {
    if (_approvedViewport == value) {
      return;
    }
    _approvedViewport = value;
    markNeedsPaint();
  }

  set requiresGeometry(bool value) {
    if (_requiresGeometry == value) {
      return;
    }
    _requiresGeometry = value;
    markNeedsPaint();
  }

  set onViewport(ValueChanged<Rect> value) => _onViewport = value;

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = localToGlobal(Offset.zero);
    final viewport = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      size.width,
      size.height,
    );
    _reportViewport(viewport);
    if (!_requiresGeometry || _approvedViewport == viewport) {
      super.paint(context, offset);
    }
  }

  void _reportViewport(Rect viewport) {
    if (_lastReportedViewport == viewport) {
      return;
    }
    _lastReportedViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || _lastReportedViewport != viewport) {
        return;
      }
      _onViewport(viewport);
    });
  }
}
