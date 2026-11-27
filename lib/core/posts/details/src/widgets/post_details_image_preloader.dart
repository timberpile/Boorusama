import '../../../../boorus/booru/types.dart';
import '../../../../../boorus/pixiv/works/work_creator_avatar.dart';
import '../../../../../boorus/pixiv/ugoira/ugoira_media.dart';
import '../../../../../boorus/pixiv/ugoira/ugoira_preparation.dart';
import '../../../../content/groups/group_metadata.dart';

import 'dart:async';

import '../../../../navigation/destination_activity.dart';
import '../../../../local_media/local_media_reference.dart';

// Package imports:
import 'package:foundation/performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../content/content_access.dart';
import '../../../../content/content_access_provider.dart';
import '../providers/viewer_source_access_provider.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../settings/providers.dart';
import '../../../details_pageview/widgets.dart';
import '../../../listing/providers.dart';
import '../../../media_preload/providers.dart';
import '../../../media_preload/types.dart';
import '../../../media_preload/src/preload_metadata_queue.dart';
import '../../../media_preload/src/viewer_preload_metadata.dart';
import '../../../post/types.dart';
import '../providers/providers.dart';
import '../providers/media_group_provider.dart';
import '../providers/group_reading_provider.dart';
import '../types/viewer_entry.dart';
import 'post_details_page_view_scope.dart';

class MixedPostDetailsImagePreloader extends ConsumerStatefulWidget {
  const MixedPostDetailsImagePreloader({
    required this.child,
    required this.posts,
    this.sequence,
    this.isMediaGroupAt,
    super.key,
  });

  final List<Post> posts;
  final ViewerEntrySequence? sequence;
  final bool Function(int index)? isMediaGroupAt;
  int get pageCount => sequence?.entries.length ?? posts.length;
  Post? postAt(int page) =>
      sequence == null ? posts.elementAtOrNull(page) : sequence!.postAt(page);
  final Widget child;

  @override
  ConsumerState<MixedPostDetailsImagePreloader> createState() =>
      _MixedPostDetailsImagePreloaderState();
}

