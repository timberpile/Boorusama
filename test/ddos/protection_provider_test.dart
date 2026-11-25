// Package imports:
import 'package:coreutils/coreutils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/debug/data.dart';
import 'package:boorusama/core/debug/providers.dart';
import 'package:boorusama/core/http/cookies/providers.dart';
import 'package:boorusama/foundation/platform.dart';

import '../support/fakes/test_platform_services.dart';

void main() {
  test('Linux HTTP protection does not initialize a WebView plugin', () {
    final container = _container(platform: AppPlatform.linux);
    addTearDown(container.dispose);

    final handler = container.read(httpDdosProtectionBypassProvider);

    expect(handler.isDisabled, isFalse);
  });

  test('public Cloudflare clearance stays on the challenged host', () async {
    final jar = PublicCloudflareCookieJar();
    final safe = Uri.parse('https://safebooru.donmai.us/pools/42.json');
    await jar.saveFromResponse(safe, [
      Cookie('cf_clearance', 'verified')..domain = '.donmai.us',
      Cookie('session', 'private')..domain = '.donmai.us',
    ]);

    expect(
      (await jar.loadForRequest(safe)).map((cookie) => cookie.name),
      ['cf_clearance'],
    );
    expect(
      await jar.loadForRequest(
        Uri.parse('https://danbooru.donmai.us/pools/42.json'),
      ),
      isEmpty,
    );
  });
}

ProviderContainer _container({required AppPlatform platform}) {
  return ProviderContainer(
    overrides: [
      appPlatformProvider.overrideWithValue(platform),
      appLoggerProvider.overrideWithValue(AppLogger()),
      cookieJarFactoryProvider.overrideWithValue(
        const MemoryCookieJarFactory(),
      ),
    ],
  );
}
