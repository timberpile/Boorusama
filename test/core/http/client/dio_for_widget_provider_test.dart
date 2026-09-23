// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/providers.dart';

void main() {
  test('uses the generic client when the post site is unavailable', () {
    final genericDio = Dio();
    final container = ProviderContainer(
      overrides: [
        booruEngineRegistryProvider.overrideWith(
          (ref) => BooruEngineRegistry(),
        ),
        genericDioProvider.overrideWithValue(genericDio),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioForWidgetProvider(BooruConfig.empty.auth));

    expect(dio, same(genericDio));
  });
}
