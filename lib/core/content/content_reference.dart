import 'package:equatable/equatable.dart';

import '../boorus/booru/types.dart';
import '../posts/links/boorusama_post_link.dart';
import '../posts/post/types.dart';
import 'content_map.dart';

enum ContentKind { post, group }

typedef ContentIdentity = ({
  String siteNamespace,
  ContentKind kind,
  String sourceKey,
});

abstract interface class ContentKeyCodec {
  BooruType get engine;
  String canonicalize(ContentKind kind, String sourceKey);
  String? keyForPost(Post post);
  PostId postIdFor(String sourceKey);
}

/// Existing deployed grammars. New engines supply their codec through the
/// existing engine capability registration, rather than adding global kinds.
final class BooruContentKeyCodec implements ContentKeyCodec {
  const BooruContentKeyCodec(this.engine);

  @override
  final BooruType engine;

  @override
  String canonicalize(ContentKind kind, String sourceKey) {
    if (engine == BooruType.unknown) {
      throw const FormatException('Unsupported content engine');
    }
    if (kind == ContentKind.post) {
      postIdFor(sourceKey);
      return sourceKey;
    }
    final parts = sourceKey.split(':');
    final supported = switch (engine) {
      BooruType.danbooru => const {'pool', 'related'},
      BooruType.szurubooru => const {'pool'},
      BooruType.pixiv => const {'work'},
      BooruType.nhentai => const {'gallery'},
      _ => const <String>{},
    };
    if (parts.length != 2 || !supported.contains(parts.first)) {
      throw const FormatException('Unsupported Group key');
    }
    final number = RegExp(r'^[1-9][0-9]*$').hasMatch(parts.last)
        ? int.tryParse(parts.last)
        : null;
    if (number == null || number > 9007199254740991) {
      throw const FormatException('Invalid Group key');
    }
    return sourceKey;
  }

  @override
  String? keyForPost(Post post) {
    if (post.origin.booruType != engine) return null;
    final key = BoorusamaPostLink.stableKeyForPost(post);
    if (key == null) return null;
    try {
      return canonicalize(ContentKind.post, key);
    } on FormatException {
      return null;
    }
  }

  @override
  PostId postIdFor(String sourceKey) {
    if (engine == BooruType.unknown) {
      throw const FormatException('Unsupported content engine');
    }
    return BoorusamaPostLink.parsePostId(engine, sourceKey);
  }
}

final class ContentReference extends Equatable {
  const ContentReference._({
    required this.engine,
    required this.site,
    required this.kind,
    required this.sourceKey,
  });

  final BooruType engine;
  final Uri site;
  final ContentKind kind;
  final String sourceKey;
  String get siteNamespace => normalizePostSourceHost(site.toString());
  ContentIdentity get identity => (
    siteNamespace: siteNamespace,
    kind: kind,
    sourceKey: sourceKey,
  );

  @override
  List<Object?> get props => [engine, site, kind, sourceKey];
}

/// Construction and decoding share one validated library-private constructor.
/// An address is data; it never grants permission to create a network client.
final class ContentReferenceCodec {
  const ContentReferenceCodec({this.keyCodecFor});

  final ContentKeyCodec? Function(BooruType engine)? keyCodecFor;

  ContentKeyCodec codecFor(BooruType engine) {
    final codec = keyCodecFor?.call(engine) ?? BooruContentKeyCodec(engine);
    if (engine == BooruType.unknown || codec.engine != engine) {
      throw const FormatException('Incompatible content engine');
    }
    return codec;
  }

  ContentReference parse({
    required BooruType engine,
    required Uri site,
    required ContentKind kind,
    required String sourceKey,
  }) => _parse(engine, site.toString(), kind, sourceKey);

  ContentReference _parse(
    BooruType engine,
    String site,
    ContentKind kind,
    String sourceKey,
  ) {
    final normalized = BoorusamaPostLink.parseSourceSite(site);
    // Inspect raw input as Uri.parse may remove dot segments. Repeatedly
    // escaped traversal and encoded path separators are not installation URLs.
    final rawPath =
        RegExp(
          r'^https?://[^/]+(/[^?#]*)?$',
          caseSensitive: false,
        ).firstMatch(site)?.group(1) ??
        '';
    var path = rawPath;
    for (var depth = 0; depth < 3; depth++) {
      if (RegExp('%2f|%5c', caseSensitive: false).hasMatch(path) ||
          path.split('/').any((part) => part == '.' || part == '..')) {
        throw const FormatException('Unsafe content installation path');
      }
      final decoded = Uri.decodeComponent(path);
      if (decoded == path) break;
      path = decoded;
    }
    return ContentReference._(
      engine: engine,
      site: normalized,
      kind: kind,
      sourceKey: codecFor(engine).canonicalize(kind, sourceKey),
    );
  }

  /// PostOrigin retains a semantic namespace, not a provable transport scheme.
  /// Callers supply the original binding's locator; legacy unaddressable Posts
  /// remain renderable without inventing an HTTPS installation or source key.
  ContentReference? fromPost(Post post, {Uri? site}) {
    if (site == null ||
        normalizePostSourceHost(site.toString()) != post.origin.sourceHost) {
      return null;
    }
    try {
      final key = codecFor(post.origin.booruType).keyForPost(post);
      return key == null
          ? null
          : parse(
              engine: post.origin.booruType,
              site: site,
              kind: ContentKind.post,
              sourceKey: key,
            );
    } on FormatException {
      return null;
    }
  }

  void requireCompatible(ContentReference a, ContentReference b) {
    if (a.identity != b.identity || a.engine != b.engine) {
      throw const FormatException('Incompatible content interpretation');
    }
  }

  Map<String, Object?> encode(ContentReference reference) => {
    'version': 1,
    'engine': reference.engine.yamlName,
    'site': reference.site.toString(),
    'kind': reference.kind.name,
    'key': reference.sourceKey,
  };

  ContentReference decode(Object? value) {
    final map = contentMap(value);
    if (map['version'] != 1) {
      throw const FormatException('Unsupported content reference version');
    }
    final engine = BooruYamlConfigs.values
        .where((config) => config.type.yamlName == map['engine'])
        .map((config) => config.type)
        .firstOrNull;
    final kind = ContentKind.values
        .where((kind) => kind.name == map['kind'])
        .firstOrNull;
    if (engine == null || kind == null) {
      throw const FormatException('Unsupported content reference');
    }
    return _parse(
      engine,
      contentString(map['site']),
      kind,
      contentString(map['key']),
    );
  }
}
