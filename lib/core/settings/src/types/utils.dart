import '../../../boorus/booru/types.dart';

const minPostsPerPage = 10;
const maxPostsPerPage = 1000;

List<int> getPostsPerPagePossibleValue() => const [20, 40, 60, 100, 200];

/// The size sent to an ordinary post listing. The stored preference sets an
/// upper bound, and engines without a verified higher limit retain 200.
int effectivePostsPerPage(BooruType engine, int requested) => requested.clamp(
  1,
  switch (engine) {
    BooruType.gelbooru || BooruType.nozomi || BooruType.szurubooru => 100,
    BooruType.e621 => 320,
    BooruType.hybooru => maxPostsPerPage,
    _ => 200,
  },
);

int effectiveGroupPostsPerPage(int requested) => requested.clamp(1, 200);

int? parseCustomPostsPerPage(String input) {
  final value = int.tryParse(input);

  if (value == null || value < minPostsPerPage || value > maxPostsPerPage) {
    return null;
  }

  return value;
}
