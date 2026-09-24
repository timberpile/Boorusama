// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/posts/favorites/providers.dart';
import '../../../../../core/posts/favorites/widgets.dart';
import '../../../../../core/posts/post/types.dart';

class DanbooruQuickFavoriteButton extends ConsumerWidget {
  const DanbooruQuickFavoriteButton({
    required this.post,
    required this.isBanned,
    super.key,
  });

  final Post post;
  final bool isBanned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final canFavorite = ref.watch(canFavoriteProvider(config));

    if (!canFavorite) return const SizedBox.shrink();

    final notifier = ref.watch(favoritesProvider(config).notifier);
    final isFaved = isBanned
        ? false
        : ref.watch(favoriteProvider((config, post.id)));

    return QuickFavoriteButton(
      isFaved: isFaved,
      onFavToggle: (isFaved) {
        if (!isFaved) {
          unawaited(notifier.remove(post.id));
        } else {
          unawaited(notifier.add(post.id));
        }
      },
    );
  }
}
