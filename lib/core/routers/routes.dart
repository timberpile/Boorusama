// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../blacklists/routes.dart';
import '../bookmarks/routes.dart';
import '../boorus/engine/providers.dart';
import '../bulk_downloads/routes.dart';
import '../changelogs/routes.dart';
import '../configs/config/providers.dart';
import '../configs/config/types.dart';
import '../configs/manage/widgets.dart';
import '../configs/create/routes.dart';
import '../debug/routes.dart';
import '../donate/routes.dart';
import '../download_manager/routes.dart';
import '../posts/details/routes.dart';
import '../posts/cross_profile_lookup/page.dart';
import '../posts/links/boorusama_post_link_page.dart';
import '../posts/details_manager/routes.dart';
import '../posts/favorites/routes.dart';
import '../posts/post/routes.dart';
import '../premiums/routes.dart';
import '../router.dart';
import '../search/search/routes.dart';
import '../search/following_topics/routes.dart';
import '../settings/routes.dart';
import '../tags/favorites/routes.dart';

///
/// When navigate to a page, must query the booru builders first to get the correct builder.
/// There is case when you want navigate to a different boorus than the current one.
///
///```dart
/// final config = ref.read(currentBooruConfigProvider);
/// final booruBuilderFunc =
///     ref.read(booruBuildersProvider)[config.booruType];
/// final booruBuilder =
///     booruBuilderFunc != null ? booruBuilderFunc(config) : null;
///
/// // Or you can use this
/// final booruBuilder = ref.readBooruBuilder(config);
///```
///

const kInitialQueryKey = 'query';
const kArtistNameKey = 'name';
const kCharacterNameKey = 'name';

class Routes {
  static List<GoRoute> features(Ref ref) => [
    addBooruConfigRoutes(ref),
    updateBooruConfigRoutes(ref),
    searchRoutes(ref),
    postDetailsRoutes(ref),
    singlePostDetailsRoutes(ref),
    boorusamaPostLinkRoute(),
    crossProfileLookupRoute(),
    lazyPostDetailsRoutes(ref),
    postFavoritesRoutes(ref),
    artists(ref),
    characters(ref),
    settingsRoutes,
    settingsDesktopRoutes,
    bookmarkRoutes,
    followingTopicRoutes,
    topicFeedRoutes,
    ...legacyFollowingTopicRoutes,
    globalBlacklistedTagsRoutes,
    downloadManagerRoutes,
    bulkDownloadsRoutes,
    favoriteTags(),
    originalImageRoutes,
    premiumRoutes(ref),
    donationRoutes(ref),
    detailsManagerRoutes,
    changelogRoutes,
    debuglogRoutes,
  ];

  static GoRoute artists(Ref ref) => GoRoute(
    path: 'artists',
    name: '/artists',
    pageBuilder: largeScreenAwarePageBuilder(
      builder: (context, state) {
        final page = InheritedArtistName(
          artistName: state.uri.queryParameters[kArtistNameKey],
          child: const ArtistPage(),
        );
        return switch (state.extra) {
          final BooruConfig config => CurrentBooruConfigScope(
            config: config,
            child: page,
          ),
          _ => page,
        };
      },
    ),
  );

  static GoRoute characters(Ref ref) => GoRoute(
    path: 'characters',
    name: '/characters',
    pageBuilder: largeScreenAwarePageBuilder(
      builder: (context, state) {
        final page = InheritedCharacterName(
          characterName: state.uri.queryParameters[kCharacterNameKey],
          child: const CharacterPage(),
        );
        return switch (state.extra) {
          final BooruConfig config => CurrentBooruConfigScope(
            config: config,
            child: page,
          ),
          _ => page,
        };
      },
    ),
  );
}

class ArtistPage extends ConsumerWidget {
  const ArtistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final builder = booruBuilder?.artistPageBuilder;
    final artistName = InheritedArtistName.of(context)?.artistName;

    return builder != null
        ? artistName != null
              ? builder(context, artistName)
              : const InvalidPage(message: 'Invalid artist name')
        : const UnimplementedPage();
  }
}

class InheritedArtistName extends InheritedWidget {
  const InheritedArtistName({
    required this.artistName,
    required super.child,
    super.key,
  });

  final String? artistName;

  static InheritedArtistName? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedArtistName>();
  }

  @override
  bool updateShouldNotify(InheritedArtistName oldWidget) {
    return artistName != oldWidget.artistName;
  }
}

class CharacterPage extends ConsumerWidget {
  const CharacterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final builder = booruBuilder?.characterPageBuilder;
    final characterName = InheritedCharacterName.of(context)?.characterName;

    return builder != null
        ? characterName != null
              ? builder(context, characterName)
              : const InvalidPage(message: 'Invalid character name')
        : const UnimplementedPage();
  }
}

class InheritedCharacterName extends InheritedWidget {
  const InheritedCharacterName({
    required this.characterName,
    required super.child,
    super.key,
  });

  final String? characterName;

  static InheritedCharacterName? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedCharacterName>();
  }

  @override
  bool updateShouldNotify(InheritedCharacterName oldWidget) {
    return characterName != oldWidget.characterName;
  }
}
