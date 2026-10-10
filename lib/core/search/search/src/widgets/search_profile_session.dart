import 'package:flutter/widgets.dart';

import '../../../../configs/config/types.dart';
import '../../../selected_tags/types.dart';
import 'search_controller.dart';

/// Search intent survives replacement of an engine-specific search subtree.
class SearchProfileSnapshot {
  SearchProfileSnapshot.capture(SearchPageController controller)
    : tags = List.of(controller.tagsController.tags),
      text = controller.textController.value,
      didSearch = controller.didSearchOnce.value,
      state = controller.state.value;

  final List<TagSearchItem> tags;
  final TextEditingValue text;
  final bool didSearch;
  final SearchState state;

  void restore(SearchPageController controller) {
    controller.tagsController.addTags([
      for (final tag in tags)
        tag.withQuery(tag.originalTag, extractor: controller.metatagExtractor),
    ]);
    controller.textController.value = text;
    controller.allowSearch.value = tags.isNotEmpty;
    controller.didSearchOnce.value = didSearch;
    controller.tagString.value = controller.tagsController.rawTagsString;
    controller.state.value = state;
  }
}

class SearchProfileSession extends InheritedWidget {
  const SearchProfileSession({
    required this.snapshot,
    required this.onSwitch,
    required super.child,
    super.key,
  });

  final SearchProfileSnapshot? snapshot;
  final void Function(BooruConfig, SearchPageController) onSwitch;

  static SearchProfileSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SearchProfileSession>();

  @override
  bool updateShouldNotify(SearchProfileSession oldWidget) =>
      snapshot != oldWidget.snapshot;
}
