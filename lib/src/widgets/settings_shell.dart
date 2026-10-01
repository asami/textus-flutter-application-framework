import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../settings/setting_definition.dart';
import '../settings/settings_snapshot.dart';
import '../view/settings_view.dart';
import 'application_text_scaling.dart';
import 'application_text_toolbar.dart';

/// Visual realization only; identity, values and storage remain platform-neutral.
enum SettingsPresentation { adaptive, material, cupertino }

/// Native Settings controls observing a borrowed application-session [view].
///
/// Composition owns explicit restoration and lifetime. Mounting or rebuilding
/// never loads, edits, resets or disposes the View, service or storage. Owners
/// detach this widget before disposing its View. Capabilities are immutable
/// ephemeral inputs supplied by rebuild; presentation overrides only visuals.
class SettingsShell extends StatefulWidget {
  /// Borrows [view] and resolves adaptive visuals from the ambient theme platform.
  const SettingsShell({
    required this.view,
    this.capabilities,
    this.presentation = SettingsPresentation.adaptive,
    super.key,
  });

  /// Caller-owned authority, observed directly without copying its snapshot.
  final SettingsView view;

  /// Current environment support; null means an empty capability set.
  final SettingsCapabilities? capabilities;

  /// Visual-only override; adaptive uses Cupertino on iOS, Material elsewhere.
  final SettingsPresentation presentation;

  @override
  State<SettingsShell> createState() => _SettingsShellState();
}

class _SettingsShellState extends State<SettingsShell> {
  SettingsCapabilities get _capabilities =>
      widget.capabilities ?? SettingsCapabilities();

  @override
  void initState() {
    super.initState();
    widget.view.addListener(_changed);
  }