class _MixedPostDetailsImagePreloaderState
    extends ConsumerState<MixedPostDetailsImagePreloader> {
  final _subscriptions =
      <ContentPreloadRequest, ProviderSubscription<PreloadManager>>{};
  late final _preloadManager =
      GroupedPreloadManager<({BooruConfigAuth auth, ContentAccessKey? access})>(
        managerBuilder: (group) {
          final auth = group.auth;
          if (group.access case final key?) {
            final request = (auth: auth, access: key);
            final subscription = ref.listenManual(
              contentPreloadManagerProvider(request),
              (_, _) {},
            );
            _subscriptions[request] = subscription;
            return subscription.read();
          }
          final dio = ref.read(dioForWidgetProvider(auth));
          return ref.read(
            preloadManagerProvider((dio: dio, authConfig: auth)),
          );
        },
        onGroupRemoved: (group) {
          if (group.access case final key?) {
            _subscriptions.remove((auth: group.auth, access: key))?.close();
          }
        },
      );
  late final _metadata =
      PreloadMetadataQueue<(Post, BooruConfig, ContentAccessKey?), Post>(
        onResolved: () {
          if (mounted && _pageViewController != null) {
            _dispatchImages(_controller.page);
          }
        },
      );
  final _groupStates =
      <GroupViewerEntry, ({MediaGroupState state, Post? landingPost})>{};
  final _directionHistory = DirectionHistory();
  PostDetailsPageViewController? _pageViewController;
  int? _lastPage;
  var _wasActive = false;
  var _refreshScheduled = false;
  PixivUgoiraRequest? _preparingNeighbor;
  late int _lastItemCount = widget.pageCount;

  PostDetailsPageViewController get _controller => _pageViewController!;

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted && _pageViewController != null) {
        _preloadAdjacentPages(_controller.page);
      }
    });
    binding.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(MixedPostDetailsImagePreloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.posts, widget.posts) ||
        !identical(oldWidget.sequence, widget.sequence) ||
        _lastItemCount != widget.pageCount) {
      _scheduleRefresh();
    }
    _lastItemCount = widget.pageCount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = NavigationActivity.of(context);
    final resumed = active && !_wasActive;
    _wasActive = active;
    if (!active) {
      _metadata.cancel();
      _preloadManager.cancelAll();
    }
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) {
      if (resumed) _scheduleRefresh();
      return;
    }

    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _metadata.cancel();
    _preloadManager.cancelAll();
    _pageViewController = controller;
    _directionHistory.clear();
    _lastPage = controller.page;
    controller.currentPage.addListener(_onPageChanged);
    _scheduleRefresh();
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
    _preloadAdjacentPages(currentPage);
    setState(() {});
  }

  BooruConfig? _configAt(int index, Post post, List<BooruConfig> profiles) {
    final binding = widget.sequence?.entries[index].source;
    if (binding != null) {
      return ref.read(viewerSourceAccessProvider(binding))?.config;
    }
    return switch (const PostOriginResolver().resolve(post.origin, profiles)) {
      ResolvedPostOrigin(:final config) => config,
      _ => null,
    };
  }

  PixivUgoiraRequest? _ugoiraRequestAt(int index) {
    if (index < 0 || index >= widget.pageCount) return null;
    final post = widget.postAt(index);
    if (post == null || pixivUgoiraIllustId(post) == null) return null;
    final binding = widget.sequence?.entries[index].source;
    final access = binding != null
        ? ref.watch(viewerSourceAccessProvider(binding))
        : switch (const PostOriginResolver().resolve(
            post.origin,
            ref.watch(booruConfigProvider),
            allowProfileHintFallback: false,
          )) {
            ResolvedPostOrigin(:final config) => ref.watch(
              contentProfileAccessProvider(config.id),
            ),
            _ => null,
          };
    return watchPixivUgoiraRequest(ref, post, access);
  }

  void _watchUgoiraWindow(int page) {
    final current = _ugoiraRequestAt(page);
    if (current != null) ref.watch(pixivUgoiraPreparationProvider(current));

    final direction = _directionHistory.directions.lastOrNull?.$1 ?? 1;
    final neighbors = {
      ?_ugoiraRequestAt(page + direction),
      ?_ugoiraRequestAt(page - direction),
    }..remove(current);
    final pending = _preparingNeighbor;
    _preparingNeighbor = null;
    // Keep a still-relevant preparation running when the direction changes.
    for (final neighbor in [
      if (pending != null && neighbors.remove(pending)) pending,
      ...neighbors,
    ]) {
      if (ref.watch(pixivUgoiraPreparationProvider(neighbor)).isLoading) {
        _preparingNeighbor = neighbor;
        break;
      }
    }
  }

  void _preloadAdjacentPages(int currentPage) {
    if (!mounted ||
        !NavigationActivity.of(context) ||
        !ref.read(automaticMediaLoadingEnabledProvider)) {
      _metadata.cancel();
      _preloadManager.cancelAll();
      return;
    }
    final configs = ref.read(booruConfigProvider);
    // Ordinary engines need no metadata admission scan. Preserve the existing
    // bounded collection reads when none of the profiles offers this capability.
    if (!configs.any(
      (config) =>
          ref.read(booruRepoProvider(config.auth))
              is ViewerPreloadMetadataResolver,
    )) {
      _metadata.cancel();
      _dispatchImages(currentPage);
      return;
    }
    final strategy = DirectionBasedPreloadStrategy(
      directionHistory: _directionHistory,
    );
    final nearby = strategy
        .getResolutionIndices(
          currentPage: currentPage,
          itemCount: widget.pageCount,
        )
        .where((index) => index != currentPage)
        .toList();
    int priority(int index) {
      final delta = index - currentPage;
      final opposite = switch (_directionHistory.scrollDirection) {
        ScrollDirection.forward => delta < 0,
        ScrollDirection.backward => delta > 0,
        _ => false,
      };
      return delta.abs() * 2 + (opposite ? 1 : 0);
    }

    nearby.sort((a, b) => priority(a).compareTo(priority(b)));
    final indices = [
      if (currentPage >= 0 && currentPage < widget.pageCount) currentPage,
      ...(_directionHistory.entryPattern == EntryPattern.direct
          ? nearby.where((index) => (index - currentPage).abs() == 1)
          : nearby.take(4)),
    ];
    final requests =
        <
          PreloadMetadataRequest<(Post, BooruConfig, ContentAccessKey?), Post>
        >[];
    for (final index in indices) {
      final post = widget.postAt(index);
      if (post == null || post.requiresDetailLookup) continue;
      final config = _configAt(index, post, configs);
      final binding = widget.sequence?.entries[index].source;
      final accessKey = binding == null
          ? null
          : ref.read(viewerSourceAccessProvider(binding))?.key;
      if (accessKey != null &&
          ref
                  .read(
                    contentPostVisibilityProvider((
                      access: accessKey,
                      post: post,
                    )),
                  )
                  .asData
                  ?.value !=
              true) {
        continue;
      }
      if (config != null) {
        final repository = ref.read(booruRepoProvider(config.auth));
        if (repository case final ViewerPreloadMetadataResolver resolver) {
          final load = resolver.viewerPreloadMetadataLoader(post, config);
          if (load != null) {
            requests.add((
              key: (post, config, accessKey),
              load: () async {
                final result = await load();
                if (!mounted ||
                    (binding != null &&
                        ref.read(viewerSourceAccessProvider(binding))?.key !=
                            accessKey)) {
                  return null;
                }
                if (result == null ||
                    result.id != post.id ||
                    result.origin.booruType != post.origin.booruType ||
                    result.origin.sourceHost != post.origin.sourceHost) {
                  return null;
                }
                return result;
              },
            ));
          }
        }
      }
    }
    unawaited(_metadata.replace(requests));
    _dispatchImages(currentPage);
  }

  void _dispatchImages(int currentPage) {
    if (!mounted || !NavigationActivity.of(context)) {
      _preloadManager.cancelAll();
      return;
    }
    final diagnosticRecording = performanceRecorder.enabled;
    var diagnosticResolved = 0;
    performanceRecorder.measureSync(PerfOperation.mixedPreloadResolve, () {
      if (!ref.read(automaticMediaLoadingEnabledProvider)) {
        _preloadManager.cancelAll();
        return;
      }

      final configs = ref.read(booruConfigProvider);
      _preloadManager.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directionHistory,
          options: const PreloadStrategyOptions(preloadDisplayOnEntry: true),
        ),
        currentPage: currentPage,
        itemCount: widget.pageCount,
        mediaBuilder: (index) {
          if (diagnosticRecording) diagnosticResolved++;
          final entry = widget.sequence?.entries[index];
          if (entry is GroupViewerEntry) {
            return (index - currentPage).abs() <= 1
                ? _groupPreloadMedia(entry)
                : null;
          }
          final input = widget.postAt(index);
          if (input == null || input.booruData is LocalMediaPostData) {
            return null;
          }
          final config = _configAt(index, input, configs);
          if (config == null) return null;
          final binding = widget.sequence?.entries[index].source;
          final accessKey = binding == null
              ? null
              : ref.read(viewerSourceAccessProvider(binding))?.key;
          if (binding != null && accessKey == null) return null;
          final repository = ref.read(booruRepoProvider(config.auth));
          final needsMetadata = switch (repository) {
            final ViewerPreloadMetadataResolver resolver =>
              resolver.viewerPreloadMetadataLoader(input, config) != null,
            _ => false,
          };
          final resolved = _metadata.peek((input, config, accessKey));
          final post = resolved ?? input;
          if (accessKey != null &&
              ref
                      .read(
                        contentPostVisibilityProvider((
                          access: accessKey,
                          post: post,
                        )),
                      )
                      .asData
                      ?.value !=
                  true) {
            return null;
          }
          final auth = config.auth;
          final resolver = ref.read(mediaUrlResolverProvider(auth));
          final thumbnail = needsMetadata || post.isVideo
              ? null
              : ref
                    .read(gridThumbnailUrlGeneratorProvider(auth))
                    .resolve(
                      post,
                      settings: ref.read(gridThumbnailSettingsProvider(auth)),
                    )
                    .url;
          final media = viewerPreloadMedia(
            post,
            thumbnailUrl: thumbnail,
            displayUrl: needsMetadata && resolved == null
                ? null
                : resolver.resolveMediaUrl(post, config.viewer),
          );
          return media == null
              ? null
              : (group: (auth: auth, access: accessKey), media: media);
        },
      );
    });
    performanceRecorder.count(
      PerfCounter.mixedCollectionSize,
      widget.pageCount,
    );
    performanceRecorder.count(
      PerfCounter.mixedResolvedPosts,
      diagnosticResolved,
    );
  }

  GroupedPreloadMedia<({BooruConfigAuth auth, ContentAccessKey? access})>?
  _groupPreloadMedia(GroupViewerEntry entry) {
    final group = _groupStates[entry];
    final access = group?.state.access;
    final config = access?.config;
    final post = group?.landingPost;
    if (access == null ||
        config == null ||
        post == null ||
        !identical(
          ref.read(viewerSourceAccessProvider(entry.source!)),
          access,
        ) ||
        ref
                .read(
                  contentPostVisibilityProvider((
                    access: access.key,
                    post: post,
                  )),
                )
                .asData
                ?.value !=
            true) {
      return null;
    }
    final resolver = ref.read(mediaUrlResolverProvider(config.auth));
    final media = viewerPreloadMedia(
      post,
      thumbnailUrl: post.sampleImageUrl,
      displayUrl: resolver.resolveMediaUrl(post, config.viewer),
    );
    return media == null
        ? null
        : (group: (auth: config.auth, access: access.key), media: media);
  }

  @override
  void dispose() {
    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _metadata.dispose();
    _preloadManager.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previousGroups = Map.of(_groupStates);
    _groupStates.clear();
    if (_pageViewController != null &&
        NavigationActivity.of(context) &&
        ref.watch(automaticMediaLoadingEnabledProvider)) {
      final hasPixiv = ref.watch(
        booruConfigProvider.select(
          (profiles) => profiles.any(
            (profile) => profile.auth.booruType == BooruType.pixiv,
          ),
        ),
      );
      if (hasPixiv && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _watchUgoiraWindow(_controller.page);
      } else {
        _preparingNeighbor = null;
      }
      // Share the foreground's manifest for the current and adjacent entries.
      for (final index in [
        _controller.page - 1,
        _controller.page,
        _controller.page + 1,
      ]) {
        final entries = widget.sequence?.entries;
        if (entries == null || index < 0 || index >= entries.length) {
          continue;
        }
        final entry = entries[index];
        if (entry is! GroupViewerEntry || entry.source == null) {
          continue;
        }
        final isMediaGroup = widget.isMediaGroupAt?.call(index) ?? false;
        if (!isMediaGroup && entry.contentReference.engine != BooruType.pixiv) {
          continue;
        }
        final state = ref.watch(mediaGroupProvider(entry));
        Post? landingPost;
        if (state.members case final members? when isMediaGroup) {
          final checkpoint = ref.watch(groupReadingProvider(entry)).checkpoint;
          final memberIndex = checkpoint.indexIn(members.members);
          if (memberIndex != null) landingPost = state.postAt(memberIndex);
        }
        if (state.access case final access? when landingPost != null) {
          final visibility = (access: access.key, post: landingPost);
          ref.listen(
            contentPostVisibilityProvider(visibility),
            (_, _) => _scheduleRefresh(),
          );
        }
        _groupStates[entry] = (state: state, landingPost: landingPost);
      }
    } else {
      _preparingNeighbor = null;
    }
    if (previousGroups.length != _groupStates.length ||
        _groupStates.entries.any(
          (entry) => previousGroups[entry.key] != entry.value,
        )) {
      _scheduleRefresh();
    }
    if (_pageViewController != null) {
      final indices =
          DirectionBasedPreloadStrategy(directionHistory: _directionHistory)
              .getResolutionIndices(
                currentPage: _controller.page,
                itemCount: widget.pageCount,
              );
      for (final index in indices) {
        final binding = widget.sequence?.entries[index].source;
        if (binding != null) {
          final access = ref.watch(viewerSourceAccessProvider(binding));
          final post = widget.postAt(index);
          if (access != null && post != null) {
            ref.listen(
              contentPostVisibilityProvider((access: access.key, post: post)),
              (_, _) => _scheduleRefresh(),
            );
          }
          ref.listen(
            viewerSourceAccessProvider(binding),
            (_, _) => _scheduleRefresh(),
          );
        }
      }
    }
    ref.listen(booruConfigProvider, (_, _) => _scheduleRefresh());
    ref.listen(
      settingsProvider.select((settings) => settings.viewer.postQuality),
      (_, _) => _scheduleRefresh(),
    );
    ref.listen(automaticMediaLoadingEnabledProvider, (_, enabled) {
      if (!enabled) {
        _metadata.cancel();
        _preloadManager.cancelAll();
      } else {
        _scheduleRefresh();
      }
    });
    return PixivWorkAvatarWindow(
      creators: [
        for (final group in _groupStates.entries)
          if (group.key.contentReference.engine == BooruType.pixiv)
            if (group.value.state.access case final access?)
              for (final creator
                  in group.value.state.details?.creators ??
                      const <CreatorRef>[])
                (creator: creator, access: access),
      ],
      child: widget.child,
    );
  }
}

