// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

// Project imports:
import '../../../../tags/favorites/types.dart';
import '../../../../tags/metatag/types.dart';
import '../../../histories/types.dart';
import '../../../options/option_query_value.dart';
import '../../../queries/types.dart';
import '../../../selected_tags/providers.dart';
import '../../../selected_tags/types.dart';

class SearchPageController extends ChangeNotifier {
  SearchPageController({
    required this.tagsController,
    required this.textMatchers,
    required this.metatagExtractor,
    this.onSearch,
    this.optionKeys = const {},
    this.optionAliases = const {},
  }) {
    focus.addListener(_onFocusChanged);
  }

  final state = ValueNotifier(SearchState.initial);
  final allowSearch = ValueNotifier(false);
  final tagString = ValueNotifier('');
  final focus = FocusNode();
  final suggestionsListbox = KurumiListboxController();
  final inputIsRaw = ValueNotifier(false);
  final editingTag = ValueNotifier<TagSearchItem?>(null);
  final didSearchOnce = ValueNotifier(false);
  late final textController = RichTextController(matchers: textMatchers);
  final SelectedTagController tagsController;
  final List<TextMatcher>? textMatchers;
  final MetatagExtractor? metatagExtractor;
  final void Function()? onSearch;
  final Set<String> optionKeys;
  final Map<String, String> optionAliases;
  TextEditingValue? _draftBeforeEdit;
  var _draftWasRaw = false;

  SearchInputDraft get inputDraft => (
    text: textController.value,
    isRaw: inputIsRaw.value,
    editing: editingTag.value,
    previousText: _draftBeforeEdit,
    previousIsRaw: _draftWasRaw,
  );
  void restoreInputDraft(SearchInputDraft draft) {
    textController.value = draft.text;
    inputIsRaw.value = draft.isRaw;
    final old = draft.editing;
    editingTag.value = old;
    if (old != null) {
      for (final tag in tagsController.tags) {
        if (tag.originalTag == old.originalTag && tag.isRaw == old.isRaw) {
          editingTag.value = tag;
          break;
        }
      }
    }
    _draftBeforeEdit = draft.previousText;
    _draftWasRaw = draft.previousIsRaw;
  }

  void _onFocusChanged() {
    if (focus.hasFocus) openEditor();
  }

  void openEditor() => changeState(
    textController.text.isEmpty ? SearchState.initial : SearchState.suggestions,
  );
  void toggleOptions() {
    if (state.value == SearchState.options) {
      openEditor();
    } else {
      focus.unfocus();
      changeState(SearchState.options);
    }
  }

  void closeEditor() {
    cancelEdit();
    focus.unfocus();
    changeState(SearchState.initial);
  }

  /// Raw mode belongs to this input, never to the complete query.
  void toggleInputMode() {
    inputIsRaw.value = !inputIsRaw.value;
    focus.requestFocus();
  }

  void editTag(TagSearchItem tag) {
    if (!tagsController.tags.contains(tag)) return;
    if (editingTag.value == null) {
      _draftBeforeEdit = textController.value;
      _draftWasRaw = inputIsRaw.value;
    }
    editingTag.value = tag;
    inputIsRaw.value = tag.isRaw;
    textController.value = TextEditingValue(
      text: tag.originalTag,
      selection: TextSelection.collapsed(offset: tag.originalTag.length),
    );
    openEditor();
    focus.requestFocus();
  }

  void cancelEdit() {
    if (editingTag.value != null) _finishInput();
  }

  void _finishInput() {
    final draft = _draftBeforeEdit;
    editingTag.value = null;
    _draftBeforeEdit = null;
    inputIsRaw.value = draft != null && _draftWasRaw;
    textController.value = draft ?? TextEditingValue.empty;
    openEditor();
  }

  void _commitItem(TagSearchItem item) {
    final old = editingTag.value;
    if (old == null) {
      tagsController.addTag(item);
    } else if (tagsController.tags.contains(old)) {
      tagsController.updateTag(old, item);
    }
    // Never resurrect a concurrently removed edit target.
    _finishInput();
    closeEditor();
  }

  void submitRaw() {
    if (!textController.value.composing.isCollapsed ||
        textController.text.trim().isEmpty) {
      return;
    }
    _commitItem(TagSearchItem.raw(tag: textController.text));
  }

  void tapTag(String tag, {String? category}) {
    final prefix = getFilterOperator(tag) == FilterOperator.none
        ? filterOperator.toString()
        : '';
    _commitItem(
      TagSearchItem.fromString(
        '$prefix$tag',
        extractor: metatagExtractor,
        category: category,
      ),
    );
  }

