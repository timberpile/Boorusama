import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/tags/tag/colors.dart';
import '../../../core/tags/tag/providers.dart';

enum NhentaiTagSection {
  parody,
  character,
  tags,
  artist,
  group,
  language,
  category;

  static NhentaiTagSection fromSource(String? category) => switch (category) {
    'parody' => parody,
    'character' => character,
    'artist' => artist,
    'group' => group,
    'language' => language,
    'category' => NhentaiTagSection.category,
    _ => tags,
  };

  String label(BuildContext context) => switch (this) {
    parody => context.t.nhentai.tags.parody,
    character => context.t.nhentai.tags.character,
    tags => context.t.nhentai.tags.general,
    artist => context.t.nhentai.tags.artist,
    group => context.t.nhentai.tags.group,
    language => context.t.nhentai.tags.language,
    category => context.t.nhentai.tags.category,
  };

  Color color(BuildContext context, WidgetRef ref, BooruConfigAuth auth) {
    final scheme = Theme.of(context).colorScheme;
    if (this == group) return scheme.tertiary;
    if (this == language) return scheme.secondary;
    final type = switch (this) {
      parody => 'copyright',
      character => 'character',
      artist => 'artist',
      category => 'meta',
      _ => 'general',
    };
    final fallback = TagColors.fromBrightness(scheme.brightness);
    return ref.watch(tagColorProvider((auth, type))) ??
        switch (this) {
          parody => fallback.copyright,
          character => fallback.character,
          artist => fallback.artist,
          category => fallback.meta,
          _ => fallback.general,
        };
  }
}
