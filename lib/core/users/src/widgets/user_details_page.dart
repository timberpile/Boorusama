// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class UserDetailsPage extends StatelessWidget {
  const UserDetailsPage({
    required this.body,
    super.key,
    this.actions = const [],
  });

  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.profile.profile),
        actions: actions,
      ),
      body: SafeArea(
        bottom: false,
        child: body,
      ),
    );
  }
}
