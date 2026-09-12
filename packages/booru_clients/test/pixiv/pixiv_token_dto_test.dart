import 'package:booru_clients/pixiv.dart';
import 'package:test/test.dart';

void main() {
  group('PixivTokens', () {
    test('does not contain the access or refresh token in toString', () {
      final tokens = PixivTokens.fromJson({
        'access_token': 'super-secret-access',
        'refresh_token': 'super-secret-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {'id': '1', 'name': 'a', 'account': 'a'},
      });

      final text = tokens.toString();

      expect(text.contains('super-secret-access'), false);
      expect(text.contains('super-secret-refresh'), false);
    });

    final userIdCases = [(raw: '7', expected: '7'), (raw: 7, expected: '7')];
    for (final c in userIdCases) {
      test('parses a token user id given as ${c.raw.runtimeType}', () {
        final tokens = PixivTokens.fromJson({
          'access_token': 'a',
          'refresh_token': 'b',
          'user': {'id': c.raw, 'name': 'someone', 'account': 'someone'},
        });

        expect(tokens.user?.id, c.expected);
      });
    }
  });
}
