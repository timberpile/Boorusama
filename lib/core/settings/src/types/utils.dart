const minPostsPerPage = 10;
const maxPostsPerPage = 200;

List<int> getPostsPerPagePossibleValue() => const [20, 40, 60, 100, 200];

int? parseCustomPostsPerPage(String input) {
  final value = int.tryParse(input);

  if (value == null || value < minPostsPerPage || value > maxPostsPerPage) {
    return null;
  }

  return value;
}
