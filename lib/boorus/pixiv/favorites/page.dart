import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/configs/create/routes.dart';
import '../../../core/navigation/navigation_profile_picker.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/posts/listing/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/posts/listing/src/widgets/timeline_option_selector.dart';
import '../../../core/posts/listing/src/widgets/timeline_toolbar.dart';
import '../configs/extra_data.dart';
import 'providers.dart';

class PixivFavoritesPage extends ConsumerWidget {
  const PixivFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final userId = int.tryParse(
      PixivExtraData.fromPassHash(config.passHash).userId ?? '',
    );
    if (userId == null || userId <= 0 || (config.apiKey?.isEmpty ?? true)) {
      return Scaffold(
        appBar: KurumiAppBar(
          title: Text(context.t.profile.favorites),
          actions: const [NavigationProfilePicker(favorites: true)],
        ),
        body: Center(
          child: FilledButton(
            onPressed: () => goToUpdateBooruConfigPage(
              ref,
              config: config,
              initialTab: 'auth',
            ),
            child: Text(context.t.pixiv.auth.login_title),
          ),
        ),
      );
    }
    return _FavoritesView(
      key: ValueKey((config.id, config.auth)),
      config: config,
      userId: userId,
    );
  }
}

class _FavoritesView extends ConsumerStatefulWidget {
  const _FavoritesView({required this.config, required this.userId, super.key});
  final BooruConfig config;
  final int userId;
  @override
  ConsumerState<_FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<_FavoritesView> {
  var _visibility = PixivBookmarkVisibility.public;

  @override
  Widget build(BuildContext context) {
    final sessionKey = (
      config: widget.config,
      userId: widget.userId,
      visibility: _visibility,
    );
    final session = ref.watch(pixivFavoritesSessionProvider(sessionKey));
    final strings = context.t.pixiv.explore.follow_restrict;
    return CustomContextMenuOverlay(
      child: PostScope<Post>(
        // The controller retains its fetcher, so it must share the session's
        // full identity, including non-authentication configuration changes.
        key: ValueKey(sessionKey),
        // A cursor cannot safely support arbitrary page jumps.
        pageMode: PageMode.infinite,
        fetcher: session.getPosts,
        builder: (context, controller) => PostGrid<Post>(
          controller: controller,
          selectionScope: (widget.config.id, _visibility),
          sliverHeaders: [
            KurumiSliverAppBar(
              title: Text(context.t.profile.favorites),
              floating: true,
              actions: const [NavigationProfilePicker(favorites: true)],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TimelineToolbar(
                  children: [
                    TimelineOptionSelector<PixivBookmarkVisibility>(
                      key: const ValueKey('pixiv-favorites-privacy'),
                      label: _visibility == PixivBookmarkVisibility.public
                          ? strings.public
                          : strings.private,
                      options: PixivBookmarkVisibility.values,
                      value: _visibility,
                      optionLabel: (value) =>
                          value == PixivBookmarkVisibility.public
                          ? strings.public
                          : strings.private,
                      onSelected: (value) {
                        if (value != _visibility)
                          setState(() => _visibility = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
