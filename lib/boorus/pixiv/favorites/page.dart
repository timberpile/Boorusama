import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/configs/create/routes.dart';
import '../../../core/navigation/navigation_profile_picker.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/widgets/widgets.dart';
import '../configs/extra_data.dart';
import '../client_provider.dart';
import '../works/favorites_session.dart';
import '../works/work_listing.dart';

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
  PixivWorkFavoritesSession? _session;
  Object? _sessionKey;

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionKey = (
      config: widget.config,
      userId: widget.userId,
      visibility: _visibility,
    );
    if (_sessionKey != sessionKey) {
      _session?.dispose();
      _sessionKey = sessionKey;
      final client = ref.watch(pixivClientProvider(widget.config.auth));
      _session = PixivWorkFavoritesSession(
        (cursor, token) => client.getUserBookmarks(
          userId: widget.userId,
          visibility: _visibility,
          maxBookmarkId: cursor,
          cancelToken: token,
        ),
      );
    }
    final strings = context.t.pixiv.explore.follow_restrict;
    return CustomContextMenuOverlay(
      child: PixivWorkGrid(
        key: ValueKey(sessionKey),
        config: widget.config,
        queryIdentity: sessionKey,
        pageMode: PageMode.infinite,
        fetchPage: _session!.fetch,
        sliverHeaders: [
          KurumiSliverAppBar(
            title: Text(context.t.profile.favorites),
            actions: const [NavigationProfilePicker(favorites: true)],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Center(
                child: KurumiSegmentedButton<PixivBookmarkVisibility>(
                  key: const ValueKey('pixiv-favorites-privacy'),
                  initialValue: _visibility,
                  segments: {
                    PixivBookmarkVisibility.public: strings.public,
                    PixivBookmarkVisibility.private: strings.private,
                  },
                  onChanged: (value) {
                    if (value != _visibility) {
                      setState(() => _visibility = value);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
