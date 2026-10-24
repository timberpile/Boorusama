import '../search_option.dart';
import 'common.dart';

// e621ng/app/logical/tag_query.rb is the post-search grammar. Do not infer
// these values from Danbooru: statuses, ratings, locks and file units differ.
List<SearchOption> e621Options() {
  const prefix = SearchOptionNegation.prefix;
  const categoryCounts = [
    'gentags',
    'arttags',
    'chartags',
    'copytags',
    'spectags',
    'invtags',
    'metatags',
    'lortags',
  ];
  return [
    ratingOption(legacy: true, short: true),
    SearchOption(
      kind: SearchOptionKind.sort,
      key: 'order',
      input: SearchOptionInput.choice,
      choices: [
        const SearchOptionChoice('newest', 'id_desc'),
        const SearchOptionChoice('oldest', 'id'),
        const SearchOptionChoice('highest_score', 'score'),
        const SearchOptionChoice('most_favorites', 'favcount'),
        for (final value in <String>{
          'random',
          'hot',
          'portrait',
          'landscape',
          for (final field in [
            'id',
            'score',
            'md5',
            'favcount',
            'note',
            'mpixels',
            'filesize',
            'tagcount',
            'change',
            'duration',
            'created',
            'updated',
            'comment',
            'comment_bumped',
            'aspect_ratio',
            'deleted',
            'flagged',
            'comment_count',
            ...categoryCounts,
          ]) ...[field, '${field}_asc', '${field}_desc'],
        }.difference({'id_desc', 'id', 'score', 'favcount'}))
          SearchOptionChoice(value, value),
      ],
    ),
    const SearchOption(
      kind: SearchOptionKind.uploaded,
      key: 'age',
      input: SearchOptionInput.duration,
      allowRange: true,
      negation: prefix,
      choices: [
        SearchOptionChoice('7 d', '<7d', literal: true),
        SearchOptionChoice('30 d', '<30d', literal: true),
      ],
    ),
    numericOption(
      'score',
      kind: SearchOptionKind.score,
      signed: true,
      negation: prefix,
      choices: const [
        SearchOptionChoice('score_20', '>=20'),
        SearchOptionChoice('score_50', '>=50'),
        SearchOptionChoice('score_100', '>=100'),
      ],
    ),
    numericOption('id', kind: SearchOptionKind.postId, negation: prefix),
    textOption(
      'user',
      kind: SearchOptionKind.uploader,
      description: 'user',
      negation: prefix,
    ),
    const E621ExactNumberOption(
      key: 'user_id',
      description: 'user_id',
      negation: prefix,
    ),
    numericOption(
      'date',
      input: SearchOptionInput.date,
      negation: prefix,
      choices: const [
        SearchOptionChoice('today', 'today'),
        SearchOptionChoice('yesterday', 'yesterday'),
      ],
    ),
    for (final key in ['width', 'height'])
      numericOption(
        key,
        choices: pixelChoices,
        description: 'pixels',
        negation: prefix,
      ),
    numericOption(
      'mpixels',
      input: SearchOptionInput.decimal,
      negation: prefix,
    ),
    const E621RatioOption(),
    const E621FileSizeOption(),
    numericOption(
      'duration',
      input: SearchOptionInput.decimal,
      description: 'seconds',
      negation: prefix,
    ),
    for (final key in ['favcount', 'tagcount', 'change', ...categoryCounts])
      numericOption(
        key,
        choices: countChoices,
        description: 'count',
        negation: prefix,
      ),
    numericOption('comment_count', choices: countChoices, description: 'count'),
    enumOption(
      'status',
      ['active', 'pending', 'modqueue', 'flagged', 'deleted', 'any', 'all'],
      description: 'status',
      negation: prefix,
    ),
    for (final key in ['filetype', 'type'])
      enumOption(
        key,
        ['jpg', 'png', 'gif', 'webm', 'mp4', 'swf'],
        label: 'filetype',
        negation: prefix,
      ),
    enumOption('locked', ['rating', 'note', 'status'], negation: prefix),
    for (final key in [
      'ratinglocked',
      'notelocked',
      'statuslocked',
      'hassource',
      'hasdescription',
      'isparent',
      'ischild',
      'hasparent',
      'haschild',
      'haschildren',
      'inpool',
      'pending_replacements',
      'artverified',
    ])
      enumOption(key, ['true', 'false']),
    for (final key in [
      'approver',
      'deletedby',
      'commenter',
      'comm',
      'noter',
      'noteupdater',
      'fav',
      'favoritedby',
    ])
      textOption(key, description: 'user', negation: prefix),
    for (final key in [
      'flagger',
      'flaggedby',
      'upvote',
      'votedup',
      'upvoted',
      'voteup',
      'downvote',
      'voteddown',
      'downvoted',
      'votedown',
      'voted',
      'vote',
    ])
      textOption(key, description: 'restricted_user', negation: prefix),
    for (final key in [
      'description',
      'note',
      'delreason',
      'flagreason',
      'flagnote',
    ])
      textOption(
        key,
        description: key == 'flagnote' ? 'restricted_user' : 'text',
        negation: prefix,
      ),
    textOption(
      'source',
      description: 'source',
      choices: anyNone,
      negation: prefix,
    ),
    textOption('pool', description: 'pool', choices: anyNone, negation: prefix),
    textOption('set', description: 'set', negation: prefix),
    textOption('search', description: 'saved_search', negation: prefix),
    textOption('md5', description: 'hash'),
    const E621ExactNumberOption(
      key: 'parent',
      description: 'id',
      choices: anyNone,
      negation: prefix,
    ),
    enumOption('child', ['any', 'none']),
    const E621ExactNumberOption(key: 'randseed', description: 'random'),
    const E621ExactNumberOption(
      key: 'limit',
      description: 'limit',
      minimum: 1,
      choices: [
        SearchOptionChoice('20', '20', literal: true),
        SearchOptionChoice('100', '100', literal: true),
      ],
    ),
  ];
}

