import 'dart:convert';

import 'package:booru_clients/sankaku.dart';
import 'package:booru_clients/src/sankaku_idol/types/post_dto.dart';
import 'package:booru_clients/src/sankaku_idol/types/type_converters.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  const channelHosts = [
    'chan.sankakucomplex.com',
    'beta.sankakucomplex.com',
    'sankakucomplex.com',
    'sankaku.app',
  ];
  const idolHosts = [
    'idol.sankakucomplex.com',
    'www.idolcomplex.com',
    'idolcomplex.com',
  ];
  for (final host in [...channelHosts, ...idolHosts]) {
    test(
      '$host preserves source upload time and known zero counts via its production client',
      () async {
        final idol = idolHosts.contains(host);
        final adapter = _Adapter((request) {
          expect(
            request.uri.host,
            idol ? 'iapi.sankakucomplex.com' : 'sankakuapi.com',
          );
          return [
            {
              'id': idol ? 970315 : 'source-id',
              'created_at': idol
                  ? '2026-10-22T20:42:29.423-04:00'
                  : {'s': 1792716149, 'n': 423000000},
              'file_size': 0,
              'total_score': 0,
              'fav_count': 0,
              'comment_count': 0,
            },
          ];
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final client = SankakuClient.extended(
          baseUrl: 'https://$host/',
          dio: dio,
        );
        final post = (await client.getPosts(limit: 1)).single;
        expect(
          post.createdAt?.s,
          DateTime.parse(
                '2026-10-22T20:42:29.423-04:00',
              ).millisecondsSinceEpoch ~/
              1000,
        );
        expect(post.createdAt?.n, 423000000);
        expect(post.fileSize, 0);
        expect(post.totalScore, 0);
        expect(post.favCount, 0);
        expect(post.commentCount, 0);
        dio.close();
      },
    );
  }
  for (final value in [null, '', 'not-a-date']) {
    test('Idol missing or invalid upload time remains unknown: $value', () {
      final post = PostIdolDto.fromJson({
        'id': 1,
        'created_at': value,
      }).toSankakuPost();
      expect(post.createdAt, isNull);
    });
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Object Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode(respond(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}
