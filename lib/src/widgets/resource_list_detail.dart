import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/presentation_realization.dart';
import '../configuration/resource_list_detail_configuration.dart';
import '../resource/resource_data_source.dart';
import '../resource/resource_view_model.dart';
import '../view/resource_list_detail_display_model.dart';
import '../view/resource_list_detail_hinge_policy.dart';
import 'application_text_scaling.dart';
import 'approved_viewport.dart';
import 'application_text_toolbar.dart';

/// Standard, configuration-driven Resource List + Detail presentation.
class ResourceListDetail extends StatefulWidget {
  const ResourceListDetail({
    required this.configuration,
    required this.viewModel,
    this.displayModel,
    this.detailSupplementBuilder,
    this.additionalActions = const [],
    super.key,
  });

  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;

  /// Optional application-owned presentation-session state.
  final ResourceListDetailDisplayModel? displayModel;

  /// Caller-provided content appended to a ready selected scrolling detail.
  ///
  /// Receives the current record and detail build context. The subtree is keyed
  /// by record ID: the same identity permits ordinary widget updates, while a
  /// different identity or removal follows Flutter's disposal lifecycle. The
  /// caller owns domain I/O, navigation, state and request/update policy. This
  /// presentation hook grants no command or storage authority, and ordinary
  /// rebuilds may invoke it again. Null preserves the configured detail alone.
  final Widget Function(BuildContext context, ResourceRecord record)?
  detailSupplementBuilder;

  /// Caller-provided toolbar widgets appended after common layout controls.
  ///
  /// Available in list, detail and diagnostic presentations. The caller owns
  /// action state, domain I/O and navigation, and may supply disabled actions.
  /// Callbacks are invoked by the supplied widgets, never by this build method.
  /// The empty default preserves the existing toolbar.
  final List<Widget> additionalActions;

  @override
  State<ResourceListDetail> createState() => _ResourceListDetailState();
}

