// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/boorus/e621/artists/providers.dart';
import 'package:boorusama/boorus/e621/artists/types.dart';
import 'package:boorusama/boorus/szurubooru/post_votes/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';

void main() {
  testWidgets('E621 artist data follows the profile scoped to the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          e621ArtistRepoProvider(_e621Config.auth).overrideWithValue(
            _E621ArtistRepository(),
          ),
        ],
        child: CurrentBooruConfigScope(
          config: _globalConfig,
          child: CurrentBooruConfigScope(
            config: _e621Config,
            child: Consumer(
              builder: (context, ref, _) => MaterialApp(
                home: Scaffold(
                  body: ref
                      .watch(e621ArtistProvider('artist'))
                      .when(
                        data: (artist) => Text(artist.name),
                        error: (error, stackTrace) => Text('$error'),
                        loading: () => const CircularProgressIndicator(),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('artist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Szurubooru votes follow the profile scoped to the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: CurrentBooruConfigScope(
          config: _globalConfig,
          child: CurrentBooruConfigScope(
            config: _szurubooruConfig,
            child: Consumer(
              builder: (context, ref, _) {
                final vote = ref.watch(szurubooruPostVoteProvider(1));
                return MaterialApp(
                  home: Scaffold(body: Text(vote?.score.toString() ?? 'none')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('none'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _E621ArtistRepository implements E621ArtistRepository {
  @override
  Future<Option<E621Artist>> getArtist(String name) async => some(
    E621Artist(name: name, otherNames: const []),
  );
}

final _globalConfig = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://global.example',
  customDownloadFileNameFormat: null,
);

final _e621Config = BooruConfig.defaultConfig(
  booruType: BooruType.e621,
  url: 'https://e621.example',
  customDownloadFileNameFormat: null,
);

final _szurubooruConfig = BooruConfig.defaultConfig(
  booruType: BooruType.szurubooru,
  url: 'https://szurubooru.example',
  customDownloadFileNameFormat: null,
);
