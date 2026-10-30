import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/configs/create/routes.dart';
import '../../../core/search/search/routes.dart';
import '../configs/extra_data.dart';
import '../posts/query.dart';
import 'artist_card.dart';
import 'l10n.dart';
import 'providers.dart';

class PixivFollowingArtistsPage extends ConsumerWidget {
  const PixivFollowingArtistsPage({required this.config, super.key});
  final BooruConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = PixivExtraData.fromPassHash(config.passHash);
    final userId = int.tryParse(account.userId ?? '');
    if (userId == null || userId <= 0 || (config.apiKey?.isEmpty ?? true)) {
      return Scaffold(
        appBar: KurumiAppBar(title: Text(context.t.pixivFollowing.title)),
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
    return _FollowingView(
      key: ValueKey((config.id, config.auth)),
      config: config,
      userId: userId,
      maxRestriction: account.xRestrict ?? 0,
    );
  }
}

class _FollowingView extends ConsumerStatefulWidget {
  const _FollowingView({
    required this.config,
    required this.userId,
    required this.maxRestriction,
    super.key,
  });
  final BooruConfig config;
  final int userId;
  final int maxRestriction;
  @override
  ConsumerState<_FollowingView> createState() => _FollowingViewState();
}

class _FollowingViewState extends ConsumerState<_FollowingView> {
  var _restrict = PixivFollowRestrict.public;

  @override
  Widget build(BuildContext context) {
    final provider = pixivFollowingProvider((
      config: widget.config,
      userId: widget.userId,
      restrict: _restrict,
    ));
    final result = ref.watch(provider);
    final strings = context.t.pixiv.explore.follow_restrict;
    return Scaffold(
      appBar: KurumiAppBar(title: Text(context.t.pixivFollowing.title)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.config.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final value in [
                    PixivFollowRestrict.public,
                    PixivFollowRestrict.private,
                  ])
                    ChoiceChip(
                      label: Text(
                        value == PixivFollowRestrict.public
                            ? strings.public
                            : strings.private,
                      ),
                      selected: _restrict == value,
                      onSelected: (selected) {
                        if (selected && value != _restrict)
                          setState(() => _restrict = value);
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: result.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t.generic.errors.unknown),
                      TextButton(
                        onPressed: () => ref.invalidate(provider),
                        child: Text(context.t.generic.action.retry),
                      ),
                    ],
                  ),
                ),
                data: (state) => KurumiRefreshIndicator(
                  onRefresh: () async {
                    try {
                      final refreshed = ref.refresh(provider.future);
                      await refreshed;
                    } catch (_) {
                      // The provider renders the error; do not report a false empty list.
                    }
                  },
                  child: ListView.builder(
                    key: ValueKey((widget.config.id, _restrict)),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: state.artists.length + 1,
                    itemBuilder: (context, index) {
                      if (index < state.artists.length) {
                        final artist = state.artists[index];
                        return PixivFollowingArtistCard(
                          key: ValueKey(artist.user.id),
                          artist: artist,
                          config: widget.config.auth,
                          maxRestriction: widget.maxRestriction,
                          onOpen: () => goToSearchPage(
                            ref,
                            config: widget.config,
                            tag: PixivQuery.userTag(artist.user.id!),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (state.artists.isEmpty)
                              Text(context.t.generic.no_content),
                            if (state.failedMore)
                              Text(context.t.generic.errors.unknown),
                            if (state.loadingMore)
                              const CircularProgressIndicator()
                            else if (state.hasMore)
                              FilledButton(
                                onPressed: () =>
                                    ref.read(provider.notifier).loadMore(),
                                child: Text(
                                  state.failedMore
                                      ? context.t.generic.action.retry
                                      : context.t.infinite_scroll.load_more,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
