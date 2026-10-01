import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../settings/setting_definition.dart';
import '../view/settings_view.dart';
import 'settings_shell.dart';

/// Opens Settings on the nearest Navigator, borrowing [view] for the route.
///
/// Composition owns explicit restoration and disposal after the route detaches.
/// The route captures these immutable capabilities and the resolved visual style;
/// it does not observe new capability inputs. Adaptive uses the ambient theme's
/// platform (Cupertino for iOS); explicit overrides affect only visuals. The
/// returned Future completes when the route pops, never as save acknowledgement.
/// Reopening with the same View retains its current values and service identity.
Future<void> showSettings(
  BuildContext context, {
  required SettingsView view,
  SettingsCapabilities? capabilities,
  SettingsPresentation presentation = SettingsPresentation.adaptive,
}) {
  final resolved = presentation == SettingsPresentation.adaptive
      ? Theme.of(context).platform == TargetPlatform.iOS
            ? SettingsPresentation.cupertino
            : SettingsPresentation.material
      : presentation;
  Widget page(BuildContext context) => SettingsShell(
    view: view,
    capabilities: capabilities,
    presentation: resolved,
  );
  return Navigator.of(context).push<void>(
    resolved == SettingsPresentation.cupertino
        ? CupertinoPageRoute<void>(builder: page)
        : MaterialPageRoute<void>(builder: page),
  );
}
