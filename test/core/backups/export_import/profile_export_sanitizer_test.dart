// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/sources/profile_export_sanitizer.dart';
import 'package:boorusama/core/configs/config/types.dart';

void main() {
  test('credential-free profiles remove login and proxy secrets', () {
    final json = BooruConfig.empty.toJson()
      ..addAll({
        'id': 1,
        'booruId': 23,
        'booruIdHint': 23,
        'name': 'Profile',
        'url': 'https://example.com',
        'apiKey': 'api-secret',
        'login': 'alice',
        'passHash': 'hash-secret',
        'proxySettings': {
          'type': 'http',
          'host': 'proxy.example',
          'port': 8080,
          'username': 'proxy-user',
          'password': 'proxy-secret',
          'enable': true,
        },
      });

    final sanitized = const ProfileExportSanitizer().sanitizeJson(
      json,
      includeCredentials: false,
    );

    expect(sanitized, isNot(contains('apiKey')));
    expect(sanitized, isNot(contains('login')));
    expect(sanitized, isNot(contains('passHash')));
    expect(sanitized['credentialsIncluded'], isFalse);
    expect(sanitized['proxySettings'], {
      'type': 'http',
      'host': 'proxy.example',
      'port': 8080,
      'enable': true,
    });
  });

  test('credential-free profiles remove URL credentials and query secrets', () {
    final sanitized = const ProfileExportSanitizer().sanitizeJson(
      {
        ...BooruConfig.empty.toJson(),
        'url': 'https://alice:secret@EXAMPLE.com/posts/?token=private#part',
      },
      includeCredentials: false,
    );

    expect(sanitized['url'], 'https://example.com/posts');
  });

  test('credential-enabled profiles retain every credential', () {
    final json = <String, dynamic>{
      'apiKey': 'key',
      'login': 'user',
      'passHash': 'hash',
      'proxySettings': {'username': 'proxy', 'password': 'password'},
    };

    final result = const ProfileExportSanitizer().sanitizeJson(
      json,
      includeCredentials: true,
    );

    expect(result['apiKey'], 'key');
    expect(result['login'], 'user');
    expect(result['passHash'], 'hash');
    expect(result['proxySettings'], {
      'username': 'proxy',
      'password': 'password',
    });
    expect(result['credentialsIncluded'], isTrue);
  });

  test('detects credentials from parsed profile data', () {
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': 1,
      'booruId': 1,
      'booruIdHint': 1,
      'name': 'Profile',
      'url': 'https://example.com',
      'apiKey': 'secret',
    });

    expect(profileContainsCredentials(profile), isTrue);
    expect(profileContainsCredentials(BooruConfig.empty), isFalse);
  });
}
