// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/network/types.dart';

void main() {
  test('Pixiv aliases retain the image referer only for validated media', () {
    for (final source in [
      'https://pixiv.net',
      'https://www.pixiv.net',
      'https://app-api.pixiv.net',
    ]) {
      for (final host in ['i.pximg.net', 's.pximg.net']) {
        final request = MediaRequest.resolve(
          'https://$host/img.jpg',
          overrides: const [],
          sourceUrl: source,
          headers: const {
            'Referer': 'https://www.pixiv.net/',
            'Authorization': 'secret',
            'Cookie': 'secret',
          },
        );
        expect(request.headers, {'Referer': 'https://www.pixiv.net/'});
      }
      final foreign = MediaRequest.resolve(
        'https://foreign.test/img.jpg',
        overrides: const [],
        sourceUrl: source,
        headers: const {
          'Referer': 'https://www.pixiv.net/',
          'Authorization': 'secret',
        },
      );
      expect(foreign.headers, isEmpty);
    }
  });

  test(
    'an explicit Pixiv media override keeps only the non-secret referer',
    () {
      final request = MediaRequest.resolve(
        'https://i.pximg.net/img.jpg',
        overrides: [MediaHostOverride(from: 'i.pximg.net', to: 'media.test')],
        sourceUrl: 'https://pixiv.net',
        headers: const {
          'Referer': 'https://www.pixiv.net/',
          'Authorization': 'secret',
        },
      );
      expect(request.url, 'https://media.test/img.jpg');
      expect(request.headers, {'Referer': 'https://www.pixiv.net/'});
    },
  );

  final overrides = [
    MediaHostOverride(from: 'img.example.com', to: 'cdn.example.net'),
  ];
  const sourceHeaders = {
    'User-Agent': 'ua',
    'Cookie': 'session=secret',
    'Authorization': 'Bearer secret',
    'Referer': 'https://example.com/',
    'Range': 'bytes=0-',
  };

  group('media host overrides', () {
    final cases = [
      (
        name: 'rewrites a matching host and keeps path, query and port',
        url: 'https://IMG.example.com:8443/a/b.jpg?x=1',
        expectedUrl: 'https://cdn.example.net:8443/a/b.jpg?x=1',
        overridden: true,
      ),
      (
        name: 'drops credentials embedded in the source URL',
        url: 'https://user:pass@img.example.com/a.jpg',
        expectedUrl: 'https://cdn.example.net/a.jpg',
        overridden: true,
      ),
      (
        name: 'leaves a subdomain of the source host untouched',
        url: 'https://a.img.example.com/a.jpg',
        expectedUrl: 'https://a.img.example.com/a.jpg',
        overridden: false,
      ),
      (
        name: 'leaves non-http URLs untouched',
        url: 'file:///img.example.com/a.jpg',
        expectedUrl: 'file:///img.example.com/a.jpg',
        overridden: false,
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final request = MediaRequest.resolve(
          c.url,
          overrides: overrides,
          headers: sourceHeaders,
        );

        expect(request.url, c.expectedUrl);
        expect(request.overridden, c.overridden);
      });
    }

    test('never forwards source credentials to the replacement host', () {
      final request = MediaRequest.resolve(
        'https://img.example.com/a.jpg',
        overrides: overrides,
        headers: sourceHeaders,
      );

      expect(request.headers, {'User-Agent': 'ua', 'Range': 'bytes=0-'});
    });

    test('keeps every source header when no override applies', () {
      final request = MediaRequest.resolve(
        'https://other.example.com/a.jpg',
        overrides: overrides,
        headers: sourceHeaders,
      );

      expect(request.headers, sourceHeaders);
    });
  });

  test('source credentials stay inside the configured installation', () {
    const source = 'https://private.example/install/';
    for (final target in [
      'https://foreign.example/file.jpg',
      'https://private.example/other/file.jpg',
      'https://private.example/install%2f..%2fother/file.jpg',
      'http://private.example/install/file.jpg',
    ]) {
      final request = MediaRequest.resolve(
        target,
        overrides: const [],
        sourceUrl: source,
        headers: sourceHeaders,
      );
      expect(request.headers, {'User-Agent': 'ua', 'Range': 'bytes=0-'});
      expect(request.overridden, isTrue);
    }
    final own = MediaRequest.resolve(
      '$source'
      'file.jpg?signature=a%2Fb',
      overrides: const [],
      sourceUrl: source,
      headers: sourceHeaders,
    );
    expect(own.headers, sourceHeaders);
    expect(own.overridden, isFalse);
  });

  group('stored network settings', () {
    final cases = [
      (
        name: 'reads overrides and the enabled flag',
        data:
            '{"mediaHostOverrides":[{"from":"img.example.com","to":"cdn.example.net"}],'
            '"mediaHostOverridesEnabled":false}',
        overrides: [
          MediaHostOverride(from: 'img.example.com', to: 'cdn.example.net'),
        ],
        active: <MediaHostOverride>[],
      ),
      (
        name: 'defaults to no overrides for settings saved before 4.6',
        data: '{"http":null}',
        overrides: <MediaHostOverride>[],
        active: <MediaHostOverride>[],
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final settings = NetworkSettings.tryParse(c.data);

        expect(settings?.mediaHostOverrides, c.overrides);
        expect(settings?.activeMediaHostOverrides, c.active);
      });
    }

    test('round-trips through JSON', () {
      final settings = NetworkSettings(
        mediaHostOverrides: [
          MediaHostOverride(from: 'img.example.com', to: 'cdn.example.net'),
        ],
        mediaHostOverridesEnabled: false,
      );

      expect(NetworkSettings.tryParse(settings.toJsonString()), settings);
    });
  });
}
