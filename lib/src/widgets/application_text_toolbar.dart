import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'application_text_scaling.dart';

double _titleHeight(
  BuildContext context,
  String title,
  TextStyle style,
  TextScaler scaler,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: scaler,
  )..layout(maxWidth: math.max(1, width));
  final height = painter.height;
  painter.dispose();
  return height;
}

double _heightBound(BuildContext context, double minimum) {
  final media = MediaQuery.of(context);
  final usable = math.max(
    0,
    media.size.height - media.padding.vertical - media.viewInsets.vertical,
  );
  return math.max(minimum, usable * 0.35);
}

Widget _titleViewport({
  required String title,
  required TextStyle style,
  required TextScaler scaler,
  required double height,
}) => SizedBox(
  height: height,
  child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DefaultTextStyle(
      style: style,
      child: Text(
        title,
        style: style,
        textScaler: scaler,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    ),
  ),
);

/// Text-aware Material AppBar for an application title and actions.
/// Requires an enclosing [ApplicationTextScaling] boundary. Pass the toolbar's
/// actual available width; text wraps/scrolls without the native scale clamp.
/// Icons, action targets and back navigation retain their physical dimensions.
AppBar applicationTextAppBar(
  BuildContext context, {
  required String title,
  required double width,
  Widget? leading,
  List<Widget> actions = const [],
}) {
  final scaler = ApplicationTextScaling.maybeTextScalerOf(context)!;
  final theme = Theme.of(context);
  final style =
      AppBarTheme.of(context).titleTextStyle ?? theme.textTheme.titleLarge!;
  final hasLeading =
      leading != null || (ModalRoute.of(context)?.canPop ?? false);
  final available = math.max(
    1.0,
    width - (hasLeading ? 56 : 0) - actions.length * 48 - 32,
  );
  final measured = _titleHeight(context, title, style, scaler, available) + 16;
  final height = math.min(math.max(56.0, measured), _heightBound(context, 56));
  return AppBar(
    toolbarHeight: height,
    leadingWidth: 56,
    titleSpacing: 16,
    titleTextStyle: style,
    title: _titleViewport(
      title: title,
      style: style,
      scaler: scaler,
      height: height,
    ),
    leading: leading,
    actions: actions,
  );
}

/// Internal opaque Cupertino bar whose preferred height includes wrapped text.
class ApplicationTextCupertinoBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  ApplicationTextCupertinoBar(
    BuildContext context, {
    required double width,
    super.key,
  }) : scaler = ApplicationTextScaling.maybeTextScalerOf(context)!,
       style = CupertinoTheme.of(context).textTheme.navTitleTextStyle,
       hasBack = Navigator.of(context).canPop(),
       height = math.min(
         math.max(
           44.0,
           _titleHeight(
                 context,
                 '設定',
                 CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                 ApplicationTextScaling.maybeTextScalerOf(context)!,
                 width - (Navigator.of(context).canPop() ? 56 : 0) - 32,
               ) +
               16,
         ),
         _heightBound(context, 44),
       );

  final TextScaler scaler;
  final TextStyle style;
  final bool hasBack;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CupertinoTheme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (hasBack)
              const SizedBox(
                width: 56,
                child: CupertinoNavigationBarBackButton(),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _titleViewport(
                  title: '設定',
                  style: style,
                  scaler: scaler,
                  height: height,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
