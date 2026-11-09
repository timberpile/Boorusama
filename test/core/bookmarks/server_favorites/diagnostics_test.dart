import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  late FavoriteHarness h;
  late AppLogger logger;
  setUp(() async {
    logger = AppLogger();
    h = FavoriteHarness();
    await h.open(
      extraOverrides: (_) => [loggerProvider.overrideWithValue(logger)],
    );
    final group = await h.container
        .read(bookmarkLibraryProvider.notifier)
        .createGroup('Fixture target');
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(group.id);
  });
  tearDown(() async {
    await h.close();
    logger.dispose();
  });

  test('disk failure reports settings-write stage while confirmed assignment survives', () async {
    final before = await h.container.read(
      serverFavoriteSettingsProvider.future,
    );
    h.store.fail = true;
    await expectLater(
      h.container.read(serverFavoriteSettingsProvider.notifier).setGlobal(null),
      throwsStateError,
    );
    expect(
      await h.container.read(serverFavoriteSettingsProvider.future),
      before,
    );
    expect(logger.dump(), contains('stage=settings_write'));
    expect(h.source.calls, 0);
  });

  test('remote failure reports dispatch stage/status and opaque actor without raw payload', () async {
    final options = RequestOptions(
      path: 'https://private.example/favorites?token=SECRET',
    );
    h.source.error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: options, statusCode: 403),
      message: 'SECRET',
    );
    final result = await h.container
        .read(serverFavoriteFetchProvider.notifier)
        .start(h.profile.id);
    expect(result.problem, ServerFavoriteProblem.remoteFailure);
    final message = logger.dump();
    expect(message, contains('stage=remote_fetch'));
    expect(message, contains('http_status=403'));
    expect(message, contains('actor='));
    expect(message, isNot(contains(h.profile.id)));
    expect(message, isNot(contains('SECRET')));
    expect(message, isNot(contains('private.example')));
  });
}
