import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Complete producer-supplied identity, without allocation policy.
final class DisplayDefinitionKey {
  DisplayDefinitionKey({
    required String namespace,
    required String presentationSet,
    required String armId,
    required int definitionVersion,
  }) : namespace = identifier(namespace),
       presentationSet = identifier(presentationSet),
       armId = identifier(armId),
       definitionVersion = positiveVersion(definitionVersion);
  final String namespace;
  final String presentationSet;
  final String armId;
  final int definitionVersion;
  @override
  bool operator ==(Object other) =>
      other is DisplayDefinitionKey &&
      namespace == other.namespace &&
      presentationSet == other.presentationSet &&
      armId == other.armId &&
      definitionVersion == other.definitionVersion;
  @override
  int get hashCode =>
      Object.hash(namespace, presentationSet, armId, definitionVersion);
}

/// Generic styles; no experiment evaluation is performed.
enum DisplayDefinitionStyle { standard, cards, sections }

/// Immutable presentation data scoped to a resource and two screens.
final class DisplayUiDefinition {
  DisplayUiDefinition({
    required String id,
    required int version,
    required String resourceType,
    required String listScreenId,
    required String detailScreenId,
    required this.style,
    this.available = true,
  }) : id = identifier(id),
       version = positiveVersion(version),
       resourceType = identifier(resourceType),
       listScreenId = identifier(listScreenId),
       detailScreenId = identifier(detailScreenId);
  final String id;
  final int version;
  final String resourceType;
  final String listScreenId;
  final String detailScreenId;
  final DisplayDefinitionStyle style;
  final bool available;
  @override
  bool operator ==(Object other) =>
      other is DisplayUiDefinition &&
      id == other.id &&
      version == other.version &&
      resourceType == other.resourceType &&
      listScreenId == other.listScreenId &&
      detailScreenId == other.detailScreenId &&
      style == other.style &&
      available == other.available;
  @override
  int get hashCode => Object.hash(
    id,
    version,
    resourceType,
    listScreenId,
    detailScreenId,
    style,
    available,
  );
}

/// One full-key registration.
final class DisplayDefinitionRegistration {
  const DisplayDefinitionRegistration({
    required this.key,
    required this.definition,
  });
  final DisplayDefinitionKey key;
  final DisplayUiDefinition definition;
}

/// Visible compatibility failures, separate from Core admission failures.
enum DisplayDefinitionFailureKind {
  missingNeutral,
  unknownArm,
  unsupportedVersion,
  unavailableDefinition,
  incompatibleDefinition,
  unsupportedArmFamily,
  definitionChangeRequiresDiscard,
}

/// An immutable presentation compatibility diagnostic.
final class DisplayDefinitionFailure {
  const DisplayDefinitionFailure({required this.kind, required this.message});
  final DisplayDefinitionFailureKind kind;
  final String message;
}

/// Immutable resolution; failure never substitutes another definition.
final class DisplayDefinitionResolution {
  const DisplayDefinitionResolution._({
    this.key,
    this.definition,
    this.failure,
  });

  /// Creates an explicit failed resolution without an available definition.
  factory DisplayDefinitionResolution.failed(
    DisplayDefinitionFailure failure, {
    DisplayDefinitionKey? key,
  }) => DisplayDefinitionResolution._(key: key, failure: failure);
  final DisplayDefinitionKey? key;
  final DisplayUiDefinition? definition;
  final DisplayDefinitionFailure? failure;
  bool get isAvailable =>
      failure == null && definition != null && definition!.available;
}

/// Pure lookup over defensively frozen registration data.
final class DisplayDefinitionRegistry {
  DisplayDefinitionRegistry({
    required Iterable<DisplayDefinitionRegistration> registrations,
    this.neutralDefinition,
  }) : registrations = List.unmodifiable(registrations) {
    final map = <DisplayDefinitionKey, DisplayUiDefinition>{};
    for (final entry in this.registrations) {
      if (entry.key.definitionVersion != entry.definition.version) {
        throw ArgumentError('Definition and key versions differ');
      }
      if (map.containsKey(entry.key)) {
        throw ArgumentError('Duplicate definition key');
      }
      map[entry.key] = entry.definition;
    }
    _definitions = Map.unmodifiable(map);
  }
  final List<DisplayDefinitionRegistration> registrations;
  final DisplayUiDefinition? neutralDefinition;
  late final Map<DisplayDefinitionKey, DisplayUiDefinition> _definitions;

  /// Resolves admitted context without ports, clocks or assignments.
  DisplayDefinitionResolution resolve({
    required PresentationContext context,
    required String resourceType,
    required String listScreenId,
    required String detailScreenId,
  }) {
    identifier(resourceType);
    identifier(listScreenId);
    identifier(detailScreenId);
    final arms = context.families.where(
      (family) => family.namespace == 'textus.presentation.arm',
    );
    DisplayDefinitionKey? key;
    DisplayUiDefinition? definition;
    if (arms.isEmpty) {
      definition = neutralDefinition;
      if (definition == null) {
        return failedResolution(DisplayDefinitionFailureKind.missingNeutral);
      }
    } else {
      final family = arms.single;
      final payload = family.payload;
      if (family.version != 1 || payload is! SuppliedArmPresentationPayload) {
        return failedResolution(
          DisplayDefinitionFailureKind.unsupportedArmFamily,
        );
      }
      final suppliedKey = DisplayDefinitionKey(
        namespace: payload.namespace,
        presentationSet: payload.presentationSet,
        armId: payload.armId,
        definitionVersion: payload.definitionVersion,
      );
      key = suppliedKey;
      definition = _definitions[suppliedKey];
      if (definition == null) {
        final knownTriple = _definitions.keys.any(
          (entry) =>
              entry.namespace == suppliedKey.namespace &&
              entry.presentationSet == suppliedKey.presentationSet &&
              entry.armId == suppliedKey.armId,
        );
        return failedResolution(
          knownTriple
              ? DisplayDefinitionFailureKind.unsupportedVersion
              : DisplayDefinitionFailureKind.unknownArm,
          key: key,
        );
      }
    }
    if (!definition.available) {
      return failedResolution(
        DisplayDefinitionFailureKind.unavailableDefinition,
        key: key,
      );
    }
    if (definition.resourceType != resourceType ||
        definition.listScreenId != listScreenId ||
        definition.detailScreenId != detailScreenId) {
      return failedResolution(
        DisplayDefinitionFailureKind.incompatibleDefinition,
        key: key,
      );
    }
    return DisplayDefinitionResolution._(key: key, definition: definition);
  }
}

DisplayDefinitionResolution failedResolution(
  DisplayDefinitionFailureKind kind, {
  DisplayDefinitionKey? key,
}) => DisplayDefinitionResolution.failed(
  DisplayDefinitionFailure(
    kind: kind,
    message: 'Presentation definition: ${kind.name}',
  ),
  key: key,
);
String identifier(String value) {
  if (value.replaceAll('\u0085', ' ').trim().isEmpty) {
    throw ArgumentError.value(value, 'identifier', 'Must be nonblank');
  }
  return value;
}

int positiveVersion(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'version', 'Must be positive');
  }
  return value;
}
