// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types/following_topic_repository.dart';
import 'hive/following_topic_hive_object.dart';
import 'hive/following_topic_repository_hive.dart';
import '../compatibility/topic_storage_contract.dart';

final followingTopicRepositoryProvider =
    AsyncNotifierProvider<
      FollowingTopicRepositoryNotifier,
      FollowingTopicRepository
    >(FollowingTopicRepositoryNotifier.new);

class FollowingTopicRepositoryNotifier
    extends AsyncNotifier<FollowingTopicRepository> {
  FollowingTopicRepositoryNotifier({
    Future<Box<FollowingTopicHiveObject>> Function()? openBox,
  }) : _withOrganization = openBox == null,
       _openBox = openBox ?? _openDefaultBox;

  final Future<Box<FollowingTopicHiveObject>> Function() _openBox;
  final bool _withOrganization;
  Future<void> _closeFuture = Future.value();

  Future<void> get closeFuture => _closeFuture;

  @override
  Future<FollowingTopicRepository> build() async {
    final previousClose = _closeFuture;
    final resource = _FollowingTopicRepositoryBuild(
      _openBox,
      _withOrganization,
    );
    ref.onDispose(() {
      _closeFuture = resource.dispose();
    });
    await previousClose;
    return resource.open();
  }

  static Future<Box<FollowingTopicHiveObject>> _openDefaultBox() {
    return Hive.openBox<FollowingTopicHiveObject>(
      followingTopicsBoxName,
    );
  }
}

class _FollowingTopicRepositoryBuild {
  _FollowingTopicRepositoryBuild(this._openBox, this._withOrganization);

  final Future<Box<FollowingTopicHiveObject>> Function() _openBox;
  final bool _withOrganization;
  Box<dynamic>? _organizationBox;
  final _closeCompleter = Completer<void>();
  Box<FollowingTopicHiveObject>? _box;
  Future<void>? _closing;
  var _disposed = false;
  var _openingComplete = false;

  Future<FollowingTopicRepository> open() async {
    try {
      final box = await _openBox();
      _box = box;
      if (_withOrganization) {
        _organizationBox = await Hive.openBox<dynamic>(
          topicOrganizationBoxName,
        );
      }
      _openingComplete = true;
      if (_disposed) {
        await _closeBox();
      }
      return HiveFollowingTopicRepository(
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
