// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../providers/search_subscription_selectors.dart';

class PinnedSearchNavigationIcon extends ConsumerWidget {
  const PinnedSearchNavigationIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNewPosts = ref.watch(
      profilePinnedSearchHasNewPostsProvider(ref.watchConfig.id),
    );
    const icon = Icon(Symbols.push_pin);
    return hasNewPosts
        ? Semantics(
            label: context.t.pinned_searches.new_posts,
            child: const Badge(child: icon),
          )
        : icon;
  }
}
