// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import 'favorites_unavailable_page.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final builder = booruBuilder?.favoritesPageBuilder;

    return builder != null
        ? builder(context)
        : const FavoritesUnavailablePage();
  }
}
