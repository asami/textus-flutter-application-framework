/// The user's in-session treatment of a recognized fold or hinge.
enum ResourceListDetailHingePolicy {
  automatic,
  avoid,
  span;

  /// Stable JSON representation for configuration contracts.
  String toJson() => name;

  /// Decodes one stable configuration representation.
  static ResourceListDetailHingePolicy fromJson(String value) =>
      switch (value) {
        'automatic' => ResourceListDetailHingePolicy.automatic,
        'avoid' => ResourceListDetailHingePolicy.avoid,
        'span' => ResourceListDetailHingePolicy.span,
        _ => throw FormatException(
          'Unknown Resource List Detail hinge policy: $value',
        ),
      };
}
