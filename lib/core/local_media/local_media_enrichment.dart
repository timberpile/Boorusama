import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/danbooru/posts/post/types.dart';
import '../blacklists/providers.dart';
import '../boorus/booru/types.dart';
import '../cache/misc_data_store.dart';
import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import '../errors/error.dart';
import '../http/client/coordination.dart';
import '../posts/cross_profile_lookup/iqdb_lookup.dart';
import '../posts/cross_profile_lookup/iqdb_signature.dart';
import '../posts/cross_profile_lookup/lookup_preferences.dart';
import '../posts/cross_profile_lookup/providers.dart';
import '../posts/cross_profile_lookup/types.dart';
import '../posts/post/providers.dart';
import '../posts/post/types.dart';
import '../posts/rating/types.dart';
import '../posts/sources/types.dart';
import '../tags/categories/types.dart';
import '../tags/tag/providers.dart';
import '../tags/tag/types.dart';
import 'local_media_library.dart';
import 'local_media_models.dart';

final localMediaOnlineConsentProvider =
    NotifierProvider<LocalMediaOnlineConsent, bool>(
      LocalMediaOnlineConsent.new,
      dependencies: [miscDataStoreProvider],
    );

class LocalMediaOnlineConsent extends Notifier<bool> {
  static const _key = 'local_media.online_enrichment';
  Future<void> _writeTail = Future.value();
  var _disposed = false;
  var _revision = 0;

  @override
  bool build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return ref.watch(miscDataStoreProvider).get(_key) == 'true';
  }

  Future<void> setEnabled(bool enabled) {
    final revision = ++_revision;
    if (!enabled) state = false;
    final store = ref.read(miscDataStoreProvider);
    final write = _writeTail.then((_) async {
      await store.put(_key, enabled.toString());
      if (!_disposed && revision == _revision) state = enabled;
    });
    _writeTail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}

final localMediaEnrichmentServiceProvider =
    Provider<LocalMediaEnrichmentService>(
      (ref) {
        final service = LocalMediaEnrichmentService(ref);
        ref.listen(localMediaOnlineConsentProvider, (_, enabled) {
          if (!enabled) service.cancelAutomatic();
        });
        ref.onDispose(service.dispose);
        return service;
      },
      dependencies: [
        localMediaOnlineConsentProvider,
        booruConfigProvider,
        lookupPreferencesProvider,
      ],
    );

enum LocalMediaEnrichmentIssue {
  missingFile,
  noApplicableMethod,
  signatureUnavailable,
  incompleteLookup,
  filteredMatches,
  noMatch,
  imageChanged,
  matchUnavailable,
  operationFailed,
}

enum LocalMediaLookupFailureKind {
  rateLimited,
  http,
  connection,
  invalidResponse,
  filtered,
  interrupted,
  unknown,
}

typedef LocalMediaLookupFailure = ({
  LocalMediaLookupFailureKind kind,
  int? httpStatus,
  DateTime? retryAt,
});

typedef LocalMediaLookupDetail = ({
  BooruConfig profile,
  PostLookupMatchKind method,
  LocalMediaLookupFailure? failure,
});

LocalMediaLookupFailure _lookupFailure(
  LocalMediaLookupFailureKind kind, {
  int? httpStatus,
  DateTime? retryAt,
}) => (kind: kind, httpStatus: httpStatus, retryAt: retryAt);

class LocalMediaEnrichmentOutcome {
  const LocalMediaEnrichmentOutcome(
    this.result, {
    this.issue,
    this.review,
    this.lookupDetails = const {},
  });

  final LocalMediaEnrichmentResult result;
  final LocalMediaEnrichmentIssue? issue;
  final LocalMediaEnrichmentReview? review;
  final Set<LocalMediaLookupDetail> lookupDetails;

  bool get incomplete =>
      issue == LocalMediaEnrichmentIssue.incompleteLookup ||
      issue == LocalMediaEnrichmentIssue.filteredMatches ||
      issue == LocalMediaEnrichmentIssue.signatureUnavailable;
}

class LocalMediaEnrichmentReview {
  LocalMediaEnrichmentReview(this.item, Iterable<IqdbHit> candidates)
    : candidates = List.unmodifiable(candidates);

