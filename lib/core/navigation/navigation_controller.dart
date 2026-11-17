import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../cache/providers.dart';
import '../configs/manage/providers.dart';
import 'destination_id.dart';
import 'destination_router.dart';
import 'favorites_entry.dart';
import 'navigation_preferences.dart';
import 'navigation_chrome_controller.dart';

final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationPreferences>(
      NavigationController.new,
    );

/// Explicit root ingress also resets a destination's in-page navigation, such
/// as the Bookmark browser's Group state. Ordinary branch switches retain it.
final destinationRootRequestsProvider =
    NotifierProvider<DestinationRootRequests, Map<DestinationId, int>>(
      DestinationRootRequests.new,
    );

class DestinationRootRequests extends Notifier<Map<DestinationId, int>> {
  @override
  Map<DestinationId, int> build() => const {};

  void request(DestinationId id) =>
      state = {...state, id: (state[id] ?? 0) + 1};
}

class NavigationController extends Notifier<NavigationPreferences> {
  DestinationRouterBinding? _binding;
  final bindingChanges = ValueNotifier(0);
  DestinationRouterBinding? get binding => _binding;
  set binding(DestinationRouterBinding? value) {
    if (identical(_binding, value)) return;
    _binding = value;
    bindingChanges.value++;
  }

  var _selecting = false;

  @override
  NavigationPreferences build() {
    ref.onDispose(bindingChanges.dispose);
    final store = ref.read(miscDataStoreProvider);
    var collapsed = <String>{};
    try {
      final data = jsonDecode(
        store.get('navigation.collapsedProfiles') ?? '[]',
      );
      if (data is List) collapsed = data.whereType<String>().toSet();
    } on FormatException {
      /* Ignore malformed preferences, not domain data. */
    }
    return NavigationPreferences(
      lastBrowseProfileId: ref.read(currentBooruConfigProvider).id,
      lastFavoritesProfileId: store.get('navigation.favoritesProfile'),
      collapsedProfileIds: collapsed,
    );
  }

  Future<bool> selectDestination(DestinationId id) async {
    final registry = binding;
    if (registry == null ||
        _selecting ||
        ref.read(navigationChromeProvider).selectionActive) {
      return false;
    }
    if (registry.currentDestination == id) return true;
    _selecting = true;
    try {
      if (!await registry.dismissTransientRoutes()) return false;
      final accepted = registry.select(id);
      if (accepted) ref.read(navigationChromeProvider.notifier).show();
      return accepted;
    } finally {
      _selecting = false;
    }
  }

  Future<bool> openBookmarksHome() => openAppRoot(AppDestination.bookmarks);

  Future<bool> openAppRoot(AppDestination destination) async {
    final id = DestinationId.app(destination);
    final registry = binding;
    if (registry == null || _selecting) return false;
    _selecting = true;
    try {
      final hadSelection = ref.read(navigationChromeProvider).selectionActive;
      var accepted = await registry.openRoot(
        id,
      );
      if (!accepted &&
          hadSelection &&
          !ref.read(navigationChromeProvider).selectionActive) {
        accepted = await registry.openRoot(
          id,
        );
      }
      if (accepted) {
        ref.read(destinationRootRequestsProvider.notifier).request(id);
        // Keep external-ingress content suppression active until the real root
        // browser has replaced its retained Group/search/selection state.
        await WidgetsBinding.instance.endOfFrame;
        ref.read(navigationChromeProvider.notifier).show();
      }
      return accepted;
    } finally {
      _selecting = false;
    }
  }

  Future<bool> selectBrowseProfile(String id) async {
    final config = ref
        .read(booruConfigProvider)
        .where((e) => e.id == id)
        .firstOrNull;
    if (config == null ||
        !(await selectDestination(DestinationId.browse(id)))) {
      return false;
    }
    state = state.selectBrowse(id);
    await ref.read(currentBooruConfigProvider.notifier).update(config);
    return true;
  }

  Future<bool> selectFavoritesProfile(String id, List<String> eligible) async {
    if (!eligible.contains(id) ||
        !(await selectDestination(DestinationId.favorites(id)))) {
      return false;
    }
    state = state.selectFavorites(id);
    await ref
        .read(miscDataStoreProvider)
        .put('navigation.favoritesProfile', id);
    return true;
  }

  DestinationId get browseDestination => switch (state.lastBrowseProfileId) {
    final id?
        when ref.read(booruConfigProvider).any((config) => config.id == id) =>
      DestinationId.browse(id),
    _ => const DestinationId.app(AppDestination.browseRecovery),
  };

  Future<bool> openFavorites(
    List<String> eligible, {
    String? explicitProfileId,
  }) async {
    final entry = resolveFavoritesEntry(
      explicitProfileId: explicitProfileId,
      rememberedProfileId: state.lastFavoritesProfileId,
      eligibleIds: eligible,
    );
    return entry.kind == FavoritesEntryKind.selected
        ? selectFavoritesProfile(entry.profileId!, eligible)
        : selectDestination(
            const DestinationId.app(AppDestination.favoritesRecovery),
          );
  }

  Future<void> toggleProfile(String id) async {
    state = state.toggleProfile(id);
    await ref
        .read(miscDataStoreProvider)
        .put(
          'navigation.collapsedProfiles',
          jsonEncode(state.collapsedProfileIds.toList()),
        );
  }
}
