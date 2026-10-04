import 'dart:io';

import 'package:boorusama/core/posts/shares/src/share_image_file_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('truncated AVIF container is rejected without throwing', () async {
    final directory = await Directory.systemTemp.createTemp('share-avif-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/truncated.avif');
    await file.writeAsBytes([
      0,
      0,
      0,
      24,
      102,
      116,
      121,
      112,
      97,
      118,
      105,
      102,
      0,
      0,
      0,
      0,
      97,
      118,
      105,
      102,
      0,
      0,
      0,
      0,
    ]);

    expect(await validateShareImageFile(file), isNull);
  });
}