/// The parser uses safe_id for these fields, not range parsing. Offering
/// comparisons would silently turn some invalid payloads into the wrong ID.
class E621ExactNumberOption extends SearchOption {
  const E621ExactNumberOption({
    required super.key,
    required String description,
    super.choices,
    super.negation,
    this.minimum = 0,
  }) : super(
         kind: SearchOptionKind.metadata,
         input: SearchOptionInput.number,
         labelKey: key,
         descriptionKey: description,
         allowNegative: false,
       );
  final int minimum;
  @override
  bool get isComparable => false;
  @override
  bool accepts(String value) {
    if (choices.any((choice) => choice.value == value)) return true;
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return false;
    final number = int.tryParse(value);
    return number != null && number >= minimum;
  }

  @override
  List<Object?> get props => [...super.props, minimum];
}

/// e621 accepts kb/mb, but gb/k/m would be parsed as a bare number of bytes.
class E621FileSizeOption extends SearchOption {
  const E621FileSizeOption()
    : super(
        kind: SearchOptionKind.metadata,
        key: 'filesize',
        input: SearchOptionInput.filesize,
        labelKey: 'filesize',
        descriptionKey: 'filesize',
        allowRange: true,
        negation: SearchOptionNegation.prefix,
        choices: const [
          SearchOptionChoice('< 1 MB', '<1mb', literal: true),
          SearchOptionChoice('≥ 10 MB', '>=10mb', literal: true),
        ],
      );
  @override
  List<String> get units => const ['b', 'kb', 'mb'];
  @override
  bool accepts(String value) =>
      super.accepts(value) &&
      !RegExp(r'(?:gb|[kmg])(?:\.\.|$)', caseSensitive: false).hasMatch(value);
}

class E621RatioOption extends SearchOption {
  const E621RatioOption()
    : super(
        kind: SearchOptionKind.metadata,
        key: 'ratio',
        input: SearchOptionInput.ratio,
        labelKey: 'ratio',
        allowRange: true,
        negation: SearchOptionNegation.prefix,
        choices: const [
          SearchOptionChoice('16:9', '16:9', literal: true),
          SearchOptionChoice('1:1', '1:1', literal: true),
        ],
      );
  @override
  String? compose(String value, {bool exclude = false}) =>
      super.compose(value.replaceAll('/', ':'), exclude: exclude);
}
