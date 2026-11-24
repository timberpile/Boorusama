import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  late _Adapter adapter;
  late PixivClient client;
  setUp(() {
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    client = PixivClient(accessToken: 'fixture', dio: dio);
  });

  test(
    'mutations send the illustration ID as a form with no redirects',
    () async {
      for (final visibility in PixivBookmarkVisibility.values) {
        await client.addIllustBookmark(
          illustId: 712345,
          visibility: visibility,
        );
        expect(adapter.requests.last.path, '/v2/illust/bookmark/add');
        expect(Uri.splitQueryString(adapter.forms.last), {
          'illust_id': '712345',
          'restrict': visibility.name,
        });
      }
      await client.deleteIllustBookmark(illustId: 712345);
      expect(adapter.requests.last.path, '/v1/illust/bookmark/delete');
      expect(Uri.splitQueryString(adapter.forms.last), {'illust_id': '712345'});
      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        expect(request.method, 'POST');
        expect(request.contentType, Headers.formUrlEncodedContentType);
        expect(request.followRedirects, isFalse);
        expect(request.extra[stateChangingRequestKey], isTrue);
      }
    },
  );

  test(
    'targeted lookup preserves unknown visibility and validates shape',
    () async {
      adapter.body =
          '{"bookmark_detail":{"is_bookmarked":true,"restrict":"private"}}';
      expect(await client.getIllustBookmarkDetail(illustId: 712345), (
        isBookmarked: true,
        visibility: PixivBookmarkVisibility.private,
      ));
      expect(adapter.requests.single.path, '/v2/illust/bookmark/detail');
      expect(adapter.requests.single.queryParameters, {'illust_id': 712345});
      adapter.body =
          '{"bookmark_detail":{"is_bookmarked":true,"restrict":"all"}}';
      expect(await client.getIllustBookmarkDetail(illustId: 712345), (
        isBookmarked: true,
        visibility: null,
      ));
      adapter.body =
          '{"bookmark_detail":{"is_bookmarked":false,"restrict":"public"}}';
      expect(await client.getIllustBookmarkDetail(illustId: 712345), (
        isBookmarked: false,
        visibility: null,
      ));
      adapter.body = '{"bookmark_detail":{"is_bookmarked":"false"}}';
      await expectLater(
        client.getIllustBookmarkDetail(illustId: 712345),
        throwsFormatException,
      );
    },
  );

  test(
    'auth rejection and error envelopes fail without resending a write',
    () async {
      adapter.status = 401;
      await expectLater(
        client.deleteIllustBookmark(illustId: 712345),
        throwsA(isA<PixivAuthException>()),
      );
      expect(adapter.requests, hasLength(1));
      adapter.status = 200;
      adapter.body = '{"error":{"message":"fixture rejection"}}';
      await expectLater(
        client.deleteIllustBookmark(illustId: 712345),
        throwsA(isA<PixivApiException>()),
      );
      expect(adapter.requests, hasLength(2));
      adapter.body = '"unexpected"';
      await expectLater(
        client.deleteIllustBookmark(illustId: 712345),
        throwsFormatException,
      );
      expect(adapter.requests, hasLength(3));
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final forms = <String>[];
  var body = '{}';
  var status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    forms.add(
      requestStream == null
          ? ''
          : await utf8.decoder.bind(requestStream).join(),
    );
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
