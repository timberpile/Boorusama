import 'dart:async';
import 'dart:typed_data';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/boorus/moebooru/client_provider.dart';
import 'package:boorusama/boorus/moebooru/moebooru.dart';
import 'package:boorusama/boorus/eshuushuu/client_provider.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/boorus/gelbooru/client_provider.dart';
import 'package:boorusama/boorus/nozomi/client_provider.dart';
import 'package:boorusama/boorus/philomena/client_provider.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/shimmie2/extensions/providers.dart';
import 'package:boorusama/boorus/zerochan/client_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/ddos/handler/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/http/client/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/info/app_info.dart';
import 'package:fake_async/fake_async.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'actual app factories share one origin budget across profiles and clients',
    () {
      fakeAsync((time) {
        final coordinator = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final container = ProviderContainer(
          overrides: [
            apiRequestCoordinatorProvider.overrideWithValue(coordinator),
            appInfoProvider.overrideWithValue(AppInfo.empty),
            packageInfoProvider.overrideWith(
              (ref) => ref.read(dummyPackageInfoProvider),
            ),
            defaultUserAgentProvider.overrideWithValue('test'),
            defaultNetworkProtocolInfoProvider.overrideWith(
              (ref, auth) =>
                  NetworkProtocolInfo.generic(cronetAvailable: false),
            ),
            httpDdosProtectionBypassProvider.overrideWithValue(_Protection()),
            loggerProvider.overrideWithValue(_Logger()),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: const []),
            ),
            gelbooruV2Provider.overrideWithValue(
              const GelbooruV2(
                config: BooruYamlConfigs.gelbooruV2,
                globalUserParams: {},
              ),
            ),
            moebooruProvider.overrideWithValue(
              const Moebooru(
                config: BooruYamlConfigs.moebooru,
                sites: [
                  (
                    url: 'site.test',
                    postRequestUrl: 'https://secondary.test',
                    salt: '',
                    version: null,
                    favoriteSupport: null,
                    overrideProtocol: null,
                  ),
                ],
              ),
            ),
          ],
        );
        final first = _auth('one');
        final second = _auth('two');
        final clients = [
          container.read(defaultDioProvider(first)),
          container.read(defaultDioProvider(second)),
          container.read(danbooruDioProvider(first)),
          container.read(gelbooruDioProvider(second)),
          container.read(gelbooruV2DioProvider(first)),
          container.read(eshuushuuDioProvider(first)),
          container.read(nozomiDioProvider(first)),
          container.read(philomenaDioProvider(second)),
          container.read(zerochanDioProvider(first)),
          container.read(shimmie2AnonymousDioProvider('https://site.test/')),
        ];
        final adapter = _ImmediateAdapter(hold: true);
        for (final client in clients) {
          expect(client.httpClientAdapter, isA<CoordinatedHttpClientAdapter>());
          expect(
            (client.httpClientAdapter as CoordinatedHttpClientAdapter)
                .coordinator,
            same(coordinator),
          );
          client.httpClientAdapter = CoordinatedHttpClientAdapter(
            adapter,
            coordinator,
          );
          client.get('/data');
        }
        _pump(time);
        expect(adapter.starts, 4);
        expect(
          coordinator
              .snapshot(ApiQuotaKey.fromUri(Uri.parse('https://site.test')))
              .queued,
          6,
        );
        while (adapter.pending.isNotEmpty) {
          adapter.releaseNext();
          _pump(time);
        }
        expect(adapter.starts, 10);
        for (final client in [
          container.read(moebooruPostRequestDioProvider(first))!,
          container.read(pixivDioProvider(first)),
        ]) {
          expect(
            (client.httpClientAdapter as CoordinatedHttpClientAdapter)
                .coordinator,
            same(coordinator),
          );
          client.httpClientAdapter = CoordinatedHttpClientAdapter(
            adapter,
            coordinator,
          );
          client.get('/data');
        }
        _pump(time);
        expect(adapter.starts, 12);
        while (adapter.pending.isNotEmpty) {
          adapter.releaseNext();
          _pump(time);
        }
        final oauth = container.read(pixivOAuthDioProvider);
        expect(oauth.httpClientAdapter, isA<CoordinatedHttpClientAdapter>());
        // No configured LoggingInterceptor may observe OAuth token bodies.
        expect(
          oauth.interceptors.where(
            (i) => i.runtimeType.toString() == 'LoggingInterceptor',
          ),
          isEmpty,
        );
        container.dispose();
        coordinator.dispose();
      });
    },
  );
}

BooruConfigAuth _auth(String account) => BooruConfigAuth(
  booruId: 0,
  booruIdHint: 0,
  url: 'https://site.test',
  apiKey: null,
  login: account,
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);
void _pump(FakeAsync time) {
  for (var i = 0; i < 20; i++) {
    time.flushMicrotasks();
    time.elapse(Duration.zero);
  }
}

final class _ImmediateAdapter implements HttpClientAdapter {
  _ImmediateAdapter({this.hold = false});
  final bool hold;
  final pending = <StreamController<Uint8List>>[];
  void releaseNext() {
    pending.removeAt(0).close();
  }

  var starts = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    starts++;
    if (hold) {
      final stream = StreamController<Uint8List>();
      pending.add(stream);
      return ResponseBody(stream.stream, 200);
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _Protection implements HttpProtectionHandler {
  @override
  Future<Map<String, String>> prepareRequestHeaders(
    Uri uri,
    Map<String, String> headers,
  ) async => headers;
  @override
  Future<bool> handleResponse(Object response) async => false;
  @override
  Future<bool> handleError(Object error) async => false;
  @override
  void resetRetryAttempts(Uri uri) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Logger implements Logger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
