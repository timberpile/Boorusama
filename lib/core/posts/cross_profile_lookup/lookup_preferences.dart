import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/booru/types.dart';
import '../../cache/misc_data_store.dart';
import '../../configs/config/types.dart';
import '../post/types.dart';
import '../sources/types.dart';
import 'data.dart';
import 'providers.dart';
import 'src/data/source_post_lookup.dart';
import 'types.dart';

typedef LookupTarget = ({
  BooruConfig profile,
  Set<PostLookupMatchKind> methods,
});

typedef LookupProfileChoice = ({
  String endpoint,
  Set<PostLookupMatchKind> methods,
});

enum IqdbPermission { none, persistent }

const minimumIqdbThreshold = 80;
const maximumIqdbThreshold = 100;
const defaultIqdbThreshold = 90;

final class LookupPreferences {
  const LookupPreferences({
    this.profiles,
    this.allowIqdb = false,
    this.threshold = defaultIqdbThreshold,
  });

  factory LookupPreferences.decode(String? encoded) {
    if (encoded == null) return const LookupPreferences();
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) {
        return const LookupPreferences(profiles: {});
      }
      final rawProfiles = value['profiles'];
      final profiles = <String, LookupProfileChoice>{};
      if (rawProfiles is Map<String, dynamic>) {
        for (final entry in rawProfiles.entries) {
          final choice = entry.value;
          if (choice is! Map<String, dynamic> ||
              choice['endpoint'] is! String ||
              choice['methods'] is! List) {
            continue;
          }
          final methods = (choice['methods'] as List).toSet();
          profiles[entry.key] = (
            endpoint: choice['endpoint'] as String,
            methods: {
              for (final method in PostLookupMatchKind.values)
                if (methods.contains(method.name)) method,
            },
          );
        }
      }
      return LookupPreferences(
        profiles: rawProfiles == null ? null : profiles,
        allowIqdb: value['allowIqdb'] == true,
        threshold: switch (value['threshold']) {
          final int value
              when value >= minimumIqdbThreshold &&
                  value <= maximumIqdbThreshold =>
            value,
          _ => defaultIqdbThreshold,
        },
      );
    } on FormatException {
      return const LookupPreferences(profiles: {});
    }
  }

  /// A missing configuration preserves existing MD5 imports. An empty saved
  /// configuration deliberately selects no targets.
  final Map<String, LookupProfileChoice>? profiles;
  final bool allowIqdb;
  final int threshold;

  bool permits(IqdbPermission permission) =>
      permission == IqdbPermission.persistent && allowIqdb;

  Set<PostLookupMatchKind>? methodsFor(BooruConfig profile) {
    final choice = profiles?[profile.id];
    if (choice == null || choice.endpoint != lookupEndpoint(profile)) {
      return profiles == null ? null : const {};
    }
    return choice.methods;
  }

  String encode() => jsonEncode({
    if (profiles case final choices?)
      'profiles': {
        for (final entry in choices.entries)
          entry.key: {
            'endpoint': entry.value.endpoint,
            'methods': entry.value.methods
                .map((method) => method.name)
                .toList(),
          },
      },
    'allowIqdb': allowIqdb,
    'threshold': threshold,
  });
}

String lookupEndpoint(BooruConfig profile) =>
    '${profile.auth.booruType.name}:${profile.url.trim()}';

bool supportsIqdbLookup(BooruConfig profile) =>
    iqdbLookupEndpoint(profile) != null &&
    (profile.auth.login?.trim().isNotEmpty ?? false) &&
    (profile.auth.apiKey?.trim().isNotEmpty ?? false);

Uri? iqdbLookupEndpoint(BooruConfig profile) {
  if (kIsWeb || profile.auth.booruType != BooruType.danbooru) return null;
  final url = Uri.tryParse(profile.url.trim());
  if (url == null ||
      url.scheme != 'https' ||
      !const {'danbooru.donmai.us', 'safebooru.donmai.us'}.contains(url.host) ||
      url.port != 443 ||
      url.userInfo.isNotEmpty ||
      url.hasQuery ||
      url.hasFragment ||
      !const {'', '/'}.contains(url.path)) {
    return null;
  }
  return Uri.https(url.host, '/iqdb_queries.json');
}

bool supportsPixivArtworkTarget(BooruConfig profile) =>
    profile.auth.booruType == BooruType.pixiv &&
    (profile.auth.apiKey?.trim().isNotEmpty ?? false);

