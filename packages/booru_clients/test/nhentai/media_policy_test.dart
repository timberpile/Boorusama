import 'package:booru_clients/nhentai.dart';
import 'package:test/test.dart';

void main() {
  NhentaiMediaPolicy policy() => NhentaiMediaPolicy(
    imageServers: ['https://i1.nhentai.net', 'https://i2.nhentai.net'],
    thumbnailServers: ['https://t1.nhentai.net'],
  );
  test(
    'only validated configured CDN roots and exact source paths are used',
    () {
      final p = policy();
      expect(
        p.resolve(mediaId: '7001', path: 'galleries/7001/1.webp').toString(),
        'https://i1.nhentai.net/galleries/7001/1.webp',
      );
      expect(
        p
            .resolve(
              mediaId: '7001',
              path: 'galleries/7001/cover.webp.webp',
              thumbnail: true,
            )
            .path,
        '/galleries/7001/cover.webp.webp',
      );
      expect(
        p
            .resolve(
              mediaId: '7001',
              path: 'galleries/7001/2.webp',
              serverIndex: 1,
            )
            .host,
        'i2.nhentai.net',
      );
      expect(
        p.allows(
          Uri.parse('https://i3.nhentai.net/galleries/7001/1.webp'),
          mediaId: '7001',
        ),
        isFalse,
      );
      expect(
        p.allows(
          Uri.parse('https://t1.nhentai.net/galleries/7001/1.webp'),
          mediaId: '7001',
        ),
        isFalse,
      );
      expect(
        p.allows(
          Uri.parse('https://i1.nhentai.net/galleries/101/1.webp'),
          mediaId: '7001',
        ),
        isFalse,
      );
    },
  );
  for (final root in [
    'http://i1.nhentai.net',
    'https://evil.test',
    'https://i1.nhentai.net.evil.test',
    'https://i1.nhentai.net/installation',
    'https://user@i1.nhentai.net',
    'https://i1.nhentai.net?secret=1',
    'https://i1.nhentai.net:444',
    'https://t1.nhentai.net',
  ]) {
    test(
      'rejects untrusted image server $root',
      () => expect(
        () => NhentaiMediaPolicy(
          imageServers: [root],
          thumbnailServers: ['https://t1.nhentai.net'],
        ),
        throwsFormatException,
      ),
    );
  }
  for (final path in [
    'galleries/7001/../7001/1.webp',
    'galleries/7001/%31.webp',
    'galleries/7001/a/../1.webp',
    'galleries/7001/1.webp?x=1',
    'galleries/7001/1.webp#fragment',
    'https://i3.nhentai.net/galleries/7001/1.webp',
    'http://i1.nhentai.net/galleries/7001/1.webp',
    '//i1.nhentai.net/galleries/7001/1.webp',
    r'galleries/7001\1.webp',
    'galleries/101/1.webp',
  ]) {
    test(
      'rejects unsafe or foreign source path $path',
      () => expect(
        () => policy().resolve(mediaId: '7001', path: path),
        throwsFormatException,
      ),
    );
  }
}
