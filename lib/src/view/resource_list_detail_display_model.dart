import 'package:flutter/foundation.dart';

import '../settings/common_settings.dart';
import 'resource_list_detail_hinge_policy.dart';

/// The user's in-session preference for a Resource List + Detail presentation.
enum ResourceListDetailDisplayPreference { split, detailFocused }

/// The presentation currently resolved from preference, selection, and space.
enum ResourceListDetailPresentation {
  compactList,
  compactDetail,
  split,
  detailFocused,
}

/// Owns only presentation-session state for a Resource List + Detail display.
///
/// Resource selection remains owned by the Resource View Model. Layout capability
/// is a build-time input so a size change cannot replace semantic state.
class ResourceListDetailDisplayModel extends ChangeNotifier {
  ResourceListDetailDisplayPreference? _preferenceOverride;
  bool _compactDetailRequested = false;
  ResourceListDetailHingePolicy? _hingePolicyOverride;
  SettingsPanePreference _panePreference = SettingsPanePreference.automatic;
  ResourceListDetailHingePolicy? _hingePreference;
  bool _hingeApplicable = true;

  /// Legacy expanded preference, defaulting to split before an explicit choice.
  ResourceListDetailDisplayPreference get preference =>
      _preferenceOverride ?? ResourceListDetailDisplayPreference.split;

  /// Explicit session choice, absent until focus or split is requested.
  ResourceListDetailDisplayPreference? get preferenceOverride =>
      _preferenceOverride;

  /// Whether sequential navigation has requested the selected detail.
  bool get compactDetailRequested => _compactDetailRequested;

  /// Explicit session hinge treatment, retained across capability changes.
  ResourceListDetailHingePolicy? get hingePolicyOverride =>
      _hingePolicyOverride;

  /// Requests sequential compact detail without changing an expanded preference.
  void openDetail() {
    if (_compactDetailRequested) return;
    _compactDetailRequested = true;
    notifyListeners();
  }

  /// Returns a compact presentation to its list while retaining preference.
  void showList() {
    if (!_compactDetailRequested) return;
    _compactDetailRequested = false;
    notifyListeners();
  }

  /// Explicitly prefers focused detail when the layout can support it.
  void focusDetail() {
    final changed =
        _preferenceOverride !=
            ResourceListDetailDisplayPreference.detailFocused ||
        !_compactDetailRequested;
    if (!changed) return;
    _preferenceOverride = ResourceListDetailDisplayPreference.detailFocused;
    _compactDetailRequested = true;
    notifyListeners();
  }

  /// Restores the split preference.
  void restoreSplit() {
    if (_preferenceOverride == ResourceListDetailDisplayPreference.split) {
      return;
    }
    _preferenceOverride = ResourceListDetailDisplayPreference.split;
    notifyListeners();
  }

  /// Sets the user's in-session treatment for a recognized fold or hinge.
  void setHingePolicy(ResourceListDetailHingePolicy policy) {
    if (_hingePolicyOverride == policy) return;
    _hingePolicyOverride = policy;
    notifyListeners();
  }

  /// Applies transient common preferences without changing compact navigation.
  ///
  /// Only the explicitly cleared session dimensions are erased. Missing hinge
  /// preference retains the caller's configuration fallback. This model never
  /// owns Settings snapshots, services, storage, or semantic Resource Views.
  void applySettingsPreferences({
    required SettingsPanePreference panePreference,
    ResourceListDetailHingePolicy? hingePreference,
    bool hingeApplicable = true,
    bool clearPaneOverride = false,
    bool clearHingeOverride = false,
  }) {
    final changed =
        _panePreference != panePreference ||
        _hingePreference != hingePreference ||
        _hingeApplicable != hingeApplicable ||
        (clearPaneOverride && _preferenceOverride != null) ||
        (clearHingeOverride && _hingePolicyOverride != null);
    if (!changed) return;
    _panePreference = panePreference;
    _hingePreference = hingePreference;
    _hingeApplicable = hingeApplicable;
    if (clearPaneOverride) _preferenceOverride = null;
    if (clearHingeOverride) _hingePolicyOverride = null;
    notifyListeners();
  }

  /// Resolves automatic hinge treatment from the current physical occlusion.
  ResourceListDetailHingePolicy resolveHingePolicy({
    required bool hasOcclusion,
    ResourceListDetailHingePolicy defaultPolicy =
        ResourceListDetailHingePolicy.automatic,
  }) {
    final policy = _hingeApplicable
        ? _hingePolicyOverride ?? _hingePreference ?? defaultPolicy
        : ResourceListDetailHingePolicy.automatic;
    return switch (policy) {
      ResourceListDetailHingePolicy.automatic =>
        hasOcclusion
            ? ResourceListDetailHingePolicy.avoid
            : ResourceListDetailHingePolicy.span,
      ResourceListDetailHingePolicy.avoid =>
        ResourceListDetailHingePolicy.avoid,
      ResourceListDetailHingePolicy.span => ResourceListDetailHingePolicy.span,
    };
  }

  /// Resolves the visible presentation without retaining capability as state.
  ResourceListDetailPresentation resolve({
    required bool splitCapable,
    required bool hasSelection,
    bool allowDetailFocus = true,
  }) {
    if (!splitCapable) {
      return hasSelection && _compactDetailRequested
          ? ResourceListDetailPresentation.compactDetail
          : ResourceListDetailPresentation.compactList;
    }
    if (hasSelection &&
        allowDetailFocus &&
        _preferenceOverride ==
            ResourceListDetailDisplayPreference.detailFocused) {
      return ResourceListDetailPresentation.detailFocused;
    }
    if (_preferenceOverride != ResourceListDetailDisplayPreference.split &&
        _panePreference == SettingsPanePreference.preferSinglePane) {
      return hasSelection && _compactDetailRequested
          ? ResourceListDetailPresentation.compactDetail
          : ResourceListDetailPresentation.compactList;
    }
    return ResourceListDetailPresentation.split;
  }
}
