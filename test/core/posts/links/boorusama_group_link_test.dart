import 'dart:convert';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_reference.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:flutter_test/flutter_test.dart';

final _references = <ContentReference>[
  _reference(BooruType.danbooru, 'https://danbooru.donmai.us', 'pool:42'),
  _reference(
    BooruType.danbooru,
    'https://danbooru.donmai.us/install',
    'related:73',
  ),
  _reference(
    BooruType.szurubooru,
    'http://szuru.local:8092/install',
    'pool:56',
  ),
  _reference(
    BooruType.pixiv,
    'https://www.pixiv.net',
    'work:123456',
  ),
];

ContentReference _reference(BooruType engine, String site, String key) =>
    const ContentReferenceCodec().parse(
      engine: engine,
      site: Uri.parse(site),
      kind: ContentKind.group,
      sourceKey: key,
    );

String _uri({
  String engine = 'danbooru',
  String site = 'https://danbooru.donmai.us',
  String key = 'pool:42',
  String version = '1',
  String? suffix,
}) =>
    'boorusama://group/open?v=$version&engine=$engine&site=${Uri.encodeComponent(site)}&key=${Uri.encodeComponent(key)}${suffix ?? ''}';

void main() {
  test('Group link round trips validated engine-owned keys and full sites', () {
    for (final reference in _references) {
      final link = BoorusamaGroupLink.fromReference(reference);
      final parsed = BoorusamaGroupLink.parse(link.uri.toString());

      expect(parsed.reference, reference);
      expect(BoorusamaGroupLink.tryParse(link.uri.toString()), parsed);
      expect(link.uri, parsed.uri);
    }

    final custom = BoorusamaGroupLink.parse(
      _uri(site: 'http://dan.local:8081/install/base'),
    );
    expect(
      custom.reference.site,
      Uri.parse('http://dan.local:8081/install/base'),
    );
  });

  test('outer Group grammar rejects malformed and untrusted parameters', () {
    final invalid = [
      'boorusama://other/open?v=1&engine=danbooru&site=https%3A%2F%2Fdanbooru.donmai.us&key=pool%3A42',
      _uri(version: '2'),
      _uri(suffix: '&key=pool%3A43'),
      _uri(suffix: '&extra=value'),
      _uri(engine: 'unknown'),
      _uri(key: 'work:42'),
      _uri(engine: 'szurubooru', key: 'related:42'),
      _uri(engine: 'pixiv'),
      _uri(site: 'https://user%3Asecret@danbooru.donmai.us'),
      _uri(site: 'https://danbooru.donmai.us/%252e%252e/install'),
      _uri(site: 'https://danbooru.donmai.us#fragment'),
      _uri().replaceFirst('/open?', '/open/extra?'),
      _uri().replaceFirst('boorusama://group/', 'boorusama://user@group/'),
      _uri().replaceFirst('boorusama://group/', 'boorusama://group:81/'),
      '${_uri()}#fragment',
      '${_uri()} ',
      ' ${_uri()}',
      'x' * (BoorusamaPostLink.maxLength + 1),
      _uri().replaceFirst('pool%3A42', 'pool%ZZ42'),
    ];
    for (final value in invalid) {
      expect(
        () => BoorusamaGroupLink.parse(value),
        throwsFormatException,
        reason: value,
      );
      expect(BoorusamaGroupLink.tryParse(value), isNull, reason: value);
    }
    expect(BoorusamaGroupLink.tryParse('not a URI'), isNull);
  });

  test('Group links do not parse as Post links or carry local metadata', () {
    final uri = _uri(
      site: 'http://szuru.local:8092/install',
      engine: 'szurubooru',
      key: 'pool:56',
    );
    final link = BoorusamaGroupLink.parse(uri);
    expect(BoorusamaPostLink.tryParse(uri), isNull);
    expect(link.reference.kind, ContentKind.group);
    expect(link.reference.sourceKey, 'pool:56');
    expect(link.uri.queryParameters.keys.toSet(), {
      'v',
      'engine',
      'site',
      'key',
    });
    expect(link.uri.queryParameters.keys, isNot(contains('auth')));
    expect(link.uri.queryParameters.keys, isNot(contains('profile')));

    final postReference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us'),
      kind: ContentKind.post,
      sourceKey: 'id:42',
    );
    expect(
      () => BoorusamaGroupLink.fromReference(postReference),
      throwsFormatException,
    );
  });

  test('Group bslink document has only the established v1 envelope', () {
    const uri =
        'boorusama://group/open?v=1&engine=danbooru&site=https%3A%2F%2Fdanbooru.donmai.us&key=pool%3A42';
    final file = BoorusamaLinkFile.fromUri(uri);
    expect(file.uri.toString(), uri);
    expect(file.fileName, 'boorusama-group-pool-42.bslink');
    final encoded =
        jsonDecode(utf8.decode(file.encode())) as Map<String, dynamic>;
    expect(encoded.keys.toSet(), {'format', 'version', 'uri'});
    expect(encoded['format'], 'boorusama-link');
    expect(encoded['version'], 1);
    expect(BoorusamaLinkFile.decode(file.encode()).uri, file.uri);
    expect(file.encode().length, lessThan(BoorusamaLinkFile.maxBytes));

    for (final document in [
      {...encoded, 'payload': 'snapshot'},
      {...encoded, 'localId': 'not-portable'},
      {
        ...encoded,
        'membership': ['local-group'],
      },
      {...encoded, 'version': 2},
    ]) {
      expect(
        () => BoorusamaLinkFile.decode(utf8.encode(jsonEncode(document))),
        throwsFormatException,
      );
    }
  });

  test('existing Post and Pixiv page links remain accepted by link documents', () {
    const post =
        'boorusama://post/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&key=id%3A42';
    const pixivPage =
        'boorusama://post/open?v=1&engine=pixiv&site=https%3A%2F%2Fwww.pixiv.net&key=work-page%3A123456%3A0';
    expect(BoorusamaLinkFile.fromUri(post).uri, Uri.parse(post));
    expect(BoorusamaLinkFile.fromUri(pixivPage).uri, Uri.parse(pixivPage));
    expect(
      () => BoorusamaGroupLink.parse(post),
      throwsFormatException,
    );
  });
}
