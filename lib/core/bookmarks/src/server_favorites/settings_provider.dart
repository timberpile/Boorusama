import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../cache/misc_data_store.dart';
import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../providers/bookmark_provider.dart';
import '../data/providers.dart';
import '../services/bookmark_library_service.dart';
import '../types/bookmark_group.dart';
import 'binding.dart';
import 'target_settings.dart';

/// Not a bookmark/profile field: exporting either must not export behavior.
const serverFavoriteSettingsStorageKey = 'server_favorite_targets_v1';

bool serverFavoriteAccountsMatch(
  List<BooruConfig> expected,
  List<BooruConfig> actual,
) =>
    expected.length == actual.length &&
    expected.every(
      (profile) => actual.any(
        (other) => other.id == profile.id && other.auth == profile.auth,
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

  Future<void> setGlobal(
    String? groupId, {
    List<BookmarkGroup> confirmedClears = const [],
  }) => _update(
    (current) => current.withGlobal(groupId),
    (current, updated) => [groupId],
    confirmedClears: confirmedClears,
  );

  Future<void> setProfile(
    String profileId,
    ServerFavoriteTarget target, {
    List<BookmarkGroup> confirmedClears = const [],
  }) => _update(
    (current) {
      if (!ref.read(booruConfigProvider).any((p) => p.id == profileId)) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.accountChanged,
        );
      }
      return current.withProfile(profileId, target);
    },
    (current, updated) => [updated.resolve(profileId)],
    confirmedClears: confirmedClears,
  );

  /// Save one dialog's global and profile choices in a single durable write.
  /// Other profiles retain their latest assignments; stale dialogs fail closed.
  Future<void> saveForProfile({
    required BooruConfig profile,
    required ServerFavoriteSettings expected,
    required String? globalGroupId,
    required ServerFavoriteTarget target,
    List<BookmarkGroup> confirmedClears = const [],
  }) => _update(
    (current) {
      if (!ref
          .read(booruConfigProvider)
          .any(
            (p) => p.id == profile.id && p.auth == profile.auth,
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
    confirmedClears: confirmedClears,
  );

  /// Commit the shared editor atomically, including every profile override.
  Future<void> saveAll({
    required List<BooruConfig> profiles,
    required ServerFavoriteSettings expected,
    required ServerFavoriteSettings updated,
    List<BookmarkGroup> confirmedClears = const [],
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
    confirmedClears: confirmedClears,
  );

  Future<void> _update(
    FutureOr<ServerFavoriteSettings> Function(ServerFavoriteSettings) update,
    Iterable<String?> Function(ServerFavoriteSettings, ServerFavoriteSettings)
    groupsToBind, {
    List<BookmarkGroup> confirmedClears = const [],
  }) => ref.read(dataMutationCoordinatorProvider).runExclusive(() async {
    final current = await future;
    final updated = await update(current);
    final groupIds = groupsToBind(current, updated).nonNulls.toSet();
    var clears = <BookmarkGroup>[];
    if (groupIds.isNotEmpty) {
      final library = await ref
          .read(bookmarkLibraryProvider.notifier)
          .snapshotForExport();
      for (final groupId in groupIds) {
        validateServerFavoriteBinding(
          groupId: groupId,
          groupIds: library.groupsById.keys.toSet(),
        );
      }
      clears = serverFavoriteGroupsToClear(current, updated, library.groups);
      if (clears.any((group) => !confirmedClears.contains(group))) {
        throw const ServerFavoriteException(
          ServerFavoriteProblem.confirmationRequired,
        );
      }
    }
    if (updated == current) return;
    Future<void> persist() => ref
        .read(miscDataStoreProvider)
        .put(
          serverFavoriteSettingsStorageKey,
          jsonEncode(updated.toJson()),
        );
    if (clears.isEmpty) {
      await persist();
    } else {
      final bookmarks = ref.read(bookmarkLibraryProvider.notifier);
      await bookmarks.runSerializedMutation(() async {
        final service = BookmarkLibraryService(
          bookmarkRepository: await bookmarks.bookmarkRepository,
          groupRepository: await ref.read(bookmarkGroupRepoProvider.future),
          imageUrlResolver: (id) => ref.read(bookmarkUrlResolverProvider(id)),
        );
        final snapshot = await service.load();
        final removals = <BookmarkGroupRemovalResult>[];
        try {
          for (final group in clears) {
            // Recheck durable contents before any destructive work.
            if (snapshot.groupsById[group.id] != group) {
              throw const ServerFavoriteException(
                ServerFavoriteProblem.confirmationRequired,
              );
            }
          }
          for (final group in clears) {
            removals.add(
              await service.removeBookmarksFromGroup(
                snapshot.items.where((b) => group.bookmarkIds.contains(b.id)),
                group.id,
              ),
            );
          }
          await persist();
        } catch (error, stack) {
          final rollbackErrors = <Object>[];
          for (final removal in removals.reversed) {
            try {
              await service.undoRemoval(removal);
            } catch (failure) {
              rollbackErrors.add(failure);
            }
          }
          if (rollbackErrors.isNotEmpty) {
            throw BookmarkLibraryRollbackException(
              operationError: error,
              rollbackErrors: rollbackErrors,
            );
          }
          Error.throwWithStackTrace(error, stack);
        }
      });
    }
    // Only explicitly confirmed first bindings clear content. Shared groups and
    // all other assignment changes preserve membership; nothing starts a fetch.
    state = AsyncData(updated);
  });
}
