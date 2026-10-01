import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../configuration/application_navigation_configuration.dart';
import 'application_text_scaling.dart';

/// Framework-owned bottom navigation with application-provided screen bodies.
class ApplicationNavigationShell extends StatefulWidget {
  const ApplicationNavigationShell({
    required this.configuration,
    required this.pages,
    super.key,
  });

  final ApplicationNavigationConfiguration configuration;
  final Map<String, Widget> pages;

  @override
  State<ApplicationNavigationShell> createState() =>
      _ApplicationNavigationShellState();
}

class _ApplicationNavigationShellState
    extends State<ApplicationNavigationShell> {
  late String _selectedId;
  late final Set<String> _visitedIds;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.configuration.initialDestinationId;
    _visitedIds = {_selectedId};
  }

  @override
  void didUpdateWidget(ApplicationNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.configuration.destinations.any(
      (destination) => destination.id == _selectedId,
    )) {
      _selectedId = widget.configuration.initialDestinationId;
      _visitedIds.add(_selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.configuration.destinations;
    final configuredIds = destinations
        .map((destination) => destination.id)
        .toSet();
    if (widget.pages.keys.toSet().difference(configuredIds).isNotEmpty ||
        configuredIds.difference(widget.pages.keys.toSet()).isNotEmpty) {
      throw ArgumentError('Pages must match configured destination ids');
    }
    final selectedIndex = destinations.indexWhere(
      (destination) => destination.id == _selectedId,
    );
    void select(int index) => setState(() {
      _selectedId = destinations[index].id;
      _visitedIds.add(_selectedId);
    });
    final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          for (var index = 0; index < destinations.length; index++)
            TickerMode(
              key: ValueKey(destinations[index].id),
              enabled: index == selectedIndex,
              child: _visitedIds.contains(destinations[index].id)
                  ? widget.pages[destinations[index].id]!
                  : const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: scaler == null
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: select,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(_iconFor(destination.symbol)),
                    label: destination.label,
                  ),
              ],
            )
          : _textDestinations(context, scaler, selectedIndex, select),
    );
  }

  Widget _textDestinations(
    BuildContext context,
    TextScaler scaler,
    int selectedIndex,
    ValueChanged<int> select,
  ) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final destinations = widget.configuration.destinations;
    final usableHeight = math.max(
      0.0,
      media.size.height - media.padding.vertical - media.viewInsets.vertical,
    );
    final bound = math.max(48.0, usableHeight * 0.35);
    return Material(
      color:
          NavigationBarTheme.of(context).backgroundColor ??
          theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : media.size.width - media.padding.horizontal;
            final cellWidth = math.max(1.0, width / destinations.length);
            final styles = [
              for (var i = 0; i < destinations.length; i++)
                theme.textTheme.labelMedium!.merge(
                  NavigationBarTheme.of(context).labelTextStyle
                      ?.resolve({if (i == selectedIndex) WidgetState.selected}),
                ),
            ];
            var rowHeight = 48.0;
            for (var i = 0; i < destinations.length; i++) {
              final painter = TextPainter(
                text: TextSpan(text: destinations[i].label, style: styles[i]),
                textDirection: Directionality.of(context),
                textScaler: scaler,
              )..layout(maxWidth: cellWidth);
              rowHeight = math.max(rowHeight, painter.height + 24 + 8 + 16);
              painter.dispose();
            }
            return SizedBox(
              key: const Key('application-text-destinations'),
              height: math.min(bound, rowHeight),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          enabled: true,
                          selected: i == selectedIndex,
                          label: destinations[i].label,
                          excludeSemantics: true,
                          onTap: () => select(i),
                          child: Tooltip(
                            message: destinations[i].label,
                            child: InkWell(
                              onTap: () => select(i),
                              child: Ink(
                                color: i == selectedIndex
                                    ? theme.colorScheme.secondaryContainer
                                    : null,
                                child: SizedBox(
                                  height: rowHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _iconFor(destinations[i].symbol),
                                          size: 24,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          destinations[i].label,
                                          style: styles[i],
                                          textScaler: scaler,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

IconData _iconFor(NavigationSymbol symbol) => switch (symbol) {
  NavigationSymbol.home => Icons.home_outlined,
  NavigationSymbol.folder => Icons.folder_outlined,
  NavigationSymbol.lightbulb => Icons.lightbulb_outline,
};
