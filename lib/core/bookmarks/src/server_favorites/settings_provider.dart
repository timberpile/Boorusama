import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../../boorus/pixiv/configs/extra_data.dart';
import '../../../boorus/booru/types.dart';
import '../../../cache/misc_data_store.dart';
import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../providers/bookmark_provider.dart';
import 'target_settings.dart';

/// Not a bookmark/profile field: exporting either must not export behavior.
const serverFavoriteSettingsStorageKey = 'server_favorite_targets_v1';

/// Refresh tokens and expiry metadata can rotate without changing the actor.
/// Unknown Pixiv identities retain the stricter credential comparison.
bool serverFavoriteActorMatches(BooruConfig expected, BooruConfig actual) {
  if (expected.id != actual.id) return false;
  final a = expected.auth;
  final b = actual.auth;
  if (a == b) return true;
  if (a.booruType != BooruType.pixiv ||
      b.booruType != BooruType.pixiv ||
      a.booruId != b.booruId ||
      a.url != b.url ||
      a.login != b.login)
    return false;
  final user = PixivExtraData.fromPassHash(a.passHash).userId;
  return user != null &&
      user.isNotEmpty &&
      user == PixivExtraData.fromPassHash(b.passHash).userId;
}

bool serverFavoriteAccountsMatch(
  List<BooruConfig> expected,
  List<BooruConfig> actual,
) =>
    expected.length == actual.length &&
    expected.every(
      (profile) => actual.any(
        (other) => serverFavoriteActorMatches(profile, other),
      ),
    );

final serverFavoriteSettingsProvider =
    AsyncNotifierProvider<
      ServerFavoriteSettingsNotifier,
      ServerFavoriteSettings
    >(
      ServerFavoriteSettingsNotifier.new,
      dependencies: [bookmarkLibraryProvider, booruConfigProvider],
    );

class ServerFavoriteSettingsNotifier
    extends AsyncNotifier<ServerFavoriteSettings> {
  @override
  FutureOr<ServerFavoriteSettings> build() {
    final encoded = ref
        .watch(miscDataStoreProvider)
        .get(serverFavoriteSettingsStorageKey);
    return encoded == null
        ? ServerFavoriteSettings()
        : ServerFavoriteSettings.fromJson(jsonDecode(encoded));
  }

  Future<void> setGlobal(String? groupId) => _update(
    (current) => current.withGlobal(groupId),
    (current, updated) => [groupId],
  );

  Future<void> setProfile(
    String profileId,
    ServerFavoriteTarget target,
  ) => _update(
    (current) {
      if (!ref.read(booruConfigProvider).any((p) => p.id == profileId)) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.accountChanged,
        );
      }
      return current.withProfile(profileId, target);
    },
    (current, updated) => [updated.resolve(profileId)],
  );

  /// Save one dialog's global and profile choices in a single durable write.
  /// Other profiles retain their latest assignments; stale dialogs fail closed.
  Future<void> saveForProfile({
    required BooruConfig profile,
    required ServerFavoriteSettings expected,
    required String? globalGroupId,
    required ServerFavoriteTarget target,
  }) => _update(
    (current) {
      if (!ref
          .read(booruConfigProvider)
          .any(
            (p) => serverFavoriteActorMatches(profile, p),
          )) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.accountChanged,
        );
      }
      if (current.globalGroupId != expected.globalGroupId ||
          current.targetFor(profile.id) != expected.targetFor(profile.id)) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.targetChanged,
        );
      }
      return current.withGlobal(globalGroupId).withProfile(profile.id, target);
    },
    (current, updated) => [
      if (current.globalGroupId != updated.globalGroupId) updated.globalGroupId,
      if (current.targetFor(profile.id) != updated.targetFor(profile.id))
        updated.resolve(profile.id),
    ],
  );

  /// Commit the shared editor atomically, including every profile override.
  Future<void> saveAll({
    required List<BooruConfig> profiles,
    required ServerFavoriteSettings expected,
    required ServerFavoriteSettings updated,
  }) => _update(
    (current) async {
      if (current != expected) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.targetChanged,
        );
      }
      if (!serverFavoriteAccountsMatch(
            profiles,
            ref.read(booruConfigProvider),
          ) ||
          !serverFavoriteAccountsMatch(
            profiles,
            await ref.read(booruConfigRepoProvider).getAll(),
          )) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.accountChanged,
        );
      }
      return updated;
    },
    (current, updated) => [
      if (current.globalGroupId != updated.globalGroupId) updated.globalGroupId,
      for (final profile in profiles)
        if (current.targetFor(profile.id) != updated.targetFor(profile.id))
          updated.resolve(profile.id),
    ],
  );

  Future<void> _update(
    FutureOr<ServerFavoriteSettings> Function(ServerFavoriteSettings) update,
    Iterable<String?> Function(ServerFavoriteSettings, ServerFavoriteSettings)
    groupsToBind,
  ) async {
    final coordinator = ref.read(dataMutationCoordinatorProvider);
    Future<void> commit(bool admitted) => coordinator.runExclusive(() async {
      final current = await future;
      final updated = await update(current);
      final groupIds = groupsToBind(current, updated).nonNulls.toSet();
      if (groupIds.isNotEmpty) {
        if (!admitted) throw const _FavoriteLibraryAdmissionRequired();
        final library = await ref
            .read(bookmarkLibraryProvider.notifier)
            .snapshotForExport();
        for (final groupId in groupIds) {
          validateServerFavoriteBinding(
            groupId: groupId,
            groupIds: library.groupsById.keys.toSet(),
          );
        }
      }
      if (updated == current) return;
      // Assignment only changes local settings. Existing Post and collection
      // memberships, snapshots and dates are never cleared or rewritten here.
      await ref
          .read(miscDataStoreProvider)
          .put(
            serverFavoriteSettingsStorageKey,
            jsonEncode(updated.toJson()),
          );
      // Publish only a successful settings write. Explicit fetch actions are
      // handled by the fetch controller, never by assigning a destination.
      state = AsyncData(updated);
    });
    try {
      // Clearing and disabling remain available when Bookmark storage fails.
      await commit(false);
    } on _FavoriteLibraryAdmissionRequired {
      await ref
          .read(bookmarkLibraryProvider.notifier)
          .runWithLibrary(() => commit(true));
    }
  }
}

final class _FavoriteLibraryAdmissionRequired implements Exception {
  const _FavoriteLibraryAdmissionRequired();
}
