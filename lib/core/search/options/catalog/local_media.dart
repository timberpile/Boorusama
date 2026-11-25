import '../../../local_media/local_media_models.dart';
import '../search_option.dart';

const localMediaRatingKey = 'rating';
const localMediaFormatKey = 'filetype';
const localMediaOrderKey = 'order';

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