  final LocalMediaItem item;
  final List<IqdbHit> candidates;
}

typedef _ProfileMatches = ({
  BooruConfig target,
  List<Post> posts,
  LocalMediaLookupFailure? failure,
});

class LocalMediaEnrichmentService {
  LocalMediaEnrichmentService(this._ref);

  final Ref _ref;
  final _requests = CrossProfileLookupQueue();
  Future<void> _automaticTail = Future.value();
  var _automaticRevision = 0;
  var _disposed = false;

  List<BooruConfig> get targets => [
    for (final profile in _ref.read(booruConfigProvider))
      if (supportsExactPostLookup(profile) || supportsIqdbLookup(profile))
        profile,
  ];

  void cancelAutomatic() => _automaticRevision++;

  void dispose() {
    _disposed = true;
    cancelAutomatic();
  }

  void Function(LocalMediaItem)? automaticImporter(
    LocalMediaLibrary library,
    LocalMediaCancellation cancellation,
  ) {
    if (!_ref.read(localMediaOnlineConsentProvider)) return null;
    final profiles = targets;
    if (profiles.isEmpty) return null;
    final revision = _automaticRevision;
    return (item) {
      _automaticTail = _automaticTail.then((_) async {
        try {
          await enrich(
            library,
            item,
            profiles: profiles,
            cancelled: () =>
                cancellation.isCancelled || revision != _automaticRevision,
            automatic: true,
          );
        } catch (_) {
          // Enrichment is best effort. A failed lookup or write never changes
          // import success, and transport errors may carry request details.
        }
      });
    };
  }

