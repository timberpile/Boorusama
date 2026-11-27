import '../../configs/config/providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../content/content_access.dart';
import '../../images/booru_image.dart';
import '../../router.dart';
import '../post/types.dart';
import '../../local_media/local_media_reference.dart';
import 'data.dart';
import 'iqdb_remote_image.dart';
import 'lookup_preferences.dart';
import 'lookup_selector.dart';
import 'providers.dart';
import 'selected_lookup_page.dart';
import 'results.dart';
import 'types.dart';

typedef _RemoteLookupSource = ({
  ContentAccessContext? access,
  String? excludedProfileId,
  Set<PostLookupMatchKind> Function(BooruConfig) methods,
});

_RemoteLookupSource _remoteLookupSource(
  WidgetRef ref,
  Post source,
  ContentAccessContext? accessOverride,
) {
  final access = lookupSourceAccess(
    ref,
    source,
    accessOverride: accessOverride,
  );
  final sourceConfig = const PostOriginResolver().resolve(
    source.origin,
    ref.read(booruConfigProvider),
    allowProfileHintFallback: false,
  );
  return (
    access: access,
    excludedProfileId:
        access?.key.profileId ??
        (sourceConfig is ResolvedPostOrigin
            ? sourceConfig.config.id
            : source.origin.profileIdHint),
    methods: (profile) => remoteLookupMethods(profile, source)
        .where(
          (method) =>
              method != PostLookupMatchKind.similarImage || access != null,
        )
        .toSet(),
  );
}

bool canFindOnOtherProfiles(
  WidgetRef ref,
  Post source, {
  ContentAccessContext? access,
}) {
  if (source.booruData is LocalMediaPostData) return false;
  final lookup = _remoteLookupSource(ref, source, access);
  if (access != null && lookup.access == null) return false;
  return ref
      .read(booruConfigProvider)
      .any(
        (profile) =>
            profile.id != lookup.excludedProfileId &&
            lookup
                .methods(profile)
                .any(
                  (method) =>
                      method != PostLookupMatchKind.similarImage ||
                      supportsIqdbLookup(profile),
                ),
      );
}

Future<void> findOnOtherProfiles(
  WidgetRef ref,
  Post source, {
  ContentAccessContext? access,
}) async {
  final view = ref.context;
  final context = Navigator.of(view, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  final lookup = _remoteLookupSource(ref, source, access);
  if (access != null && lookup.access == null) return;
  final targets = await selectLookupTargets(
    context,
    container,
    available: lookup.methods,
    excludedProfileId: lookup.excludedProfileId,
    useSourceDefaults: ExactPostLookup.normalizeMd5(source.md5) == null,
  );
  if (targets == null || !context.mounted) return;
  unawaited(
    container
        .read(routerProvider)
        .push(
          '/cross-profile-lookup',
          extra: SelectedLookupRequest(
            targets: targets,
            source: source,
            access: lookup.access,
            permission: IqdbPermission.persistent,
          ),
        ),
  );
}

void openSelectedLookup(WidgetRef ref, SelectedLookupRequest request) =>
    ref.pushRoute('/cross-profile-lookup', extra: request);

void findLocalFileOnOtherProfiles(
  WidgetRef ref,
  String md5,
  List<BooruConfig> profiles,
) {
  ref.pushRoute(
    '/cross-profile-lookup',
    extra: (md5: md5, profiles: profiles),
  );
}

typedef LocalFileLookupRequest = ({String md5, List<BooruConfig> profiles});

GoRoute crossProfileLookupRoute() => GoRoute(
  path: 'cross-profile-lookup',
  builder: (context, state) => switch (state.extra) {
    final SelectedLookupRequest request => CrossProfileLookupPage.selected(
      request,
    ),
    final LocalFileLookupRequest request => CrossProfileLookupPage.local(
      request,
    ),
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
      artwork = null,
      local = null,
      selected = null;
  const CrossProfileLookupPage.pixiv({
    required PixivArtworkReference artwork,
    super.key,
  }) : artwork = artwork,
       source = null,
       local = null,
       selected = null;
  const CrossProfileLookupPage.local(this.local, {super.key})
    : artwork = null,
      source = null,
      selected = null;
  const CrossProfileLookupPage.selected(this.selected, {super.key})
    : artwork = null,
      source = null,
      local = null;

  final SelectedLookupRequest? selected;
  final Post? source;
  final PixivArtworkReference? artwork;
  final LocalFileLookupRequest? local;

  @override
  ConsumerState<CrossProfileLookupPage> createState() => _PostLookupPageState();
}

class _PostLookupPageState extends ConsumerState<CrossProfileLookupPage> {
  final _results = <String, CrossProfileResult>{};
  final _pages = <String, int>{};
  final _cancellations = <String, PostLookupCancellation>{};
  final _queue = CrossProfileLookupQueue();
  final _invalidLocalTargets = <BooruConfig>{};

  bool _isLocalTarget(BooruConfig profile) =>
      widget.local == null ||
      (widget.local!.profiles.contains(profile) &&
          !_invalidLocalTargets.contains(profile));

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) return;
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
    if (widget.local case final local?) {
      _invalidLocalTargets.addAll(
        local.profiles.where((p) => !profiles.contains(p)),
      );
    }
    for (final entry in _results.entries.toList()) {
      if (!profiles.contains(entry.value.profile)) {
        _cancellations.remove(entry.key)?.cancel();
        _results.remove(entry.key);
        _pages.remove(entry.key);
      }
    }
    for (final profile in profiles) {
      if (_isLocalTarget(profile) &&
          profile.id !=
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
    final local = widget.local;
    final localLookup = local == null
        ? null
        : ref.read(localFileHashLookupProvider);
    final lookup = switch ((widget.artwork, widget.source)) {
      (final artwork?, _) =>
        ref.read(sharedPixivLookupSessionProvider(artwork)).find,
      (_, final source?) =>
        ref.read(crossProfileLookupSessionProvider(source)).find,
      _ => null,
    };
    final result = await _queue.run(
      () => local == null
          ? lookup!(target, page: page, cancellation: cancellation)
          : localLookup!(
              target,
              local.md5,
              page: page,
              cancellation: cancellation,
            ),
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

  @override
  Widget build(BuildContext context) {
    if (widget.selected case final request?) {
      return SelectedLookupPage(request: request);
    }
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
    } else if (widget.source case final source?) {
      ref.watch(crossProfileLookupSessionProvider(source));
    }
    ref.listen(booruConfigProvider, (_, _) => _syncProfiles());
    final profiles = ref.watch(orderedProfileConfigsProvider);
    final sourceConfig = _sourceConfig(profiles);
    final targets = profiles.where(
      (p) =>
          _isLocalTarget(p) &&
          p.id != (sourceConfig?.id ?? widget.source?.origin.profileIdHint),
    );
    final results = [
      for (final profile in targets)
        _results[profile.id]?.profile == profile
            ? _results[profile.id]!
            : CrossProfileResult(
                profile: profile,
                status: _supports(profile)
                    ? CrossProfileResultStatus.idle
                    : CrossProfileResultStatus.unsupported,
              ),
    ];
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
              : widget.local != null
              ? Text(context.t.local_media.title)
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
          results: results,
          onSelect: _select,
          onMore: (profile) => _select(profile, more: true),
          onOpen: (profile, post) =>
              unawaited(openCrossProfileResults(ref, results, profile, post)),
        ),
      ),
    );
  }
}
