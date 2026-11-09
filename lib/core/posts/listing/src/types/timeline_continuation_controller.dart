import 'package:flutter/foundation.dart';

import 'page_mode.dart';

/// Shared viewport continuation contract for Post and native Group timelines.
/// Layout caching remains independent from the page-fetch budget.
abstract interface class TimelineContinuationController implements Listenable {
  bool get refreshing;
  bool get hasMore;
  bool get loadingMore;
  ValueListenable<Object?> get errors;
  PageMode get pageMode;
  Future<void> fetchMore({bool Function()? canStart});
}
