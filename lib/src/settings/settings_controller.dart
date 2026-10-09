import 'package:textus_flutter_core/textus_flutter_core.dart' as core;

import 'common_settings.dart';
import 'settings_registry.dart';

/// Caller-compatible common settings authority backed by Core's lifecycle.
/// Storage stays caller-owned; construction performs no load or write.
class SettingsController extends core.SettingsLifecycleController {
  /// Composes the unchanged common catalog with optional registered extensions.
  SettingsController({
    SettingsRegistry? registry,
    required super.storage,
  }) : super(
         registry: _commonRegistry(registry),
         resetDefinitions: CommonSettings.definitions,
       );
}

SettingsRegistry _commonRegistry(SettingsRegistry? supplied) {
  final registry = supplied ?? CommonSettings.registry();
  for (final definition in CommonSettings.definitions) {
    registry.requireRegistered(definition);
  }
  return registry;
}
