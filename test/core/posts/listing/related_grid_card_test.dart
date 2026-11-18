import 'package:boorusama/core/posts/listing/src/widgets/related_grid_card.dart';
import 'package:boorusama/core/posts/listing/src/types/image_list_type.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ImageListType.values) {
    for (final ratio in <double?>[.5, 1, 2, null]) {
      testWidgets('$mode ratio=$ratio fills its cell with the Post fit', (
        tester,
      ) async {
        final geometry = RelatedGridGeometry();
        BoxFit? fit;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 240,
                height: mode == ImageListType.masonry ? null : 160,
                child: RelatedGridCard(
                  listType: mode,
                  geometry: geometry,
                  aspectRatio: ratio,
                  builder: (value) {
                    fit = value;
                    return const SizedBox.expand(key: ValueKey('cover'));
                  },
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('cover'))),
          Size(240, mode == ImageListType.masonry ? 240 / (ratio ?? .6) : 160),
        );
        expect(
          fit,
          mode == ImageListType.standard ? BoxFit.cover : BoxFit.contain,
        );
      });
    }
  }

  for (final initial in <double?>[
    .5,
    1,
    2,
    null,
    0,
    -1,
    double.nan,
    double.infinity,
  ]) {
    testWidgets(
      'Masonry captures $initial once across late media and recycling',
      (tester) async {
        final geometry = RelatedGridGeometry();
        Future<void> show(double? ratio) => tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 240,
                child: RelatedGridCard(
                  listType: ImageListType.masonry,
                  geometry: geometry,
                  aspectRatio: ratio,
                  builder: (_) => const SizedBox.expand(key: ValueKey('cover')),
                ),
              ),
            ),
          ),
        );
        await show(initial);
        final first = tester.getSize(find.byKey(const ValueKey('cover')));
        for (final later in <double?>[2, null, .5, 1]) {
          await show(later);
          expect(tester.getSize(find.byKey(const ValueKey('cover'))), first);
        }
        // Lazy slivers dispose offscreen children. Listing-owned geometry remains.
        await tester.pumpWidget(const SizedBox.shrink());
        await show(3);
        expect(tester.getSize(find.byKey(const ValueKey('cover'))), first);
      },
    );
  }
}
