import 'package:flutter/widgets.dart';

import '../settings/application_text_scaler.dart';
import '../settings/common_settings.dart';
import '../view/settings_view.dart';

/// Opt-in app text presentation, placed in the app builder above Navigator.
///
/// Borrows [view]; owners restore and dispose it after this boundary detaches.
/// Only textScaler changes. Nested boundaries must share the same View and
/// reuse the original OS scaler, so the app preference is applied once.
class ApplicationTextScaling extends StatelessWidget {
  const ApplicationTextScaling({
    required this.view,
    required this.child,
    super.key,
  });

  final SettingsView view;
  final Widget child;

  /// Full effective scaler for consumers beneath Flutter-local text clamps.
  static TextScaler? maybeTextScalerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ApplicationTextScope>()
      ?.effective;

  @override
  Widget build(BuildContext context) {
    view.registry.requireRegistered(CommonSettings.textSizeMultiplier);
    final enclosing = context
        .dependOnInheritedWidgetOfExactType<_ApplicationTextScope>();
    if (enclosing != null && !identical(enclosing.view, view)) {
      throw ArgumentError(
        'Nested text boundaries must borrow the same SettingsView',
      );
    }
    final ambient = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: view,
      child: child,
      builder: (context, child) {
        final source = enclosing?.source ?? ambient.textScaler;
        final effective =
            enclosing?.effective ??
            composeApplicationTextScaler(
              systemTextScaler: source,
              multiplier: view.snapshot.value(
                CommonSettings.textSizeMultiplier,
              ),
            );
        return _ApplicationTextScope(
          view: view,
          source: source,
          effective: effective,
          child: MediaQuery(
            data: ambient.copyWith(textScaler: effective),
            child: child!,
          ),
        );
      },
    );
  }
}

class _ApplicationTextScope extends InheritedWidget {
  const _ApplicationTextScope({
    required this.view,
    required this.source,
    required this.effective,
    required super.child,
  });

  final SettingsView view;
  final TextScaler source;
  final TextScaler effective;

  @override
  bool updateShouldNotify(_ApplicationTextScope oldWidget) =>
      !identical(view, oldWidget.view) ||
      source != oldWidget.source ||
      effective != oldWidget.effective;
}
