// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

class ExploreSliverAppBar extends StatelessWidget {
  const ExploreSliverAppBar({
    required this.title,
    required this.onBack,
    super.key,
  });

  final String title;
  final void Function()? onBack;

  @override
  Widget build(BuildContext context) {
    return KurumiSliverAppBar(
      title: Text(
        title,
        style: Kurumi.themeOf(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      floating: true,
      leading: onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            )
          : null,
      backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
    );
  }
}
