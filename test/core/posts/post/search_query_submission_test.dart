import 'package:boorusama/core/posts/post/src/data/post_repository_builder.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/selected_tag_controller.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('typed multiword tags and autocomplete send the same query; raw preserves spaces', () async {
    final requests = <List<String>>[];
    final repository = PostRepositoryBuilder<Post>(
      fetch: (tags, page, {limit, options}) async {
        requests.add(tags);
        return PostResult.empty();
      },
      fetchSingle: (id, {options}) async => throw UnimplementedError(),
      getSettings: () async => Settings.defaultSettings.listing,
      tagComposer: EmptyTagQueryComposer(),
    );
    final tags = SelectedTagController(metatagExtractor: null);
    final controller = SearchPageController(
      tagsController: tags,
      metatagExtractor: null,
      textMatchers: [],
    );
    addTearDown(() {
      controller.dispose();
      tags.dispose();
    });
    controller.submit('one piece');
    await repository.getPostsFromController(tags.tagSet, 1).run();
    tags.clear();
    controller.tapTag('one_piece');
    await repository.getPostsFromController(tags.tagSet, 1).run();
    tags.clear();
    controller.updateQuery('one piece  rating:g');
    controller.submitRaw();
    await repository.getPostsFromController(tags.tagSet, 1).run();
    expect(requests, [
      ['one_piece'],
      ['one_piece'],
      ['one piece  rating:g'],
    ]);
  });
}
