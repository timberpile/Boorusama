import '../../configs/config/providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../boorus/pixiv/posts/types.dart';
import '../../../boorus/pixiv/works/work_mapper.dart';
import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../content/content_access.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_reference.dart';
import '../../images/booru_image.dart';
import '../../router.dart';
import '../post/providers.dart';
import '../post/types.dart';
import '../../local_media/local_media_reference.dart';
import 'data.dart';
import 'iqdb_remote_image.dart';
import 'lookup_preferences.dart';
import 'lookup_selector.dart';
import 'providers.dart';
import 'selected_lookup_page.dart';
import 'results.dart';
import 'src/data/pixiv_lookup_capabilities.dart';
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

NativePixivLookupRequest? _nativePixivPost(
  WidgetRef ref,
  Post post,
  ContentAccessContext? accessOverride,
) {
  final data = post.pixivData;
  if (data == null || data.isRestricted || data.pageIndex < 0) return null;
  final artwork = PixivArtworkReference.fromId(data.illustId);
  final access = lookupSourceAccess(ref, post, accessOverride: accessOverride);
  if (artwork == null ||
      access == null ||
      access.key.engine != BooruType.pixiv ||
      access.key.profileId == null) {
    return null;
  }
  return (
    artwork: artwork,
    sourceAccess: access.key,
    pageIndex: data.pageIndex,
  );
}

NativePixivLookupRequest? _nativePixivWork(
  WidgetRef ref,
  ContentReference reference,
  ContentAccessContext access,
) {
  if (reference.kind != ContentKind.group ||
      !access.accepts(reference) ||
      access.key.profileId == null ||
      !identical(ref.read(contentAccessContextProvider(access.key)), access)) {
    return null;
  }
  final id = pixivWorkIllustId(reference);
  final artwork = id == null ? null : PixivArtworkReference.fromId(id);
  if (artwork == null || reference.sourceKey != 'work:$id') return null;
  return (artwork: artwork, sourceAccess: access.key, pageIndex: null);
}

_RemoteLookupSource _nativePixivLookupSource(
  WidgetRef ref,
  NativePixivLookupRequest request, {
  required bool stillImage,
}) {
  final access = ref.read(contentAccessContextProvider(request.sourceAccess));
  final config = access?.config;
  final canHash =
      stillImage && config != null && supportsPixivArtworkTarget(config);
  return (
    access: access,
    excludedProfileId: request.sourceAccess.profileId,
    methods: (profile) {
      if (!supportsSharedPixivLookup(profile)) return const {};
      return {
        if (pixivSourceQueries(
          postOriginFromConfig(profile),
          request.artwork.id,
        ).isNotEmpty)
          PostLookupMatchKind.pixivSource,
        if (canHash && supportsExactPostLookup(profile))
          PostLookupMatchKind.exactFile,
      };
    },
  );
}

bool _hasPixivLookupTarget(
  WidgetRef ref,
  NativePixivLookupRequest request, {
  required bool stillImage,
}) {
  final lookup = _nativePixivLookupSource(ref, request, stillImage: stillImage);
  return lookup.access != null &&
      ref
          .read(booruConfigProvider)
          .any(
            (profile) =>
                profile.id != lookup.excludedProfileId &&
                lookup.methods(profile).isNotEmpty,
          );
}

