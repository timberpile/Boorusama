import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../images/booru_image.dart';
import '../../router.dart';
import '../details/routes.dart';
import '../post/types.dart';
import '../post/providers.dart';
import 'providers.dart';
import 'results.dart';
import 'types.dart';

void findOnOtherProfiles(WidgetRef ref, Post source) {
  ref.pushRoute('/cross-profile-lookup', extra: source);
}

GoRoute crossProfileLookupRoute() => GoRoute(
  path: 'cross-profile-lookup',
  builder: (context, state) => switch (state.extra) {
    final Post source => CrossProfileLookupPage(source: source),
    final PixivArtworkReference artwork => CrossProfileLookupPage.pixiv(
      artwork: artwork,
    ),
    _ => Scaffold(
      body: Center(child: Text(context.t.post.cross_profile.failed)),
    ),
  },
);

class CrossProfileLookupPage extends ConsumerStatefulWidget {
  const CrossProfileLookupPage({required Post source, super.key})
    : source = source,
      artwork = null;
  const CrossProfileLookupPage.pixiv({
    required PixivArtworkReference artwork,
    super.key,
  }) : artwork = artwork,
       source = null;

  final Post? source;
  final PixivArtworkReference? artwork;

  @override
  ConsumerState<CrossProfileLookupPage> createState() => _PostLookupPageState();
}

