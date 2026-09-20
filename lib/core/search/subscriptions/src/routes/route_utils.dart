// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../router.dart';

Future<void> goToPinnedSearchesPage(WidgetRef ref) =>
    ref.router.push('/pinned-searches');

Future<void> goToFollowingFeedsPage(WidgetRef ref) =>
    ref.router.push('/following-feeds');
