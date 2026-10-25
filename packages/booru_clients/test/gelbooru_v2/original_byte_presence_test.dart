import 'package:booru_clients/gelbooru.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  for (final value in [null, 0, 900, '900']) {
    test('JSON Original bytes preserve source presence: $value', () {
      final dto = PostV2Dto.fromJson({
        'id': 1,
        'file_size': value,
      }, 'https://source.test');
      expect(dto.fileSize, value == null ? null : int.parse(value.toString()));
    });
  }
  test('an XML total is not inferred from missing or invalid attributes', () {
    PostV2Dto read(String attributes) => PostV2Dto.fromXml(
      XmlDocument.parse('<post id="1" $attributes/>').rootElement,
      'https://source.test',
    );
    expect(read('').fileSize, isNull);
    expect(read('file_size="unknown"').fileSize, isNull);
    expect(read('file_size="0"').fileSize, 0);
    expect(read('file_size="900"').fileSize, 900);
  });
}
