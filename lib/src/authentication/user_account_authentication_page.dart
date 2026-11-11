import 'package:flutter/material.dart';

import 'user_account_authentication_facade.dart';
import 'user_account_authentication_panel.dart';

/// An account route that borrows its owner and preserves the caller's work.
class UserAccountAuthenticationPage extends StatelessWidget {
  const UserAccountAuthenticationPage({required this.facade, super.key});

  final UserAccountAuthenticationFacade facade;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('アカウント')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: UserAccountAuthenticationPanel(facade: facade),
      ),
    ),
  );
}
