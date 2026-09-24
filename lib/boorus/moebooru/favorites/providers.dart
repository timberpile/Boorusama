// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/configs/manage/providers.dart';
import '../client_provider.dart';

final moebooruFavoritesProvider =
    NotifierProvider.family<MoebooruFavoritesNotifier, Set<String>?, int>(
      MoebooruFavoritesNotifier.new,
      dependencies: [currentReadOnlyBooruConfigAuthProvider],
    );

class MoebooruFavoritesNotifier extends FamilyNotifier<Set<String>?, int> {
  late BooruConfigAuth _config;
  var _cancelToken = CancelToken();

  @override
  Set<String>? build(int arg) {
    _config = ref.watchConfigAuth;
    ref.onDispose(() => _cancelToken.cancel());
    return null;
  }

  void clear() {
    state = null;
    loadFavoriteUsers();
  }

  Future<void> loadFavoriteUsers() async {
    if (state != null) {
      return;
    }

    // Cancel the previous request before making a new one
    _cancelToken.cancel();

    // Create a new CancelToken for the new request
    _cancelToken = CancelToken();

    try {
      final client = ref.read(moebooruClientProvider(_config));

      final users = await client.getFavoriteUsers(
        postId: arg,
        cancelToken: _cancelToken,
      );

      state = users;
    } catch (e) {
      state = null;
    }
  }
}
