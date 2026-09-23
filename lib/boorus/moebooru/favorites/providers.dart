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

var _cancelToken = CancelToken();

class MoebooruFavoritesNotifier extends FamilyNotifier<Set<String>?, int> {
  late BooruConfigAuth _config;

  @override
  Set<String>? build(int arg) {
    _config = ref.watchConfigAuth;
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
