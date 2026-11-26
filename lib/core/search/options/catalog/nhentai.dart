import '../../../../boorus/nhentai/search/query.dart';
import '../search_option.dart';

const nhentaiOptions = <SearchOption>[
  SearchOption(
    kind: SearchOptionKind.metadata,
    key: 'pages',
    input: SearchOptionInput.number,
    labelKey: 'nhentai_pages',
    descriptionKey: 'nhentai_number',
    allowNegative: false,
  ),
  SearchOption(
    kind: SearchOptionKind.metadata,
    key: 'favorites',
    input: SearchOptionInput.number,
    labelKey: 'nhentai_favorites',
    descriptionKey: 'nhentai_number',
    allowNegative: false,
  ),
  _NhentaiUploadedOption(),
  _NhentaiTitleOption('title', 'nhentai_title'),
  _NhentaiTitleOption('jtitle', 'nhentai_jtitle'),
];

class _NhentaiUploadedOption extends SearchOption {
  const _NhentaiUploadedOption()
    : super(
        kind: SearchOptionKind.uploaded,
        key: 'uploaded',
        input: SearchOptionInput.duration,
        descriptionKey: 'nhentai_uploaded',
      );

  @override
  List<String> get units => const ['d', 'w', 'm', 'y'];

  @override
  bool accepts(String value) =>
      RegExp(r'^(?:>=|<=|>|<)?[1-9][0-9]*[dwmy]$').hasMatch(value);
}

class _NhentaiTitleOption extends SearchOption {
  const _NhentaiTitleOption(String key, String label)
    : super(
        kind: SearchOptionKind.metadata,
        key: key,
        input: SearchOptionInput.text,
        labelKey: label,
        descriptionKey: 'nhentai_title_text',
        negation: SearchOptionNegation.prefix,
      );

  @override
  bool accepts(String value) =>
      value.trim().isNotEmpty && !RegExp(r'[\x00-\x1f]').hasMatch(value);

  @override
  String editorValue(String value) =>
      value.startsWith('"') && value.endsWith('"') && value.length >= 2
      ? value
            .substring(1, value.length - 1)
            .replaceAllMapped(RegExp(r'\\(["\\])'), (match) => match[1]!)
      : value;

  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    final prefix = exclude ? '-' : '';
    return '$prefix$key:${quoteNhentaiSearchValue(value.trim())}';
  }
}
