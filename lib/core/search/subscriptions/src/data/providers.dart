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
  Future<void> _closeFuture = Future.value();

  Future<void> get closeFuture => _closeFuture;

  @override
  Future<SearchSubscriptionRepository> build() async {
    final previousClose = _closeFuture;
    final resource = _SearchSubscriptionRepositoryBuild(_openBox);
    ref.onDispose(() {
      _closeFuture = resource.dispose();
    });
    await previousClose;
    return resource.open();
  }

  static Future<Box<SearchSubscriptionHiveObject>> _openDefaultBox() {
    return Hive.openBox<SearchSubscriptionHiveObject>(
      'pinned_search_subscriptions',
    );
  }
}

class _SearchSubscriptionRepositoryBuild {
  _SearchSubscriptionRepositoryBuild(this._openBox);

  final Future<Box<SearchSubscriptionHiveObject>> Function() _openBox;
  final _closeCompleter = Completer<void>();
  Box<SearchSubscriptionHiveObject>? _box;
  Future<void>? _closing;
  var _disposed = false;

  Future<SearchSubscriptionRepository> open() async {
    final box = await _openBox();
    _box = box;
    if (_disposed) {
      await _closeBox();
    }
    return HiveSearchSubscriptionRepository(box: box);
  }

  Future<void> dispose() {
    _disposed = true;
    if (_box != null) {
      unawaited(_closeBox());
    }
    return _closeCompleter.future;
  }

  Future<void> _closeBox() {
    return _closing ??= () async {
      try {
        await _box?.close();
        _closeCompleter.complete();
      } catch (error, stackTrace) {
        _closeCompleter.completeError(error, stackTrace);
      }
    }();
  }
}
