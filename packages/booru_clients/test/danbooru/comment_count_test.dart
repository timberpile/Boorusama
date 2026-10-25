import 'package:booru_clients/danbooru.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  DanbooruClient client(List<Object?> bodies, List<RequestOptions> calls) =>
      DanbooruClient(
        baseUrl: 'https://source.test',
        dio: Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                calls.add(options);
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: bodies.removeAt(0),
                  ),
                );
              },
            ),
          ),
      );
  test('a successful empty source result is a known zero', () async {
    final calls = <RequestOptions>[];
    expect(await client([[]], calls).getCommentCount(postId: 12), 0);
    expect(calls, hasLength(1));
  });
  test('an empty continuation proves a complete small comment set', () async {
    final calls = <RequestOptions>[];
    expect(
      await client([
        [
          {'id': 30, 'is_deleted': false},
          {'id': 20, 'is_deleted': false},
        ],
        [],
      ], calls).getCommentCount(postId: 12),
      2,
    );
    expect(calls, hasLength(2));
    expect(calls.last.queryParameters['search[id]'], '<20');
    expect(calls.last.queryParameters['limit'], 1);
  });
  test('a server page cap or another page cannot become a total', () async {
    for (final size in [20, 100]) {
      final calls = <RequestOptions>[];
      expect(
        await client([
          [
            for (var i = 200; i > 200 - size; i--)
              {'id': i, 'is_deleted': false},
          ],
          [
            {'id': 1, 'is_deleted': false},
          ],
        ], calls).getCommentCount(postId: 12),
        isNull,
      );
      expect(calls, hasLength(2));
    }
  });
  test(
    'malformed responses and unverified deletion flags remain unknown',
    () async {
      for (final body in [
        null,
        {'success': false},
        [
          {'id': 1},
        ],
        [
          {'id': 1, 'is_deleted': false},
          {'id': 2, 'is_deleted': false},
        ],
      ]) {
        expect(await client([body], []).getCommentCount(postId: 12), isNull);
      }
    },
  );
}
