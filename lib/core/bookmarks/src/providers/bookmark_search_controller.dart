// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../../../search/selected_tags/providers.dart';
import '../../../search/selected_tags/types.dart';
import '../types/bookmark_search_token.dart';

/// Adapts browse-search selection to the bookmark listing's committed query.
/// Editing a draft never changes the active filter until it is submitted.
class BookmarkSearchController extends ChangeNotifier {
  BookmarkSearchController(this._query) {
    _readQuery();
    _query.addListener(_onQueryChanged);
    draft.addListener(_onDraftChanged);
    selectedTags.addListener(_onSelectedTagsChanged);
  }

  final TextEditingController _query;
  final draft = TextEditingController();
  final selectedTags = SelectedTagController(metatagExtractor: null);
  TagSearchItem? _editingTag;
  var _lastQueryText = '';
  var _updating = false;

  TagSearchItem? get editingTag => _editingTag;

  void submit({Set<String> knownTags = const {}}) {
    _commit(
      parseBookmarkSearchInput(
        draft.text,
        knownTags: {
          ...knownTags,
          // A source change or pending index must not split the readable
          // version of a tag that is already selected.
          if (_editingTag case final tag?) tag.rawTag,
        },
      ),
    );
  }

  void selectSuggestion(String tag, {Set<String> knownTags = const {}}) {
    _commit(
      parseBookmarkSearchInput(
        insertBookmarkTagSuggestion(draft.text, tag),
        knownTags: knownTags,
      ),
    );
  }

  void edit(TagSearchItem tag) {
    if (!selectedTags.tags.contains(tag)) return;
    _editingTag = tag;
    final text = tag.toString().replaceAll('_', ' ');
    draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  bool editLastTag() {
    if (_editingTag != null ||
        draft.text.isNotEmpty ||
        selectedTags.tags.isEmpty) {
      return false;
    }
    edit(selectedTags.tags.last);
    return true;
  }

  void cancelEdit() {
    _updating = true;
    _editingTag = null;
    draft.clear();
    _updating = false;
    notifyListeners();
  }

  void remove(TagSearchItem tag) {
    _setTags(
      selectedTags.tags.where((item) => item != tag).toList(),
      resetDraft: tag == _editingTag,
    );
  }

  void clear() => _setTags(const [], resetDraft: true);

  void _commit(List<String> rawTags) {
    final tags = [...selectedTags.tags];
    final additions = [
      for (final tag in rawTags) TagSearchItem.fromString(tag),
    ];
    final editingIndex = _editingTag == null ? -1 : tags.indexOf(_editingTag!);
    if (editingIndex >= 0) {
      tags.replaceRange(editingIndex, editingIndex + 1, additions);
    } else {
      tags.addAll(additions);
    }
    _setTags(tags, resetDraft: true);
  }

  List<TagSearchItem> _unique(Iterable<TagSearchItem> tags) {
    final seen = <String>{};
    return [
      for (final tag in tags)
        if (seen.add(tag.toString())) tag,
    ];
  }

  void _setTags(List<TagSearchItem> tags, {required bool resetDraft}) {
    _updating = true;
    selectedTags
      ..clear()
      ..addTags(_unique(tags));
    if (resetDraft) {
      _editingTag = null;
      draft.clear();
    }
    _writeQuery();
    _updating = false;
    notifyListeners();
  }

  void _writeQuery() {
    _lastQueryText = selectedTags.rawTagsString;
    if (_query.text == _lastQueryText) return;
    _query.value = TextEditingValue(
      text: _lastQueryText,
      selection: TextSelection.collapsed(offset: _lastQueryText.length),
    );
  }

  void _readQuery() {
    _updating = true;
    _lastQueryText = _query.text;
    _editingTag = null;
    draft.clear();
    selectedTags
      ..clear()
      ..addTags(
        _unique(
          parseBookmarkSearchInput(_query.text).map(
            (tag) => TagSearchItem.fromString(tag),
          ),
        ),
      );
    _updating = false;
  }

  void _onQueryChanged() {
    if (_updating || _query.text == _lastQueryText) return;
    _readQuery();
    notifyListeners();
  }

  void _onSelectedTagsChanged() {
    if (_updating) return;
    _writeQuery();
    notifyListeners();
  }

  void _onDraftChanged() {
    if (!_updating) notifyListeners();
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    draft.removeListener(_onDraftChanged);
    selectedTags.removeListener(_onSelectedTagsChanged);
    draft.dispose();
    selectedTags.dispose();
    super.dispose();
  }
}