  @override
  void didUpdateWidget(SettingsShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.view, widget.view)) {
      oldWidget.view.removeListener(_changed);
      widget.view.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.view.removeListener(_changed);
    super.dispose();
  }

  bool _permits(SettingsView view, SettingDefinition<Object> definition) =>
      mounted &&
      identical(widget.view, view) &&
      view.registry.definitions.any((entry) => identical(entry, definition)) &&
      definition.availability(_capabilities) == SettingAvailability.available;

  @override
  Widget build(BuildContext context) {
    final cupertino = switch (widget.presentation) {
      SettingsPresentation.adaptive =>
        Theme.of(context).platform == TargetPlatform.iOS,
      SettingsPresentation.material => false,
      SettingsPresentation.cupertino => true,
    };
    final view = widget.view;
    final children = <Widget>[];
    for (final group in view.registry.groups) {
      final definitions = view.registry.definitions.where(
        (definition) =>
            definition.groupId == group.id &&
            definition.availability(_capabilities) !=
                SettingAvailability.hidden,
      );
      if (definitions.isEmpty) continue;
      final rows = [
        for (final definition in definitions) _control(definition, cupertino),
      ];
      final key = ValueKey('settings-group:${group.id}');
      children.add(
        cupertino
            ? CupertinoListSection.insetGrouped(
                key: key,
                hasLeading: false,
                header: _wrapped(group.label),
                children: rows,
              )
            : Card(
                key: key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(group.label),
                    ),
                    ...rows,
                  ],
                ),
              ),
      );
    }
    children.add(_statuses(cupertino));
    children.add(
      _action(
        'Reset common settings',
        'settings-reset',
        () => _reset(cupertino),
        cupertino,
      ),
    );
    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    if (ApplicationTextScaling.maybeTextScalerOf(context) != null) {
      return LayoutBuilder(
        builder: (context, constraints) => cupertino
            ? CupertinoPageScaffold(
                navigationBar: ApplicationTextCupertinoBar(
                  context,
                  width: constraints.maxWidth,
                ),
                child: body,
              )
            : Scaffold(
                appBar: applicationTextAppBar(
                  context,
                  title: 'Settings',
                  width: constraints.maxWidth,
                ),
                body: body,
              ),
      );
    }
    return cupertino
        ? CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Settings'),
            ),
            child: body,
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: body,
          );
  }

  Widget _control(SettingDefinition<Object> definition, bool cupertino) {
    final view = widget.view;
    final value = view.value(definition);
    final label = definition.choices
        .firstWhere((choice) => choice.value == value)
        .label;
    final enabled =
        definition.availability(_capabilities) == SettingAvailability.available;
    final binary =
        definition.choices.length == 2 &&
        definition.choices.any((choice) => choice.value == false) &&
        definition.choices.any((choice) => choice.value == true);
    final key = ValueKey('settings-control:${definition.id}');
    final description = [
      label,
      if (!enabled) 'Unavailable in this environment',
    ].join('\n');
    void toggle(bool next) {
      if (_permits(view, definition)) view.setValue(definition.id, next);
    }

    if (!cupertino) {
      if (binary) {
        return SwitchListTile(
          key: key,
          title: Text(definition.label),
          subtitle: Text(description),
          value: value as bool,
          onChanged: enabled ? toggle : null,
        );
      }
      return ListTile(
        key: key,
        title: Text(definition.label),
        subtitle: Text(description),
        enabled: enabled,
        onTap: enabled ? () => _choose(definition, cupertino) : null,
      );
    }
    return MergeSemantics(
      child: Semantics(
        enabled: enabled,
        value: label,
        child: CupertinoListTile.notched(
          key: key,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_wrapped(definition.label), _wrapped(description)],
          ),
          trailing: binary
              ? CupertinoSwitch(
                  value: value as bool,
                  onChanged: enabled ? toggle : null,
                )
              : const CupertinoListTileChevron(),
          onTap: !binary && enabled
              ? () => _choose(definition, cupertino)
              : null,
        ),
      ),
    );
  }

  Future<void> _choose(
    SettingDefinition<Object> definition,
    bool cupertino,
  ) async {
    final view = widget.view;
    final current = view.value(definition);
    Widget choice(int index, BuildContext modalContext) {
      final entry = definition.choices[index];
      final selected = entry.value == current;
      final title = Semantics(
        selected: selected,
        value: selected ? 'Current value' : null,
        child: _modalText(
          '${selected ? '✓ ' : ''}${entry.label}',
          logicalSize: cupertino ? 21 : null,
        ),
      );
      final key = ValueKey('settings-choice:${definition.id}:$index');
      void select() => Navigator.of(modalContext).pop(entry.value);
      return cupertino
          ? CupertinoActionSheetAction(
              key: key,
              onPressed: select,
              child: title,
            )
          : SimpleDialogOption(key: key, onPressed: select, child: title);
    }

    final Object? selected;
    if (cupertino) {
      selected = await showCupertinoModalPopup<Object>(
        context: context,
        useRootNavigator: false,
        builder: (modalContext) => CupertinoActionSheet(
          title: _modalText(definition.label, logicalSize: 13),
          actions: [
            for (var i = 0; i < definition.choices.length; i++)
              choice(i, modalContext),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(modalContext).pop(),
            child: _modalText('Cancel', logicalSize: 21),
          ),
        ),
      );
    } else {
      selected = await showDialog<Object>(
        context: context,
        useRootNavigator: false,
        builder: (modalContext) => SimpleDialog(
          title: _materialChoiceTitle(definition.label),
          children: [
            for (var i = 0; i < definition.choices.length; i++)
              choice(i, modalContext),
          ],
        ),
      );
    }
    if (selected != null && _permits(view, definition)) {
      view.setValue(definition.id, selected);
    }
  }

  Future<void> _reset(bool cupertino) async {
    final view = widget.view;
    Widget dialog(BuildContext modalContext) {
      final cancelKey = const ValueKey('settings-reset-cancel');
      final resetKey = const ValueKey('settings-reset-confirm');
      void cancel() => Navigator.of(modalContext).pop(false);
      void reset() => Navigator.of(modalContext).pop(true);
      final title = _modalText(
        'Reset common settings?',
        logicalSize: cupertino ? 17 : null,
      );
      final explanation = _modalText(
        'Restore common defaults. Application settings are kept.',
        logicalSize: cupertino ? 13 : null,
      );
      return cupertino
          ? CupertinoAlertDialog(
              title: title,
              content: explanation,
              actions: [
                CupertinoDialogAction(
                  key: cancelKey,
                  onPressed: cancel,
                  child: _modalText('Cancel', logicalSize: 16.8),
                ),
                CupertinoDialogAction(
                  key: resetKey,
                  onPressed: reset,
                  child: _modalText('Reset', logicalSize: 16.8),
                ),
              ],
            )
          : AlertDialog(
              scrollable:
                  ApplicationTextScaling.maybeTextScalerOf(modalContext) !=
                  null,
              title: title,
              content: explanation,
              actions: [
                TextButton(
                  key: cancelKey,
                  onPressed: cancel,
                  child: _modalText('Cancel'),
                ),
                TextButton(
                  key: resetKey,
                  onPressed: reset,
                  child: _modalText('Reset'),
                ),
              ],
            );
    }

    final confirmed = cupertino
        ? await showCupertinoDialog<bool>(
            context: context,
            useRootNavigator: false,
            builder: dialog,
          )
        : await showDialog<bool>(
            context: context,
            useRootNavigator: false,
            builder: dialog,
          );
    if (confirmed == true && mounted && identical(widget.view, view)) {
      view.resetCommon();
    }
  }

  Widget _statuses(bool cupertino) {
    final view = widget.view;
    final snapshot = view.snapshot;
    final children = <Widget>[];
    switch (snapshot.readState) {
      case SettingsReadState.notLoaded:
        children.add(const Text('Settings not loaded'));
        children.add(
          _action('Load settings', 'settings-load', view.load, cupertino),
        );
      case SettingsReadState.loading:
        children.add(const Text('Loading settings'));
      case SettingsReadState.failed:
        children.add(const Text('Settings could not be loaded'));
        children.add(
          _action(
            'Retry loading',
            'settings-retry-load',
            view.retryLoad,
            cupertino,
          ),
        );
      case SettingsReadState.unsupported:
        children.add(const Text('Unsupported settings format'));
        children.add(
          _action(
            'Retry loading',
            'settings-retry-load',
            view.retryLoad,
            cupertino,
          ),
        );
      case SettingsReadState.ready:
        break;
    }
    switch (snapshot.saveState) {
      case SettingsSaveState.saving:
        children.add(const Text('Saving settings'));
      case SettingsSaveState.failed:
        children.add(const Text('Settings could not be saved'));
        children.add(
          _action(
            'Retry saving',
            'settings-retry-save',
            view.retrySave,
            cupertino,
          ),
        );
      case SettingsSaveState.idle:
        break;
    }
    if (snapshot.unsavedIds.isNotEmpty) {
      children.add(const Text('Unsaved changes'));
    } else if (snapshot.readState == SettingsReadState.ready &&
        snapshot.saveState == SettingsSaveState.idle) {
      children.add(const Text('Changes saved'));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _action(
    String label,
    String key,
    VoidCallback callback,
    bool cupertino,
  ) => cupertino
      ? CupertinoButton(
          key: ValueKey(key),
          onPressed: callback,
          child: Text(label),
        )
      : TextButton(key: ValueKey(key), onPressed: callback, child: Text(label));

  // CupertinoListTile's inherited one-line style must not truncate schema text.
  Widget _wrapped(String text) => Builder(
    builder: (context) => DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      child: Text(text, softWrap: true, overflow: TextOverflow.visible),
    ),
  );

  // Bound only the opted-in title; SimpleDialog keeps its native option scroll.
  Widget _materialChoiceTitle(String text) => Builder(
    builder: (context) {
      if (ApplicationTextScaling.maybeTextScalerOf(context) == null) {
        return _modalText(text);
      }
      final media = MediaQuery.of(context);
      final usable =
          media.size.height -
          media.padding.vertical -
          media.viewInsets.vertical -
          48;
      final available = usable.isFinite ? math.max(0.0, usable) : 0.0;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: available * 0.35),
        child: SingleChildScrollView(
          key: const Key('settings-choice-title-viewport'),
          child: _modalText(text),
        ),
      );
    },
  );

  // Resolve inside each native role, observing the live app scope through modal
  // rebuilds while retaining native colors/weights and the original role size.
  Widget _modalText(String text, {double? logicalSize}) => Builder(
    builder: (context) {
      final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
      if (scaler == null) return Text(text);
      final style = DefaultTextStyle.of(context).style;
      return DefaultTextStyle(
        style: logicalSize == null
            ? style
            : style.copyWith(fontSize: logicalSize),
        child: Text(
          text,
          textScaler: scaler,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      );
    },
  );
}
