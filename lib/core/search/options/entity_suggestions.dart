import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../boorus/e621/client_provider.dart';
import '../../../boorus/szurubooru/client_provider.dart';
import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../../http/client/providers.dart';
import '../../tags/autocompletes/providers.dart';
import '../../tags/autocompletes/types.dart';
import 'entity_endpoint.dart';

String? searchEntityPrefix(BooruType type, String key) {
  if (type == BooruType.danbooru) {
    if (const {
      'user',
      'approver',
      'commenter',
      'comm',
      'noter',
      'noteupdater',
      'commentaryupdater',
      'artcomm',
      'flagger',
      'appealer',
      'fav',
      'ordfav',
      'upvote',
      'downvote',
      'ordvote',
      'disapproved',
    }.contains(key)) {
      return 'user';
    }
    if (const {'pool', 'ordpool', 'newpool'}.contains(key)) return 'pool';
  }
  if (type == BooruType.e621 &&
      const {
        'user',
        'approver',
        'deletedby',
        'commenter',
        'comm',
        'noter',
        'noteupdater',
        'fav',
        'favoritedby',
        'flagger',
        'flaggedby',
        'upvote',
        'votedup',
        'upvoted',
        'voteup',
        'downvote',
        'voteddown',
        'downvoted',
        'votedown',
        'voted',
        'vote',
      }.contains(key)) {
    return 'user';
  }
  if (type == BooruType.moebooru && key == 'user') return 'user';
  if (type == BooruType.szurubooru) {
    if (const {
      'uploader',
      'upload',
      'submit',
      'comment',
      'fav',
    }.contains(key)) {
      return 'user';
    }
    if (key == 'pool') return 'pool';
  }
  return null;
}

String? searchEntityValue(AutocompleteData item, String prefix) {
  if (item.type != prefix) return null;
  final value = item.value.startsWith('$prefix:')
      ? item.value.substring(prefix.length + 1)
      : item.value;
  if (value.isEmpty || RegExp(r'[\s\x00-\x1f]').hasMatch(value)) return null;
  return value;
}

typedef SearchEntityRequest = ({
  BooruConfigAuth config,
  String key,
  String text,
});

final searchEntitySuggestionsProvider = FutureProvider.autoDispose
    .family<List<AutocompleteData>, SearchEntityRequest>((ref, request) async {
      final prefix = searchEntityPrefix(request.config.booruType, request.key);
      final text = request.text.trim().replaceAll(' ', '_');
      if (prefix == null ||
          text.isEmpty ||
          const {'any', 'none'}.contains(text)) {
        return const [];
      }
      final type = request.config.booruType;
      final endpoint = searchEntityEndpoint(type, prefix, text);
      if (type != BooruType.danbooru && endpoint == null) return const [];

      final repository = type == BooruType.danbooru
          ? ref.watch(autocompleteRepoProvider(request.config))
          : null;
      Dio? dio;
      if (type == BooruType.e621) {
        // Initialize the existing client so the shared transport has its auth
        // headers. Do not construct a second, uncoordinated HTTP client.
        ref.watch(e621ClientProvider(request.config));
        dio = ref.watch(defaultDioProvider(request.config));
      } else if (type == BooruType.szurubooru) {
        dio = ref.watch(szurubooruClientProvider(request.config)).dio;
      } else if (type == BooruType.moebooru) {
        dio = ref.watch(defaultDioProvider(request.config));
      }

      final ready = Completer<bool>();
      final cancel = CancelToken();
      final timer = Timer(
        const Duration(milliseconds: 250),
        () => ready.complete(true),
      );
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        timer.cancel();
        cancel.cancel();
        if (!ready.isCompleted) ready.complete(false);
      });
      if (!await ready.future || disposed) return const [];
      final List<AutocompleteData> values;
      if (repository != null) {
        values = await repository.getAutocomplete(
          AutocompleteQuery(text: '$prefix:$text'),
        );
      } else if (dio != null && endpoint != null) {
        final response = await dio.get<Object?>(
          endpoint.path,
          queryParameters: endpoint.parameters,
          cancelToken: cancel,
        );
        values = parseSearchEntityResponse(
          response.data,
          prefix,
          poolIds: endpoint.poolIds,
        );
      } else {
        return const [];
      }
      if (disposed) return const [];
      final seen = <String>{};
      return [
        for (final item in values)
          if (searchEntityValue(item, prefix) case final value?)
            if (seen.add(value)) item,
      ].take(8).toList();
    });

/// The sheet has its own profile/query-scoped suggestions. Selecting a row
/// updates only its draft; it never executes a post search before Apply.
class SearchEntitySuggestions extends ConsumerWidget {
  const SearchEntitySuggestions({
    required this.config,
    required this.optionKey,
    required this.text,
    required this.onSelected,
    super.key,
  });
  final BooruConfigAuth config;
  final String optionKey;
  final String text;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefix = searchEntityPrefix(config.booruType, optionKey);
    if (prefix == null || text.trim().isEmpty) return const SizedBox.shrink();
    final suggestions = ref.watch(
      searchEntitySuggestionsProvider((
        config: config,
        key: optionKey,
        text: text,
      )),
    );
    return suggestions.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      // Missing permissions or endpoint availability must not prevent typing.
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              minTileHeight: 40,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                item.label.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelected(searchEntityValue(item, prefix)!),
            ),
        ],
      ),
    );
  }
}
