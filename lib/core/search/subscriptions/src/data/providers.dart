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
  }) : _withOrganization = openBox == null,
       _openBox = openBox ?? _openDefaultBox;

  final Future<Box<SearchSubscriptionHiveObject>> Function() _openBox;
  final bool _withOrganization;
  Future<void> _closeFuture = Future.value();

  Future<void> get closeFuture => _closeFuture;

  @override
  Future<SearchSubscriptionRepository> build() async {
    final previousClose = _closeFuture;
    final resource = _SearchSubscriptionRepositoryBuild(
      _openBox,
      _withOrganization,
    );
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
  _SearchSubscriptionRepositoryBuild(this._openBox, this._withOrganization);

  final Future<Box<SearchSubscriptionHiveObject>> Function() _openBox;
  final bool _withOrganization;
  Box<dynamic>? _organizationBox;
  final _closeCompleter = Completer<void>();
  Box<SearchSubscriptionHiveObject>? _box;
  Future<void>? _closing;
  var _disposed = false;
  var _openingComplete = false;

  Future<SearchSubscriptionRepository> open() async {
    try {
      final box = await _openBox();
      _box = box;
      if (_withOrganization) {
        _organizationBox = await Hive.openBox<dynamic>('pinned_search_folders');
      }
      _openingComplete = true;
      if (_disposed) {
        await _closeBox();
      }
      return HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: _organizationBox,
      );
    } catch (_) {
      _openingComplete = true;
      await _closeBox();
      rethrow;
    }
  }

  Future<void> dispose() {
    _disposed = true;
    if (_openingComplete) {
      unawaited(_closeBox());
    }
    return _closeCompleter.future;
  }

  Future<void> _closeBox() {
    return _closing ??= () async {
      try {
        await _box?.close();
        await _organizationBox?.close();
        _completeClose();
      } catch (error, stackTrace) {
        _closeCompleter.completeError(error, stackTrace);
      }
    }();
  }

  void _completeClose() {
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }
}
