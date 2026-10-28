import 'package:booru_clients/moebooru.dart';
import 'package:test/test.dart';

void main() {
  test('absent and malformed scores remain unavailable', () {
    for (final value in [null, '', 'unavailable', false]) {
      expect(PostDto.fromJson({'id': 1, 'score': value}).score, isNull);
    }
    expect(PostDto.fromJson({'id': 1}).score, isNull);
  });
  test('known zero and signed numeric scores retain their values', () {
    for (final value in [0, -2, 10]) {
      expect(PostDto.fromJson({'id': 1, 'score': value}).score, value);
      expect(
        PostDto.fromJson({'id': 1, 'score': value.toString()}).score,
        value,
      );
    }
  });
}