  Future<LocalMediaEnrichmentOutcome> enrich(
    LocalMediaLibrary library,
    LocalMediaItem item, {
    required List<BooruConfig> profiles,
    required bool Function() cancelled,
    bool automatic = false,
    bool batch = false,
    CancelToken? lookupCancellation,
    List<LookupTarget>? selection,
    IqdbPermission iqdbPermission = IqdbPermission.none,
  }) async {
    bool stopped() =>
        _disposed || cancelled() || (lookupCancellation?.isCancelled ?? false);
    final requestClass = switch ((automatic, batch)) {
      (true, _) => ApiRequestClass.automaticBulk,
      (false, true) => ApiRequestClass.bulkTransfer,
      _ => ApiRequestClass.interactive,
    };

    const skipped = LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.skipped,
    );
    if (stopped()) return skipped;
    if (library.find(item.reference)?.id != item.id) {
      return const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.missingFile,
      );
    }
    final file = await library.resolve(item.reference);
    if (stopped()) return skipped;
    if (file == null) {
      return const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.missingFile,
      );
    }
    final preferences = _ref.read(lookupPreferencesProvider);
    final selected =
        selection ??
        [
          for (final profile in profiles)
            (
              profile: profile,
              methods: automatic
                  ? (preferences.methodsFor(profile) ??
                            {PostLookupMatchKind.exactFile})
                        .intersection(
                          localLookupMethods(
                            profile,
                            stillImage: supportsIqdbImageFormat(
                              item.format.extension,
                            ),
                          ),
                        )
                  : const {PostLookupMatchKind.exactFile},
            ),
        ];
    final grant = automatic ? IqdbPermission.persistent : iqdbPermission;
    final exact = selected
        .where(
          (target) => target.methods.contains(PostLookupMatchKind.exactFile),
        )
        .toList();
    final similar = selected
        .where(
          (target) =>
              target.methods.contains(PostLookupMatchKind.similarImage) &&
              supportsIqdbLookup(target.profile) &&
              supportsIqdbImageFormat(item.format.extension) &&
              preferences.permits(grant),
        )
        .toList();
    if (exact.isEmpty && similar.isEmpty) {
      return const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.noApplicableMethod,
      );
    }

    final invalidated = <BooruConfig>{};
    final profileSubscription = _ref.listen(booruConfigProvider, (_, current) {
      invalidated.addAll(
        profiles.where((profile) => !current.contains(profile)),
      );
    });
    final deselected = <(BooruConfig, PostLookupMatchKind)>{};
    var iqdbRevoked = false;
    final selectionSubscription = _ref.listen(lookupPreferencesProvider, (
      _,
      next,
    ) {
      if (grant == IqdbPermission.persistent && !next.allowIqdb) {
        iqdbRevoked = true;
      }
      if (selection == null && !automatic) return;
      for (final target in selected) {
        for (final method in target.methods) {
          if (!stillSelected(next, target, method)) {
            deselected.add((target.profile, method));
          }
        }
      }
    });
    bool current(BooruConfig target) =>
        !invalidated.contains(target) && _isCurrent(target);
    bool selectedNow(LookupTarget target, PostLookupMatchKind method) =>
        current(target.profile) &&
        !deselected.contains((target.profile, method)) &&
        (selection == null && !automatic ||
            stillSelected(
              _ref.read(lookupPreferencesProvider),
              target,
              method,
            ));
    bool exactCurrent(LookupTarget target) =>
        selectedNow(target, PostLookupMatchKind.exactFile);
    bool similarCurrent(LookupTarget target) =>
        !iqdbRevoked &&
        selectedNow(target, PostLookupMatchKind.similarImage) &&
        _ref.read(lookupPreferencesProvider).permits(grant);
    final exactDetails = [
      for (final target in exact)
        (
          profile: target.profile,
          method: PostLookupMatchKind.exactFile,
          failure: null,
        ),
    ];
    final similarDetails = [
      for (final target in similar)
        (
          profile: target.profile,
          method: PostLookupMatchKind.similarImage,
          failure: null,
        ),
    ];
    final lookup = _ref.read(localFileHashLookupProvider);
    final subscriptions = [
      for (final target in profiles)
        _ref.listen(blacklistTagsProvider(target.filter), (_, _) {}),
    ];
    try {
      final results = await Future.wait([
        for (final target in exact)
          _findMatches(
            target.profile,
            item.md5,
            lookup,
            () => stopped() || !exactCurrent(target),
            requestClass: requestClass,
            cancellation: lookupCancellation,
          ),
      ]);
      if (stopped()) return skipped;

      bool exactCompletedEmpty() =>
          exact.every(exactCurrent) &&
          results.every(
            (result) => result.failure == null && result.posts.isEmpty,
          );
      if (similar.isNotEmpty && exactCompletedEmpty()) {
        bool stillSearching() =>
            !stopped() &&
            exactCompletedEmpty() &&
            similar.every(similarCurrent);
        LocalMediaEnrichmentOutcome interrupted() =>
            LocalMediaEnrichmentOutcome(
              LocalMediaEnrichmentResult.skipped,
              issue: LocalMediaEnrichmentIssue.incompleteLookup,
              lookupDetails: {
                for (final (index, target) in exact.indexed)
                  if (!exactCurrent(target)) exactDetails[index],
                for (final (index, target) in similar.indexed)
                  if (!similarCurrent(target)) similarDetails[index],
              },
            );
        final signature = await iqdbSignatureQueue
            .run(() async {
              if (!stillSearching() ||
                  library.find(item.reference)?.id != item.id) {
                return null;
              }
              return iqdbSignatureFromFile(file.path);
            })
            .onError<Object>((_, _) => null);
        if (stopped()) return skipped;
        if (!stillSearching()) return interrupted();
        if (signature == null) {
          return LocalMediaEnrichmentOutcome(
            LocalMediaEnrichmentResult.skipped,
            issue: LocalMediaEnrichmentIssue.signatureUnavailable,
            lookupDetails: similarDetails.toSet(),
          );
        }
        final search = _ref.read(iqdbSearchProvider);
        final responses = await Future.wait([
          for (final target in similar)
            _requests.run<
              ({List<IqdbHit>? hits, LocalMediaLookupFailure? failure})
            >(() async {
              try {
                final hits = await runWithApiRequestContext(
                  ApiRequestContext(
                    requestClass: requestClass,
                    cancelToken: lookupCancellation,
                    canStart: stillSearching,
                  ),
                  () =>
                      search(target, signature, grant, () => !stillSearching()),
                );
                return (hits: hits, failure: null);
              } on ApiCooldownException catch (error) {
                return (
                  hits: null,
                  failure: _lookupFailure(
                    LocalMediaLookupFailureKind.rateLimited,
                    retryAt: error.retryAt,
                  ),
                );
              }
            }),
        ]);
        if (stopped()) return skipped;
        if (!stillSearching()) return interrupted();
        final problems = {
          for (final (index, response) in responses.indexed)
            if (response.hits == null)
              (
                profile: similarDetails[index].profile,
                method: PostLookupMatchKind.similarImage,
                failure: response.failure,
              ),
        };
        final hits = [for (final response in responses) ...?response.hits];
        final ranked = rankIqdbHits(
          hits,
          _ref.read(lookupPreferencesProvider).threshold,
        );
        final accepted = problems.isEmpty ? ranked.automatic : null;
        if (accepted == null) {
          return LocalMediaEnrichmentOutcome(
            LocalMediaEnrichmentResult.unchanged,
            issue: problems.isNotEmpty
                ? LocalMediaEnrichmentIssue.incompleteLookup
                : ranked.visible.isEmpty
                ? LocalMediaEnrichmentIssue.noMatch
                : null,
            lookupDetails: problems.isEmpty && ranked.visible.isEmpty
                ? {...exactDetails, ...similarDetails}
                : problems,
            review: !automatic && ranked.visible.isNotEmpty
                ? LocalMediaEnrichmentReview(item, ranked.visible)
                : null,
          );
        }

        final result = await _applyIqdb(
          library,
          item,
          accepted,
          automatic: automatic,
          current: () =>
              stillSearching() &&
              rankIqdbHits(
                    hits,
                    _ref.read(lookupPreferencesProvider).threshold,
                  ).automatic ==
                  accepted,
        );
        return LocalMediaEnrichmentOutcome(
          result,
          issue: result == LocalMediaEnrichmentResult.skipped && !stopped()
              ? _reviewFailure(library, item)
              : null,
        );
      }

      final categories = <PostOrigin, Map<String, Set<String>>>{};
      for (final profile in results) {
        if (stopped()) return skipped;
        if (!current(profile.target)) continue;
        final blacklist = _ref.read(
          blacklistTagsProvider(profile.target.filter),
        );
        final blacklistTags = blacklist.isLoading
            ? null
            : blacklist.asData?.value;
        if (blacklistTags == null) continue;
        final visible = profile.posts
            .where(
              (post) => isExactLookupPostVisible(
                post,
                profile.target,
                blacklistTags,
              ),
            )
            .toList();
        if (visible.isEmpty ||
            profile.target.auth.booruType == BooruType.danbooru) {
          continue;
        }
        final resolved = await runWithApiRequestContext(
          ApiRequestContext(
            requestClass: requestClass,
            cancelToken: lookupCancellation,
            canStart: () => !stopped() && current(profile.target),
          ),
          () => _resolveCategories(profile.target, visible),
        );
        if (current(profile.target)) {
          categories[postOriginFromConfig(profile.target)] = resolved;
        }
      }

      final problems = <LocalMediaLookupDetail>{};
      var matched = false;
      final result = await library.applyEnrichment(item, () {
        if (stopped()) return null;
        final posts = <Post>[];
        for (final (index, profile) in results.indexed) {
          final blacklist = _ref.read(
            blacklistTagsProvider(profile.target.filter),
          );
          final tags = blacklist.isLoading ? null : blacklist.asData?.value;
          var failure = profile.failure;
          if (!exactCurrent(exact[index]) || tags == null) {
            failure = _lookupFailure(LocalMediaLookupFailureKind.interrupted);
          } else {
            for (final post in profile.posts) {
              if (isExactLookupPostVisible(post, profile.target, tags)) {
                posts.add(post);
              } else {
                failure ??= _lookupFailure(
                  LocalMediaLookupFailureKind.filtered,
                );
              }
            }
          }
          if (failure != null) {
            problems.add((
              profile: profile.target,
              method: PostLookupMatchKind.exactFile,
              failure: failure,
            ));
          }
        }
        matched = posts.isNotEmpty;
        return metadataFromMatches(
          posts,
          automatic: automatic,
          applyMetadata: !automatic || problems.isEmpty,
          profileCategories: categories,
        );
      });
      LocalMediaEnrichmentIssue? issue;
      if (problems.isNotEmpty) {
        final onlyFiltered = problems.every(
          (detail) =>
              detail.failure?.kind == LocalMediaLookupFailureKind.filtered,
        );
        issue = onlyFiltered
            ? LocalMediaEnrichmentIssue.filteredMatches
            : LocalMediaEnrichmentIssue.incompleteLookup;
      } else if (!stopped()) {
        if (result == LocalMediaEnrichmentResult.skipped) {
          issue = LocalMediaEnrichmentIssue.missingFile;
        } else if (!matched) {
          issue = LocalMediaEnrichmentIssue.noMatch;
        }
      }
      return LocalMediaEnrichmentOutcome(
        result,
        issue: issue,
        lookupDetails: issue == LocalMediaEnrichmentIssue.noMatch
            ? exactDetails.toSet()
            : problems,
      );
    } finally {
      profileSubscription.close();
      selectionSubscription.close();
      for (final subscription in subscriptions) {
        subscription.close();
      }
    }
  }

  Future<LocalMediaEnrichmentOutcome> applyReview(
    LocalMediaLibrary library,
    LocalMediaEnrichmentReview review,
    IqdbHit hit, {
    required bool Function() current,
  }) async {
    bool allowed() {
      if (_disposed || !current() || !_isCurrent(hit.profile)) return false;
      final preferences = _ref.read(lookupPreferencesProvider);
      return preferences.allowIqdb &&
          (preferences
                  .methodsFor(hit.profile)
                  ?.contains(PostLookupMatchKind.similarImage) ??
              true);
    }

    const unavailable = LocalMediaEnrichmentOutcome(
      LocalMediaEnrichmentResult.skipped,
      issue: LocalMediaEnrichmentIssue.matchUnavailable,
    );
    if (!review.candidates.contains(hit) ||
        hit.score < minimumVisibleIqdbScore ||
        !allowed()) {
      return unavailable;
    }
    final filter = blacklistTagsProvider(hit.profile.filter);
    final subscription = _ref.listen(filter, (_, _) {});
    try {
      await _ref.read(filter.future).timeout(const Duration(seconds: 15));
      if (!allowed()) return unavailable;
      final result = await _applyIqdb(
        library,
        review.item,
        hit,
        automatic: false,
        current: allowed,
      );
      return LocalMediaEnrichmentOutcome(
        result,
        issue: result == LocalMediaEnrichmentResult.skipped
            ? _reviewFailure(library, review.item)
            : null,
      );
    } catch (_) {
      return const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.operationFailed,
      );
    } finally {
      subscription.close();
    }
  }

  LocalMediaEnrichmentIssue _reviewFailure(
    LocalMediaLibrary library,
    LocalMediaItem original,
  ) {
    final item = library.find(original.reference);
    if (item?.id != original.id) return LocalMediaEnrichmentIssue.missingFile;
    if (item?.metadataRevision != original.metadataRevision) {
      return LocalMediaEnrichmentIssue.imageChanged;
    }
    return LocalMediaEnrichmentIssue.matchUnavailable;
  }

  Future<LocalMediaEnrichmentResult> _applyIqdb(
    LocalMediaLibrary library,
    LocalMediaItem item,
    IqdbHit hit, {
    required bool automatic,
    required bool Function() current,
  }) => library.applyEnrichment(
    item,
    () {
      if (!current() ||
          !isCurrentIqdbHit(_ref, hit) ||
          library.find(item.reference)?.metadataRevision !=
              item.metadataRevision) {
        return null;
      }
      final metadata = metadataFromMatches(
        [hit.post!],
        automatic: automatic,
        applyMetadata: true,
      );
      return (
        tags: metadata.tags,
        rating: metadata.rating,
        source: metadata.source,
        matches: const {},
      );
    },
    similarMatch: (
      origin: hit.post!.origin,
      postId: hit.postId,
      score: hit.score,
    ),
  );

  Future<Map<String, Set<String>>> _resolveCategories(
    BooruConfig profile,
    List<Post> posts,
  ) async {
    final cancellation = CancelToken();
    try {
      final extractor = _ref.read(tagExtractorProvider(profile.auth));
      final tags = await Future<List<Tag>>.sync(
        () =>
            extractor?.extractTagsBatch(
              posts,
              options: ExtractOptions(cancelToken: cancellation),
            ) ??
            const [],
      ).timeout(const Duration(seconds: 15));
      final categories = <String, Set<String>>{};
      for (final tag in tags) {
        if (tag.category == TagCategory.unknown()) continue;
        final category = tag.category.name;
        try {
          final normalized = normalizeLocalMediaTag((
            name: tag.rawName,
            category: category,
          ));
          (categories[normalized.name] ??= {}).add(normalized.category);
        } on FormatException {
          // Ignore the malformed name and keep other resolved categories.
        }
      }
      return categories;
    } catch (_) {
      // Exact matches still provide tag names if a profile cannot resolve them.
      return const {};
    } finally {
      cancellation.cancel();
    }
  }

  bool _isCurrent(BooruConfig target) =>
      !_disposed && _ref.read(booruConfigProvider).contains(target);

  Future<_ProfileMatches> _findMatches(
    BooruConfig target,
    String md5,
    LocalFileHashLookup lookup,
    bool Function() stopped, {
    required ApiRequestClass requestClass,
    required CancelToken? cancellation,
  }) async {
    final posts = <String, Post>{};
    _ProfileMatches finish(LocalMediaLookupFailure? failure) => (
      target: target,
      posts: posts.values.toList(),
      failure: failure,
    );

    var filtered = false;
    var page = 1;
    const matches = ListEquality<String>();
    List<String>? previousPage;
    // Real exact-hash lookups with larger result sets can be inspected manually.
    while (page <= 100 && !stopped()) {
      final result = await _requests.run(() {
        if (stopped()) return Future.value(const PostLookupCancelled());
        return runWithApiRequestContext(
          ApiRequestContext(
            requestClass: requestClass,
            cancelToken: cancellation,
            canStart: () => !stopped(),
          ),
          () => lookup(
            target,
            md5,
            page: page,
            cancellation: PostLookupCancellation(shouldCancel: stopped),
          ),
        );
      });
      if (result is! PostLookupPage) return finish(_exactLookupFailure(result));
      filtered |= result.hasFilteredMatches;
      final ids = <String>[];
      for (final post in result.posts) {
        final id = post.sitePostId;
        if (id == null) continue;
        ids.add(id);
        posts[id] = post;
      }
      if (!result.hasMore) {
        return finish(
          filtered
              ? _lookupFailure(LocalMediaLookupFailureKind.filtered)
              : null,
        );
      }
      // Hidden rows can make multiple pages empty. Detect repeated visible IDs.
      if (ids.isNotEmpty && matches.equals(previousPage, ids)) break;
      previousPage = ids;
      page++;
    }
    return finish(
      _lookupFailure(
        stopped()
            ? LocalMediaLookupFailureKind.interrupted
            : LocalMediaLookupFailureKind.invalidResponse,
      ),
    );
  }
}

