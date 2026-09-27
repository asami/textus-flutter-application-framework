/// Selects who realizes an application presentation unit.
///
/// Standard presentations default to [PresentationRealization.framework].
enum PresentationRealization {
  /// TFAF renders the presentation from configuration.
  framework,

  /// Generated application source renders the presentation.
  generated,

  /// TFAF renders the standard behavior with application extensions.
  hybrid,

  /// Application-owned source renders the presentation.
  custom;

  /// Reads the stable configuration value used by future Cozy output.
  static PresentationRealization fromJson(String value) =>
      PresentationRealization.values.byName(value);

  /// Writes the stable configuration value used by future Cozy output.
  String toJson() => name;
}
