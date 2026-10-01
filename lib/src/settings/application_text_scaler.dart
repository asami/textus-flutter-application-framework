import 'package:flutter/painting.dart';

import 'common_settings.dart';

/// Composes the catalogued app preference with the original OS scaling function.
///
/// For logical size s, the result is multiplier * systemTextScaler.scale(s).
/// Recomposition replaces this helper's app multiplier; Standard returns the
/// original OS scaler, including its nonlinear accessibility behavior.
TextScaler composeApplicationTextScaler({
  required TextScaler systemTextScaler,
  required double multiplier,
}) {
  CommonSettings.textSizeMultiplier.validate(multiplier);
  final source = systemTextScaler is _ApplicationTextScaler
      ? systemTextScaler.source
      : systemTextScaler;
  return multiplier == 1.0
      ? source
      : _ApplicationTextScaler(source, multiplier);
}

final class _ApplicationTextScaler extends TextScaler {
  const _ApplicationTextScaler(this.source, this.multiplier);

  final TextScaler source;
  final double multiplier;

  @override
  double scale(double fontSize) => multiplier * source.scale(fontSize);

  // Legacy approximation only. Presentation always calls scale(logicalSize).
  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _ApplicationTextScaler &&
      source == other.source &&
      multiplier == other.multiplier;

  @override
  int get hashCode => Object.hash(source, multiplier);
}
