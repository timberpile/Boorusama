import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '11111111-1111-4111-8111-111111111111',
    'booruId': BooruType.danbooru.id,
    'booruIdHint': BooruType.danbooru.id,
    'url': 'https://safebooru.donmai.us',
  });
  for (final status in [503, 401, 403]) {
    test(
      'unresolved policy fails visibly closed and explicit retry recovers ($status)',
      () async {
        var result = Completer<Set<String>>();
        final c = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [config]),
            ),
            blacklistTagsProvider.overrideWith((ref, filter) => result.future),
          ],
        );
        addTearDown(c.dispose);
        final hold = c.listen(
          contentProfileAccessProvider(config.id),
          (_, _) {},
        );
        addTearDown(hold.close);
        expect(c.read(contentProfileAccessProvider(config.id)), isNull);
        result.completeError(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: status,
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        await c.pump();
        expect(c.read(contentProfileAccessProvider(config.id)), isNull);
        expect(
          c.read(contentEffectivePolicyProvider(config.id)).hasError,
          isTrue,
        );
        result = Completer<Set<String>>()..complete({'local_rule'});
        c.invalidate(blacklistTagsProvider(config.filter));
        await c.read(blacklistTagsProvider(config.filter).future);
        await c.pump();
        expect(c.read(contentProfileAccessProvider(config.id))?.config, config);
      },
    );
  }
}
