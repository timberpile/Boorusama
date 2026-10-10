// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/providers.dart';

class BooruConfigAuthFailsafe extends ConsumerWidget {
  const BooruConfigAuthFailsafe({
    required this.builder,
    super.key,
    this.hasLogin,
  });

  final WidgetBuilder builder;
  final bool? hasLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(booruLoginDetailsProvider(config));

    return hasLogin ?? loginDetails.hasLogin()
        ? builder(context)
        : const UnauthorizedPage();
  }
}

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: KurumiAppBar(),
      body: Center(
        child: Text('You must be logged in to view this page'),
      ),
    );
  }
}
