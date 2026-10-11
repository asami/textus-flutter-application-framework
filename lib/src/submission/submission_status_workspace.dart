import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../resource/resource_view_model.dart';
import '../view/resource_list_detail_display_model.dart';
import 'submission_facade.dart';
import 'submission_presentation_configuration.dart';
import 'submission_status_binding.dart';

/// Owns the route projection and an optional default display; borrows Core.
final class SubmissionStatusWorkspace {
  SubmissionStatusWorkspace({
    required SubmissionFacade facade,
    required SubmissionPresentationConfiguration presentationConfiguration,
    ResourceListDetailDisplayModel? displayModel,
    DateTime Function()? now,
    SubmissionNetworkState Function()? networkState,
  }) : binding = SubmissionStatusBinding(
         facade: facade,
         presentationConfiguration: presentationConfiguration,
         now: now,
         networkState: networkState,
       ),
       displayModel = displayModel ?? ResourceListDetailDisplayModel(),
       _ownsDisplay = displayModel == null {
    viewModel = ResourceViewModel(dataSource: binding, actionHandler: binding);
  }

  final SubmissionStatusBinding binding;
  late final ResourceViewModel viewModel;
  final ResourceListDetailDisplayModel displayModel;
  final bool _ownsDisplay;
  bool _detached = false;
  Future<void>? _detachment;

  bool get isDetached => _detached;

  /// Remove the page before/while detaching; await this before closing Core.
  Future<void> detach() {
    final existing = _detachment;
    if (existing != null) return existing;
    _detached = true;
    viewModel.dispose();
    final pending = binding.detach();
    // Given accepted binding work, When it settles after retirement,
    // Then release only the workspace-owned default display.
    return _detachment = pending.then<void>((_) {
      if (_ownsDisplay) displayModel.dispose();
    });
  }
}
