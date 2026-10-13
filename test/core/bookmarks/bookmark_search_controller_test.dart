import 'package:boorusama/core/bookmarks/src/providers/bookmark_search_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController query;
  late BookmarkSearchController search;

  setUp(() {
    query = TextEditingController(text: 'blue_hair');
    search = BookmarkSearchController(query);
  });

  tearDown(() {
    search.dispose();
    query.dispose();
  });

  test('keeps draft text separate from committed tags', () {
    search.draft.text = 'one piece';
    expect(query.text, 'blue_hair');
    expect(search.selectedTags.rawTags, ['blue_hair']);
  });

  for (final draft in ['one piece', 'ONE_PIECE', 'one   piece']) {
    test('commits the whole suggestion for $draft without a stray word', () {
      search.draft.text = draft;
      search.selectSuggestion('one_piece');
      expect(query.text, 'blue_hair one_piece');
      expect(search.draft.text, isEmpty);
      expect(search.selectedTags.tags.last.tag, 'one piece');
    });
  }

  test('preserves exclusions and pasted tags when choosing a suggestion', () {
    search.draft.text = 'smile -one piece';
    search.selectSuggestion('one_piece');
    expect(query.text, 'blue_hair smile -one_piece');
  });

  test('submits readable tag names and canonical multi-tag queries', () {
    search.draft.text = 'one piece -glasses';
    search.submit(knownTags: {'one_piece', 'glasses'});
    expect(query.text, 'blue_hair one_piece -glasses');
    search.draft.text = 'red_eyes smile';
    search.submit();
    expect(query.text, 'blue_hair one_piece -glasses red_eyes smile');
  });

  test('keeps a readable prefix intact when selecting a later suggestion', () {
    search.draft.text = 'one piece -gla';
    search.selectSuggestion('glasses', knownTags: {'one_piece'});
    expect(query.text, 'blue_hair one_piece -glasses');
  });

  test('deduplicates canonical tags but preserves opposite operators', () {
    search.draft.text = 'BLUE HAIR';
    search.selectSuggestion('blue_hair');
    expect(query.text, 'blue_hair');
    search.draft.text = '-blue hair';
    search.selectSuggestion('blue_hair');
    expect(query.text, 'blue_hair -blue_hair');
  });

  test('edits a chip in place without changing the query until submission', () {
    query.text = 'blue_hair glasses';
    search.edit(search.selectedTags.tags.first);
    expect(search.draft.text, 'blue hair');
    expect(query.text, 'blue_hair glasses');
    search.draft.text = 'red hair';
    search.selectSuggestion('red_hair');
    expect(query.text, 'red_hair glasses');
  });

  test('cancels chip editing without losing the original tag', () {
    search.editLastTag();
    search.draft.text = 'red hair';
    search.cancelEdit();
    expect(query.text, 'blue_hair');
    expect(search.draft.text, isEmpty);
  });

  for (final tag in ['blue_hair', '-blue_hair']) {
    test(
      'preserves $tag when submitting an unchanged edit without an index',
      () {
        query.text = '$tag glasses';
        search.edit(search.selectedTags.tags.first);
        search.submit();
        expect(query.text, '$tag glasses');
        expect(search.selectedTags.tags.length, 2);
      },
    );
  }

  test('removing the edited tag also clears its draft', () {
    final tag = search.selectedTags.tags.first;
    search.edit(tag);
    search.remove(tag);
    expect(query.text, isEmpty);
    expect(search.draft.text, isEmpty);
    expect(search.editingTag, isNull);
  });

  test(
    'clear and external query changes keep both controllers synchronized',
    () {
      search.draft.text = 'unfinished';
      query.text = '-glasses one_piece';
      expect(search.selectedTags.rawTags, ['-glasses', 'one_piece']);
      expect(search.draft.text, isEmpty);
      search.clear();
      expect(query.text, isEmpty);
      expect(search.selectedTags.tags, isEmpty);
    },
  );

  test('cursor-only changes to the committed query do not discard a draft', () {
    search.draft.text = 'one piece';
    query.selection = const TextSelection.collapsed(offset: 2);
    expect(search.draft.text, 'one piece');
  });

  test('does not commit an unfinished IME composition', () {
    search.draft.value = const TextEditingValue(
      text: 'one piece',
      composing: TextRange(start: 0, end: 9),
      selection: TextSelection.collapsed(offset: 9),
    );
    expect(query.text, 'blue_hair');
    expect(search.selectedTags.tags.length, 1);
  });

  test(
    'does not create chips from whitespace or a bare exclusion operator',
    () {
      search.draft.text = '  -  ';
      search.submit();
      expect(query.text, 'blue_hair');
      expect(search.selectedTags.tags.length, 1);
    },
  );
}