int? linkedPixivArtworkId(Post post) {
  final artwork = PixivArtworkReference.parseSharedText(post.source.url);
  return artwork == null ? null : int.tryParse(artwork.id);
}

Set<PostLookupMatchKind> configuredLookupMethods(BooruConfig profile) => {
  if (supportsExactPostLookup(profile)) PostLookupMatchKind.exactFile,
  if (profile.auth.booruType == BooruType.danbooru ||
      supportsPixivArtworkTarget(profile))
    PostLookupMatchKind.pixivSource,
  if (supportsSourceUrlLookup(profile.auth.booruType))
    PostLookupMatchKind.sourceUrl,
  if (iqdbLookupEndpoint(profile) != null) PostLookupMatchKind.similarImage,
};

bool supportsIqdbImageFormat(String format) => const {
  'jpeg',
  'jpg',
  'png',
  'webp',
}.contains(format.toLowerCase().replaceFirst(RegExp(r'^\.'), ''));

Set<PostLookupMatchKind> localLookupMethods(
  BooruConfig profile, {
  required bool stillImage,
}) => configuredLookupMethods(profile).intersection({
  PostLookupMatchKind.exactFile,
  if (stillImage) PostLookupMatchKind.similarImage,
});

Set<PostLookupMatchKind> remoteLookupMethods(
  BooruConfig profile,
  Post source,
) => configuredLookupMethods(profile).intersection({
  if (ExactPostLookup.normalizeMd5(source.md5) != null ||
      source.sitePostId != null)
    PostLookupMatchKind.exactFile,
  if (supportsPixivArtworkTarget(profile)
      ? linkedPixivArtworkId(source) != null
      : pixivArtworkId(source.source.url) != null)
    PostLookupMatchKind.pixivSource,
  if (lookupSourceUrl(source.source.url) != null) PostLookupMatchKind.sourceUrl,
  if (supportsIqdbImageFormat(source.format)) PostLookupMatchKind.similarImage,
});

final lookupPreferencesProvider =
    NotifierProvider<LookupPreferencesNotifier, LookupPreferences>(
      LookupPreferencesNotifier.new,
      dependencies: [miscDataStoreProvider],
    );

class LookupPreferencesNotifier extends Notifier<LookupPreferences> {
  static const _key = 'cross_profile.lookup_preferences';
  Future<void> _writeTail = Future.value();
  var _disposed = false;
  var _iqdbRevision = 0;

  @override
  LookupPreferences build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return LookupPreferences.decode(ref.watch(miscDataStoreProvider).get(_key));
  }

  Future<void> saveProfiles(
    Map<String, LookupProfileChoice> profiles, {
    bool enableIqdb = false,
  }) => _save(
    (old) => LookupPreferences(
      profiles: Map.unmodifiable(profiles),
      allowIqdb: old.allowIqdb || enableIqdb,
      threshold: old.threshold,
    ),
  );

  Future<void> setThreshold(int threshold) => _save(
    (old) => LookupPreferences(
      profiles: old.profiles,
      allowIqdb: old.allowIqdb,
      threshold: threshold.clamp(minimumIqdbThreshold, maximumIqdbThreshold),
    ),
  );

  Future<void> setIqdb(bool allowed) {
    ++_iqdbRevision;
    if (!allowed) {
      state = LookupPreferences(
        profiles: state.profiles,
        threshold: state.threshold,
      );
    }
    return _save(
      (old) => LookupPreferences(
        profiles: old.profiles,
        allowIqdb: allowed,
        threshold: old.threshold,
      ),
    );
  }

  Future<void> _save(LookupPreferences Function(LookupPreferences) update) {
    final store = ref.read(miscDataStoreProvider);
    final write = _writeTail.then((_) async {
      if (_disposed) return;
      final revision = _iqdbRevision;
      final next = update(state);
      await store.put(_key, next.encode());
      if (!_disposed) {
        state = revision == _iqdbRevision
            ? next
            : LookupPreferences(
                profiles: next.profiles,
                allowIqdb: state.allowIqdb,
                threshold: next.threshold,
              );
      }
    });
    _writeTail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}

bool stillSelected(
  LookupPreferences preferences,
  LookupTarget target,
  PostLookupMatchKind method,
) => preferences.methodsFor(target.profile)?.contains(method) ?? true;
