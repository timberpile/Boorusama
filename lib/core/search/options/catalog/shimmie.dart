import '../search_option.dart';
import 'common.dart';

/// Paheal uses '=' for exact values and direct comparisons without ':'.
class ShimmieOption extends SearchOption {
  const ShimmieOption({
    required super.key,
    super.kind = SearchOptionKind.metadata,
    super.input = SearchOptionInput.text,
    super.choices = const [],
    super.labelKey,
    super.descriptionKey,
    super.allowNegative = false,
    super.negation = SearchOptionNegation.prefix,
  });
  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value) || (exclude && !supportsExclusion)) return null;
    final separator = isComparable && RegExp('^[<>]').hasMatch(value)
        ? ''
        : '=';
    return '${exclude ? '-' : ''}$key$separator$value';
  }
}

class ShimmieLengthOption extends ShimmieOption {
  const ShimmieLengthOption()
    : super(
        key: 'length',
        input: SearchOptionInput.duration,
        labelKey: 'duration',
        descriptionKey: 'duration',
        choices: const [
          SearchOptionChoice('≥ 10 s', '>=10s', literal: true),
          SearchOptionChoice('≥ 1 m', '>=1m', literal: true),
        ],
      );
  @override
  List<String> get units => const ['ms', 's', 'm', 'h', 'd', 'y'];
  @override
  bool accepts(String value) =>
      RegExp(r'^(?:>=|<=|>|<)?[1-9][0-9]*(?:ms|s|m|h|d|y)$').hasMatch(value);
}

List<SearchOption> pahealOptions() => [
  ShimmieOption(
    key: 'order',
    kind: SearchOptionKind.sort,
    input: SearchOptionInput.choice,
    negation: SearchOptionNegation.none,
    choices: [
      const SearchOptionChoice('newest', 'id_desc'),
      const SearchOptionChoice('oldest', 'id_asc'),
      const SearchOptionChoice('highest_score', 'score_desc'),
      for (final field in ['score', 'width', 'height', 'filesize', 'filename'])
        for (final direction in ['asc', 'desc'])
          if (field != 'score' || direction != 'desc')
            SearchOptionChoice('${field}_$direction', '${field}_$direction'),
    ],
  ),
  const ShimmieOption(
    key: 'id',
    kind: SearchOptionKind.postId,
    input: SearchOptionInput.number,
  ),
  const ShimmieOption(
    key: 'score',
    kind: SearchOptionKind.score,
    input: SearchOptionInput.number,
    allowNegative: true,
    choices: countChoices,
  ),
  const ShimmieOption(
    key: 'poster',
    kind: SearchOptionKind.uploader,
    descriptionKey: 'user',
  ),
  const ShimmieOption(
    key: 'posted',
    input: SearchOptionInput.date,
    labelKey: 'date',
    descriptionKey: 'timestamp_date',
  ),
  for (final key in ['tags', 'comments'])
    ShimmieOption(
      key: key,
      input: SearchOptionInput.number,
      labelKey: key,
      descriptionKey: 'count',
      choices: countChoices,
    ),
  for (final key in ['width', 'height'])
    ShimmieOption(
      key: key,
      input: SearchOptionInput.number,
      labelKey: key,
      descriptionKey: 'pixels',
      choices: pixelChoices,
    ),
  const ShimmieOption(
    key: 'ratio',
    input: SearchOptionInput.ratio,
    labelKey: 'ratio',
    descriptionKey: 'ratio',
    choices: [
      SearchOptionChoice('16:9', '16:9', literal: true),
      SearchOptionChoice('1:1', '1:1', literal: true),
    ],
  ),
  const ShimmieOption(
    key: 'filesize',
    input: SearchOptionInput.filesize,
    labelKey: 'filesize',
    descriptionKey: 'filesize',
    choices: [SearchOptionChoice('≥ 1 MB', '>=1mb', literal: true)],
  ),
  const ShimmieLengthOption(),
  for (final key in ['commented_by', 'upvoted_by', 'downvoted_by'])
    ShimmieOption(key: key, labelKey: key, descriptionKey: 'user'),
  const ShimmieOption(
    key: 'comments_locked',
    input: SearchOptionInput.choice,
    labelKey: 'comments_locked',
    choices: [SearchOptionChoice('yes', 'yes'), SearchOptionChoice('no', 'no')],
  ),
  const ShimmieOption(
    key: 'source',
    labelKey: 'source',
    descriptionKey: 'source',
    choices: anyNone,
  ),
  for (final key in ['md5', 'filename', 'mime', 'size'])
    ShimmieOption(
      key: key,
      labelKey: key,
      descriptionKey: key == 'md5' ? 'hash' : 'text',
    ),
  ShimmieOption(
    key: 'ext',
    input: SearchOptionInput.choice,
    labelKey: 'filetype',
    descriptionKey: 'choice',
    choices: [
      for (final ext in [
        'jpg',
        'gif',
        'png',
        'webp',
        'avif',
        'bmp',
        'heic',
        'ico',
        'ppm',
        'psd',
        'tif',
        'tga',
        'mp4',
        'webm',
        'asf',
        'avi',
        'mov',
        'flv',
        'mpg',
        'mkv',
        'ogv',
      ])
        SearchOptionChoice(ext, ext, literal: true),
    ],
  ),
  const ShimmieOption(
    key: 'content',
    input: SearchOptionInput.choice,
    labelKey: 'content',
    descriptionKey: 'choice',
    choices: [
      SearchOptionChoice('audio', 'audio'),
      SearchOptionChoice('video', 'video'),
    ],
  ),
];
