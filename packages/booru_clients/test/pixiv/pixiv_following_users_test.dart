import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  String next({String host = 'app-api.pixiv.net', String user = '7',
    String restrict = 'public', String offset = '30'}) =>
      'https://$host/v1/user/following?user_id=$user&restrict=$restrict&offset=$offset';
  Map<String, dynamic> entry(int id, {int previews = 0}) => {
    'user': {'id': id, 'name': 'Fixture'},
    'illusts': List.generate(previews, (i) => {'id': i + 100}),
  };

  test('user list requests fixed endpoint and preserves privacy/offset', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, handler) {
      requests.add(r);
      handler.resolve(Response(requestOptions: r, data: {
        'user_previews': [entry(42, previews: 4)],
        'next_url': requests.length == 1 ? next(restrict: 'private') : null,
      }));
    }));
    final client = PixivClient(accessToken: 'fixture-only', dio: dio);
    final first = await client.getFollowingUsers(userId: 7,
      restrict: PixivFollowRestrict.private);
    final last = await client.getFollowingUsers(userId: 7,
      restrict: PixivFollowRestrict.private, offset: first.nextOffset!);
    expect(first.artists.single.user.id, 42);
    expect(first.artists.single.illusts, hasLength(3));
    expect(last.hasMore, isFalse);
    expect(requests.map((r) => r.path).toSet(), {'/v1/user/following'});
    expect(requests.map((r) => r.queryParameters['offset']), [0, 30]);
    expect(requests.last.queryParameters['restrict'], 'private');
    expect(requests.last.followRedirects, isFalse);
    expect(requests.last.headers['Authorization'], 'Bearer fixture-only');
  });

  for (final url in [next(host: 'example.invalid'), next(user: '8'),
    next(restrict: 'private'), next(offset: '0'), next(offset: '-1'),
    next(offset: 'x'), next() + '&offset=60',
    next().replaceFirst('https:', 'http:'), next() + '#fragment']) {
    test('rejects invalid or non-advancing continuation $url', () {
      expect(() => PixivFollowingPage.fromJson(
        {'user_previews': [], 'next_url': url}, userId: 7,
        restrict: PixivFollowRestrict.public, offset: 0,
      ), throwsFormatException);
    });
  }

  test('missing avatars/previews do not remove an otherwise valid artist', () {
    final page = PixivFollowingPage.fromJson(
      {'user_previews': [{'user': {'id': 42}}]}, userId: 7,
      restrict: PixivFollowRestrict.public, offset: 0,
    );
    expect(page.artists.single.user.id, 42);
    expect(page.artists.single.illusts, isEmpty);
    expect(page.artists.single.user.profileImageUrls?.medium, isNull);
  });

  test('malformed collection is not a successful empty result', () {
    expect(() => PixivFollowingPage.fromJson({}, userId: 7,
      restrict: PixivFollowRestrict.public, offset: 0), throwsFormatException);
  });

  test('unverified all restriction is not sent to the user-list API', () async {
    final client = PixivClient(accessToken: 'fixture-only');
    await expectLater(client.getFollowingUsers(userId: 7,
      restrict: PixivFollowRestrict.all), throwsArgumentError);
  });
}