LocalMediaLookupFailure _exactLookupFailure(PostLookupResult result) =>
    switch (result) {
      PostLookupFailed(error: RateLimitedError(:final retryAt)) =>
        _lookupFailure(
          LocalMediaLookupFailureKind.rateLimited,
          retryAt: retryAt,
        ),
      PostLookupFailed(error: ServerError(httpStatusCode: 429)) =>
        _lookupFailure(LocalMediaLookupFailureKind.rateLimited),
      PostLookupFailed(error: ServerError(httpStatusCode: final status?)) =>
        _lookupFailure(LocalMediaLookupFailureKind.http, httpStatus: status),
      PostLookupFailed(
        error: AppError(type: AppErrorType.loadDataFromServerFailed),
      ) ||
      PostLookupFailed(error: FormatException()) ||
      PostLookupInvalidResponse() => _lookupFailure(
        LocalMediaLookupFailureKind.invalidResponse,
      ),
      PostLookupFailed(error: AppError()) => _lookupFailure(
        LocalMediaLookupFailureKind.connection,
      ),
      PostLookupCancelled() || PostLookupUnavailable() => _lookupFailure(
        LocalMediaLookupFailureKind.interrupted,
      ),
      _ => _lookupFailure(LocalMediaLookupFailureKind.unknown),
    };

