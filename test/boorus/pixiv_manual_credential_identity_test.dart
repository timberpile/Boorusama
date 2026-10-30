import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/configs/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/providers/internal_providers.dart';
import 'package:boorusama/core/configs/create/src/types/edit_booru_config_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dio/dio.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/boorus/pixiv/client_provider.dart';

const _id = EditBooruConfigId.newId(
  booruType: BooruType.pixiv,
  url: 'https://www.pixiv.net/',
);
const _oldIdentity = PixivExtraData(userId: '100', userName: 'Account A');

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  for (final fresh in [false, true]) {
    testWidgets(
      'explicit verification pairs the manual token and account ($fresh)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final transport = _TokenTransport();
        final container = await _pump(
          tester,
          transport: transport,
          fresh: fresh,
          scale: fresh ? 2 : 1,
          keyboard: 220,
        );
        await tester.enterText(find.byType(EditableText), 'refresh-test-b');
        await tester.pump();
        expect(transport.requests, isEmpty);
        final verify = find.byKey(const ValueKey('pixiv-verify-manual-token'));
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await _until(tester, () => transport.requests.isNotEmpty);
        expect(
          (transport.requests.single.options.data as Map)['refresh_token'],
          'refresh-test-b',
        );
        transport.requests.single.complete(200);
        await _until(
          tester,
          () =>
              container.read(editBooruConfigProvider(_id)).apiKey ==
              'rotated-test-200',
        );
        final data = container.read(editBooruConfigProvider(_id));
        expect(data.login, 'account-200');
        expect(PixivExtraData.fromPassHash(data.passHash).userId, '200');
        expect(
          find.byKey(const ValueKey('pixiv-verify-manual-token')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('verification completion after leaving the auth tab is ignored', (
    tester,
  ) async {
    final transport = _TokenTransport();
    await _pump(tester, transport: transport);
    await tester.enterText(find.byType(EditableText), 'refresh-test-b');
    await tester.pump();
    final verify = find.byKey(const ValueKey('pixiv-verify-manual-token'));
    await tester.ensureVisible(verify);
    await tester.tap(verify);
    await _until(tester, () => transport.requests.isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    transport.requests.single.complete(200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an obsolete verification cannot replace a newer manual account',
    (tester) async {
      final transport = _TokenTransport();
      final container = await _pump(tester, transport: transport);
      final verify = find.byKey(const ValueKey('pixiv-verify-manual-token'));
      for (final account in ['b', 'c']) {
        await tester.enterText(
          find.byType(EditableText),
          'refresh-test-$account',
        );
        await tester.pump();
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await _until(
          tester,
          () => transport.requests.length == (account == 'b' ? 1 : 2),
        );
      }
      transport.requests[1].complete(300);
      await _until(
        tester,
        () =>
            container.read(editBooruConfigProvider(_id)).apiKey ==
            'rotated-test-300',
      );
      transport.requests[0].complete(200);
      await tester.pumpAndSettle();
      final data = container.read(editBooruConfigProvider(_id));
      expect(data.apiKey, 'rotated-test-300');
      expect(PixivExtraData.fromPassHash(data.passHash).userId, '300');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'incomplete verification keeps identity unknown and remains retryable',
    (tester) async {
      final transport = _TokenTransport();
      final container = await _pump(tester, transport: transport);
      await tester.enterText(find.byType(EditableText), 'refresh-test-b');
      await tester.pump();
      final verify = find.byKey(const ValueKey('pixiv-verify-manual-token'));
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await _until(tester, () => transport.requests.isNotEmpty);
      transport.requests.single.complete(null);
      await tester.pumpAndSettle();
      expect(container.read(editBooruConfigProvider(_id)).passHash, isNull);
      expect(tester.widget<OutlinedButton>(verify).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final token in ['refresh-test-b', '']) {
    testWidgets('manual replacement clears the previous identity: $token', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tester.enterText(find.byType(EditableText), token);
      await tester.pump();

      final data = container.read(editBooruConfigProvider(_id));
      expect(data.apiKey, token);
      expect(data.login, isEmpty);
      expect(data.passHash, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unchanged manual credential retains its verified identity', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.enterText(find.byType(EditableText), 'refresh-test-a');
    await tester.pump();

    final data = container.read(editBooruConfigProvider(_id));
    expect(data.login, 'account-a');
    expect(data.passHash, _oldIdentity.toPassHash());
    expect(tester.takeException(), isNull);
  });

  testWidgets('programmatic token updates do not clear paired OAuth metadata', (
    tester,
  ) async {
    final container = await _pump(tester);
    const newIdentity = PixivExtraData(userId: '200', userName: 'Account B');
    container.read(editBooruConfigProvider(_id).notifier)
      ..updateLogin('account-b')
      ..updateApiKey('refresh-test-b')
      ..updatePassHash(newIdentity.toPassHash());
    await tester.pump();

    final data = container.read(editBooruConfigProvider(_id));
    expect(data.login, 'account-b');
    expect(data.apiKey, 'refresh-test-b');
    expect(data.passHash, newIdentity.toPassHash());
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'refresh-test-b',
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  _TokenTransport? transport,
  bool fresh = false,
  double scale = 1,
  double keyboard = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        editBooruConfigIdProvider.overrideWithValue(_id),
        editBooruConfigProvider.overrideWith(() => _SeededEditNotifier(fresh)),
        if (transport != null)
          pixivOAuthDioProvider.overrideWithValue(transport.dio),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
          ),
          home: const Scaffold(body: PixivAuthConfigView()),
        ),
      ),
    ),
  );
  await tester.ensureVisible(find.byType(EditableText));
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(PixivAuthConfigView)),
  );
}

class _SeededEditNotifier extends EditBooruConfigNotifier {
  _SeededEditNotifier([this.fresh = false]);
  final bool fresh;
  @override
  BooruConfigData build(EditBooruConfigId arg) =>
      BooruConfig.defaultConfig(
        booruType: arg.booruType,
        url: arg.url,
        customDownloadFileNameFormat: null,
      ).toBooruConfigData().copyWith(
        login: fresh ? '' : 'account-a',
        apiKey: fresh ? '' : 'refresh-test-a',
        passHash: () => fresh ? null : _oldIdentity.toPassHash(),
      );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

class _TokenRequest {
  _TokenRequest(this.options);
  final RequestOptions options;
  final response = Completer<ResponseBody>();
  void complete(int? userId) => response.complete(
    ResponseBody.fromString(
      jsonEncode({
        'access_token': 'access-test-$userId',
        'refresh_token': 'rotated-test-$userId',
        'expires_in': 3600,
        if (userId != null)
          'user': {
            'id': '$userId',
            'account': 'account-$userId',
            'name': 'Fixture',
          },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
}

class _TokenTransport implements HttpClientAdapter {
  _TokenTransport() {
    dio = Dio(BaseOptions(baseUrl: 'https://oauth.secure.pixiv.net'))
      ..httpClientAdapter = this;
    addTearDown(() => dio.close(force: true));
  }
  late final Dio dio;
  final requests = <_TokenRequest>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) {
    final request = _TokenRequest(options);
    requests.add(request);
    return request.response.future;
  }

  @override
  void close({bool force = false}) {}
}
