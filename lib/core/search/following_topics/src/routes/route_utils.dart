// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../router.dart';

Future<void> goToFollowingTopicsPage(WidgetRef ref) =>
    ref.router.push('/following-topics');

Future<void> goToTopicFeedsPage(WidgetRef ref) =>
    ref.router.push('/topic-feeds');
