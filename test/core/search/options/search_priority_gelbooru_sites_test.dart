import 'package:boorusama/boorus/gelbooru/tags/metatag_extractor.dart';
import 'package:boorusama/boorus/gelbooru/tags/providers.dart';
import 'package:boorusama/boorus/gelbooru/tags/site_search_options.dart';
import 'package:boorusama/boorus/gelbooru/tags/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GelbooruMetatagExtractor extractorFor(String url, {required bool legacy}) {
  final site = gelbooruSiteSearchOptions(url, legacy: legacy);
  return GelbooruMetatagExtractor(
    metatags: {
      for (final key in [
        'id',
        'score',
        'rating',
        'user',
        'height',
        'width',
        'parent',
        'md5',
        'sort',
        ...site.extraMetatags,
      ])
        Metatag.simple(name: key),
    },
    sortableTypes: {
      for (final name in site.sortFields) SortableTagType(name: name),
    },
    allowRandomSort: site.randomSort,
    allowSeededRandomSort: site.seededRandomSort,
  );
}

void main() {
  final sites = {
    'realbooru.com': BooruType.gelbooruV2,
    'rule34.xxx': BooruType.gelbooruV2,
    'safebooru.org': BooruType.gelbooruV2,
    'gelbooru.com': BooruType.gelbooru,
  };

  for (final site in sites.entries) {
    test('choices and keys are unique for ${site.key}', () {
      final options = capabilitiesFor(site.value, 'https://${site.key}');
      expect(
        options.options.map((option) => option.key).toSet().length,
        options.options.length,
      );
      for (final option in options.options) {
        expect(
          option.choices.map((choice) => choice.value).toSet().length,
          option.choices.length,
          reason: option.key,
        );
        for (final choice in option.choices) {
          expect(
            option.compose(choice.value),
            isNotNull,
            reason: '${option.key}:${choice.value}',
          );
        }
      }
    });
  }

  test('Realbooru keeps its legacy options without Rule34-only fields', () {
    final options = capabilitiesFor(
      BooruType.gelbooruV2,
      'https://www.realbooru.com/',
    );
    expect(options.options.map((option) => option.key).toSet(), {
      'rating',
      'sort',
      'score',
      'id',
      'user',
      'width',
      'height',
      'parent',
      'md5',
    });
    expect(options.byKey('sort')!.compose('rating:desc'), 'sort:rating:desc');
    expect(options.byKey('sort')!.compose('parent:asc'), 'sort:parent:asc');
    expect(options.byKey('sort')!.compose('random'), isNull);
    expect(options.byKey('aspectratio'), isNull);
    expect(options.byKey('sourcedomains'), isNull);
    expect(
      options.byKey('rating')!.compose('questionable', exclude: true),
      '-rating:questionable',
    );
    expect(options.byKey('score')!.compose('>=10'), 'score:>=10');
    expect(options.byKey('score')!.compose('>=10', exclude: true), 'score:<10');
    expect(options.byKey('width')!.compose('>=1920'), 'width:>=1920');
    expect(options.byKey('height')!.compose('>1000'), 'height:>1000');
  });

  test('Rule34 and Gelbooru.com only offer their documented sort extras', () {
    final rule = capabilitiesFor(BooruType.gelbooruV2, 'https://rule34.xxx');
    final gel = capabilitiesFor(BooruType.gelbooru, 'https://gelbooru.com');
    expect(rule.byKey('sort')!.compose('random'), 'sort:random');
    expect(rule.byKey('sort')!.compose('rating:desc'), isNull);
    expect(rule.byKey('aspectratio'), isNull);
    expect(
      rule.byKey('source')!.compose('*://example.com/*'),
      'source:*://example.com/*',
    );
    expect(gel.byKey('sort')!.compose('random'), 'sort:random');
    expect(gel.byKey('sort')!.compose('parent:asc'), isNull);
    expect(gel.byKey('sort')!.compose('rating:desc'), 'sort:rating:desc');
  });

  test('the current host defines recognized native search expressions', () {
    final real = extractorFor('https://realbooru.com', legacy: true);
    final rule = extractorFor('https://rule34.xxx', legacy: true);
    final gel = extractorFor('https://gelbooru.com', legacy: false);
    expect(real.fromString('sort:rating:desc'), 'sort');
    expect(real.hasMetatag('sort:random'), isFalse);
    expect(real.hasMetatag('aspectratio:16:9'), isFalse);
    expect(rule.hasMetatag('sort:rating:desc'), isFalse);
    expect(rule.fromString('sort:random'), 'sort');
    expect(rule.fromString('aspectratio:16:9'), isNull);
    expect(rule.fromString('aspectratiof:>=1.5'), isNull);
    expect(rule.fromString('sourcedomains:example.com'), isNull);
    expect(rule.fromString('source:*example.com*'), 'source');
    expect(rule.hasMetatag('sort:random:3456'), isFalse);
    expect(gel.fromString('sort:random:3456'), 'sort');
    expect(gel.hasMetatag('sort:random:0'), isTrue);
    expect(gel.hasMetatag('sort:random:10000'), isTrue);
    expect(gel.hasMetatag('sort:random:10001'), isFalse);
    expect(gel.hasMetatag('sort:random:-1'), isFalse);
    expect(gel.hasMetatag('sort:parent:desc'), isFalse);
    expect(gel.hasMetatag('sort:rating:desc'), isTrue);
  });

  test('random syntax highlighting is enabled only when supported', () {
    final fields = ['id', 'score', 'rating'];
    expect(extractMetatagMatch('sort:random', ['sort'], fields), 'sort:');
    expect(
      extractMetatagMatch(
        'sort:random',
        ['sort'],
        fields,
        allowRandomSort: true,
      ),
      'sort:random',
    );
    expect(
      extractMetatagMatch(
        'sort:random:1234',
        ['sort'],
        fields,
        allowRandomSort: true,
        allowSeededRandomSort: true,
      ),
      'sort:random:1234',
    );
  });

  test(
    'real profile providers recognize native syntax for the correct site',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      BooruConfigAuth profile(BooruType type, String url) =>
          BooruConfig.defaultConfig(
            booruType: type,
            url: url,
            customDownloadFileNameFormat: null,
          ).auth;

      final real = profile(BooruType.gelbooruV2, 'https://realbooru.com');
      final rule = profile(BooruType.gelbooruV2, 'https://rule34.xxx');
      final gel = profile(BooruType.gelbooru, 'https://gelbooru.com');

      final realKeys = container
          .read(gelbooruMetatagsProvider(real))
          .map((tag) => tag.name)
          .toSet();
      final ruleKeys = container
          .read(gelbooruMetatagsProvider(rule))
          .map((tag) => tag.name)
          .toSet();
      expect(realKeys, isNot(contains('aspectratio')));
      expect(realKeys, isNot(contains('sourcedomains')));
      expect(ruleKeys, contains('source'));
      for (final key in ['aspectratio', 'aspectratiof', 'sourcedomains']) {
        expect(ruleKeys, isNot(contains(key)));
      }

      expect(
        container
            .read(gelbooruMetatagExtractorProvider(real))
            .fromString('sort:rating:desc'),
        'sort',
      );
      expect(
        container
            .read(gelbooruMetatagExtractorProvider(real))
            .fromString('sort:random'),
        isNull,
      );
      expect(
        container
            .read(gelbooruMetatagExtractorProvider(rule))
            .fromString('sort:random'),
        'sort',
      );
      expect(
        container
            .read(gelbooruMetatagExtractorProvider(rule))
            .fromString('source:*example.com*'),
        'source',
      );
      expect(
        container
            .read(gelbooruMetatagExtractorProvider(gel))
            .fromString('sort:random:3456'),
        'sort',
      );
    },
  );
}
