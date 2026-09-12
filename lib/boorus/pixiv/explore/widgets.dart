// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/explores/types.dart';
import '../../../core/posts/explores/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../configs/extra_data.dart';
import '../posts/types.dart';
import 'feed.dart';
import 'providers.dart';

/// Pixiv's Explore page: a feed selector (Ranking / Following /
/// Recommended) over a shared post grid.
///
/// Ranking is the pre-made popularity feed — day/week/month plus the male,
/// female, rookie, AI and manga variants, and the R-18/R-18G set — stepping
/// back and forward through pixiv's per-day ranking snapshots. A true
/// rolling 24h window is not offered by the API: the ranking is an
/// immutable per-JST-day snapshot, so "day" here means the whole of one
/// JST calendar day, not a trailing 24 hours.
class PixivExplorePage extends ConsumerStatefulWidget {
  const PixivExplorePage({super.key});

  @override
  ConsumerState<PixivExplorePage> createState() => _PixivExplorePageState();
}

class _PixivExplorePageState extends ConsumerState<PixivExplorePage> {
  final _feed = ValueNotifier<PixivExploreFeed>(
    PixivRankingFeed(
      mode: PixivRankingMode.day,
      date: pixivRankingNewestDate(),
    ),
  );

  // The floating header's content (feed selector, warning banner, mode
  // picker) changes height depending on the feed and account state, so its
  // `SliverAppBar.bottom` height is measured rather than hardcoded — see
  // `_PixivExploreSliverAppBar`.
  final _headerHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _feed.dispose();
    _headerHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigAuth;
    final accountXRestrict = PixivExtraData.fromPassHash(
      config.passHash,
    ).xRestrict;

