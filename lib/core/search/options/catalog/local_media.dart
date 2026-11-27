import '../../../local_media/local_media_models.dart';
import '../search_option.dart';

const localMediaRatingKey = 'rating';
const localMediaFormatKey = 'filetype';
const localMediaOrderKey = 'order';
const localMediaTagCountKey = 'tagcount';

final localMediaSearchOptions = [
  const SearchOption(
    kind: SearchOptionKind.rating,
    key: localMediaRatingKey,
    input: SearchOptionInput.choice,
    negation: SearchOptionNegation.prefix,
    choices: [
      SearchOptionChoice('general', 'g'),
      SearchOptionChoice('sensitive', 's'),
      SearchOptionChoice('questionable', 'q'),
      SearchOptionChoice('explicit', 'e'),
      SearchOptionChoice('unrated', 'unknown'),
    ],
  ),
  SearchOption(
    kind: SearchOptionKind.metadata,
    key: localMediaFormatKey,
    input: SearchOptionInput.choice,
    negation: SearchOptionNegation.prefix,
    descriptionKey: 'local_file_type',
    choices: [
      for (final format in LocalMediaFormat.values)
        SearchOptionChoice(
          format.name.toUpperCase(),
          format.extension,
          literal: true,
        ),
    ],
  ),
  const SearchOption(
    kind: SearchOptionKind.metadata,
    key: localMediaTagCountKey,
    input: SearchOptionInput.number,
    negation: SearchOptionNegation.prefix,
    descriptionKey: 'local_tag_count',
    allowNegative: false,
    choices: [
      SearchOptionChoice('0', '0', literal: true),
      SearchOptionChoice('>0', '>0', literal: true),
    ],
  ),
  const SearchOption(
    kind: SearchOptionKind.sort,
    key: localMediaOrderKey,
    input: SearchOptionInput.choice,
    descriptionKey: 'local_order',
    choices: [
      SearchOptionChoice('newest', 'newest'),
      SearchOptionChoice('oldest', 'oldest'),
      SearchOptionChoice('largest', 'largest'),
      SearchOptionChoice('smallest', 'smallest'),
    ],
  ),
];
