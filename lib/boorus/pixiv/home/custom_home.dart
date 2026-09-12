// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../core/home/types.dart';
import '../explore/widgets.dart';

/// The Explore page offered as an alternate home view — a feed selector
/// (Ranking / Following / Recommended) over a shared post grid. Not the
/// default: most users land on the regular search/browse feed, with
/// Explore as an opt-in alternative.
final pixivCustomHome = {
  ...kDefaultAltHomeView,
  const CustomHomeViewKey('explore'): CustomHomeDataBuilder(
    displayName: (context) => context.t.pixiv.explore.title,
    builder: (context, _) => const PixivExplorePage(),
  ),
};
