// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:

class UnimplementedPage extends StatelessWidget {
  const UnimplementedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: KurumiAppBar(),
      body: Center(
        child: Text('Page not implemented yet'),
      ),
    );
  }
}

class LargeScreenAwareInvalidPage extends StatelessWidget {
  const LargeScreenAwareInvalidPage({
    required this.message,
    super.key,
    this.useDialog = true,
  });

  final String message;
  final bool useDialog;

  @override
  Widget build(BuildContext context) {
    final isLarge = context.isLargeScreen;
    final page = InvalidPage(message: message);

    return isLarge && useDialog ? KurumiDialog(child: page) : page;
  }
}

class InvalidPage extends StatelessWidget {
  const InvalidPage({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KurumiAppBar(),
      body: Center(
        child: Text(message),
      ),
    );
  }
}
