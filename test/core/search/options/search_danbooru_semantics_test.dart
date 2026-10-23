import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(
    BooruType.danbooru,
    'https://danbooru.donmai.us',
  );
  test('exclude supports comparison complements and complete ranges', () {
    final age = catalog.byKey('age')!;
    expect(age.compose('<7d', exclude: true), 'age:>=7d');
    expect(age.compose('1d..7d', exclude: true), '-age:1d..7d');
    expect(age.compose('7d', exclude: true), '-age:7d');
    final score = catalog.byKey('score')!.withFree(true);
    expect(score.compose('10..50', exclude: true), '-score:10..50');
    expect(score.compose('20', exclude: true), '-score:20');
  });
  test('result counts and parent IDs cannot use unsupported ranges', () {
    for (final key in ['limit', 'random']) {
      final option = catalog.byKey(key)!;
      expect(option.isComparable, isFalse);
      expect(option.compose('20'), '$key:20');
      expect(option.compose('>=20'), isNull);
      expect(option.compose('20..50'), isNull);
      expect(option.compose('20', exclude: true), isNull);
    }
    final parent = catalog.byKey('parent')!;
    expect(parent.compose('42'), 'parent:42');
    expect(parent.compose('42..100'), isNull);
    expect(parent.compose('>42'), isNull);
    expect(parent.compose('deleted', exclude: true), '-parent:deleted');
    expect(catalog.byKey('child')!.compose('pending'), 'child:pending');
    expect(catalog.byKey('child')!.compose('42'), isNull);
  });
  test('the public native field vocabulary has typed editors', () {
    const fields =
        'user approver commenter comm noter noteupdater artcomm commentaryupdater flagger appealer upvote downvote fav ordvote ordfav favgroup ordfavgroup reacted pool ordpool note comment commentary id rating source status filetype disapproved parent child search embedded md5 pixelhash width height mpixels ratio score upvotes downvotes favcount filesize date age order limit tagcount pixiv_id pixiv unaliased exif duration random is has ai';
    for (final key in fields.split(' ')) {
      expect(catalog.byKey(key), isNotNull, reason: key);
      expect(
        catalog.byKey(key)!.kind,
        isNot(SearchOptionKind.native),
        reason: key,
      );
    }
    expect(catalog.byKey('newpool'), isNull);
    expect(catalog.byKey('locked'), isNull);
    expect(
      catalog.options.map((option) => option.key).toSet().length,
      catalog.options.length,
    );
  });
  testWidgets(
    'a guided order replaces ordered scopes but not raw expressions',
    (tester) async {
      final tags = SelectedTagController(metatagExtractor: null);
      final controller = SearchPageController(
        tagsController: tags,
        textMatchers: null,
        metatagExtractor: null,
        optionKeys: catalog.options.map((option) => option.key).toSet(),
      );
      tags.addTags([
        TagSearchItem.fromString('ordpool:42'),
        TagSearchItem.fromString('order:score'),
        const TagSearchItem.raw(tag: '(ordfav:self rating:g)'),
        TagSearchItem.fromString('landscape'),
      ]);
      controller.applyOption('order', 'order:id_desc');
      expect(tags.rawTags, [
        'order:id_desc',
        '(ordfav:self rating:g)',
        'landscape',
      ]);
      controller.editTag(tags.tags.first);
      controller.applyOption('ordfav', 'ordfav:self');
      expect(tags.rawTags.first, 'ordfav:self');
      controller.dispose();
      tags.dispose();
    },
  );
}
