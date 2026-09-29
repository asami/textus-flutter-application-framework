import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/presentation_realization.dart';
import '../configuration/resource_list_detail_configuration.dart';
import '../resource/resource_data_source.dart';
import '../resource/resource_view_model.dart';
import '../view/resource_list_detail_display_model.dart';
import '../view/resource_list_detail_hinge_policy.dart';

/// Standard, configuration-driven Resource List + Detail presentation.
class ResourceListDetail extends StatefulWidget {
  const ResourceListDetail({
    required this.configuration,
    required this.viewModel,
    this.displayModel,
    super.key,
  });

  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;

  /// Optional application-owned presentation-session state.
  final ResourceListDetailDisplayModel? displayModel;

  @override
  State<ResourceListDetail> createState() => _ResourceListDetailState();
}

class _ResourceListDetailState extends State<ResourceListDetail> {
  late ResourceListDetailDisplayModel _displayModel;
  late bool _ownsDisplayModel;
  Rect? _approvedBodyViewport;

  @override
  void initState() {
    super.initState();
    _displayModel = widget.displayModel ?? ResourceListDetailDisplayModel();
    _ownsDisplayModel = widget.displayModel == null;
    widget.viewModel.addListener(_changed);
    _displayModel.addListener(_changed);
    widget.viewModel.load();
  }