LocalMediaEnrichment metadataFromMatches(
  List<Post> posts, {
  required bool automatic,
  required bool applyMetadata,
  Map<PostOrigin, Map<String, Set<String>>> profileCategories = const {},
}) {
  final matches = {
    for (final post in posts)
      if (post.sitePostId case final id? when post.origin.profileIdHint != null)
        (origin: post.origin, postId: id),
  };
  if (!applyMetadata) {
    return (
      tags: const [],
      rating: Rating.unknown,
      source: null,
      matches: matches,
    );
  }

  final tagSets = [
    for (final post in posts)
      _postTags(post, profileCategories[post.origin] ?? const {}),
  ].where((tags) => tags.isNotEmpty).toList();
  final categoryVotes = <String, Set<String>>{};
  for (final tags in tagSets) {
    for (final entry in tags.entries) {
      (categoryVotes[entry.key] ??= {}).addAll(entry.value);
    }
  }
  final sameNames = tagSets.every(
    (tags) => tags.length == categoryVotes.length,
  );
  final categoriesAgree = categoryVotes.values.every(
    (votes) => votes.length <= 1,
  );
  final tags = [
    if (!automatic || (sameNames && categoriesAgree))
      for (final entry in categoryVotes.entries)
        (
          name: entry.key,
          category: switch (entry.value.length) {
            0 => 'unknown',
            1 => entry.value.single,
            _ => 'general',
          },
        ),
  ];

  final ratings = posts.map((post) => post.rating).toSet();
  final rating = const [
    Rating.explicit,
    Rating.questionable,
    Rating.sensitive,
    Rating.general,
  ].firstWhere(ratings.contains, orElse: () => Rating.unknown);
  final sources = {
    for (final post in posts)
      for (final source in _postSources(post))
        if (source.trim().isNotEmpty) source.trim(),
  };
  return (
    tags: tags,
    rating: rating,
    source: sources.length == 1 ? sources.single : null,
    matches: matches,
  );
}

