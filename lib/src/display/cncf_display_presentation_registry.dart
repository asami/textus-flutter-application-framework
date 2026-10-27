import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../configuration/resource_list_detail_configuration.dart';

/// A redacted reason that a supplied formal presentation cannot be realized.
enum CncfDisplayPresentationFailure { incompatibleDisplay, unknownVariant }

/// The immutable result of resolving one formal Display observation.
final class CncfDisplayPresentationResolution {
  const CncfDisplayPresentationResolution._({
    this.configuration,
    this.variant,
    this.failure,
  });

  final ResourceListDetailConfiguration? configuration;
  final String? variant;
  final CncfDisplayPresentationFailure? failure;
  bool get isAvailable => configuration != null && failure == null;
}

/// Realizes an exact supplied cncf.presentation/1 variant using trusted entries.
///
/// This registry has no allocation, transport, credential, or session policy.
/// Other context families retain the formal Core decoder's inert semantics.
final class CncfDisplayPresentationRegistry {
  CncfDisplayPresentationRegistry({
    required this.profile,
    required ResourceListDetailConfiguration neutralConfiguration,
    required Map<String, ResourceListDetailConfiguration> variants,
  }) : neutralConfiguration = _freezeConfiguration(neutralConfiguration),
       variants = Map.unmodifiable({
         for (final entry in variants.entries)
           _variantKey(entry.key): _freezeConfiguration(entry.value),
       });

  final CncfDisplayReadProfile profile;
  final ResourceListDetailConfiguration neutralConfiguration;
  final Map<String, ResourceListDetailConfiguration> variants;

  CncfDisplayPresentationResolution resolve(CncfDisplayRead? observation) {
    if (observation == null) return _neutral;
    final CncfDisplayRead admitted;
    try {
      final detail = observation.model['type'] == 'detail';
      admitted = CncfDisplayRead.decode(
        observation.wire,
        profile,
        detail: detail,
        expectedResourceId: detail
            ? observation.resources.single.entityId
            : null,
      );
    } on CncfDisplayReadException {
      return const CncfDisplayPresentationResolution._(
        failure: CncfDisplayPresentationFailure.incompatibleDisplay,
      );
    }
    final context = admitted.presentationContext;
    if (context == null) return _neutral;
    for (final item in context['families']! as List) {
      final family = item as Map<String, Object?>;
      if (family['name'] != 'cncf.presentation' || family['version'] != 1) {
        continue;
      }
      final variant =
          (family['data']! as Map<String, Object?>)['variant']! as String;
      final configuration = variants[variant];
      return CncfDisplayPresentationResolution._(
        configuration: configuration,
        variant: variant,
        failure: configuration == null
            ? CncfDisplayPresentationFailure.unknownVariant
            : null,
      );
    }
    return _neutral;
  }

  CncfDisplayPresentationResolution get _neutral =>
      CncfDisplayPresentationResolution._(configuration: neutralConfiguration);

  static String _variantKey(String value) {
    if (value.trim().isEmpty || value.length > 128) {
      throw ArgumentError(
        'Variant keys must be nonblank and at most 128 characters',
      );
    }
    return value;
  }

  static ResourceListDetailConfiguration _freezeConfiguration(
    ResourceListDetailConfiguration configuration,
  ) {
    try {
      return ResourceListDetailConfiguration.fromJson(configuration.toJson());
    } on FormatException {
      throw ArgumentError('Invalid presentation configuration');
    } on TypeError {
      throw ArgumentError('Invalid presentation configuration');
    }
  }
}
