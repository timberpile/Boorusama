import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/settings/src/search/settings_search.dart';

void main() {
  const items = [
    SettingsSearchItem(
      id: 'storage.video_cache',
      sectionId: 'storage',
      sectionTitle: 'Data and storage',
      title: 'Video cache',
      description: 'Keep downloaded videos on disk',
    ),
    SettingsSearchItem(
      id: 'viewer.mute',
      sectionId: 'viewer',
      sectionTitle: 'Image viewer',
      title: 'Mute video',
      keywords: ['sound audio volume'],
    ),
    SettingsSearchItem(
      id: 'accessibility.motion',
      sectionId: 'accessibility',
      sectionTitle: 'Accessibility',
      title: 'Reduce animations',
      description: 'Use less motion when moving between pages',
    ),
  ];

  test('matches words across the title, category and description', () {
    expect(
      searchSettings(items, 'storage downloaded video').map((item) => item.id),
      ['storage.video_cache'],
    );
  });

  test('ignores case, word order and repeated whitespace', () {
    expect(
      searchSettings(items, '  VIDEO\n  MuTe  ').map((item) => item.id),
      ['viewer.mute'],
    );
  });

  test('matches aliases without requiring their display in the title', () {
    expect(
      searchSettings(items, 'audio').map((item) => item.id),
      ['viewer.mute'],
    );
  });

  test('matches localized labels and normalizes separators', () {
    const localized = [
      SettingsSearchItem(
        id: 'accessibility.motion',
        sectionId: 'accessibility',
        sectionTitle: 'Bedienungshilfen',
        title: 'Animationen reduzieren',
      ),
    ];
    expect(searchSettings(localized, 'REDUZIEREN_animationen'), localized);
    expect(
      searchSettings(items, 'video-cache').single.id,
      'storage.video_cache',
    );
  });

  test('requires every word and treats query punctuation literally', () {
    for (final query in ['video motion', '.*', '[', 'unrelated']) {
      expect(searchSettings(items, query), isEmpty, reason: query);
    }
  });

  test('returns no search results for a blank query', () {
    expect(searchSettings(items, ''), isEmpty);
    expect(searchSettings(items, ' \n\t '), isEmpty);
  });

  test('ranks exact titles before prefixes, title words and aliases', () {
    const ranked = [
      SettingsSearchItem(
        id: 'alias',
        sectionId: 'storage',
        sectionTitle: 'Storage',
        title: 'Maximum size',
        keywords: ['cache'],
      ),
      SettingsSearchItem(
        id: 'contains',
        sectionId: 'storage',
        sectionTitle: 'Storage',
        title: 'Video cache',
      ),
      SettingsSearchItem(
        id: 'prefix',
        sectionId: 'storage',
        sectionTitle: 'Storage',
        title: 'Cache limit',
      ),
      SettingsSearchItem(
        id: 'exact',
        sectionId: 'storage',
        sectionTitle: 'Storage',
        title: 'Cache',
      ),
    ];
    expect(
      searchSettings(ranked, 'cache').map((item) => item.id),
      ['exact', 'prefix', 'contains', 'alias'],
    );
  });

  test('preserves catalog order for equally relevant matches', () {
    expect(searchSettings(items, 'i').map((item) => item.id), [
      'storage.video_cache',
      'viewer.mute',
      'accessibility.motion',
    ]);
    expect(items.first.id, 'storage.video_cache');
  });
}
