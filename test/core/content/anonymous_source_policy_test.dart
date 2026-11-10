import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AnonymousSourcePolicy();
  test('requested public sites reuse catalog eligibility with bounded transports', () {
    final eshuushuu = policy.resolve(
      BooruType.eshuushuu,
      Uri.parse('https://e-shuushuu.net'),
    )!;
    expect(
      eshuushuu.allowsApi(Uri.parse('https://e-shuushuu.net/api/v1/images/42')),
      isTrue,
    );
    expect(
      eshuushuu.allowsMedia(
        Uri.parse('https://e-shuushuu.net/images/2026-11-10-42.jpg'),
      ),
      isTrue,
    );
    expect(
      eshuushuu.allowsMedia(
        Uri.parse('https://cdn.e-shuushuu.net/fullsize/2026-11-10-42.jpg'),
      ),
      isTrue,
    );
    expect(
      eshuushuu.allowsApi(
        Uri.parse('https://cdn.e-shuushuu.net/api/v1/images/42'),
      ),
      isFalse,
    );
    final hypnohub = policy.resolve(
      BooruType.gelbooruV2,
      Uri.parse('https://hypnohub.net'),
    )!;
    expect(
      hypnohub.allowsApi(
        Uri.parse(
          'https://hypnohub.net/index.php?page=dapi&s=post&q=index&json=1&limit=1',
        ),
      ),
      isTrue,
    );
    expect(
      hypnohub.allowsApi(
        Uri.parse('https://hypnohub.net/index.php?page=post&s=view&id=42'),
      ),
      isTrue,
    );
    expect(
      hypnohub.allowsMedia(
        Uri.parse('https://hypnohub.net/images/ab/cd/42.png'),
      ),
      isTrue,
    );
    for (final (source, url) in [
      (eshuushuu, 'https://e-shuushuu.net/api/v1/auth/login'),
      (eshuushuu, 'https://e-shuushuu.net/api/v1/images/42?token=secret'),
      (eshuushuu, 'https://unlisted.e-shuushuu.net/images/42.jpg'),
      (hypnohub, 'https://hypnohub.net/index.php?page=account&s=login'),
      (hypnohub, 'https://hypnohub.net/index.php?page=post&s=delete&id=42'),
      (
        hypnohub,
        'https://hypnohub.net/index.php?page=post&s=view&id=42&action=delete',
      ),
    ]) {
      expect(source.allowsApi(Uri.parse(url)), isFalse, reason: url);
      expect(source.allowsMedia(Uri.parse(url)), isFalse, reason: url);
    }
    // A catalog flag cannot grant an unimplemented transport or arbitrary site.
    expect(
      policy.resolve(BooruType.gelbooruV2, Uri.parse('https://xbooru.com')),
      isNull,
    );
    expect(
      policy.resolve(BooruType.e621, Uri.parse('https://e621.net')),
      isNull,
    );
    expect(
      policy.resolve(BooruType.eshuushuu, Uri.parse('https://unlisted.test')),
      isNull,
    );
    expect(
      policy.resolve(BooruType.gelbooruV2, Uri.parse('https://rule34.xxx')),
      isNull,
    );
  });
  test(
    'Realbooru permits only its registered anonymous read/parser endpoints',
    () {
      final source = policy.resolve(
        BooruType.gelbooruV2,
        Uri.parse('https://realbooru.com'),
      )!;
      for (final path in [
        '/index.php?page=dapi&s=post&q=index&limit=1&pid=0&tags=rating:safe',
        '/index.php?page=post&s=list&tags=cat&pid=42',
        '/index.php?page=post&s=view&id=42',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://realbooru.com$path')),
          isTrue,
          reason: path,
        );
      }
      for (final path in [
        '/index.php?page=account&s=login',
        '/index.php?page=post&s=delete&id=42',
        '/index.php?page=dapi&s=post&q=index&login=fixture',
        '/index.php?page=dapi&s=post&q=index&limit=101',
        '/index.php?page=dapi&s=post&q=index&pid=-1',
        '/index.php?page=post&s=view&id=42&id=43',
        '/index.php?page=post&s=view&id=42&action=delete',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://realbooru.com$path')),
          isFalse,
          reason: path,
        );
      }
      for (final extension in ['jpeg', 'mp4', 'webm']) {
        expect(
          source.allowsMedia(
            Uri.parse('https://realbooru.com//images/ab/cd/saved.$extension'),
          ),
          isTrue,
        );
      }
      expect(
        source.allowsMedia(
          Uri.parse('https://realbooru.com/thumbnails/ab/cd/thumb.jpg?v=1'),
        ),
        isTrue,
      );
      for (final url in [
        'http://realbooru.com/images/x.jpg',
        'https://cdn.realbooru.com/images/x.jpg',
        'https://realbooru.com/admin/x.jpg',
        'https://realbooru.com/images/x.jpg?token=secret',
        'https://realbooru.com/images/x.jpg?v=1&v=2',
      ]) {
        expect(source.allowsMedia(Uri.parse(url)), isFalse, reason: url);
      }
      expect(
        policy.resolve(BooruType.danbooru, Uri.parse('https://realbooru.com')),
        isNull,
      );
      expect(
        policy.resolve(
          BooruType.gelbooruV2,
          Uri.parse('https://realbooru.com/install'),
        ),
        isNull,
      );
    },
  );
  test('Sakuga post endpoint mapping does not merge source identities', () {
    final root = policy.forNamespace(BooruType.moebooru, 'sakugabooru.com')!;
    final www = policy.forNamespace(BooruType.moebooru, 'www.sakugabooru.com')!;
    expect(root, isNot(www));
    expect(root.site.host, 'sakugabooru.com');
    expect(
      root.allowsApi(
        Uri.parse('https://www.sakugabooru.com/post.json?tags=cat'),
      ),
      isTrue,
    );
    expect(
      root.allowsApi(Uri.parse('https://elsewhere.sakugabooru.com/post.json')),
      isFalse,
    );
  });
  final sources = <(BooruType, String, List<String>)>[
    (BooruType.danbooru, 'danbooru.donmai.us', ['cdn.donmai.us']),
    (BooruType.danbooru, 'safebooru.donmai.us', ['cdn.donmai.us']),
    (BooruType.danbooru, 'aibooru.online', ['cdn.aibooru.download']),
    (BooruType.gelbooruV2, 'safebooru.org', ['wimg.safebooru.org']),
    (BooruType.moebooru, 'konachan.com', []),
    (BooruType.moebooru, 'konachan.net', []),
    (BooruType.moebooru, 'yande.re', ['files.yande.re', 'assets.yande.re']),
    (BooruType.moebooru, 'www.sakugabooru.com', []),
    (BooruType.moebooru, 'sakugabooru.com', ['www.sakugabooru.com']),
  ];

  test(
    'namespace lookup grants only registered endpoints and can be revoked',
    () {
      const disabled = AnonymousSourcePolicy(enabled: false);
      for (final (engine, host, _) in sources) {
        expect(policy.forNamespace(engine, host)?.site.host, host);
        expect(disabled.forNamespace(engine, host), isNull);
        expect(disabled.resolve(engine, Uri.parse('https://$host')), isNull);
        for (final unknown in ['$host/install', '$host:444', 'sub.$host']) {
          expect(policy.forNamespace(engine, unknown), isNull);
        }
      }
      final aibooru = policy.resolve(
        BooruType.danbooru,
        Uri.parse('https://aibooru.online'),
      )!;
      expect(
        aibooru.allowsMedia(Uri.parse('https://cdn.aibooru.online/data/a.jpg')),
        isFalse,
      );
      expect(
        aibooru.allowsMedia(
          Uri.parse('https://cdn.aibooru.download/original/a.jpg'),
        ),
        isTrue,
      );
    },
  );

  test('only exact built-in engine and HTTPS root resolve', () {
    for (final (engine, host, _) in sources) {
      for (final url in [
        'https://$host',
        'https://$host/',
        'https://$host:443/',
      ]) {
        final source = policy.resolve(engine, Uri.parse(url));
        expect(source, isNotNull, reason: url);
        expect(source!.engine, engine);
        expect(source.site, Uri.parse('https://$host'));
      }
      expect(
        policy.resolve(BooruType.unknown, Uri.parse('https://$host')),
        isNull,
      );
      final wrong = engine == BooruType.danbooru
          ? BooruType.moebooru
          : BooruType.danbooru;
      expect(policy.resolve(wrong, Uri.parse('https://$host')), isNull);
    }
    for (final url in [
      'https://custom.example.test/',
      'https://localhost/',
      'https://127.0.0.1/',
      'https://192.168.1.1/',
      'https://sub.danbooru.donmai.us/',
      'https://danbooru.donmai.us.example.test/',
      'https://danbooru.donmai.us/install/',
      'https://danbooru.donmai.us:444/',
      'http://danbooru.donmai.us/',
      'https://user:pass@danbooru.donmai.us/',
      'https://danbooru.donmai.us/#fragment',
      'https://danbooru.donmai.us/?x=1',
    ]) {
      expect(
        policy.resolve(BooruType.danbooru, Uri.parse(url)),
        isNull,
        reason: url,
      );
    }
  });

  test('Danbooru API allows read endpoints and rejects writes and secrets', () {
    final source = policy.resolve(
      BooruType.danbooru,
      Uri.parse('https://danbooru.donmai.us'),
    )!;
    for (final path in [
      '/posts.json?tags=cat&page=2',
      '/posts/7.json',
      '/pools/7.json',
      '/counts/posts.json?tags=cat',
      '/tags.json',
      '/notes.json',
      '/comments.json',
      '/artists.json',
    ]) {
      expect(
        source.allowsApi(Uri.parse('https://danbooru.donmai.us$path')),
        isTrue,
        reason: path,
      );
    }
    for (final path in [
      '/favorites.json',
      '/posts/7/vote.json',
      '/posts/7/edit.json',
      '/uploads.json',
      '/posts.json?api_key=secret',
      '/posts.json?API_KEY=secret',
      '/posts.json?Login=user',
      '/posts.json?PassWord=secret',
      '/posts.json?TOKEN=secret',
      '/posts.json?access_token=secret',
      '/posts.json?authorization=secret',
      '/posts.json?user_id=7',
      '/posts%2f7.json',
      '/posts.json#fragment',
      '/posts.json?tags=cat&auth=secret',
    ]) {
      expect(
        source.allowsApi(Uri.parse('https://danbooru.donmai.us$path')),
        isFalse,
        reason: path,
      );
    }
    for (final url in [
      'https://cdn.donmai.us/posts.json',
      'http://danbooru.donmai.us/posts.json',
      'https://user@danbooru.donmai.us/posts.json',
      'https://danbooru.donmai.us:444/posts.json',
    ]) {
      expect(source.allowsApi(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test('Gelbooru V2 only permits unambiguous read controls', () {
    final source = policy.resolve(
      BooruType.gelbooruV2,
      Uri.parse('https://safebooru.org'),
    )!;
    for (final category in ['post', 'tag', 'pool']) {
      for (final action in ['index', 'show']) {
        final uri = Uri.parse(
          'https://safebooru.org/index.php?page=dapi&s=$category&q=$action&id=7',
        );
        expect(source.allowsApi(uri), isTrue, reason: '$uri');
      }
    }
    for (final query in [
      'page=dapi&s=post&q=add',
      'page=dapi&s=favorite&q=index',
      'page=account&s=post&q=index',
      'page=dapi&page=dapi&s=post&q=index',
      'page=dapi&s=post&s=tag&q=index',
      'page=dapi&s=post&q=index&q=show',
      'page=dapi&s=post&q=index&API_KEY=secret',
      'page=dapi&s=post&q=index&Login=user',
    ]) {
      expect(
        source.allowsApi(Uri.parse('https://safebooru.org/index.php?$query')),
        isFalse,
        reason: query,
      );
    }
    expect(
      source.allowsApi(
        Uri.parse('https://safebooru.org/post.json?page=dapi&s=post&q=index'),
      ),
      isFalse,
    );
  });

  test('Moebooru permits read endpoints but not vote or account actions', () {
    for (final host in [
      'konachan.com',
      'konachan.net',
      'yande.re',
      'www.sakugabooru.com',
      'sakugabooru.com',
    ]) {
      final source = policy.resolve(
        BooruType.moebooru,
        Uri.parse('https://$host'),
      )!;
      for (final path in [
        '/post.json?tags=cat',
        '/post/show/7.json',
        '/pool/show/7.json',
        '/pool/index.json',
        '/tag.json',
        '/note.json',
        '/comment.json',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://$host$path')),
          isTrue,
          reason: '$host$path',
        );
      }
      for (final path in [
        '/post/vote.json',
        '/post/7/vote.json',
        '/post/update.json',
        '/user.json',
        '/post.json?APIKEY=secret',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://$host$path')),
          isFalse,
          reason: '$host$path',
        );
      }
    }
  });

  test('media trust is exact, source-specific, HTTPS and restricted to safe assets', () {
    for (final (engine, host, cdns) in sources) {
      final source = policy.resolve(engine, Uri.parse('https://$host'))!;
      for (final mediaHost in [host, ...cdns]) {
        for (final extension in [
          'jpg',
          'JPEG',
          'png',
          'gif',
          'webp',
          'avif',
          'bmp',
          'webm',
          'mp4',
        ]) {
          final url = 'https://$mediaHost/data/image.$extension';
          expect(
            source.allowsMedia(Uri.parse(url)),
            isTrue,
            reason: '$host: $url',
          );
        }
      }
      for (final url in [
        'https://unknown.example.test/image.jpg',
        'https://$host.example.test/image.jpg',
        'https://sub.$host/image.jpg',
        'https://127.0.0.1/image.jpg',
        'http://$host/image.jpg',
        'https://user:secret@$host/image.jpg',
        'https://$host:444/image.jpg',
        'https://$host/image.jpg#fragment',
        'https://$host/image.jpg?token=secret',
        'https://$host/image.jpg?x=1',
        'https://$host/image.html',
        'https://$host/path%2fimage.jpg',
        'https://$host/path%5cimage.jpg',
        'https://$host/path%252fimage.jpg',
      ]) {
        expect(
          source.allowsMedia(Uri.parse(url)),
          isFalse,
          reason: '$host: $url',
        );
      }
    }
    final danbooru = policy.resolve(
      BooruType.danbooru,
      Uri.parse('https://danbooru.donmai.us'),
    )!;
    expect(
      danbooru.allowsMedia(Uri.parse('https://files.yande.re/image.jpg')),
      isFalse,
    );
  });
}
