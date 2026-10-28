// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../router.dart';
import '../../../../navigation/operation_source_picker.dart';
import '../../../selected_tags/types.dart';
import '../views/simple_tag_search_view.dart';
import 'params.dart';
import '../types/topic_search_origin.dart';
import '../../../following_topics/providers.dart';

Future<void> goToSearchPage(
  WidgetRef ref, {
  String? tag,
  //FIXME: migrate to SearchTagSet instead of String
  SearchTagSet? tags,
  int? page,
  int? position,
  QueryType? queryType,
  bool? fromSearchBar,
  String? order,
  BooruConfig? config,
  String? originatingTopicId,
}) async {
  final source = config ?? await chooseOperationSource(ref);
  if (!ref.context.mounted || source == null) return;
  final topic = originatingTopicId == null
      ? null
      : ref
            .read(followingTopicsProvider)
            .valueOrNull
            ?.topics
            .where((topic) => topic.id == originatingTopicId)
            .firstOrNull;
  await ref.pushRoute(
    Uri(
      path: '/search',
      queryParameters: switch (SearchParams(
        query: tag,
        tags: tags,
        page: page,
        scrollPosition: position,
        queryType: queryType,
        fromSearchBar: fromSearchBar,
        order: order,
      ).toQueryParams()) {
        final params when params.isNotEmpty => params,
        _ => null,
      },
    ).toString(),
    extra: SearchRouteContext(
      config: source,
      originatingTopicId: originatingTopicId,
      topicOrigin: topic == null
          ? null
          : TopicSearchOrigin(topic: topic, profile: source),
    ),
  );
}

/// Route-local ownership for searches opened from a saved Topic.
///
/// Keeping the owner here prevents a Topic from changing the global browsing
/// profile. The immutable snapshot keeps the original identity and editable
/// state associated with the timeline while its query and profile evolve.
final class SearchRouteContext {
  const SearchRouteContext({
    required this.config,
    this.originatingTopicId,
    this.topicOrigin,
  });

  final BooruConfig config;
  final String? originatingTopicId;
  final TopicSearchOrigin? topicOrigin;
}

void goToQuickSearchPage(
  BuildContext context, {
  required WidgetRef ref,
  required void Function(String tag, bool isRaw) onSelected,
  bool ensureValidTag = false,
  bool showInputSelector = true,
  BooruConfigAuth? initialConfig,
  Widget Function(String text)? floatingActionButton,
  void Function(BuildContext context, String text, bool isRaw)? onSubmitted,
  Widget Function(TextEditingController controller)? emptyBuilder,
}) {
  showSimpleTagSearchView(
    context,
    settings: const RouteSettings(
      name: RouterPageConstant.quickSearch,
    ),
    ensureValidTag: ensureValidTag,
    floatingActionButton: floatingActionButton,
    builder: (_, isMobile) => isMobile
        ? SimpleTagSearchView(
            initialConfig: initialConfig,
            showInputSelector: showInputSelector,
            onSubmitted: onSubmitted,
            ensureValidTag: ensureValidTag,
            floatingActionButton: floatingActionButton != null
                ? (text) => floatingActionButton.call(text)
                : null,
            onSelected: onSelected,
            emptyBuilder: emptyBuilder,
          )
        : SimpleTagSearchView(
            initialConfig: initialConfig,
            showInputSelector: showInputSelector,
            onSubmitted: onSubmitted,
            backButton: IconButton(
              splashRadius: 16,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Symbols.arrow_back),
            ),
            ensureValidTag: ensureValidTag,
            onSelected: onSelected,
            emptyBuilder: emptyBuilder,
          ),
  );
}