    return Scaffold(
      body: PostScope<PixivPost>(
        fetcher: (page) => ref
            .read(pixivExploreRepoProvider(config))
            .getPosts(
              feed: _feed.value,
              page: page,
            ),
        // `top: false` because the SliverAppBar in `sliverHeaders` already
        // covers the status bar itself, and `safeArea: false` on the grid
        // so the grid itself still paints to the edges. Without this,
        // controls pinned below the grid render underneath Android's
        // system navigation bar in edge-to-edge mode. Mirrors Danbooru's
        // explore page.
        builder: (context, controller) => SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: PostGrid(
                  controller: controller,
                  safeArea: false,
                  sliverHeaders: [
                    _PixivExploreSliverAppBar(
                      feed: _feed,
                      headerHeight: _headerHeight,
                      accountXRestrict: accountXRestrict,
                      onFeedKindChanged: (kind) {
                        _feed.value = pixivDefaultFeedFor(
                          kind,
                          current: _feed.value,
                          newestRankingDate: pixivRankingNewestDate(),
                        );
                        controller.refresh();
                      },
                      onControlsChanged: () => controller.refresh(),
                    ),
                  ],
                ),
              ),
              // The date stepper is meaningless outside Ranking and stays
              // pinned at the bottom, outside the scrolling grid — it does
              // not float away with the header.
              ValueListenableBuilder(
                valueListenable: _feed,
                builder: (context, feed, _) => switch (feed) {
                  PixivRankingFeed() => _RankingDateStepper(
                    feed: _feed,
                    onChanged: () => controller.refresh(),
                  ),
                  PixivFollowingFeed() ||
                  PixivRecommendedFeed() => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Explore page's floating header: title, feed selector, X-restrict
/// warning and the Ranking-only mode picker, all attached via
/// `SliverAppBar.bottom` so they float away and back together with the
/// title on scroll.
///
/// The bottom content's height varies — the mode picker is absent for
/// Following/Recommended, and the warning banner only shows sometimes — so
/// rather than hardcoding a height, [KurumiMeasureSize] measures the
/// actual rendered content and feeds it back into [headerHeight], which
/// then sizes `SliverAppBar.bottom`'s `PreferredSize`.
class _PixivExploreSliverAppBar extends StatelessWidget {
  const _PixivExploreSliverAppBar({
    required this.feed,
    required this.headerHeight,
    required this.accountXRestrict,
    required this.onFeedKindChanged,
    required this.onControlsChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final ValueNotifier<double> headerHeight;
  final int? accountXRestrict;
  final ValueChanged<PixivExploreFeedKind> onFeedKindChanged;
  final VoidCallback onControlsChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: headerHeight,
      builder: (context, height, _) => SliverAppBar(
        title: Text(context.t.pixiv.explore.title),
        floating: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(height),
          child: KurumiMeasureSize(
            onChange: (size) {
              if (size.height != headerHeight.value) {
                headerHeight.value = size.height;
              }
            },
            child: _HeaderControls(
              feed: feed,
              accountXRestrict: accountXRestrict,
              onFeedKindChanged: onFeedKindChanged,
              onControlsChanged: onControlsChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderControls extends StatelessWidget {
  const _HeaderControls({
    required this.feed,
    required this.accountXRestrict,
    required this.onFeedKindChanged,
    required this.onControlsChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final int? accountXRestrict;
  final ValueChanged<PixivExploreFeedKind> onFeedKindChanged;
  final VoidCallback onControlsChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: feed,
      builder: (context, value, _) {
        final warn = pixivShouldWarnXRestrict(value, accountXRestrict);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: _FeedSelector(
                feed: feed,
                onChanged: onFeedKindChanged,
              ),
            ),
            if (warn)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: KurumiWarningContainer(
                  title: context.t.generic.warning,
                  contentBuilder: (context) => Text(
                    context.t.pixiv.explore.x_restrict_warning,
                  ),
                ),
              ),
            switch (value) {
              PixivRankingFeed() => _RankingModePicker(
                feed: feed,
                onChanged: onControlsChanged,
              ),
              PixivFollowingFeed() => _FollowingControls(
                feed: feed,
                onChanged: onControlsChanged,
              ),
              PixivRecommendedFeed() => const SizedBox.shrink(),
            },
          ],
        );
      },
    );
  }
}

class _FeedSelector extends StatelessWidget {
  const _FeedSelector({
    required this.feed,
    required this.onChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final ValueChanged<PixivExploreFeedKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder(
        valueListenable: feed,
        builder: (context, value, _) =>
            KurumiSegmentedButton<PixivExploreFeedKind>(
              initialValue: pixivExploreFeedKindOf(value),
              segments: {
                PixivExploreFeedKind.ranking:
                    context.t.pixiv.explore.feed.ranking,
                PixivExploreFeedKind.following:
                    context.t.pixiv.explore.feed.following,
                PixivExploreFeedKind.recommended:
                    context.t.pixiv.explore.feed.recommended,
              },
              onChanged: onChanged,
            ),
      ),
    );
  }
}

/// The mode dropdown — meaningless outside the Ranking feed, so this
/// widget only ever appears while [feed] holds a [PixivRankingFeed]. Floats
/// in the header alongside the feed selector; the date stepper for this
/// same feed is rendered separately, pinned at the bottom of the page.
class _RankingModePicker extends StatelessWidget {
  const _RankingModePicker({
    required this.feed,
    required this.onChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: feed,
      builder: (context, value, _) {
        final ranking = value as PixivRankingFeed;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: KurumiOptionDropDownButton<PixivRankingMode>(
            value: ranking.mode,
            alignment: AlignmentDirectional.centerStart,
            onChanged: (mode) {
              if (mode == null) return;

              feed.value = ranking.copyWith(mode: mode);
              onChanged();
            },
            items: [
              for (final mode in PixivRankingMode.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(pixivRankingModeLabel(context, mode)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The date stepper for the Ranking feed, pinned at the bottom of the
/// page, outside the scrolling grid — unlike the rest of the Explore
/// controls, it does not float away with the header.
class _RankingDateStepper extends StatelessWidget {
  const _RankingDateStepper({
    required this.feed,
    required this.onChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: feed,
      builder: (context, value, _) {
        final ranking = value as PixivRankingFeed;
        final newestDate = pixivRankingNewestDate();

        return DateTimeSelector(
          date: ranking.date,
          scale: _timeScaleOf(ranking.mode),
          backgroundColor: Colors.transparent,
          firstDate: kPixivRankingEarliestDate,
          lastDate: newestDate,
          onDateChanged: (newDate) {
            final clamped = clampPixivRankingDate(newDate);
            feed.value = ranking.copyWith(date: clamped);
            onChanged();
          },
        );
      },
    );
  }
}

/// The day/week/month step size the date stepper should use for [mode] —
/// month-scoped modes step by month, everything else steps by day (pixiv
/// has no week-stepping ranking mode outside `week*`, and even those are
/// still daily snapshots, just tallied over a trailing week).
TimeScale _timeScaleOf(PixivRankingMode mode) =>
    mode == PixivRankingMode.month ? TimeScale.month : TimeScale.day;

class _FollowingControls extends StatelessWidget {
  const _FollowingControls({
    required this.feed,
    required this.onChanged,
  });

  final ValueNotifier<PixivExploreFeed> feed;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: feed,
      builder: (context, value, _) {
        final following = value as PixivFollowingFeed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: KurumiSegmentedButton<PixivFollowRestrict>(
              initialValue: following.restrict,
              segments: {
                PixivFollowRestrict.all:
                    context.t.pixiv.explore.follow_restrict.all,
                PixivFollowRestrict.public:
                    context.t.pixiv.explore.follow_restrict.public,
                PixivFollowRestrict.private:
                    context.t.pixiv.explore.follow_restrict.private,
              },
              onChanged: (restrict) {
                feed.value = following.copyWith(restrict: restrict);
                onChanged();
              },
            ),
          ),
        );
      },
    );
  }
}

/// pxview's wording for each ranking mode.
String pixivRankingModeLabel(BuildContext context, PixivRankingMode mode) {
  final t = context.t.pixiv.explore.ranking_mode;

  return switch (mode) {
    PixivRankingMode.day => t.day,
    PixivRankingMode.week => t.week,
    PixivRankingMode.month => t.month,
    PixivRankingMode.dayMale => t.day_male,
    PixivRankingMode.dayFemale => t.day_female,
    PixivRankingMode.weekOriginal => t.week_original,
    PixivRankingMode.weekRookie => t.week_rookie,
    PixivRankingMode.dayManga => t.day_manga,
    PixivRankingMode.weekManga => t.week_manga,
    PixivRankingMode.monthManga => t.month_manga,
    PixivRankingMode.weekRookieManga => t.week_rookie_manga,
    PixivRankingMode.dayAi => t.day_ai,
    PixivRankingMode.dayR18 => t.day_r18,
    PixivRankingMode.dayR18Ai => t.day_r18_ai,
    PixivRankingMode.dayMaleR18 => t.day_male_r18,
    PixivRankingMode.dayFemaleR18 => t.day_female_r18,
    PixivRankingMode.dayR18Manga => t.day_r18_manga,
    PixivRankingMode.weekR18 => t.week_r18,
    PixivRankingMode.weekR18Manga => t.week_r18_manga,
    PixivRankingMode.weekR18g => t.week_r18g,
    PixivRankingMode.weekR18gManga => t.week_r18g_manga,
  };
}
