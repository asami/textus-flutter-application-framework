import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'approved_viewport.dart';

/// Shared document commands/source/editor panes. Layout never chooses a domain
/// mode or command; caller-owned buffers survive width/posture changes.
class DocumentEditingWorkspace extends StatefulWidget {
  const DocumentEditingWorkspace({
    required this.title,
    required this.navigation,
    required this.source,
    required this.editorBuilder,
    required this.editing,
    required this.onEditingChanged,
    required this.status,
    this.beforeEditingChange,
    this.onSave,
    this.onReload,
    this.accountAction,
    this.compactBreakpoint = 700,
    super.key,
  });
  final String title;
  final Widget navigation;
  final Widget source;
  final Widget Function(BuildContext, bool editable) editorBuilder;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;
  final Future<bool> Function(bool editing)? beforeEditingChange;
  final String status;
  final VoidCallback? onSave;
  final VoidCallback? onReload;
  final Widget? accountAction;
  final double compactBreakpoint;
  @override
  State<DocumentEditingWorkspace> createState() =>
      _DocumentEditingWorkspaceState();
}

class _DocumentEditingWorkspaceState extends State<DocumentEditingWorkspace> {
  bool _editingSuspended = false;
  bool _changingMode = false;
  bool _sourceHidden = false;
  double _fraction = .5;
  Rect? _viewport;
  Rect? _lastSeparator;
  Future<void> _mode(bool value) async {
    if (_changingMode) return;
    setState(() => _changingMode = true);
    try {
      final allowed = await widget.beforeEditingChange?.call(value) ?? true;
      if (!mounted || !allowed) return;
      setState(() => _editingSuspended = false);
      widget.onEditingChanged(value);
    } finally {
      if (mounted) setState(() => _changingMode = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final screenFold = SeparatedDisplayRegions.fromMediaQuery(media);
      if (_lastSeparator != screenFold?.separation) {
        _editingSuspended = true;
        _lastSeparator = screenFold?.separation;
      }
      final fold = _viewport == null
          ? null
          : SeparatedDisplayRegions.fromMediaQuery(media, viewport: _viewport);
      final geometryKnown = screenFold == null || _viewport != null;
      bool viable(Rect area) => area.width >= 280 && area.height >= 120;
      final wide =
          constraints.maxWidth - media.padding.horizontal >=
              widget.compactBreakpoint &&
          geometryKnown &&
          (fold == null || (viable(fold.leading) && viable(fold.trailing)));
      if (!wide) _editingSuspended = true;
      final editable = wide && widget.editing && !_editingSuspended;
      final expanded = screenFold == null && constraints.maxWidth >= 1100;
      final save = editable && !_changingMode ? widget.onSave : null;
      final editor = widget.editorBuilder(context, editable);
      final toolbar = Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment(value: false, label: Text('入力・参照')),
              ButtonSegment(
                value: true,
                label: const Text('編集'),
                enabled: wide,
              ),
            ],
            selected: {editable},
            onSelectionChanged: _changingMode
                ? null
                : (value) => unawaited(_mode(value.single)),
          ),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('変更を保存'),
          ),
          OutlinedButton.icon(
            onPressed: widget.onReload,
            icon: const Icon(Icons.refresh),
            label: const Text('保存状態を確認'),
          ),
          if (wide && screenFold == null)
            TextButton.icon(
              onPressed: () => setState(() => _sourceHidden = !_sourceHidden),
              icon: Icon(
                _sourceHidden ? Icons.view_sidebar_outlined : Icons.unfold_less,
              ),
              label: Text(_sourceHidden ? '原資料を表示' : '原資料を折りたたむ'),
            ),
          Semantics(liveRegion: true, child: Text(widget.status)),
          if (!wide) const Text('編集は十分な表示領域で利用できます。'),
        ],
      );
      final availableToolbar = screenFold?.axis == Axis.horizontal
          ? (screenFold!.leading.width >= 280
                ? screenFold.leading
                : screenFold.trailing)
          : null;
      final toolbarWidth = availableToolbar?.width ?? constraints.maxWidth;
      return Shortcuts(
        shortcuts: {
          if (save != null) ...{
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                const _SaveDocumentIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                const _SaveDocumentIntent(),
          },
        },
        child: Actions(
          actions: {
            _SaveDocumentIntent: CallbackAction<_SaveDocumentIntent>(
              onInvoke: (_) {
                save?.call();
                return null;
              },
            ),
          },
          child: Scaffold(
            appBar: AppBar(
              title: SizedBox(
                width: availableToolbar == null
                    ? null
                    : math.max(0, toolbarWidth - 72),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              actions: [?widget.accountAction],
            ),
            drawer: !expanded
                ? Drawer(child: SafeArea(child: widget.navigation))
                : null,
            body: Column(
              children: [
                Align(
                  alignment:
                      availableToolbar != null && availableToolbar.left > 0
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: SizedBox(
                    width: toolbarWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: toolbar,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ApprovedViewport(
                    approvedViewport: _viewport,
                    requiresGeometry: screenFold != null,
                    onViewport: (value) {
                      if (mounted && _viewport != value) {
                        setState(() => _viewport = value);
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, body) {
                        Widget reference() => DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: '資料一覧'),
                                  Tab(text: '原資料'),
                                  Tab(text: '内容'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    widget.navigation,
                                    widget.source,
                                    editor,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                        if (!wide) {
                          if (fold != null && _viewport != null) {
                            final region =
                                fold.leading.width * fold.leading.height >=
                                    fold.trailing.width * fold.trailing.height
                                ? fold.leading
                                : fold.trailing;
                            return Stack(
                              fit: StackFit.expand,
                              children: [_region(region, reference())],
                            );
                          }
                          return reference();
                        }
                        if (fold != null) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              _region(fold.leading, widget.source),
                              _region(fold.trailing, editor),
                              Positioned.fromRect(
                                rect: fold.separation.shift(
                                  -_viewport!.topLeft,
                                ),
                                child: const SizedBox(
                                  key: ValueKey('workspace-fold-separation'),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (expanded) ...[
                              SizedBox(width: 240, child: widget.navigation),
                              const VerticalDivider(width: 1),
                            ],
                            Expanded(
                              child: _sourceHidden
                                  ? editor
                                  : LayoutBuilder(
                                      builder: (context, panes) {
                                        final span = panes.maxWidth - 16;
                                        final minimum = math.min(
                                          .5,
                                          280 / math.max(1, span),
                                        );
                                        final fraction = _fraction.clamp(
                                          minimum,
                                          1 - minimum,
                                        );
                                        void adjust(double value) => setState(
                                          () => _fraction = value.clamp(
                                            minimum,
                                            1 - minimum,
                                          ),
                                        );
                                        return Row(
                                          children: [
                                            SizedBox(
                                              width: math.max(
                                                0,
                                                span * fraction,
                                              ),
                                              child: widget.source,
                                            ),
                                            Semantics(
                                              label: '原資料と編集欄の幅',
                                              value:
                                                  '${(fraction * 100).round()}%',
                                              increasedValue:
                                                  '${((fraction + .05).clamp(minimum, 1 - minimum) * 100).round()}%',
                                              decreasedValue:
                                                  '${((fraction - .05).clamp(minimum, 1 - minimum) * 100).round()}%',
                                              onIncrease: () =>
                                                  adjust(fraction + .05),
                                              onDecrease: () =>
                                                  adjust(fraction - .05),
                                              child: FocusableActionDetector(
                                                shortcuts: {
                                                  const SingleActivator(
                                                    LogicalKeyboardKey
                                                        .arrowLeft,
                                                  ): const _ResizePaneIntent(
                                                    -1,
                                                  ),
                                                  const SingleActivator(
                                                    LogicalKeyboardKey
                                                        .arrowRight,
                                                  ): const _ResizePaneIntent(
                                                    1,
                                                  ),
                                                },
                                                actions: {
                                                  _ResizePaneIntent:
                                                      CallbackAction<
                                                        _ResizePaneIntent
                                                      >(
                                                        onInvoke: (intent) {
                                                          adjust(
                                                            fraction +
                                                                intent.direction *
                                                                    .05,
                                                          );
                                                          return null;
                                                        },
                                                      ),
                                                },
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onHorizontalDragUpdate:
                                                      (event) => adjust(
                                                        fraction +
                                                            event.delta.dx /
                                                                math.max(
                                                                  1,
                                                                  span,
                                                                ),
                                                      ),
                                                  child: const SizedBox(
                                                    width: 16,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.drag_indicator,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(child: editor),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _region(Rect rect, Widget child) => Positioned.fromRect(
    rect: rect.shift(-_viewport!.topLeft),
    child: ClipRect(child: child),
  );
}

class _SaveDocumentIntent extends Intent {
  const _SaveDocumentIntent();
}

class _ResizePaneIntent extends Intent {
  const _ResizePaneIntent(this.direction);
  final int direction;
}

/// Visible explicit editing entry based on usable area, never device-name rules.
class AdaptiveEditingEntry extends StatelessWidget {
  const AdaptiveEditingEntry({
    required this.onPressed,
    this.padding = const EdgeInsets.only(top: 12),
    super.key,
  });
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fold = SeparatedDisplayRegions.fromMediaQuery(media);
    final usable =
        media.size.width -
        media.padding.horizontal -
        (fold?.axis == Axis.horizontal ? fold!.separation.width : 0);
    if (usable < 700 ||
        (fold != null &&
            (fold.leading.width < 280 || fold.trailing.width < 280))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_note),
        label: const Text('編集モードを開く'),
      ),
    );
  }
}