Iterable<String> _postSources(Post post) sync* {
  if (post.source case NonWebSource(:final value)) yield value;
  yield* post.knownSourceUrls;
}

Map<String, Set<String>> _postTags(
  Post post,
  Map<String, Set<String>> profileCategories,
) {
  final inline = {
    for (final tag in post.generalTags) tag: 'general',
    for (final tag in post.metaTags) tag: 'meta',
    for (final tag in post.artistTags ?? const <String>{}) tag: 'artist',
    for (final tag in post.characterTags ?? const <String>{}) tag: 'character',
    for (final tag in post.copyrightTags ?? const <String>{}) tag: 'copyright',
  };
  final tags = <String, Set<String>>{};
  for (final name in {...post.tags, ...inline.keys}) {
    try {
      final tag = normalizeLocalMediaTag((
        name: name,
        category: inline[name] ?? 'unknown',
      ));
      final votes = tags[tag.name] ??= {};
      if (tag.category != 'unknown') votes.add(tag.category);
      votes.addAll(profileCategories[tag.name] ?? const {});
    } on FormatException {
      // A malformed tag does not invalidate otherwise verified metadata.
    }
  }
  return tags;
}

Future<Post?> resolveLocalMediaMatch(
  WidgetRef ref,
  BooruConfig target,
  LocalMediaExactMatch match,
  String? md5,
) async {
  bool current() =>
      ref.context.mounted &&
      ref.read(booruConfigProvider).contains(target) &&
      postOriginFromConfig(target) == match.origin;

  if (!current()) return null;
  final result = await ref
      .read(originAwarePostRepoProvider(target))
      .getPost(PostId.from(match.postId), options: PostFetchOptions.raw)
      .run();
  if (!current()) return null;
  final post = result.fold((_) => null, (post) => post);
  if (post == null ||
      post.sitePostId != match.postId ||
      post.origin != match.origin ||
      (md5 != null && post.md5.trim().toLowerCase() != md5)) {
    return null;
  }
  final blacklist = await ref.read(blacklistTagsProvider(target.filter).future);
  return current() && isExactLookupPostVisible(post, target, blacklist)
      ? post
      : null;
}
