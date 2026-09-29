import 'package:flutter/foundation.dart';

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
  ResourceListDetailDisplayPreference _preference =
      ResourceListDetailDisplayPreference.split;
  bool _compactDetailRequested = false;
  ResourceListDetailHingePolicy? _hingePolicyOverride;

  ResourceListDetailDisplayPreference get preference => _preference;
  bool get compactDetailRequested => _compactDetailRequested;
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
        _preference != ResourceListDetailDisplayPreference.detailFocused ||
        !_compactDetailRequested;
    if (!changed) return;
    _preference = ResourceListDetailDisplayPreference.detailFocused;
    _compactDetailRequested = true;
    notifyListeners();
  }

  /// Restores the split preference.
  void restoreSplit() {
    if (_preference == ResourceListDetailDisplayPreference.split) return;
    _preference = ResourceListDetailDisplayPreference.split;
    notifyListeners();
  }

  /// Sets the user's in-session treatment for a recognized fold or hinge.
  void setHingePolicy(ResourceListDetailHingePolicy policy) {
    if (_hingePolicyOverride == policy) return;
    _hingePolicyOverride = policy;
    notifyListeners();
  }

  /// Resolves automatic hinge treatment from the current physical occlusion.
  ResourceListDetailHingePolicy resolveHingePolicy({
    required bool hasOcclusion,
    ResourceListDetailHingePolicy defaultPolicy =
        ResourceListDetailHingePolicy.automatic,
  }) {
    final policy = _hingePolicyOverride ?? defaultPolicy;
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
        _preference == ResourceListDetailDisplayPreference.detailFocused) {
      return ResourceListDetailPresentation.detailFocused;
    }
    return ResourceListDetailPresentation.split;
  }
}
