import 'package:boorusama/boorus/danbooru/artists/urls/src/types/artist_url_presentation.dart';
import 'package:test/test.dart';

void main() {
  final cases = [
    (
      'https://x.com/menheragirl_inc',
      ArtistUrlPlatform.x,
      'X',
      '@menheragirl_inc',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://twitter.com/example_name',
      ArtistUrlPlatform.x,
      'X',
      '@example_name',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://mobile.twitter.com/example_name/',
      ArtistUrlPlatform.x,
      'X',
      '@example_name',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://x.com/i/user/3147427',
      ArtistUrlPlatform.x,
      'X',
      '3147427',
      ArtistUrlAccountKind.userId,
    ),
    (
      'https://www.youtube.com/@ktnazm0702',
      ArtistUrlPlatform.youtube,
      'YouTube',
      '@ktnazm0702',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://m.youtube.com/channel/UC123_Abc?view_as=subscriber',
      ArtistUrlPlatform.youtube,
      'YouTube',
      'UC123_Abc',
      ArtistUrlAccountKind.channelId,
    ),
    (
      'https://youtube.com/c/SomeName/',
      ArtistUrlPlatform.youtube,
      'YouTube',
      'SomeName',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://youtube.com/user/SomeName',
      ArtistUrlPlatform.youtube,
      'YouTube',
      'SomeName',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.tiktok.com/@ktnazm0702',
      ArtistUrlPlatform.tiktok,
      'TikTok',
      '@ktnazm0702',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.threads.net/@hakam',
      ArtistUrlPlatform.threads,
      'Threads',
      '@hakam',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.threads.com/@hakam',
      ArtistUrlPlatform.threads,
      'Threads',
      '@hakam',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://nico.ms/user/121151926',
      ArtistUrlPlatform.niconico,
      'Niconico',
      'user/121151926',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.nicovideo.jp/user/121151926',
      ArtistUrlPlatform.niconico,
      'Niconico',
      'user/121151926',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://lit.link/ktnazm0702',
      ArtistUrlPlatform.litLink,
      'Lit.Link',
      'ktnazm0702',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.pixiv.net/users/12345',
      ArtistUrlPlatform.pixiv,
      'Pixiv',
      '12345',
      ArtistUrlAccountKind.userId,
    ),
    (
      'https://www.pixiv.net/en/users/12345/',
      ArtistUrlPlatform.pixiv,
      'Pixiv',
      '12345',
      ArtistUrlAccountKind.userId,
    ),
    (
      'https://m.pixiv.net/member.php?id=12345&from=link',
      ArtistUrlPlatform.pixiv,
      'Pixiv',
      '12345',
      ArtistUrlAccountKind.userId,
    ),
    (
      'https://unknown.example/artist/abc',
      ArtistUrlPlatform.web,
      'unknown.example',
      'artist/abc',
      ArtistUrlAccountKind.name,
    ),
    (
      'http://art.unknown.example:8080/artist/abc?ref=other#about',
      ArtistUrlPlatform.web,
      'art.unknown.example',
      'artist/abc?ref=other#about',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://unknown.example',
      ArtistUrlPlatform.web,
      'unknown.example',
      '',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://youtube.com/%40%E7%B5%B5%E5%B8%AB?si=abc',
      ArtistUrlPlatform.youtube,
      'YouTube',
      '@絵師',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://x.com/%65xample_name?lang=en',
      ArtistUrlPlatform.x,
      'X',
      '@example_name',
      ArtistUrlAccountKind.name,
    ),
    (
      'https://www.threads.com/@%E7%B5%B5%E5%B8%AB',
      ArtistUrlPlatform.threads,
      'Threads',
      '@絵師',
      ArtistUrlAccountKind.name,
    ),
  ];
  for (final (url, platform, label, account, kind) in cases) {
    test(
      'formats the identity encoded in $url without rewriting its target',
      () {
        expect(artistUrlPresentation(url), (
          platform: platform,
          platformLabel: label,
          account: account,
          accountKind: kind,
          url: url,
        ));
      },
    );
  }

  for (final url in [
    'https://notx.com/handle',
    'https://x.com.evil.example/handle',
    'https://notyoutube.com/@handle',
    'https://youtube.com.evil.example/channel/UC123',
    'https://threads.com.evil.example/@handle',
    'https://notpixiv.net/users/123',
    'https://x.com/home',
    'https://x.com/intent/follow?user_id=123',
    'https://x.com/name/status/123',
    'https://youtube.com/watch?v=123',
    'https://youtu.be/video123',
    'https://youtube.com/shorts/abc',
    'https://youtube.com/@name/videos',
    'https://tiktok.com/@name/video/123',
    'https://threads.com/@name/post/abc',
    'https://lit.link/about',
  ]) {
    test('keeps non-profile and lookalike URL $url as a generic target', () {
      final result = artistUrlPresentation(url);
      expect(result, isNotNull);
      expect(result!.platform, ArtistUrlPlatform.web);
      expect(result.accountKind, ArtistUrlAccountKind.name);
      expect(result.url, url);
    });
  }

  for (final url in [
    '',
    'javascript:alert(1)',
    'data:text/plain,hello',
    'file:///tmp/artist',
    'ftp://example.com/artist',
    'https://',
    'https:///artist',
    'not a URL',
    'https://bad host.example/artist',
    'https://example.com/a b',
    'https://user:secret@example.com/artist',
    'https://x.com/%ZZ',
    'https://x.com/%FF',
    'https://www.pixiv.net/member.php?id=%FF',
    'https://[invalid/artist',
  ]) {
    test('rejects malformed or unsupported URL $url', () {
      expect(artistUrlPresentation(url), isNull);
    });
  }

  test(
    'keeps distinct accounts and preserves normalized duplicate filtering',
    () {
      expect(
        validArtistProfileUrls([
          'https://x.com/one',
          'https://x.com/one/',
          ' https://x.com/two ',
          'https://x.com/i/user/123',
          'https://youtube.com/channel/UC123',
          'https://youtube.com/@name',
          'https://unknown.example/artist/abc',
          'javascript:alert(1)',
          'https://',
        ]),
        [
          'https://x.com/one',
          'https://x.com/two',
          'https://x.com/i/user/123',
          'https://youtube.com/channel/UC123',
          'https://youtube.com/@name',
          'https://unknown.example/artist/abc',
        ],
      );
    },
  );
}
