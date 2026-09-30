import 'setting_definition.dart';
import 'settings_registry.dart';

/// Global pane preference, separate from presentation-session display state.
enum SettingsPanePreference { automatic, preferSinglePane, preferDualPane }

/// Global hinge preference, mapped to session policy by a later resolver.
enum SettingsHingePreference { automatic, avoid, span }

/// Stable common catalog and explicit application extension composition.
abstract final class CommonSettings {
  /// Standard group identities and presentation order.
  static final List<SettingGroup> groups = List.unmodifiable([
    SettingGroup(id: 'appearance', label: 'Appearance'),
    SettingGroup(id: 'layout', label: 'Layout'),
    SettingGroup(id: 'accessibility', label: 'Accessibility'),
    SettingGroup(id: 'application', label: 'Application'),
  ]);

  /// Pane preference; automatic preserves adaptive configuration behavior.
  static final panePreference = SettingDefinition<SettingsPanePreference>(
    id: 'textus.layout.panePreference',
    groupId: 'layout',
    label: 'Pane preference',
    defaultValue: SettingsPanePreference.automatic,
    choices: [
      SettingChoice(
        value: SettingsPanePreference.automatic,
        label: 'Automatic',
        storedValue: 'automatic',
      ),
      SettingChoice(
        value: SettingsPanePreference.preferSinglePane,
        label: 'Prefer single pane',
        storedValue: 'preferSinglePane',
      ),
      SettingChoice(
        value: SettingsPanePreference.preferDualPane,
        label: 'Prefer dual pane',
        storedValue: 'preferDualPane',
      ),
    ],
  );

  /// Hinge preference retained even when the hinge control is disabled.
  static final hingePreference = SettingDefinition<SettingsHingePreference>(
    id: 'textus.layout.hingePreference',
    groupId: 'layout',
    label: 'Hinge preference',
    defaultValue: SettingsHingePreference.automatic,
    requiredCapability: 'hinge',
    availabilityPolicy: SettingAvailabilityPolicy.disableWhenUnsupported,
    choices: [
      SettingChoice(
        value: SettingsHingePreference.automatic,
        label: 'Automatic',
        storedValue: 'automatic',
      ),
      SettingChoice(
        value: SettingsHingePreference.avoid,
        label: 'Avoid hinge',
        storedValue: 'avoid',
      ),
      SettingChoice(
        value: SettingsHingePreference.span,
        label: 'Span hinge',
        storedValue: 'span',
      ),
    ],
  );

  /// User multiplier to compose with OS accessibility scaling in the successor.
  static final textSizeMultiplier = SettingDefinition<double>(
    id: 'textus.appearance.textSizeMultiplier',
    groupId: 'appearance',
    label: 'Text size',
    defaultValue: 1.0,
    choices: [
      SettingChoice(value: 1.0, label: 'Standard', storedValue: 1.0),
      SettingChoice(value: 1.15, label: 'Larger', storedValue: 1.15),
      SettingChoice(value: 1.30, label: 'Largest', storedValue: 1.30),
    ],
  );

  /// Immutable common definitions; reset affects these identities only.
  static final List<SettingDefinition<Object>> definitions = List.unmodifiable([
    panePreference,
    hingePreference,
    textSizeMultiplier,
  ]);

  /// Creates an isolated registry with extensions after the common catalog.
  /// Duplicate common/extension identities and unresolved groups are rejected.
  static SettingsRegistry registry({
    List<SettingGroup> extensionGroups = const [],
    List<SettingDefinition<Object>> extensions = const [],
  }) => SettingsRegistry(
    groups: [...groups, ...extensionGroups],
    definitions: [...definitions, ...extensions],
  );
}
