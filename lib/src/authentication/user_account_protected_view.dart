import 'package:flutter/material.dart';

import 'user_account_authentication_facade.dart';
import 'user_account_authentication_page.dart';

/// Presentation entry, not server authorization. The caller owns the facade
/// and draft retention/leave policy. Protected contents retire when authority
/// is withdrawn; a subsequent login builds a fresh subtree.
class UserAccountProtectedView extends StatefulWidget {
  const UserAccountProtectedView({
    required this.facade,
    required this.builder,
    super.key,
  });

  final UserAccountAuthenticationFacade facade;
  final WidgetBuilder builder;

  @override
  State<UserAccountProtectedView> createState() =>
      _UserAccountProtectedViewState();
}

class _UserAccountProtectedViewState extends State<UserAccountProtectedView> {
  Widget? _protected;

  @override
  void didUpdateWidget(UserAccountProtectedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.facade, oldWidget.facade)) _protected = null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.facade,
    builder: (context, _) {
      final facade = widget.facade;
      final allowed =
          !facade.isClosed && !facade.busy && facade.snapshot.isAuthenticated;
      if (allowed) {
        _protected = KeyedSubtree(
          key: ValueKey((facade, facade.snapshot.account!.userAccountId)),
          child: Builder(builder: widget.builder),
        );
      } else if (facade.isClosed || !facade.busy) {
        _protected = null;
      }
      // Keep local editing state during a pending refresh, while removing its
      // focus, semantics and visibility. Idle rejection/logout retires it.
      return Stack(
        children: [
          if (_protected != null)
            Offstage(
              offstage: !allowed,
              child: TickerMode(
                enabled: allowed,
                child: ExcludeFocus(excluding: !allowed, child: _protected!),
              ),
            ),
          if (!allowed)
            HeroControllerScope.none(
              child: Navigator(
                key: ValueKey((facade, 'authentication')),
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => UserAccountAuthenticationPage(facade: facade),
                ),
              ),
            ),
        ],
      );
    },
  );
}
