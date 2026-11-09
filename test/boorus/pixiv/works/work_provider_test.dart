import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/providers.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

final _contexts = StateProvider<Map<ContentAccessKey, ContentAccessContext>>(
  (ref) => {},
);

void main() {
  test(
    'secondary Work source provider also captures the effective blacklist',
    () async {
      final access = workAccess();
      final client = _Client()..response.complete(work());
      final container = ProviderContainer(
        overrides: [
          contentAccessContextProvider.overrideWith((_, _) => access),
          contentEffectiveBlacklistProvider.overrideWith(
            (_, _) => const AsyncData({'fixture'}),
          ),
          pixivClientProvider.overrideWith((_, _) => client),
        ],
      );
      addTearDown(container.dispose);
      final hold = container.listen(
        pixivWorkSourceProvider(access.key),
        (_, _) {},
      );
      addTearDown(hold.close);
      final source = container.read(pixivWorkSourceProvider(access.key));
      expect(
        (await source.loadDetails(pixivWorkReference(access, 120)).run())
            .isLeft(),
        isTrue,
      );
      expect(source.blacklist, {'fixture'});
    },
  );

  test('production source provider captures actor and rejects late data after revocation', () async {
    final access = workAccess();
    final client = _Client();
    final container = ProviderContainer(
      overrides: [
        contentAccessContextProvider.overrideWith(
          (ref, key) => ref.watch(_contexts)[key],
        ),
        pixivClientProvider.overrideWith((ref, config) => client),
        contentEffectiveBlacklistProvider.overrideWith(
          (ref, id) => const AsyncData(<String>{}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(_contexts.notifier).state = {access.key: access};
    final provider = pixivWorkSourceProvider(access.key);
    final hold = container.listen(
      provider,
      (_, _) {},
      onError: (_, _) {},
    );
    addTearDown(hold.close);
    final source = container.read(provider);
    expect(source.access.key, access.key);
    final pending = source.loadDetails(pixivWorkReference(access, 120)).run();
    await client.started.future;
    container.read(_contexts.notifier).state = {};
    await container.pump();
    client.response.complete(work());
    expect((await pending).isLeft(), isTrue);
    expect(client.calls, 1);
    expect(() => container.read(provider), throwsStateError);
  });
}

class _Client extends PixivClient {
  _Client() : super(accessToken: 'fixture');
  final started = Completer<void>();
  final response = Completer<PixivIllustDto?>();
  var calls = 0;
  @override
  Future<PixivIllustDto?> getIllustDetail({required int illustId}) {
    expect(illustId, 120);
    calls++;
    started.complete();
    return response.future;
  }
}
