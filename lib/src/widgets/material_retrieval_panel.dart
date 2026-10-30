import 'dart:async';

import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../retrieval/material_retrieval_controller.dart';

/// Reusable query/results UI. Its caller retains all controller/source ownership.
class MaterialRetrievalPanel extends StatefulWidget {
  const MaterialRetrievalPanel({
    required this.controller,
    required this.onOpen,
    this.interactionAllowed,
    super.key,
  });

  final MaterialRetrievalController controller;
  final Future<void> Function(MaterialRetrievalDocument) onOpen;
  final bool Function()? interactionAllowed;

  @override
  State<MaterialRetrievalPanel> createState() => _MaterialRetrievalPanelState();
}

class _MaterialRetrievalPanelState extends State<MaterialRetrievalPanel> {
  late final TextEditingController _input;
  int _epoch = 0;
  Object? _opening;
  bool _openFailed = false;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.controller.query);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    final text = widget.controller.query;
    if (_input.text != text) {
      _input.value = TextEditingValue(text: text,
        selection: TextSelection.collapsed(offset: text.length));
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant MaterialRetrievalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.onOpen, widget.onOpen) ||
        !identical(oldWidget.interactionAllowed, widget.interactionAllowed)) {
      _epoch++;
      _opening = null;
      _openFailed = false;
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _input.value = TextEditingValue(text: widget.controller.query,
        selection: TextSelection.collapsed(offset: widget.controller.query.length));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _input.dispose();
    super.dispose();
  }

  _RetrievalRender _capture() => _RetrievalRender(widget.controller,
    widget.onOpen, widget.interactionAllowed, _epoch,
    widget.controller.resultVersion, widget.controller.query,
    widget.controller.result, ModalRoute.of(context));

  bool _same(_RetrievalRender render, {
    bool requireCurrentRoute = true, int? admissionVersion,
  }) =>
      mounted && render.epoch == _epoch &&
      identical(render.controller, widget.controller) &&
      identical(render.onOpen, widget.onOpen) &&
      identical(render.interactionAllowed, widget.interactionAllowed) &&
      !render.controller.isClosed &&
      render.query == render.controller.query &&
      (admissionVersion ?? render.version) == render.controller.resultVersion &&
      identical(render.result, render.controller.result) &&
      identical(render.route, ModalRoute.of(context)) &&
      (render.route == null || (render.route!.isActive &&
        (!requireCurrentRoute || render.route!.isCurrent)));

  bool _admitted(_RetrievalRender render, {int? admissionVersion}) {
    if (!_same(render, admissionVersion: admissionVersion)) {
      return false;
    }
    try {
      final allowed = render.interactionAllowed?.call() ?? true;
      return allowed && _same(render, admissionVersion: admissionVersion);
    } catch (_) {
      return false;
    }
  }

  void _command(_RetrievalRender render, String action) {
    if (!_admitted(render) || (_opening != null && action != 'cancel')) {
      return;
    }
    final controller = render.controller;
    _openFailed = false;
    switch (action) {
      case 'search':
        if (controller.canSearch) {
          unawaited(controller.search());
        }
      case 'cancel':
        if (controller.canCancel) {
          controller.cancel();
        }
      case 'rebuild':
        if (!controller.busy) {
          unawaited(controller.rebuild());
        }
    }
  }

  Future<void> _open(_RetrievalRender render, MaterialRetrievalHit hit) async {
    if (!_admitted(render) || _opening != null || render.controller.busy ||
        !(render.result?.hits.any((value) => identical(value, hit)) ?? false)) {
      return;
    }
    final operation = Object();
    setState(() {
      _opening = operation;
      _openFailed = false;
    });
    int? admissionVersion;
    try {
      // setState does not grant a new owner permission to consume this result.
      if (!_admitted(render) || !identical(_opening, operation)) {
        return;
      }
      final pending = render.controller.resolveHit(hit);
      admissionVersion = render.controller.resultVersion;
      final resolution = await pending;
      if (!_admitted(render, admissionVersion: admissionVersion) ||
          !identical(_opening, operation) ||
          resolution == null ||
          resolution.status != MaterialRetrievalResolutionStatus.available ||
          resolution.document != hit.document) {
        return;
      }
      // The callback may push a route and await it. No route-current fence is
      // applied inside that caller-owned navigation future.
      await render.onOpen(resolution.document!);
    } catch (_) {
      if (_same(render, admissionVersion: admissionVersion) &&
          identical(_opening, operation)) {
        setState(() => _openFailed = true);
      }
    } finally {
      if (mounted && identical(_opening, operation)) {
        setState(() => _opening = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final render = _capture();
    final result = controller.result;
    final stale = controller.resolution?.status == MaterialRetrievalResolutionStatus.stale;
    final unavailable = controller.resolution?.status ==
        MaterialRetrievalResolutionStatus.unavailable;
    final active = !controller.isClosed && _opening == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('端末内の語句一致検索'),
      const Text('空白で区切った語句をすべて含む資料を検索します'),
      TextField(key: const ValueKey('material-retrieval-query'),
        controller: _input,
        enabled: !controller.isClosed,
        decoration: const InputDecoration(labelText: '検索する語句'),
        onChanged: (value) {
          // Input stays editable during cleanup; query changes retire old work.
          if (_admitted(render)) {
            _openFailed = false;
            render.controller.setQuery(value);
          } else if (mounted && identical(widget.controller, render.controller)) {
            _changed();
          }
        }),
      Wrap(spacing: 8, children: [
        FilledButton(key: const ValueKey('material-retrieval-search'),
          onPressed: active && controller.canSearch
              ? () => _command(render, 'search') : null,
          child: const Text('検索')),
        TextButton(key: const ValueKey('material-retrieval-cancel'),
          onPressed: !controller.isClosed && controller.canCancel
              ? () => _command(render, 'cancel') : null,
          child: const Text('取消')),
        TextButton(key: const ValueKey('material-retrieval-rebuild'),
          onPressed: active && !controller.busy
              ? () => _command(render, 'rebuild') : null,
          child: const Text('索引を再作成')),
      ]),
      if (controller.busy) ...[
        const LinearProgressIndicator(),
        Text(controller.canCancel
          ? (controller.status == MaterialRetrievalStatus.rebuilding
            ? '索引を再作成中です' : '資料を確認中です')
          : '元の処理の終了を待っています'),
      ],
      if (!controller.busy && controller.status == MaterialRetrievalStatus.empty)
        const Text('一致する資料はありません'),
      if (controller.status == MaterialRetrievalStatus.error)
        Text(controller.error is ArgumentError
          ? '検索語句が上限を超えています。語句を短くして再検索してください'
          : '検索処理に失敗しました。再検索または索引の再作成をお試しください'),
      if (controller.status == MaterialRetrievalStatus.unavailable && !unavailable)
        const Text('この環境では検索を利用できません'),
      if (controller.status == MaterialRetrievalStatus.canceled)
        const Text('検索操作を取り消しました'),
      if (controller.rebuildCompleted)
        const Text('索引を再作成しました。検索ボタンで再検索してください'),
      if (stale)
        const Text('出典が更新されています。再検索して現在の出典を確認してください'),
      if (unavailable)
        const Text('出典は削除されたか、現在は参照できません。再検索してください'),
      if (_openFailed)
        const Text('資料を開けませんでした。再検索してからお試しください'),
      if (result != null) ...[
        Text('${result.hits.length}件表示 / ${result.totalMatches}件一致'
          '・対象${result.indexedSourceCount}件'),
        if (result.hasMore) const Text('表示上限を超える結果があります'),
        Text('検索方式：${result.capability.mode.name}'),
        if (stale || unavailable) const Text('検索時点の参考情報（開くことはできません）'),
        for (var i = 0; i < result.hits.length; i++)
          Card(child: Padding(padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(result.hits[i].document.title),
              Text(result.hits[i].document.sourceLabel),
              if (result.hits[i].snippetStart > 0) const Text('前略'),
              SelectableText(result.hits[i].snippet),
              if (result.hits[i].snippetEnd < result.hits[i].document.text.runes.length)
                const Text('後略'),
              TextButton(key: ValueKey('material-retrieval-open-$i'),
                onPressed: active && !controller.busy && !stale && !unavailable
                    ? () => unawaited(_open(render, result.hits[i])) : null,
                child: const Text('開く')),
            ]))),
      ],
    ]);
  }
}

final class _RetrievalRender {
  const _RetrievalRender(this.controller, this.onOpen, this.interactionAllowed,
    this.epoch, this.version, this.query, this.result, this.route);
  final MaterialRetrievalController controller;
  final Future<void> Function(MaterialRetrievalDocument) onOpen;
  final bool Function()? interactionAllowed;
  final int epoch;
  final int version;
  final String query;
  final MaterialRetrievalResult? result;
  final ModalRoute<dynamic>? route;
}
