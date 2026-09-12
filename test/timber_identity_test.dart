import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('environment files use the Timber display names', () {
    final prod =
        jsonDecode(File('env/prod.json').readAsStringSync())
            as Map<String, dynamic>;
    final dev =
        jsonDecode(File('env/dev.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(prod['APP_NAME'], 'Boorusama Timber');
    expect(dev['APP_NAME'], 'Boorusama Timber Dev');
  });
}