class PostDetailsImagePreloader<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsImagePreloader({
    required this.child,
    required this.authConfig,
    required this.posts,
    required this.imageUrlBuilder,
    super.key,
  });

  final BooruConfigAuth authConfig;
  final List<T> posts;
  final Widget child;
  final String Function(T post) imageUrlBuilder;

  @override
  ConsumerState<PostDetailsImagePreloader<T>> createState() =>
      _PostDetailsImagePreloaderState<T>();
}

class _PostDetailsImagePreloaderState<T extends Post>
    extends ConsumerState<PostDetailsImagePreloader<T>> {
  PreloadManager? _preloadManager;

  PostDetailsPageViewController? _pageViewController;

  // Direction tracking
  int? _lastPage;
  var _wasActive = false;
  var _refreshScheduled = false;
  final _directionHistory = DirectionHistory();

  PostDetailsPageViewController get _controller => _pageViewController!;

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted && _pageViewController != null) {
        _preloadAdjacentPages(_controller.page);
      }
    });
    binding.ensureVisualUpdate();
  }

  void _bindPreloadManager() {
    final auth = widget.authConfig;
    final dio = ref.read(dioForWidgetProvider(auth));
    _preloadManager = ref.read(
      preloadManagerProvider((dio: dio, authConfig: auth)),
    );
  }

  @override
  void didUpdateWidget(PostDetailsImagePreloader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authConfig != widget.authConfig) {
      _preloadManager?.cancelAll();
      _bindPreloadManager();
    }
    if (oldWidget.authConfig != widget.authConfig ||
        !identical(oldWidget.posts, widget.posts) ||
        oldWidget.imageUrlBuilder != widget.imageUrlBuilder) {
      _scheduleRefresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final active = NavigationActivity.of(context);
    final resumed = active && !_wasActive;
    _wasActive = active;
    if (!active) _preloadManager?.cancelAll();
    final controller = PostDetailsPageViewScope.of(context);
    if (identical(_pageViewController, controller)) {
      if (resumed) _scheduleRefresh();
      return;
    }

    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager?.cancelAll();
    _pageViewController = controller;
    _directionHistory.clear();
    _lastPage = controller.page;
    _bindPreloadManager();
    controller.currentPage.addListener(_onPageChanged);
    _scheduleRefresh();
  }

  void _onPageChanged() {
    if (!mounted) return;
    final currentPage = _controller.page;
    _updateDirectionHistory(currentPage);
    _preloadAdjacentPages(currentPage);
  }

  void _updateDirectionHistory(int currentPage) {
    _directionHistory.addDirection(currentPage, _lastPage);
    _lastPage = currentPage;
  }

  void _preloadAdjacentPages(int currentPage) {
    if (!mounted ||
        !NavigationActivity.of(context) ||
        !ref.read(automaticMediaLoadingEnabledProvider)) {
      _preloadManager?.cancelAll();
      return;
    }
    performanceRecorder.measureSync(PerfOperation.viewerPreloadDispatch, () {
      if (!mounted) return;

      final gridThumbnailUrlBuilder = ref.read(
        gridThumbnailUrlGeneratorProvider(widget.authConfig),
      );

      final settings = ref.read(
        gridThumbnailSettingsProvider(widget.authConfig),
      );

      _preloadManager?.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directionHistory,
          options: const PreloadStrategyOptions(preloadDisplayOnEntry: true),
        ),
        currentPage: currentPage,
        itemCount: widget.posts.length,
        mediaBuilder: (index) {
          final post = widget.posts[index];
          return viewerPreloadMedia(
            post,
            thumbnailUrl: post.isVideo
                ? null
                : gridThumbnailUrlBuilder.resolve(post, settings: settings).url,
            displayUrl: post.isVideo ? null : widget.imageUrlBuilder(post),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _pageViewController?.currentPage.removeListener(_onPageChanged);
    _preloadManager?.cancelAll();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(automaticMediaLoadingEnabledProvider, (_, enabled) {
      if (enabled) {
        _scheduleRefresh();
      } else {
        _preloadManager?.cancelAll();
      }
    });
    return widget.child;
  }
}
