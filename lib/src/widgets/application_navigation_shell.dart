import 'package:flutter/material.dart';

import '../configuration/application_navigation_configuration.dart';

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedId = destinations[index].id;
          _visitedIds.add(_selectedId);
        }),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(_iconFor(destination.symbol)),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

IconData _iconFor(NavigationSymbol symbol) => switch (symbol) {
  NavigationSymbol.home => Icons.home_outlined,
  NavigationSymbol.folder => Icons.folder_outlined,
  NavigationSymbol.lightbulb => Icons.lightbulb_outline,
};