Future<void> _openNativePixivLookup(
  WidgetRef ref,
  NativePixivLookupRequest request, {
  required bool stillImage,
}) async {
  final lookup = _nativePixivLookupSource(ref, request, stillImage: stillImage);
  final access = lookup.access;
  if (access == null) return;
  final view = ref.context;
  final context = Navigator.of(view, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  final targets = await selectLookupTargets(
    context,
    container,
    available: lookup.methods,
    excludedProfileId: lookup.excludedProfileId,
    preferredMethod: PostLookupMatchKind.pixivSource,
    rememberChoices: false,
  );
  if (targets == null ||
      !view.mounted ||
      !context.mounted ||
      !identical(
        container.read(contentAccessContextProvider(access.key)),
        access,
      )) {
    return;
  }
  unawaited(
    ref.pushRoute<void>(
      '/cross-profile-lookup',
      extra: SelectedLookupRequest(
        targets: targets,
        permission: IqdbPermission.none,
        access: access,
        nativePixiv: request,
      ),
    ),
  );
}

bool canFindPixivWorkOnOtherProfiles(
  WidgetRef ref,
  ContentReference reference,
  ContentAccessContext access,
) {
  final request = _nativePixivWork(ref, reference, access);
  return request != null &&
      _hasPixivLookupTarget(ref, request, stillImage: true);
}

Future<void> findPixivWorkOnOtherProfiles(
  WidgetRef ref,
  ContentReference reference,
  ContentAccessContext access,
) async {
  final request = _nativePixivWork(ref, reference, access);
  if (request != null) {
    await _openNativePixivLookup(ref, request, stillImage: true);
  }
}

bool canFindOnOtherProfiles(
  WidgetRef ref,
  Post source, {
  ContentAccessContext? access,
}) {
  if (source.booruData is LocalMediaPostData) return false;
  if (source.origin.booruType == BooruType.pixiv) {
    final request = _nativePixivPost(ref, source, access);
    return request != null &&
        _hasPixivLookupTarget(
          ref,
          request,
          stillImage: source.pixivData?.isUgoira == false,
        );
  }
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
  if (source.origin.booruType == BooruType.pixiv) {
    final request = _nativePixivPost(ref, source, access);
    if (request != null) {
      await _openNativePixivLookup(
        ref,
        request,
        stillImage: source.pixivData?.isUgoira == false,
      );
    }
    return;
  }
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

  PixivArtworkReference? get _artwork => widget.artwork;

  AutoDisposeProvider<SharedPixivLookupSession>? get _artworkSession {
    if (widget.artwork case final artwork?) {
      return sharedPixivLookupSessionProvider(artwork);
    }
    return null;
  }

  bool _supports(BooruConfig profile) => _artwork != null
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

  String? _excludedProfileId(BooruConfig? sourceConfig) =>
      sourceConfig?.id ?? widget.source?.origin.profileIdHint;

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
          profile.id != _excludedProfileId(sourceConfig) &&
          _supports(profile) &&
          _results[profile.id]?.profile != profile) {
        unawaited(_select(profile));
      }
    }
    if (mounted) setState(() {});
  }

  void _clearResults() {
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
    _cancellations.clear();
    _results.clear();
    _pages.clear();
  }

  @override
  void dispose() {
    _clearResults();
    super.dispose();
  }

  Future<void> _select(BooruConfig target, {bool more = false}) async {
    _cancellations[target.id]?.cancel();
    final cancellation = PostLookupCancellation(
      shouldCancel: () => !mounted,
    );
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
    final lookup = switch ((_artworkSession, widget.source)) {
      (final session?, _) => ref.read(session).find,
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
    if (_artworkSession case final session?) {
      ref.watch(session);
      ref.listen(session, (previous, next) {
        if (previous == null || identical(previous, next)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !identical(ref.read(session), next)) return;
          _clearResults();
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
      (p) => _isLocalTarget(p) && p.id != _excludedProfileId(sourceConfig),
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
          _artwork != null
              ? context.t.post.cross_profile.shared_pixiv_title
              : context.t.post.cross_profile.action,
        ),
      ),
      body: SafeArea(
        child: CrossProfileResults(
          reference: _artwork != null
              ? Text(
                  context.t.post.cross_profile.pixiv_artwork(
                    id: _artwork!.id,
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
          onOpen: (profile, post) {
            unawaited(
              openCrossProfileResults(
                ref,
                results,
                profile,
                post,
              ),
            );
          },
        ),
      ),
    );
  }
}