class _PostLookupPageState extends ConsumerState<CrossProfileLookupPage> {
  final _results = <String, CrossProfileResult>{};
  final _pages = <String, int>{};
  final _cancellations = <String, PostLookupCancellation>{};
  final _queue = CrossProfileLookupQueue();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProfiles();
    });
  }

  bool _supports(BooruConfig profile) => widget.artwork != null
      ? supportsSharedPixivLookup(profile)
      : supportsExactPostLookup(profile);

  BooruConfig? _sourceConfig(List<BooruConfig> profiles) {
    final source = widget.source;
    if (source == null) return null;
    return switch (const PostOriginResolver().resolve(
      source.origin,
      profiles,
    )) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };
  }

  void _syncProfiles() {
    final profiles = ref.read(booruConfigProvider);
    final sourceConfig = _sourceConfig(profiles);
    for (final entry in _results.entries.toList()) {
      if (!profiles.contains(entry.value.profile)) {
        _cancellations.remove(entry.key)?.cancel();
        _results.remove(entry.key);
        _pages.remove(entry.key);
      }
    }
    for (final profile in profiles) {
      if (profile.id !=
              (sourceConfig?.id ?? widget.source?.origin.profileIdHint) &&
          _supports(profile) &&
          _results[profile.id]?.profile != profile) {
        unawaited(_select(profile));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
    super.dispose();
  }

  Future<void> _select(BooruConfig target, {bool more = false}) async {
    _cancellations[target.id]?.cancel();
    final cancellation = PostLookupCancellation();
    _cancellations[target.id] = cancellation;
    final previous = _results[target.id];
    final page = more ? (_pages[target.id] ?? 1) + 1 : 1;
    setState(() {
      _results[target.id] = CrossProfileResult(
        profile: target,
        status: CrossProfileResultStatus.loading,
        posts: more ? previous?.posts ?? [] : [],
        matchKind: more ? previous?.matchKind : null,
      );
    });
    final lookup = widget.artwork != null
        ? ref.read(sharedPixivLookupSessionProvider(widget.artwork!)).find
        : ref.read(crossProfileLookupSessionProvider(widget.source!)).find;
    final result = await _queue.run(
      () => lookup(target, page: page, cancellation: cancellation),
    );
    if (!mounted || cancellation.isCancelled) return;
    if (!ref.read(booruConfigProvider).contains(target)) {
      setState(() => _results.remove(target.id));
      return;
    }
    final row = switch (result) {
      PostLookupPage(:final posts, :final hasMore) => CrossProfileResult(
        profile: target,
        status:
            posts.isEmpty &&
                !hasMore &&
                (!more || (previous?.posts.isEmpty ?? true))
            ? result.coverageIssue == null
                  ? CrossProfileResultStatus.noMatch
                  : CrossProfileResultStatus.incomplete
            : CrossProfileResultStatus.success,
        posts: {
          for (final post in [
            ...(more ? previous?.posts ?? <Post>[] : <Post>[]),
            ...posts,
          ])
            post.id: post,
        }.values.toList(),
        complete: !hasMore && result.coverageIssue == null,
        hasMore: hasMore,
        coverageIssue: result.coverageIssue,
        matchKind: result.matchKind,
      ),
      PostLookupUnavailable(:final reason) => CrossProfileResult(
        profile: target,
        status: switch (reason) {
          PostLookupUnavailableReason.unsupported =>
            CrossProfileResultStatus.unsupported,
          PostLookupUnavailableReason.missingHash =>
            CrossProfileResultStatus.missingHash,
          _ => CrossProfileResultStatus.error,
        },
      ),
      _ => CrossProfileResult(
        profile: target,
        status: CrossProfileResultStatus.error,
        posts: more ? previous?.posts ?? [] : [],
        matchKind: more ? previous?.matchKind : null,
        hasMore: more,
      ),
    };
    setState(() {
      _results[target.id] = row;
      if (result is PostLookupPage) _pages[target.id] = result.page;
    });
  }

  void _open(BooruConfig profile, Post post) {
    if (!ref.read(booruConfigProvider).contains(profile) ||
        post.origin != postOriginFromConfig(profile)) {
      return;
    }
    goToPostDetailsPageFromPosts(
      ref: ref,
      posts: [post],
      initialIndex: 0,
      initialThumbnailUrl: post.thumbnailImageUrl,
      config: profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the refresh cache scoped to the lifetime of this results page.
    if (widget.artwork case final artwork?) {
      ref.watch(sharedPixivLookupSessionProvider(artwork));
      ref.listen(sharedPixivLookupSessionProvider(artwork), (previous, next) {
        if (previous == null || identical(previous, next)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !identical(
                ref.read(sharedPixivLookupSessionProvider(artwork)),
                next,
              )) {
            return;
          }
          for (final cancellation in _cancellations.values) {
            cancellation.cancel();
          }
          _results.clear();
          _pages.clear();
          _syncProfiles();
        });
      });
    } else {
      ref.watch(crossProfileLookupSessionProvider(widget.source!));
    }
    ref.listen(booruConfigProvider, (_, _) => _syncProfiles());
    final profiles = ref.watch(booruConfigProvider);
    final sourceConfig = _sourceConfig(profiles);
    final targets = profiles.where(
      (p) => p.id != (sourceConfig?.id ?? widget.source?.origin.profileIdHint),
    );
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(
          widget.artwork != null
              ? context.t.post.cross_profile.shared_pixiv_title
              : context.t.post.cross_profile.action,
        ),
      ),
      body: SafeArea(
        child: CrossProfileResults(
          reference: widget.artwork != null
              ? Text(
                  context.t.post.cross_profile.pixiv_artwork(
                    id: widget.artwork!.id,
                  ),
                )
              : Row(
                  children: [
                    if (sourceConfig != null)
                      SizedBox.square(
                        dimension: 72,
                        child: BooruImage(
                          config: sourceConfig.auth,
                          imageUrl: widget.source!.thumbnailImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '#${widget.source!.sitePostId ?? widget.source!.id}',
                      ),
                    ),
                  ],
                ),
          results: [
            for (final profile in targets)
              _results[profile.id]?.profile == profile
                  ? _results[profile.id]!
                  : CrossProfileResult(
                      profile: profile,
                      status: _supports(profile)
                          ? CrossProfileResultStatus.idle
                          : CrossProfileResultStatus.unsupported,
                    ),
          ],
          onSelect: _select,
          onMore: (profile) => _select(profile, more: true),
          onOpen: _open,
        ),
      ),
    );
  }
}