  /// Replace one guided condition, or its declared ordering family. Opaque raw
  /// items are never rewritten unless the user explicitly selected that item.
  void applyOption(String key, String query) {
    final old = editingTag.value;
    if (old != null && !tagsController.tags.contains(old)) {
      _finishInput();
      closeEditor();
      return;
    }
    final item = TagSearchItem.fromString(query, extractor: metatagExtractor);
    final keys = optionReplacementKeys(key, optionKeys, aliases: optionAliases);
    final existing = tagsController.tags.where((tag) {
      if (tag.isRaw) return false;
      final text = tag.toString().replaceFirst(RegExp('^[-~]'), '');
      return keys.any((candidate) => optionQueryValue(text, candidate) != null);
    }).toList();
    final target = old ?? existing.firstOrNull;
    // Remove duplicates before updating so an already present new value cannot
    // accidentally be removed after it becomes the replacement target.
    for (final tag in existing) {
      if (tag != target) tagsController.removeTag(tag);
    }
    if (target == null) {
      tagsController.addTag(item);
    } else {
      tagsController.updateTag(target, item);
    }
    _finishInput();
    closeEditor();
  }

  void tapFavTag(FavoriteTag tag) {
    tagsController.addTagFromFavTag(tag);
    _finishInput();
    closeEditor();
  }

  void changeState(SearchState newState) => state.value = newState;
  void skipToResultWithTag(String tag, {QueryType? queryType}) {
    // Links may contain opaque grouping; do not turn its spaces into underscores.
    final raw =
        _isRaw(queryType) || (queryType == null && RegExp(r'\s').hasMatch(tag));
    tagString.value = tag;
    didSearchOnce.value = true;
    tagsController
      ..clear()
      ..addTag(
        raw
            ? TagSearchItem.raw(tag: tag)
            : TagSearchItem.fromString(tag, extractor: metatagExtractor),
      );
  }

  void skipToResultWithTags(SearchTagSet tags, {QueryType? queryType}) {
    tagString.value = tags.spaceDelimitedOriginalTags;
    didSearchOnce.value = true;
    tagsController
      ..clear()
      ..merge(tags, isRaw: _isRaw(queryType));
  }

  bool _isRaw(QueryType? queryType) => queryType == QueryType.simple;

  /// Applies confirmed selections without changing keyboard/editor state.
  void commitSelection() {
    tagString.value = tagsController.rawTagsString;
    didSearchOnce.value = true;
    onSearch?.call();
  }

  void search() {
    commitSelection();
    changeState(SearchState.initial);
  }

  void onQueryChanged(String query) {
    if (state.value == SearchState.initial && !focus.hasFocus) return;
    changeState(
      query.isNotEmpty
          ? SearchState.suggestions
          : state.value == SearchState.options
          ? SearchState.options
          : SearchState.initial,
    );
  }

  void submit(String value) {
    if (!textController.value.composing.isCollapsed) return;
    if (value.trim().isEmpty) {
      final old = editingTag.value;
      if (old != null) {
        tagsController.removeTag(old);
        _finishInput();
        closeEditor();
      }
      return;
    }
    final trimmed = value.trim();
    final unsigned = trimmed.replaceFirst(RegExp('^[-~]'), '');
    if (!inputIsRaw.value) {
      for (final key in optionKeys) {
        final optionValue = optionQueryValue(unsigned, key);
        if (optionValue != null &&
            (optionValue.isEmpty ||
                const {'>', '<', '>=', '<='}.contains(optionValue))) {
          return;
        }
      }
      if (trimmed.endsWith(':') &&
          metatagExtractor?.fromString(trimmed) != null) {
        return;
      }
    }
    _commitItem(
      inputIsRaw.value
          ? TagSearchItem.raw(tag: value)
          : TagSearchItem.fromString(trimmed, extractor: metatagExtractor),
    );
  }

  void tapHistoryTag(SearchHistory history) {
    tagsController.addTagFromSearchHistory(history);
    closeEditor();
  }

  void tapRawMetaTag(String tag) {
    inputIsRaw.value = false;
    updateQuery('$tag:');
    openEditor();
    focus.requestFocus();
  }

  void updateQuery(String query) => textController.value = TextEditingValue(
    text: query,
    selection: TextSelection.collapsed(offset: query.length),
  );
  FilterOperator get filterOperator => getFilterOperator(textController.text);

  @override
  void dispose() {
    focus.removeListener(_onFocusChanged);
    textController.dispose();
    focus.dispose();
    suggestionsListbox.dispose();
    tagString.dispose();
    state.dispose();
    allowSearch.dispose();
    didSearchOnce.dispose();
    inputIsRaw.dispose();
    editingTag.dispose();
    super.dispose();
  }
}

typedef SearchInputDraft = ({
  TextEditingValue text,
  bool isRaw,
  TagSearchItem? editing,
  TextEditingValue? previousText,
  bool previousIsRaw,
});

enum SearchState { initial, suggestions, options }

class InheritedSearchPageController extends InheritedWidget {
  const InheritedSearchPageController({
    required this.controller,
    required super.child,
    super.key,
  });
  final SearchPageController controller;
  static SearchPageController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<InheritedSearchPageController>()
      ?.controller;
  static SearchPageController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('No InheritedSearchPageController in this context.');
    }
    return controller;
  }

  @override
  bool updateShouldNotify(InheritedSearchPageController oldWidget) =>
      oldWidget.controller != controller;
}