  @override
  void didUpdateWidget(ResourceListDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_changed);
      widget.viewModel.addListener(_changed);
      widget.viewModel.load();
    }
    if (oldWidget.displayModel != widget.displayModel) {
      final oldDisplayModel = _displayModel;
      oldDisplayModel.removeListener(_changed);
      if (_ownsDisplayModel) oldDisplayModel.dispose();
      _displayModel = widget.displayModel ?? ResourceListDetailDisplayModel();
      _ownsDisplayModel = widget.displayModel == null;
      _displayModel.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_changed);
    _displayModel.removeListener(_changed);
    if (_ownsDisplayModel) _displayModel.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _select(ResourceRecord resource) {
    widget.viewModel.select(resource.id);
    _displayModel.openDetail();
  }

  void _showList() => _displayModel.showList();

  void _approveBodyViewport(Rect viewport) {
    if (!mounted || _approvedBodyViewport == viewport) return;
    setState(() => _approvedBodyViewport = viewport);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.configuration.realization != PresentationRealization.framework) {
      throw ArgumentError.value(
        widget.configuration.realization,
        'configuration.realization',
        'ResourceListDetail supports framework realization only',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final requiresGeometry =
            SeparatedDisplayRegions.fromMediaQuery(mediaQuery) != null;
        final fold = _approvedBodyViewport == null
            ? null
            : SeparatedDisplayRegions.fromMediaQuery(
                mediaQuery,
                viewport: _approvedBodyViewport,
              );
        final geometryKnown =
            !requiresGeometry || _approvedBodyViewport != null;
        final usableWidth = math.max(
          0.0,
          constraints.maxWidth -
              mediaQuery.padding.left -
              mediaQuery.padding.right,
        );
        final avoidViable =
            fold != null &&
            _isEligibleFoldRegion(fold.leading) &&
            _isEligibleFoldRegion(fold.trailing);
        final spanViable =
            fold != null &&
            _approvedBodyViewport != null &&
            _approvedBodyViewport!.width >=
                widget.configuration.minimumFoldPaneWidth * 2 + 1 &&
            _approvedBodyViewport!.height >=
                widget.configuration.minimumFoldPaneHeight;
        final hingePolicy = _displayModel.resolveHingePolicy(
          hasOcclusion: fold?.hasOcclusion ?? false,
          defaultPolicy: widget.configuration.defaultHingePolicy,
        );
        final usesAvoidFold =
            fold != null && hingePolicy == ResourceListDetailHingePolicy.avoid;
        final usesSpanFold =
            fold != null && hingePolicy == ResourceListDetailHingePolicy.span;
        final selectedPolicyViable = switch (hingePolicy) {
          ResourceListDetailHingePolicy.automatic => false,
          ResourceListDetailHingePolicy.avoid => avoidViable,
          ResourceListDetailHingePolicy.span => spanViable,
        };
        final splitCapable = !geometryKnown
            ? false
            : fold != null
            ? selectedPolicyViable
            : usableWidth >= widget.configuration.compactBreakpoint;
        final presentation = _displayModel.resolve(
          splitCapable: splitCapable,
          hasSelection: splitCapable
              ? widget.viewModel.selectedResource != null
              : widget.viewModel.selectedId != null,
          allowDetailFocus: widget.configuration.allowDetailFocus,
        );
        final activeRoute = ModalRoute.of(context)?.isCurrent ?? false;
        final interceptsCompactBack =
            presentation == ResourceListDetailPresentation.compactDetail &&
            TickerMode.valuesOf(context).enabled &&
            activeRoute;

        return PopScope<Object?>(
          canPop: !interceptsCompactBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && interceptsCompactBack) _showList();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                presentation == ResourceListDetailPresentation.compactDetail ||
                        presentation ==
                            ResourceListDetailPresentation.detailFocused
                    ? widget.configuration.detailTitle
                    : widget.configuration.listTitle,
              ),
              leading:
                  presentation == ResourceListDetailPresentation.compactDetail
                  ? BackButton(onPressed: _showList)
                  : null,
              actions: _actionsFor(
                presentation,
                hingePolicy: hingePolicy,
                avoidViable: avoidViable,
                spanViable: spanViable,
                hasOcclusion: fold?.hasOcclusion ?? false,
                showHingePolicy:
                    fold != null &&
                    widget.configuration.allowHingePolicySwitch &&
                    (avoidViable || spanViable),
              ),
            ),
            body: SafeArea(
              child: _ViewportObserver(
                approvedViewport: _approvedBodyViewport,
                requiresGeometry: requiresGeometry,
                onViewport: _approveBodyViewport,
                child: SizedBox.expand(
                  child: _bodyFor(
                    fold: fold,
                    viewport: _approvedBodyViewport,
                    usesAvoidFold: usesAvoidFold,
                    usesSpanFold: usesSpanFold,
                    usableWidth: usableWidth,
                    presentation: presentation,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actionsFor(
    ResourceListDetailPresentation presentation, {
    required ResourceListDetailHingePolicy hingePolicy,
    required bool avoidViable,
    required bool spanViable,
    required bool hasOcclusion,
    required bool showHingePolicy,
  }) {
    final actions = <Widget>[];
    if (showHingePolicy) {
      final currentPolicyLabel =
          hingePolicy == ResourceListDetailHingePolicy.avoid ? '避ける' : 'またぐ';
      final warning =
          hasOcclusion && hingePolicy == ResourceListDetailHingePolicy.span
          ? ' ヒンジ部分では内容が隠れる場合があります'
          : '';
      actions.add(
        PopupMenuButton<ResourceListDetailHingePolicy>(
          key: const Key('resource-hinge-policy'),
          tooltip: 'ヒンジの扱い: $currentPolicyLabel$warning',
          icon: Icon(
            hingePolicy == ResourceListDetailHingePolicy.avoid
                ? Icons.splitscreen
                : Icons.view_column,
          ),
          onSelected: _displayModel.setHingePolicy,
          itemBuilder: (context) => [
            CheckedPopupMenuItem<ResourceListDetailHingePolicy>(
              key: const Key('resource-hinge-avoid'),
              value: ResourceListDetailHingePolicy.avoid,
              checked: hingePolicy == ResourceListDetailHingePolicy.avoid,
              enabled: avoidViable,
              child: const Text('ヒンジを避ける'),
            ),
            CheckedPopupMenuItem<ResourceListDetailHingePolicy>(
              key: const Key('resource-hinge-span'),
              value: ResourceListDetailHingePolicy.span,
              checked: hingePolicy == ResourceListDetailHingePolicy.span,
              enabled: spanViable,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ヒンジをまたぐ'),
                  if (hasOcclusion) const Text('ヒンジ部分では内容が隠れる場合があります'),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final canFocus =
        widget.configuration.allowDetailFocus &&
        widget.viewModel.selectedResource != null;
    if (!canFocus) return actions;
    actions.addAll(switch (presentation) {
      ResourceListDetailPresentation.split => [
        IconButton(
          key: const Key('resource-detail-focus'),
          tooltip: 'Show detail full screen',
          icon: const Icon(Icons.open_in_full),
          onPressed: _displayModel.focusDetail,
        ),
      ],
      ResourceListDetailPresentation.detailFocused => [
        IconButton(
          key: const Key('resource-restore-split'),
          tooltip: 'Show list and detail',
          icon: const Icon(Icons.close_fullscreen),
          onPressed: _displayModel.restoreSplit,
        ),
      ],
      ResourceListDetailPresentation.compactList ||
      ResourceListDetailPresentation.compactDetail => const [],
    });
    return actions;
  }

  Widget _bodyFor({
    required SeparatedDisplayRegions? fold,
    required Rect? viewport,
    required bool usesAvoidFold,
    required bool usesSpanFold,
    required double usableWidth,
    required ResourceListDetailPresentation presentation,
  }) {
    final list = _ResourceList(
      configuration: widget.configuration,
      viewModel: widget.viewModel,
      selected:
          presentation != ResourceListDetailPresentation.compactList &&
          presentation != ResourceListDetailPresentation.compactDetail,
      onSelect: _select,
    );
    final detail = _detailOrPlaceholder();
    return switch (presentation) {
      ResourceListDetailPresentation.compactList => _compactBodyFor(
        child: list,
        fold: fold,
        viewport: viewport,
        usesAvoidFold: usesAvoidFold,
      ),
      ResourceListDetailPresentation.compactDetail => _compactBodyFor(
        child: detail,
        fold: fold,
        viewport: viewport,
        usesAvoidFold: usesAvoidFold,
      ),
      ResourceListDetailPresentation.split =>
        usesAvoidFold
            ? _foldSplit(fold!, viewport!, list, detail)
            : _ordinarySplit(
                list: list,
                detail: detail,
                listWidth: usesSpanFold
                    ? _spanListWidth(viewport!.width)
                    : usableWidth * 0.35,
              ),
      ResourceListDetailPresentation.detailFocused =>
        usesAvoidFold ? _foldFocusedDetail(fold!, viewport!, detail) : detail,
    };
  }

  bool _isEligibleFoldRegion(Rect region) =>
      region.width >= widget.configuration.minimumFoldPaneWidth &&
      region.height >= widget.configuration.minimumFoldPaneHeight;

  Widget _compactBodyFor({
    required Widget child,
    required SeparatedDisplayRegions? fold,
    required Rect? viewport,
    required bool usesAvoidFold,
  }) {
    if (fold == null || viewport == null || !usesAvoidFold) {
      return child;
    }
    final region = _largestUsableRegion(fold);
    if (region == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [_positionedRegion(region, viewport, child)],
    );
  }

  double _spanListWidth(double fullBodyWidth) {
    final minimum = widget.configuration.minimumFoldPaneWidth;
    return math.min(
      math.max(fullBodyWidth * 0.35, minimum),
      fullBodyWidth - 1 - minimum,
    );
  }

  Widget _ordinarySplit({
    required Widget list,
    required Widget detail,
    required double listWidth,
  }) => Row(
    children: [
      SizedBox(width: listWidth, child: list),
      const VerticalDivider(width: 1),
      Expanded(child: detail),
    ],
  );

  Rect? _largestUsableRegion(SeparatedDisplayRegions fold) {
    final leading = fold.leading;
    final trailing = fold.trailing;
    final leadingUsable = leading.width > 0 && leading.height > 0;
    final trailingUsable = trailing.width > 0 && trailing.height > 0;
    if (!leadingUsable && !trailingUsable) return null;
    if (!trailingUsable) return leading;
    if (!leadingUsable) return trailing;
    final leadingArea = leading.width * leading.height;
    final trailingArea = trailing.width * trailing.height;
    return leadingArea >= trailingArea ? leading : trailing;
  }

  Widget _foldSplit(
    SeparatedDisplayRegions fold,
    Rect viewport,
    Widget list,
    Widget detail,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      _positionedRegion(fold.leading, viewport, list),
      Positioned(
        left: fold.separation.left - viewport.left,
        top: fold.separation.top - viewport.top,
        width: fold.separation.width,
        height: fold.separation.height,
        child: const SizedBox(key: Key('fold-separation')),
      ),
      _positionedRegion(fold.trailing, viewport, detail),
    ],
  );

  Widget _foldFocusedDetail(
    SeparatedDisplayRegions fold,
    Rect viewport,
    Widget detail,
  ) => Stack(
    fit: StackFit.expand,
    children: [_positionedRegion(fold.trailing, viewport, detail)],
  );

  Widget _positionedRegion(Rect region, Rect viewport, Widget child) =>
      Positioned(
        left: region.left - viewport.left,
        top: region.top - viewport.top,
        width: region.width,
        height: region.height,
        child: ClipRect(child: child),
      );

  Widget _detailOrPlaceholder() => widget.viewModel.selectedId == null
      ? const Center(child: Text('Select a resource'))
      : _ResourceDetail(
          configuration: widget.configuration,
          viewModel: widget.viewModel,
        );
}

class _ViewportObserver extends SingleChildRenderObjectWidget {
  const _ViewportObserver({
    required this.approvedViewport,
    required this.requiresGeometry,
    required this.onViewport,
    required super.child,
  });

  final Rect? approvedViewport;
  final bool requiresGeometry;
  final ValueChanged<Rect> onViewport;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderViewportObserver(approvedViewport, requiresGeometry, onViewport);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderViewportObserver renderObject,
  ) {
    renderObject
      ..approvedViewport = approvedViewport
      ..requiresGeometry = requiresGeometry
      ..onViewport = onViewport;
  }
}

class _RenderViewportObserver extends RenderProxyBox {
  _RenderViewportObserver(
    this._approvedViewport,
    this._requiresGeometry,
    this._onViewport,
  );

  Rect? _approvedViewport;
  bool _requiresGeometry;
  ValueChanged<Rect> _onViewport;
  Rect? _lastReportedViewport;

  set approvedViewport(Rect? value) {
    if (_approvedViewport == value) return;
    _approvedViewport = value;
    markNeedsPaint();
  }

  set requiresGeometry(bool value) {
    if (_requiresGeometry == value) return;
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
    if (_lastReportedViewport == viewport) return;
    _lastReportedViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || _lastReportedViewport != viewport) return;
      _onViewport(viewport);
    });
  }
}

class _ResourceList extends StatelessWidget {
  const _ResourceList({
    required this.configuration,
    required this.viewModel,
    required this.selected,
    required this.onSelect,
  });

  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;
  final bool selected;
  final ValueChanged<ResourceRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    if (viewModel.listFailed) {
      return const Center(child: Text('Could not load resources'));
    }
    if (viewModel.listLoading || viewModel.resources == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final resources = viewModel.resources!;
    if (resources.isEmpty) return const Center(child: Text('No resources'));
    return ListView.builder(
      key: PageStorageKey<ResourceViewModel>(viewModel),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        final secondary = configuration.secondaryField;
        return ListTile(
          title: Text(resource.value(configuration.primaryField)),
          subtitle: secondary == null ? null : Text(resource.value(secondary)),
          selected: selected && viewModel.selectedId == resource.id,
          onTap: () => onSelect(resource),
        );
      },
    );
  }
}

class _ResourceDetail extends StatelessWidget {
  const _ResourceDetail({required this.configuration, required this.viewModel});

  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.detailFailed) {
      return const Center(child: Text('Could not load resource'));
    }
    if (viewModel.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final record = viewModel.selectedResource;
    if (record == null) return const Center(child: Text('Resource not found'));
    return ListView(
      children: [
        for (final field in configuration.detailFields)
          ListTile(
            title: Text(field.label),
            subtitle: Text(record.value(field.key)),
          ),
        if (viewModel.actionFailed)
          const ListTile(title: Text('Could not update resource')),
        for (final action in viewModel.selectedActions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: viewModel.actionRunning
                  ? null
                  : () => viewModel.performAction(action.id),
              child: Text(action.label),
            ),
          ),
      ],
    );
  }
}
