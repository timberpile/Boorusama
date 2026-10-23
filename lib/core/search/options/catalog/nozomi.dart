import '../search_option.dart';

List<SearchOption> nozomiOptions() => const [
  SearchOption(
    kind: SearchOptionKind.sort,
    key: 'order',
    input: SearchOptionInput.choice,
    descriptionKey: 'api_sort',
    choices: [
      SearchOptionChoice('newest', 'date'),
      SearchOptionChoice('popular', 'popular'),
    ],
  ),
];
