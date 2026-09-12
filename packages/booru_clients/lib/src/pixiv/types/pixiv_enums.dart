/// Ranking mode, mapped to the API's wire string via [value].
///
/// [minimumXRestrict] is the account's `x_restrict` level required to use a
/// mode: 0 (general only), 1 (R-18 permitted) or 2 (R-18G permitted).
enum PixivRankingMode {
  day('day'),
  week('week'),
  month('month'),
  dayMale('day_male'),
  dayFemale('day_female'),
  weekOriginal('week_original'),
  weekRookie('week_rookie'),
  dayManga('day_manga'),
  weekManga('week_manga'),
  monthManga('month_manga'),
  weekRookieManga('week_rookie_manga'),
  dayAi('day_ai'),
  dayR18('day_r18'),
  dayR18Ai('day_r18_ai'),
  dayMaleR18('day_male_r18'),
  dayFemaleR18('day_female_r18'),
  dayR18Manga('day_r18_manga'),
  weekR18('week_r18'),
  weekR18Manga('week_r18_manga'),
  weekR18g('week_r18g'),
  weekR18gManga('week_r18g_manga');

  const PixivRankingMode(this.value);

  final String value;

  /// The `x_restrict` level required to use this mode: 0 (general), 1
  /// (R-18) or 2 (R-18G).
  int get minimumXRestrict => switch (this) {
    PixivRankingMode.weekR18g || PixivRankingMode.weekR18gManga => 2,
    PixivRankingMode.dayR18 ||
    PixivRankingMode.dayR18Ai ||
    PixivRankingMode.dayMaleR18 ||
    PixivRankingMode.dayFemaleR18 ||
    PixivRankingMode.dayR18Manga ||
    PixivRankingMode.weekR18 ||
    PixivRankingMode.weekR18Manga => 1,
    _ => 0,
  };
}

/// `restrict` parameter for `/v2/illust/follow` — whether the *follow
/// relationship* is public or private, not the artwork itself.
enum PixivFollowRestrict {
  all('all'),
  public('public'),
  private('private');

  const PixivFollowRestrict(this.value);

  final String value;
}

/// `search_target` parameter for `/v1/search/illust`.
enum PixivSearchTarget {
  partialMatchForTags('partial_match_for_tags'),
  exactMatchForTags('exact_match_for_tags'),
  titleAndCaption('title_and_caption');

  const PixivSearchTarget(this.value);

  final String value;
}

/// `sort` parameter for `/v1/search/illust`. `popularDesc` requires Premium.
enum PixivSearchSort {
  dateDesc('date_desc'),
  dateAsc('date_asc'),
  popularDesc('popular_desc');

  const PixivSearchSort(this.value);

  final String value;
}