class _ResourceListDetailState extends State<ResourceListDetail> {
  late ResourceListDetailDisplayModel _displayModel;
  late bool _ownsDisplayModel;
  Rect? _approvedBodyViewport;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _displayModel = widget.displayModel ?? ResourceListDetailDisplayModel();
    _ownsDisplayModel = widget.displayModel == null;
    widget.viewModel.addListener(_changed);
    _displayModel.addListener(_changed);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(ResourceListDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_changed);
      widget.viewModel.addListener(_changed);
      _scheduleLoad();
    }
    if (oldWidget.displayModel != widget.displayModel) {
      final oldDisplayModel = _displayModel;
      oldDisplayModel.removeListener(_changed);
      if (_ownsDisplayModel) {
        oldDisplayModel.dispose();
      }
      _displayModel = widget.displayModel ?? ResourceListDetailDisplayModel();
      _ownsDisplayModel = widget.displayModel == null;
      _displayModel.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    widget.viewModel.removeListener(_changed);
    _displayModel.removeListener(_changed);
    if (_ownsDisplayModel) {
      _displayModel.dispose();
    }
    super.dispose();
  }

  void _scheduleLoad() {
    final viewModel = widget.viewModel;
    final generation = ++_loadGeneration;
    // Given an attached borrower, when its build frame finishes, then only the
    // current mounted attachment may start its automatic semantic read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(viewModel, widget.viewModel)) {
        return;
      }
      viewModel.load();
    });
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void _select(ResourceRecord resource) {
    widget.viewModel.select(resource.id);
    _displayModel.openDetail();
  }

  void _showList() => _displayModel.showList();

  void _approveBodyViewport(Rect viewport) {
    if (!mounted || _approvedBodyViewport == viewport) {
      return;
    }
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
        final title =
            presentation == ResourceListDetailPresentation.compactDetail ||
                presentation == ResourceListDetailPresentation.detailFocused
            ? widget.configuration.detailTitle
            : widget.configuration.listTitle;
        final leading =
            presentation == ResourceListDetailPresentation.compactDetail
            ? BackButton(onPressed: _showList)
            : null;
        final actions = _actionsFor(
          presentation,
          splitCapable: splitCapable,
          hingePolicy: hingePolicy,
          avoidViable: avoidViable,
          spanViable: spanViable,
          hasOcclusion: fold?.hasOcclusion ?? false,
          showHingePolicy:
              fold != null &&
              widget.configuration.allowHingePolicySwitch &&
              (avoidViable || spanViable),
        );

        return PopScope<Object?>(
          canPop: !interceptsCompactBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && interceptsCompactBack) {
              _showList();
            }
          },
          child: Scaffold(
            appBar: ApplicationTextScaling.maybeTextScalerOf(context) == null
                ? AppBar(title: Text(title), leading: leading, actions: actions)
                : applicationTextAppBar(
                    context,
                    title: title,
                    width: constraints.maxWidth,
                    leading: leading,
                    actions: actions,
                  ),
            body: SafeArea(
              child: ApprovedViewport(
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
    required bool splitCapable,
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
    actions.addAll(switch (presentation) {
      ResourceListDetailPresentation.split when canFocus => [
        IconButton(
          key: const Key('resource-detail-focus'),
          tooltip: '詳細を全画面で表示',
          icon: const Icon(Icons.open_in_full),
          onPressed: _displayModel.focusDetail,
        ),
      ],
      ResourceListDetailPresentation.detailFocused ||
      ResourceListDetailPresentation.compactList when splitCapable => [
        IconButton(
          key: const Key('resource-restore-split'),
          tooltip: '一覧と詳細を表示',
          icon: const Icon(Icons.close_fullscreen),
          onPressed: _displayModel.restoreSplit,
        ),
      ],
      ResourceListDetailPresentation.compactDetail when splitCapable => [
        IconButton(
          key: const Key('resource-restore-split'),
          tooltip: '一覧と詳細を表示',
          icon: const Icon(Icons.close_fullscreen),
          onPressed: _displayModel.restoreSplit,
        ),
      ],
      _ => const [],
    });
    // Given caller actions, when any presentation builds, then common controls
    // retain their order and the caller's widgets follow them without execution.
    actions.addAll(widget.additionalActions);
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
    if (region == null) {
      return const SizedBox.shrink();
    }
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
    if (!leadingUsable && !trailingUsable) {
      return null;
    }
    if (!trailingUsable) {
      return leading;
    }
    if (!leadingUsable) {
      return trailing;
    }
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
      ? const Center(child: Text('項目を選択してください'))
      : _ResourceDetail(
          configuration: widget.configuration,
          viewModel: widget.viewModel,
          detailSupplementBuilder: widget.detailSupplementBuilder,
        );
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
      return const Center(child: Text('一覧を読み込めませんでした。'));
    }
    if (viewModel.listLoading || viewModel.resources == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final resources = viewModel.resources!;
    if (resources.isEmpty) {
      return const Center(child: Text('項目がありません'));
    }
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
  const _ResourceDetail({
    required this.configuration,
    required this.viewModel,
    this.detailSupplementBuilder,
  });

  final ResourceListDetailConfiguration configuration;
  final ResourceViewModel viewModel;

  /// Borrows the caller's ready-record presentation builder.
  final Widget Function(BuildContext context, ResourceRecord record)?
  detailSupplementBuilder;

  List<ResourceAction> _visibleActions() {
    final available = viewModel.selectedActions;
    final configured = configuration.detailActions;
    if (configured == null) {
      return available;
    }
    final availableIds = available.map((action) => action.id).toSet();
    return [
      for (final action in configured)
        if (availableIds.contains(action.id))
          ResourceAction(id: action.id, label: action.label),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (viewModel.detailFailed) {
      return const Center(child: Text('詳細を読み込めませんでした。'));
    }
    if (viewModel.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final record = viewModel.selectedResource;
    if (record == null) return const Center(child: Text('項目が見つかりません'));
    return ListView(
      children: [
        for (final field in configuration.detailFields)
          ListTile(
            title: Text(field.label),
            subtitle: Text(record.value(field.key)),
          ),
        if (viewModel.actionFailed)
          const ListTile(title: Text('項目を更新できませんでした。')),
        for (final action in _visibleActions())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: viewModel.actionRunning
                  ? null
                  : () => viewModel.performAction(action.id),
              child: Text(action.label),
            ),
          ),
        // Given a ready selected record, when its detail is actually built,
        // then supplied content follows configured fields and actions. Ordinary
        // Flutter updates retain same-ID state and dispose removed identities.
        if (detailSupplementBuilder != null)
          KeyedSubtree(
            key: ValueKey<String>(record.id),
            child: detailSupplementBuilder!(context, record),
          ),
      ],
    );
  }
}
