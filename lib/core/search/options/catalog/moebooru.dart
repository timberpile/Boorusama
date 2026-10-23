import '../search_option.dart';
import 'common.dart';

// Moebooru Tag::ParseMethods explicitly supports only selected prefix-negated
// fields. Numeric exclusions therefore use comparison complements, not -field.
List<SearchOption> moebooruOptions() => [
  ratingOption(legacy: true, short: true),
  const SearchOption(
    kind: SearchOptionKind.sort,
    key: 'order',
    input: SearchOptionInput.choice,
    choices: [
      SearchOptionChoice('newest', 'id_desc'),
      SearchOptionChoice('oldest', 'id'),
      SearchOptionChoice('highest_score', 'score'),
      SearchOptionChoice('lowest_score', 'score_asc'),
      SearchOptionChoice('mpixels', 'mpixels'),
      SearchOptionChoice('mpixels_asc', 'mpixels_asc'),
      SearchOptionChoice('landscape', 'landscape'),
      SearchOptionChoice('portrait', 'portrait'),
      SearchOptionChoice('vote', 'vote'),
    ],
  ),
  scoreOption(),
  numericOption(
    'id',
    kind: SearchOptionKind.postId,
    negation: SearchOptionNegation.comparison,
  ),
  textOption('user', kind: SearchOptionKind.uploader, description: 'user'),
  for (final key in ['width', 'height'])
    numericOption(
      key,
      choices: pixelChoices,
      description: 'pixels',
      negation: SearchOptionNegation.comparison,
    ),
  numericOption(
    'mpixels',
    input: SearchOptionInput.decimal,
    negation: SearchOptionNegation.comparison,
  ),
  numericOption(
    'ratio',
    input: SearchOptionInput.ratio,
    negation: SearchOptionNegation.comparison,
    choices: const [
      SearchOptionChoice('16:9', '16:9', literal: true),
      SearchOptionChoice('1:1', '1:1', literal: true),
    ],
  ),
  numericOption(
    'date',
    input: SearchOptionInput.date,
    negation: SearchOptionNegation.comparison,
  ),
  textOption('source', description: 'source'),
  textOption('md5', description: 'hash'),
  textOption(
    'pool',
    description: 'pool',
    negation: SearchOptionNegation.prefix,
  ),
  numericOption(
    'parent',
    ranges: false,
    choices: const [SearchOptionChoice('none', 'none')],
    description: 'id',
  ),
  textOption('fav', description: 'user'),
  textOption('sub', description: 'saved_search'),
  // vote:<score>:<username>, whereas -vote accepts a username only. A generic
  // Include/Exclude toggle would incorrectly reuse the positive payload.
  textOption('vote', description: 'vote'),
  enumOption('unlocked', ['rating']),
  enumOption('deleted', ['true', 'all'], description: 'status'),
  enumOption('ext', ['jpg', 'png', 'gif', 'webm', 'mp4'], label: 'filetype'),
  for (final key in ['holds', 'pending'])
    enumOption(key, ['true', 'false', 'all', 'only'], description: 'status'),
  enumOption('shown', ['true', 'false']),
  numericOption(
    'change',
    description: 'count',
    negation: SearchOptionNegation.comparison,
  ),
];
