import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_profile_session.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

SearchPageController createController() {
  final extractor = DefaultMetatagExtractor(
    metatags: {
      const Metatag.simple(name: 'age'),
      const Metatag.simple(name: 'order'),
      const Metatag.simple(name: 'rating'),
    },
  );
  final tags = SelectedTagController(metatagExtractor: extractor);
  final controller = SearchPageController(
    tagsController: tags,
    metatagExtractor: extractor,
    textMatchers: [],
  );
  addTearDown(() {
    controller.dispose();
    tags.dispose();
  });
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a native multi-condition query retains whitespace during restoration',
    () {
      final controller = createController();
      controller.skipToResultWithTag('cat  rating:safe');
      expect(controller.tagsController.rawTagsString, 'cat  rating:safe');
      expect(controller.tagsController.tags.single.isRaw, isTrue);
      controller.commitSelection();
      expect(controller.tagString.value, 'cat  rating:safe');
    },
  );

  test(
    'raw editing replaces only the selected item and preserves its bytes',
    () {
      final controller = createController();
      controller.submit('one piece');
      controller.submit('landscape');
      final first = controller.tagsController.tags.first;
      controller.editTag(first);
      controller.toggleInputMode();
      controller.submit('(cat ~ dog) rating:g');
      expect(controller.tagsController.tags.first.isRaw, isTrue);
      expect(
        controller.tagsController.tags.first.toString(),
        '(cat ~ dog) rating:g',
      );
      expect(controller.tagsController.tags.last.toString(), 'landscape');
    },
  );

  test(
    'cancelling a chip edit restores the pending raw input without committing',
    () {
      final controller = createController();
      controller.submit('landscape');
      controller.updateQuery('(pending: expression)');
      controller.toggleInputMode();
      controller.editTag(controller.tagsController.tags.single);
      controller.updateQuery('changed');
      controller.closeEditor();
      expect(controller.tagsController.rawTags, ['landscape']);
      expect(controller.textController.text, '(pending: expression)');
      expect(controller.inputIsRaw.value, isTrue);
      expect(controller.state.value, SearchState.initial);
    },
  );

  test('a stale edit cannot resurrect a removed item', () {
    final controller = createController();
    controller.submit('cat');
    final tag = controller.tagsController.tags.single;
    controller.editTag(tag);
    controller.tagsController.removeTag(tag);
    controller.submit('dog');
    expect(controller.tagsController.tags, isEmpty);
  });

  test(
    'preserves an existing target while removing duplicate ordinary options',
    () {
      final controller = createController();
      controller.submit('order:score');
      controller.submit('order:id_desc');
      controller.tagsController.addTag(
        const TagSearchItem.raw(tag: 'order:custom'),
      );
      controller.applyOption('order', 'order:id_desc');
      expect(controller.tagsController.rawTags, [
        'order:id_desc',
        'order:custom',
      ]);
      expect(controller.tagsController.tags.last.isRaw, isTrue);
    },
  );

  test(
    'typing is not a completed search and IME composition is not submitted',
    () {
      final controller = createController();
      controller.updateQuery('one piece');
      expect(controller.tagsController.tags, isEmpty);
      expect(controller.didSearchOnce.value, isFalse);
      controller.textController.value = const TextEditingValue(
        text: 'one piece',
        composing: TextRange(start: 0, end: 9),
      );
      controller.submit('one piece');
      expect(controller.tagsController.tags, isEmpty);
    },
  );

  test('autocomplete preserves one exclusion prefix', () {
    final controller = createController();
    controller.updateQuery('-cat');
    controller.tapTag('cat');
    expect(controller.tagsController.rawTags, ['-cat']);
    controller.updateQuery('-dog');
    controller.tapTag('-dog');
    expect(controller.tagsController.rawTags, ['-cat', '-dog']);
  });

  test(
    'a profile snapshot preserves raw mode and the selected edit target',
    () {
      final first = createController();
      first.submit('landscape');
      first.updateQuery('pending');
      first.editTag(first.tagsController.tags.single);
      first.toggleInputMode();
      first.updateQuery('(cat ~ dog)');
      final next = createController();
      SearchProfileSnapshot.capture(first).restore(next);
      expect(next.inputIsRaw.value, isTrue);
      expect(next.editingTag.value?.originalTag, 'landscape');
      next.submit(next.textController.text);
      expect(next.tagsController.rawTags, ['(cat ~ dog)']);
      expect(next.textController.text, 'pending');
      expect(next.inputIsRaw.value, isFalse);
    },
  );
  test(
    'an empty confirmed chip edit removes it while an empty new input does not',
    () {
      final controller = createController();
      controller.submit('cat');
      controller.editTag(controller.tagsController.tags.single);
      controller.submit('');
      expect(controller.tagsController.tags, isEmpty);
      controller.submit('');
      expect(controller.tagsController.tags, isEmpty);
    },
  );

  test('does not submit an unfinished metatag prefix', () {
    final controller = createController();
    controller.submit('age:');
    expect(controller.tagsController.tags, isEmpty);
    controller.submit('age:7d');
    expect(controller.tagsController.rawTags, ['age:7d']);
  });

  test('a snapshot of a removed edit target does not resurrect the tag', () {
    final first = createController();
    first.submit('cat');
    first.editTag(first.tagsController.tags.single);
    first.tagsController.clear();
    final second = createController();
    SearchProfileSnapshot.capture(first).restore(second);
    second.submit('dog');
    expect(second.tagsController.tags, isEmpty);
  });

  test('a delayed draft notification does not reopen a cancelled editor', () {
    final controller = createController();
    controller.submit('cat');
    controller.updateQuery('pending');
    controller.editTag(controller.tagsController.tags.single);
    controller.closeEditor();
    controller.onQueryChanged(controller.textController.text);
    expect(controller.state.value, SearchState.initial);
    expect(controller.tagsController.rawTags, ['cat']);
  });

  test(
    'an unfinished known option is rejected even without an engine extractor',
    () {
      final tags = SelectedTagController(metatagExtractor: null);
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: [],
        metatagExtractor: null,
        optionKeys: {'rating'},
      );
      addTearDown(() {
        controller.dispose();
        tags.dispose();
      });
      controller.submit('rating:');
      expect(tags.tags, isEmpty);
      controller.submit('rating:s');
      expect(tags.rawTags, ['rating:s']);
    },
  );
}
