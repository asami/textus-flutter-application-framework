/// A framework-defined symbol for a navigation destination.
enum NavigationSymbol {
  home,
  folder,
  lightbulb;

  static NavigationSymbol fromJson(String value) {
    for (final symbol in values) {
      if (symbol.name == value) return symbol;
    }
    throw FormatException('Unknown navigation symbol: $value');
  }
}

/// One application-supplied destination in the framework navigation model.
class NavigationDestinationConfiguration {
  const NavigationDestinationConfiguration({
    required this.id,
    required this.label,
    required this.symbol,
  });

  final String id;
  final String label;
  final NavigationSymbol symbol;

  factory NavigationDestinationConfiguration.fromJson(
    Map<String, dynamic> json,
  ) => NavigationDestinationConfiguration(
    id: json['id'] as String,
    label: json['label'] as String,
    symbol: NavigationSymbol.fromJson(json['symbol'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'symbol': symbol.name,
  };
}

/// Serializable destination order and initial selection for bottom navigation.
class ApplicationNavigationConfiguration {
  ApplicationNavigationConfiguration({
    required this.initialDestinationId,
    required List<NavigationDestinationConfiguration> destinations,
  }) : destinations = List.unmodifiable(destinations) {
    if (destinations.length < 2) {
      throw const FormatException('At least two destinations are required');
    }
    final ids = <String>{};
    for (final destination in destinations) {
      if (destination.id.trim().isEmpty || destination.label.trim().isEmpty) {
        throw const FormatException('Destination id and label are required');
      }
      if (!ids.add(destination.id)) {
        throw FormatException('Duplicate destination id: ${destination.id}');
      }
    }
    if (!ids.contains(initialDestinationId)) {
      throw FormatException(
        'Unknown initial destination: $initialDestinationId',
      );
    }
  }

  final String initialDestinationId;
  final List<NavigationDestinationConfiguration> destinations;

  factory ApplicationNavigationConfiguration.fromJson(
    Map<String, dynamic> json,
  ) => ApplicationNavigationConfiguration(
    initialDestinationId: json['initialDestinationId'] as String,
    destinations: (json['destinations'] as List<dynamic>)
        .map(
          (destination) => NavigationDestinationConfiguration.fromJson(
            destination as Map<String, dynamic>,
          ),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'initialDestinationId': initialDestinationId,
    'destinations': destinations
        .map((destination) => destination.toJson())
        .toList(),
  };
}
