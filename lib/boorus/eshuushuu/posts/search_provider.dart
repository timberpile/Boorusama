// Package imports:
import 'package:booru_clients/eshuushuu.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/options/search_id_parameters.dart';
import '../client_provider.dart';
import 'parser.dart';

class EshuushuuSearchState extends Equatable {
  const EshuushuuSearchState({this.tagIdCache = const {}});
  final Map<String, List<int>> tagIdCache;
  @override
  List<Object?> get props => [tagIdCache];
  List<int>? getCachedIds(String key) => tagIdCache[key];
  EshuushuuSearchState setCachedIds(String key, List<int> ids) =>
      EshuushuuSearchState(tagIdCache: {...tagIdCache, key: ids});
}

class EshuushuuSearchNotifier
    extends FamilyNotifier<EshuushuuSearchState, BooruConfigAuth> {
  @override
  EshuushuuSearchState build(BooruConfigAuth arg) =>
      const EshuushuuSearchState();
  EShuushuuClient get _client => ref.read(eshuushuuClientProvider(arg));

  Future<List<Post>> searchByTags(
    List<String> tags, {
    required int page,
    int? limit,
  }) async {
    final request = splitSearchIdParameters(tags, const {
      'user_id',
      'favorited_by_user_id',
    });
    final tagIds = request.terms.isEmpty
        ? <int>[]
        : await _resolveTagIds(request.terms);
    // Never broaden an unresolved tag search into an unfiltered user feed.
    if (request.terms.isNotEmpty && tagIds.isEmpty) return [];
    final dtos = await _client.getPosts(
      tagIds: tagIds,
      userId: request.ids['user_id'],
      favoritedByUserId: request.ids['favorited_by_user_id'],
      page: page,
      perPage: limit,
    );
    return _mapToPosts(dtos, page: page, tags: tags, limit: limit);
  }

  Future<List<int>> _resolveTagIds(List<String> tags) async {
    final cacheKey = tags.join('+');
    final cached = state.getCachedIds(cacheKey);
    if (cached != null) return cached;
    final ids = await _client.resolveTagIds(tags);
    state = state.setCachedIds(cacheKey, ids);
    return ids;
  }

  List<Post> _mapToPosts(
    List<PostDto> dtos, {
    int? page,
    List<String>? tags,
    int? limit,
  }) => dtos
      .map(
        (e) => postDtoToPost(
          e,
          PostMetadata(page: page, search: tags?.join(' '), limit: limit),
        ),
      )
      .toList();
}

final eshuushuuPostSearchProvider =
    NotifierProviderFamily<
      EshuushuuSearchNotifier,
      EshuushuuSearchState,
      BooruConfigAuth
    >(EshuushuuSearchNotifier.new);
