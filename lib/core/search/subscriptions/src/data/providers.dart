// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types/search_subscription_repository.dart';
import 'hive/search_subscription_hive_object.dart';
import 'hive/search_subscription_repository_hive.dart';

final searchSubscriptionRepositoryProvider =
    AsyncNotifierProvider<
      SearchSubscriptionRepositoryNotifier,
      SearchSubscriptionRepository
    >(SearchSubscriptionRepositoryNotifier.new);

class SearchSubscriptionRepositoryNotifier
    extends AsyncNotifier<SearchSubscriptionRepository> {
  SearchSubscriptionRepositoryNotifier({
    Future<Box<SearchSubscriptionHiveObject>> Function()? openBox,
  }) : _openBox = openBox ?? _openDefaultBox;

  final Future<Box<SearchSubscriptionHiveObject>> Function() _openBox;
  final _closeCompleter = Completer<void>();
  Box<SearchSubscriptionHiveObject>? _box;
  var _disposed = false;

  Future<void> get closeFuture => _closeCompleter.future;

  @override
  Future<SearchSubscriptionRepository> build() async {
    ref.onDispose(() {
      _disposed = true;
      final box = _box;
      if (box != null) {
        unawaited(_closeBox(box));
      }
    });

    final box = await _openBox();
    _box = box;
    if (_disposed) {
      await _closeBox(box);
    }
    return HiveSearchSubscriptionRepository(box: box);
  }

  static Future<Box<SearchSubscriptionHiveObject>> _openDefaultBox() {
    return Hive.openBox<SearchSubscriptionHiveObject>(
      'pinned_search_subscriptions',
    );
  }

  Future<void> _closeBox(Box<SearchSubscriptionHiveObject> box) async {
    try {
      await box.close();
      _closeCompleter.complete();
    } catch (error, stackTrace) {
      _closeCompleter.completeError(error, stackTrace);
    }
  }
}
