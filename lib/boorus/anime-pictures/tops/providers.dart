// Package imports:
import 'package:booru_clients/anime_pictures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../client_provider.dart';
import '../posts/parser.dart';
import '../posts/types.dart';

typedef TopParams = ({BooruConfig config, bool erotic});

class EroticModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void updateValue(bool value) {
    state = value;
  }
}

final eroticOnProvider = NotifierProvider<EroticModeNotifier, bool>(
  EroticModeNotifier.new,
);

final animePicturesDailyPopularProvider = FutureProvider.autoDispose
    .family<List<Post>, TopParams>((ref, params) {
      final config = params.config;
      final erotic = params.erotic;

      final client = ref.watch(animePicturesClientProvider(config.auth));
      final origin = postOriginFromConfig(config);

      return client
          .getTopPosts(length: TopLength.day, erotic: erotic)
          .then(
            (value) => bindPostsOrigin(
              value.map(dtoToAnimePicturesPost),
              origin: origin,
            ),
          );
    });

final animePicturesWeeklyPopularProvider = FutureProvider.autoDispose
    .family<List<Post>, TopParams>((ref, params) {
      final config = params.config;
      final erotic = params.erotic;
      final client = ref.watch(animePicturesClientProvider(config.auth));
      final origin = postOriginFromConfig(config);

      return client
          .getTopPosts(length: TopLength.week, erotic: erotic)
          .then(
            (value) => bindPostsOrigin(
              value.map(dtoToAnimePicturesPost),
              origin: origin,
            ),
          );
    });
