import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../config_widgets/website_logo.dart';
import '../settings/providers.dart';
import 'navigation_drawer_host.dart';
import '../search/following_topics/src/widgets/following_topic_navigation_icon.dart';
import 'destination_id.dart';
import 'destination_definition.dart';
import 'navigation_catalog.dart';
import 'navigation_chrome_controller.dart';
import 'navigation_interaction_scopes.dart';
import 'navigation_overlay_insets.dart';

/// The shell owns chrome only; GoRouter owns every supplied Navigator.
class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({
    required this.navigationShell,
    required this.active,
    required this.catalog,
    required this.browse,
    required this.collapsedProfiles,
    required this.onSelect,
    required this.onFavorites,
    required this.onToggleProfile,
    this.hasNewFollowingPosts = false,
    this.interactionsBlocked = false,
    super.key,
  });
  final bool hasNewFollowingPosts;
  final bool interactionsBlocked;
  final StatefulNavigationShell navigationShell;
  final DestinationId active;
  final DestinationId browse;
  final NavigationCatalog catalog;
  final Set<String> collapsedProfiles;
  final Future<bool> Function(DestinationId) onSelect;
  final Future<bool> Function() onFavorites;
  final ValueChanged<String> onToggleProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(
      navigationChromeProvider.select(
        (s) => (
          menuOpen: s.menuOpen,
          selectionActive: s.selectionActive,
          viewerOpen: s.viewerOpen,
          viewerClosing: s.viewerClosing,
          barVisible: s.barVisible,
        ),
      ),
    );
    final controller = ref.read(navigationChromeProvider.notifier);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    Future<void> select(DestinationId id) async {
      if (chrome.selectionActive) return;
      if (await onSelect(id)) {
        controller.setMenuOpen(false);
      }
    }

    return CallbackShortcuts(
      bindings: {
        if (chrome.menuOpen)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              controller.setMenuOpen(false),
      },
      child: BackButtonListener(
        onBackButtonPressed: () async {
          if (!ref.read(navigationChromeProvider).menuOpen) return false;
          controller.setMenuOpen(false);
          return true;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final bottomExtent = wide
                ? 0.0
                : kNavigationBarHeight +
                      MediaQuery.viewPaddingOf(context).bottom;
            const managementDestinations = {
              AppDestination.settings,
              AppDestination.support,
              AppDestination.donate,
            };
            final generalEntries = catalog.globalEntries
                .where(
                  (entry) =>
                      !managementDestinations.contains(entry.destination),
                )
                .toList();
            final managementEntries = catalog.globalEntries
                .where(
                  (entry) => managementDestinations.contains(entry.destination),
                )
                .toList();
            Widget globalEntry(GlobalNavigationDefinition entry) =>
                entry.isSharedFavorites
                ? ListTile(
                    key: const Key('nav-shared-favorites'),
                    leading: Icon(entry.icon),
                    title: Text(entry.label(context)),
                    selected: active.kind == DestinationKind.favorites,
                    enabled: !chrome.selectionActive,
                    onTap: () async {
                      if (await onFavorites()) controller.setMenuOpen(false);
                    },
                  )
                : _destination(
                    entry.label(context),
                    entry.icon,
                    DestinationId.app(entry.destination!),
                    () => unawaited(
                      select(DestinationId.app(entry.destination!)),
                    ),
                  );
            Widget catalogPanel() => Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                bottom: false,
                child: ListTileTheme(
                  data: ListTileThemeData(
                    dense: true,
                    minTileHeight: 48,
                    minVerticalPadding: 0,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    minLeadingWidth: 24,
                    horizontalTitleGap: 12,
                    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    titleTextStyle: Theme.of(context).textTheme.titleSmall,
                  ),
                  child: ListView(
                    key: const Key('nav-catalog-list'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (wide) ...[
                        _destination(
                          context.t.navigation.browse,
                          Icons.grid_view,
                          browse,
                          () => unawaited(select(browse)),
                        ),
                        _destination(
                          context.t.navigation.following,
                          Icons.rss_feed,
                          const DestinationId.app(AppDestination.following),
                          () => unawaited(
                            select(
                              const DestinationId.app(AppDestination.following),
                            ),
                          ),
                        ),
                        _destination(
                          context.t.navigation.bookmarks,
                          Icons.bookmark,
                          const DestinationId.app(AppDestination.bookmarks),
                          () => unawaited(
                            select(
                              const DestinationId.app(AppDestination.bookmarks),
                            ),
                          ),
                        ),
                        if (catalog.profileSections.isNotEmpty ||
                            generalEntries.isNotEmpty ||
                            managementEntries.isNotEmpty)
                          const Divider(),
                      ],
                      for (final section in catalog.profileSections) ...[
                        Semantics(
                          expanded: !collapsedProfiles.contains(
                            section.profileId,
                          ),
                          child: ListTile(
                            key: ValueKey(
                              'nav-profile-section:${section.profileId}',
                            ),
                            leading: SizedBox.square(
                              dimension: 24,
                              child: ConfigAwareWebsiteLogo(
                                url: section.profileIcon,
                              ),
                            ),
                            title: Text(section.caption),
                            trailing: Icon(
                              collapsedProfiles.contains(section.profileId)
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                            ),
                            onTap: () => onToggleProfile(section.profileId),
                          ),
                        ),
                        if (!collapsedProfiles.contains(section.profileId))
                          for (final tool in section.rows)
                            _destination(
                              tool.label(context),
                              tool.icon,
                              DestinationId.tool(
                                section.profileId,
                                tool.toolId,
                              ),
                              () => unawaited(
                                select(
                                  DestinationId.tool(
                                    section.profileId,
                                    tool.toolId,
                                  ),
                                ),
                              ),
                            ),
                      ],
                      if (catalog.profileSections.isNotEmpty &&
                          (generalEntries.isNotEmpty ||
                              managementEntries.isNotEmpty))
                        const Divider(key: Key('nav-divider-profile-tools')),
                      for (final entry in generalEntries) globalEntry(entry),
                      if (generalEntries.isNotEmpty &&
                          managementEntries.isNotEmpty)
                        const Divider(key: Key('nav-divider-global-tools')),
                      for (final entry in managementEntries) globalEntry(entry),
                    ],
                  ),
                ),
              ),
            );
            final barPositionVisible =
                !keyboard &&
                !chrome.selectionActive &&
                (chrome.menuOpen || chrome.barVisible);
            final viewerCoversBar = chrome.viewerOpen && !chrome.viewerClosing;
            final barShown = barPositionVisible && !viewerCoversBar;
            return PopScope(
              canPop: !chrome.menuOpen && active == browse,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && chrome.menuOpen) {
                  controller.setMenuOpen(false);
                } else if (!didPop &&
                    active != browse &&
                    !chrome.selectionActive) {
                  unawaited(select(browse));
                }
              },
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: SafeArea(
                  top: false,
                  bottom: false,
                  child: Row(
                    children: [
                      if (wide) SizedBox(width: 240, child: catalogPanel()),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            NavigationOverlayInsetsScope(
                              systemMediaQuery: MediaQuery.of(context),
                              extent: bottomExtent,
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  padding: MediaQuery.paddingOf(context)
                                      .copyWith(
                                        bottom:
                                            wide ||
                                                keyboard ||
                                                chrome.selectionActive ||
                                                chrome.viewerOpen
                                            ? MediaQuery.paddingOf(context)
                                                  .bottom
                                            : bottomExtent,
                                      ),
                                  viewPadding: MediaQuery.viewPaddingOf(context)
                                      .copyWith(
                                        bottom:
                                            wide ||
                                                keyboard ||
                                                chrome.selectionActive ||
                                                chrome.viewerOpen
                                            ? MediaQuery.viewPaddingOf(context)
                                                  .bottom
                                            : bottomExtent,
                                      ),
                                ),
                                child: ExcludeFocus(
                                  excluding: !wide && chrome.menuOpen,
                                  child: ExcludeSemantics(
                                    excluding: !wide && chrome.menuOpen,
                                    child: NavigationBarScrollScope(
                                      extent: bottomExtent,
                                      child: navigationShell,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              bottom: bottomExtent,
                              child: NavigationDrawerHost(
                                enabled:
                                    !wide &&
                                    !keyboard &&
                                    !chrome.viewerOpen &&
                                    !chrome.selectionActive &&
                                    !interactionsBlocked &&
                                    (ModalRoute.isCurrentOf(context) ?? true),
                                edgeDragWidth: legacyDrawerEdgeDragWidth(
                                  MediaQuery.widthOf(context),
                                  ref.watch(
                                    settingsProvider.select(
                                      (s) => s.swipeAreaToOpenSidebarPercentage,
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                  width: (constraints.maxWidth - 48).clamp(
                                    240,
                                    280,
                                  ),
                                  child: catalogPanel(),
                                ),
                              ),
                            ),
                            if (!wide)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: bottomExtent,
                                // Keep the timeline position ready as soon as
                                // the viewer starts revealing it again.
                                child: Visibility(
                                  visible: !viewerCoversBar,
                                  maintainState: true,
                                  child: IgnorePointer(
                                    ignoring: !barShown || chrome.viewerOpen,
                                    child: ExcludeFocus(
                                      excluding: !barShown || chrome.viewerOpen,
                                      child: _NavigationBarSlide(
                                        keyboard: keyboard,
                                        child: Material(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainer,
                                          child: SafeArea(
                                            top: false,
                                            child: _NavigationBarFocusScope(
                                              child: Row(
                                                children: [
                                                  _shortcut(
                                                    'browse',
                                                    context.t.navigation.browse,
                                                    Icons.grid_view,
                                                    active.kind ==
                                                            DestinationKind
                                                                .browse ||
                                                        active.appDestination ==
                                                            AppDestination
                                                                .browseRecovery,
                                                    () => unawaited(
                                                      select(browse),
                                                    ),
                                                  ),
                                                  _shortcut(
                                                    'following',
                                                    context
                                                        .t
                                                        .navigation
                                                        .following,
                                                    Icons.rss_feed,
                                                    active.appDestination ==
                                                        AppDestination
                                                            .following,
                                                    () => unawaited(
                                                      select(
                                                        const DestinationId.app(
                                                          AppDestination
                                                              .following,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _shortcut(
                                                    'bookmarks',
                                                    context
                                                        .t
                                                        .navigation
                                                        .bookmarks,
                                                    Icons.bookmark,
                                                    active.appDestination ==
                                                        AppDestination
                                                            .bookmarks,
                                                    () => unawaited(
                                                      select(
                                                        const DestinationId.app(
                                                          AppDestination
                                                              .bookmarks,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _shortcut(
                                                    'menu',
                                                    context.t.navigation.menu,
                                                    Icons.menu,
                                                    chrome.menuOpen,
                                                    () =>
                                                        controller.setMenuOpen(
                                                          !chrome.menuOpen,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _destination(
    String label,
    IconData icon,
    DestinationId id,
    VoidCallback onTap,
  ) => ListTile(
    key: ValueKey('nav-destination:${id.toStorageKey()}'),
    leading: id.appDestination == AppDestination.following
        ? FollowingTopicNavigationIcon(hasNewPosts: hasNewFollowingPosts)
        : Icon(icon),
    title: Text(label),
    selected: active == id,
    onTap: onTap,
  );
  Widget _shortcut(
    String name,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Expanded(
    child: Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey(
          name == 'menu' ? 'nav-menu-toggle' : 'nav-shortcut-$name',
        ),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (name == 'following')
                FollowingTopicNavigationIcon(hasNewPosts: hasNewFollowingPosts)
              else
                Icon(icon, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Only the bar's translation rebuilds for each scroll update.
class _NavigationBarSlide extends ConsumerWidget {
  const _NavigationBarSlide({required this.keyboard, required this.child});

  final bool keyboard;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(navigationChromeProvider);
    final transition = navigationBarTransition(
      chrome: chrome,
      keyboard: keyboard,
      disableAnimations: MediaQuery.disableAnimationsOf(context),
    );
    return AnimatedSlide(
      offset: Offset(0, transition.hiddenFraction),
      duration: transition.duration,
      child: child,
    );
  }
}

/// Arrows stay within the shortcut row; Tab can leave for the destination.
class _NavigationBarFocusScope extends StatefulWidget {
  const _NavigationBarFocusScope({required this.child});
  final Widget child;

  @override
  State<_NavigationBarFocusScope> createState() =>
      _NavigationBarFocusScopeState();
}

class _NavigationBarFocusScopeState extends State<_NavigationBarFocusScope> {
  final _node = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: _node, child: widget.child);
}
