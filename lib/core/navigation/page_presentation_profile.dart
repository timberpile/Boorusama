import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';
import '../configs/manage/providers.dart';

/// Null is a genuinely global presentation, not an anonymous source account.
final pagePresentationProfileProvider = Provider<BooruConfig?>(
  (ref) => ref.watch(currentReadOnlyBooruConfigProvider),
  dependencies: [currentReadOnlyBooruConfigProvider],
);
