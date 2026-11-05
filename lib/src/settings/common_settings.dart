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
    SettingGroup(id: 'appearance', label: '外観'),
    SettingGroup(id: 'layout', label: '画面構成'),
    SettingGroup(id: 'accessibility', label: 'アクセシビリティ'),
    SettingGroup(id: 'application', label: 'アプリ'),
  ]);

  /// Pane preference; automatic preserves adaptive configuration behavior.
  static final panePreference = SettingDefinition<SettingsPanePreference>(
    id: 'textus.layout.panePreference',
    groupId: 'layout',
    label: '画面の分割',
    defaultValue: SettingsPanePreference.automatic,
    choices: [
      SettingChoice(
        value: SettingsPanePreference.automatic,
        label: '自動',
        storedValue: 'automatic',
      ),
      SettingChoice(
        value: SettingsPanePreference.preferSinglePane,
        label: '1画面を優先',
        storedValue: 'preferSinglePane',
      ),
      SettingChoice(
        value: SettingsPanePreference.preferDualPane,
        label: '2画面を優先',
        storedValue: 'preferDualPane',
      ),
    ],
  );

  /// Hinge preference retained even when the hinge control is disabled.
  static final hingePreference = SettingDefinition<SettingsHingePreference>(
    id: 'textus.layout.hingePreference',
    groupId: 'layout',
    label: '折り目の扱い',
    defaultValue: SettingsHingePreference.automatic,
    requiredCapability: 'hinge',
    availabilityPolicy: SettingAvailabilityPolicy.disableWhenUnsupported,
    choices: [
      SettingChoice(
        value: SettingsHingePreference.automatic,
        label: '自動',
        storedValue: 'automatic',
      ),
      SettingChoice(
        value: SettingsHingePreference.avoid,
        label: '折り目を避ける',
        storedValue: 'avoid',
      ),
      SettingChoice(
        value: SettingsHingePreference.span,
        label: '折り目をまたいで表示',
        storedValue: 'span',
      ),
    ],
  );

  /// User multiplier to compose with OS accessibility scaling in the successor.
  static final textSizeMultiplier = SettingDefinition<double>(
    id: 'textus.appearance.textSizeMultiplier',
    groupId: 'appearance',
    label: '文字サイズ',
    defaultValue: 1.0,
    choices: [
      SettingChoice(value: 1.0, label: '標準', storedValue: 1.0),
      SettingChoice(value: 1.15, label: '大きめ', storedValue: 1.15),
      SettingChoice(value: 1.30, label: 'さらに大きく', storedValue: 1.30),
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
