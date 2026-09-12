// Package imports:
import 'package:booru_clients/generated.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/configs/create/src/types/validator/booru_url_validator.dart';

void main() {
  // A single-site source is filtered out of the manual engine dropdown in
  // UnknownConfigBooruSelector, so typing its URL is the only way to add it.
  // That lookup (BooruDb.getBooruFromUrl -> Booru.hasSite) compares by exact
  // string equality against the registered site URL, and the input is first put
  // through createBooruUri. So a registered URL that createBooruUri can never
  // produce makes the source unreachable — which is what shipping
  // `https://www.pixiv.net/` did, since the validator rejects any `www.` host.
  group('single-site sources', () {
    final singleSiteConfigs = BooruYamlConfigs.values
        .where((config) => config.type.isSingleSite)
        .toList();

    test('some are registered', () {
      expect(singleSiteConfigs, isNotEmpty);
    });

    for (final config in singleSiteConfigs) {
      test('the registered url for ${config.type.name} can be typed in', () {
        final reachable = config.sites.any(
          (site) => createBooruUri(site.url).fold(
            (_) => false,
            (uri) => uri.toString() == site.url,
          ),
        );

        expect(reachable, isTrue);
      });
    }
  });
}
