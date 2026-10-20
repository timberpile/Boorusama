import 'dart:async';

import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/legacy_navigation_bridge.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/videos/engines/types.dart';
import 'package:boorusama/core/videos/player/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Player implements BooruPlayer {
  var plays = 0;
  var pauses = 0;
  @override
  var isPlaying = false;
  @override
  Future<void> play() async {
    isPlaying = true;
    plays++;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    pauses++;
  }

  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LatePlayer extends _Player {
  final initialized = Completer<void>();
  @override
  Future<void> play() async {
    await initialized.future;
    await super.play();
  }
}

void main() {
  test(
    'native play completion cannot restart a suspended destination',
    () async {
      final manager = VideoPlaybackManager();
      addTearDown(manager.dispose);
      final player = _LatePlayer();
      manager.registerPlayer(player, 'late');
      await manager.playVideo('late');
      manager.setActive(false);
      player.initialized.complete();
      await player.initialized.future;
      await Future<void>.value();
      await Future<void>.value();
      expect(player.isPlaying, isFalse);
      manager.setActive(true);
      await Future<void>.value();
      await Future<void>.value();
      expect(player.isPlaying, isTrue);
    },
  );
  test('scroll hysteresis ignores bounce/noise and selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final chrome = container.read(navigationChromeProvider.notifier);
    void scroll(double delta, {double pixels = 100, bool outOfRange = false}) =>
        chrome.userScroll(delta: delta, pixels: pixels, outOfRange: outOfRange);
    scroll(23);
    expect(container.read(navigationChromeProvider).barVisible, isTrue);
    scroll(1);
    expect(container.read(navigationChromeProvider).barVisible, isFalse);
    scroll(-11);
    expect(container.read(navigationChromeProvider).barVisible, isFalse);
    scroll(-1);
    expect(container.read(navigationChromeProvider).barVisible, isTrue);
    scroll(100, outOfRange: true);
    expect(container.read(navigationChromeProvider).barVisible, isTrue);
    chrome.setSelection(true);
    scroll(100);
    expect(container.read(navigationChromeProvider).barVisible, isTrue);
    chrome.setSelection(false);
    scroll(100);
    scroll(-2, pixels: 8);
    expect(container.read(navigationChromeProvider).barVisible, isTrue);
  });
  test('suspended native player cannot honor late pending playback', () async {
    final manager = VideoPlaybackManager();
    addTearDown(manager.dispose);
    await manager.playVideo('one');
    manager.setActive(false);
    final player = _Player();
    manager.registerPlayer(player, 'one');
    expect(player.plays, 0);
    expect(player.isPlaying, isFalse);
    manager.setActive(true);
    expect(player.plays, 1);
    manager.setActive(false);
    expect(player.isPlaying, isFalse);
    await manager.pauseVideo('one');
    manager.setActive(true);
    expect(player.plays, 1);
  });
  test(
    'navigation setting migrates by default and persists explicit false',
    () {
      final old = Settings.defaultSettings.toJson()
        ..remove('autoHideMainNavigation');
      expect(Settings.fromJson(old).autoHideMainNavigation, isTrue);
      final settings = Settings.defaultSettings.copyWith(
        autoHideMainNavigation: false,
      );
      expect(
        Settings.fromJson(settings.toJson()).autoHideMainNavigation,
        isFalse,
      );
    },
  );
  test('legacy aliases preserve query and independent explicit owners', () {
    const a = DestinationId.browse('a');
    final destinations = [
      a,
      const DestinationId.browse('b'),
      const DestinationId.favorites('b'),
      const DestinationId.tool('b', 'danbooru.pools'),
      for (final id in AppDestination.values) DestinationId.app(id),
    ];
    String resolve(String path) => resolveLegacyNavigation(
      path,
      browse: a,
      destinations: destinations,
      favoritesProfileId: 'b',
    );
    expect(
      Uri.parse(resolve('/danbooru/pools?cid=b')).path,
      const DestinationId.tool('b', 'danbooru.pools').location,
    );
    for (final path in [
      '/following-topics',
      '/topic-feeds',
      '/pinned-searches',
      '/following-feeds',
    ]) {
      expect(
        resolve(path),
        const DestinationId.app(AppDestination.following).location,
      );
    }
    expect(
      Uri.parse(resolve('/?cid=b')).path,
      const DestinationId.browse('b').location,
    );
    expect(
      Uri.parse(resolve('/favorites')).path,
      const DestinationId.favorites('b').location,
    );
    expect(
      Uri.parse(resolve('/favorites?cid=missing')).path,
      const DestinationId.app(AppDestination.favoritesRecovery).location,
    );
    expect(
      Uri.parse(resolve('/search?query=%7Ecat+order%3Ascore'))
          .queryParameters['query'],
      '~cat order:score',
    );
    expect(resolve('/boorus/add'), '/boorus/add');
    const postLink =
        'boorusama://post/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&key=id%3A42';
    expect(resolve(postLink), postLink);
    const searchLink =
        'boorusama://search/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&mode=raw&q=cat';
    expect(resolve(searchLink), searchLink);
  });
}
