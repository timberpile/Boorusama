import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/posts/shares/src/share_cached_image_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('corrupt AVIF boxes do not produce cached metadata', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([
      0,
      0,
      0,
      16,
      0x66,
      0x74,
      0x79,
      0x70,
      0x61,
      0x76,
      0x69,
      0x66,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      9,
      0x6d,
      0x65,
      0x74,
      0x61,
      0,
      0,
      0,
      0,
      9,
      0x6d,
      0x64,
      0x61,
      0x74,
      0,
    ]);

    expect(
      await tester.runAsync(() => cachedShareImageDescription(bytes)),
      isNull,
    );
  });

  testWidgets(
    'valid cached AVIF reports metadata-only dimensions with size and format',
    (tester) async {
      final bytes = base64Decode(
        'AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAAD5bWV0YQAAAAAAAAAvaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAFBpY3R1cmVIYW5kbGVyAAAAAA5waXRtAAAAAAABAAAAHmlsb2MAAAAARAAAAQABAAAAAQAAASEAAAAbAAAAKGlpbmYAAAAAAAEAAAAaaW5mZQIAAAAAAQAAYXYwMUNvbG9yAAAAAGppcHJwAAAAS2lwY28AAAAUaXNwZQAAAAAAAAACAAAAAgAAABBwaXhpAAAAAAMICAgAAAAMYXYxQ4EADAAAAAATY29scm5jbHgAAgACAAIAAAAAF2lwbWEAAAAAAAAAAQABBAECgwQAAAAjbWRhdAoFGAA2wCAyEhgAAABQAABAA1Lt5xf080WmIA==',
      );

      expect(
        await tester.runAsync(
          () => cachedShareImageDescription(bytes.sublist(0, 32)),
        ),
        isNull,
      );
      expect(
        await tester.runAsync(() => cachedShareImageDescription(bytes)),
        '2 × 2 · 316 B · AVIF',
      );
    },
  );
}
