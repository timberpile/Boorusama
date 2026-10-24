import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../../tags/configs/providers.dart';
import 'catalog/api_user_filters.dart';
import 'catalog/aliases.dart';
import 'catalog/danbooru.dart';
import 'catalog/danbooru_semantics.dart';
import 'catalog/e621.dart';
import 'catalog/gelbooru.dart';
import 'catalog/hybooru.dart';
import 'catalog/hydrus.dart';
import 'catalog/moebooru.dart';
import 'catalog/nozomi.dart';
import 'catalog/philomena.dart';
import 'catalog/shimmie.dart';
import 'catalog/szurubooru.dart';
import 'search_option.dart';

final searchCapabilitiesProvider =
    Provider.family<SearchCapabilities, BooruConfigAuth>((ref, config) {
      final capabilities = capabilitiesFor(config.booruType, config.url);
      if (config.booruType != BooruType.danbooru) return capabilities;
      final aliases = searchOptionAliasesFor(config.booruType);
      final metatags = ref.watch(tagInfoProvider).metatags;
      final freeKeys = metatags
          .where((tag) => tag.isFree)
          .map((tag) => aliases[tag.name] ?? tag.name)
          .toSet();
      final keys = capabilities.options.map((option) => option.key).toSet();
      return SearchCapabilities([
        for (final option in capabilities.options)
          option.withFree(freeKeys.contains(aliases[option.key] ?? option.key)),
        for (final tag in metatags)
          if (!keys.contains(tag.name) &&
              !const {'newpool', 'locked'}.contains(tag.name))
            SearchOption(
              kind: SearchOptionKind.native,
              key: tag.name,
              input: SearchOptionInput.text,
              isFree: tag.isFree,
            ),
      ]);
    }, dependencies: [tagInfoProvider]);

/// The complete grammar remains available for history, sharing and typed aliases;
/// discovery surfaces offer just one preferred spelling of each predicate.
final searchOptionCatalogProvider =
    Provider.family<List<SearchOption>, BooruConfigAuth>((ref, config) {
      final capabilities = ref.watch(searchCapabilitiesProvider(config));
      final aliases = searchOptionAliasesFor(config.booruType);
      return [
        for (final option in capabilities.options)
          if (!aliases.containsKey(option.key) ||
              capabilities.byKey(aliases[option.key]!) == null)
            option,
      ];
    }, dependencies: [searchCapabilitiesProvider]);

SearchCapabilities capabilitiesFor(BooruType type, String url) =>
    SearchCapabilities(switch (type) {
      BooruType.danbooru => completeDanbooruOptions(danbooruOptions()),
      BooruType.gelbooru => gelbooruOptions(legacy: false, url: url),
      BooruType.gelbooruV2 when knownLegacyGelbooru(url) => gelbooruOptions(
        legacy: true,
        url: url,
      ),
      BooruType.moebooru => moebooruOptions(),
      BooruType.e621 => e621Options(),
      BooruType.szurubooru => szurubooruOptions(),
      BooruType.philomena => philomenaOptions(),
      BooruType.hybooru => hybooruOptions(),
      BooruType.hydrus => hydrusOptions(),
      BooruType.nozomi => nozomiOptions(),
      BooruType.eshuushuu => eshuushuuOptions(),
      BooruType.animePictures => animePicturesOptions(),
      BooruType.shimmie2 when Uri.tryParse(url)?.host == 'rule34.paheal.net' =>
        pahealOptions(),
      _ => const [],
    });
