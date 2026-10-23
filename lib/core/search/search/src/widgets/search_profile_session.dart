import 'package:flutter/widgets.dart';

import '../../../../configs/config/types.dart';
import '../../../selected_tags/types.dart';
import 'search_controller.dart';

/// Search intent survives replacement of an engine-specific search subtree.
class SearchProfileSnapshot {
  SearchProfileSnapshot.capture(SearchPageController controller)
    : tags = List.of(controller.tagsController.tags),
      inputDraft = controller.inputDraft,
      didSearch = controller.didSearchOnce.value,
      state = controller.state.value;

  final List<TagSearchItem> tags;
  final SearchInputDraft inputDraft;
  TextEditingValue get text => inputDraft.text;
  final bool didSearch;
  final SearchState state;

  void restore(SearchPageController controller) {
    controller.tagsController.addTags([
      for (final tag in tags)
        // Autocomplete categories belong to the source profile. Resolve them
        // from the destination's local cache after transferring search intent.
        if (tag.isRaw)
          TagSearchItem.raw(tag: tag.originalTag)
        else
          TagSearchItem.fromString(
            tag.originalTag,
            extractor: controller.metatagExtractor,
          ),
    ]);
    controller.restoreInputDraft(inputDraft);
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
    this.local = false,
    super.key,
  });

  final bool local;
  final SearchProfileSnapshot? snapshot;
  final void Function(BooruConfig, SearchPageController) onSwitch;

  static SearchProfileSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SearchProfileSession>();

  @override
  bool updateShouldNotify(SearchProfileSession oldWidget) =>
      snapshot != oldWidget.snapshot;
}
