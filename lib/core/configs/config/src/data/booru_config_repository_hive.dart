// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../downloads/filename/types.dart';
import '../types/booru_config.dart';
import '../types/booru_config_data.dart';
import '../types/booru_config_repository.dart';
import '../types/profile_id.dart';
import 'booru_config_converter.dart';

class HiveBooruConfigRepository implements BooruConfigRepository {
  HiveBooruConfigRepository({
    required this.box,
    this.logger,
  });
  final Box<String> box;
  final Logger? logger;

  static String defaultValue() => jsonEncode(
    BooruConfigData.anonymous(
      booru: BooruType.danbooru,
      booruHint: BooruType.danbooru,
      name: 'Default profile',
      filter: BooruConfigRatingFilter.none,
      url: 'https://safebooru.donmai.us/',
      customDownloadFileNameFormat: kBoorusamaCustomDownloadFileNameFormat,
      customBulkDownloadFileNameFormat:
          kBoorusamaBulkDownloadCustomFileNameFormat,
      imageDetaisQuality: null,
      videoQuality: null,
    ),
  );

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) async {
    final generation = const Uuid().v4();
    final json = {...booruConfigData.toJson(), _generationKey: generation};
    final jsonString = jsonEncode(json);
    final id = createProfileId();
    await box.put(id, jsonString);

    return booruConfigData
        .toBooruConfig(id: id)
        ?.copyWith(localMediaGeneration: generation);
  }

  @override
  Future<void> remove(BooruConfig booruConfig) async {
    await box.delete(booruConfig.id);
  }

  @override
  Future<List<BooruConfig>> getAll() async {
    final configs = <BooruConfig>[];
    for (final id in box.keys.toList()) {
      if (!isCanonicalProfileId(id)) continue;
      final raw = box.get(id);
      if (raw == null) continue;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      var generation = json[_generationKey] as String?;
      if (generation == null || !Uuid.isValidUUID(fromString: generation)) {
        generation = const Uuid().v4();
        // Confirm provenance durably before exposing the profile to readers.
        await box.put(id, jsonEncode({...json, _generationKey: generation}));
      }
      final config = BooruConfigData.fromJson(json)
          .toBooruConfig(id: id as String);
      if (config != null)
        configs.add(config.copyWith(localMediaGeneration: generation));
    }
    return configs;
  }

  static const _generationKey = '_localMediaGenerationV1';

  @override
  Future<BooruConfig?> update(
    String id,
    BooruConfigData booruConfigData,
  ) async {
    final raw = box.get(id);
    final previous = raw == null
        ? null
        : jsonDecode(raw) as Map<String, dynamic>;
    final old = previous == null
        ? null
        : BooruConfigData.fromJson(previous).toBooruConfig(id: id);
    final next = booruConfigData.toBooruConfig(id: id);
    final oldGeneration = previous?[_generationKey] as String?;
    final generation = old?.auth == next?.auth && oldGeneration != null
        ? oldGeneration
        : const Uuid().v4();
    final json = {...booruConfigData.toJson(), _generationKey: generation};
    final jsonString = jsonEncode(json);

    try {
      await box.put(id, jsonString);

      return next?.copyWith(localMediaGeneration: generation);
    } catch (error, stackTrace) {
      logger?.handledError(
        'Profiles',
        'write_profile',
        error: error,
        stackTrace: stackTrace,
        outcome: 'write_not_confirmed',
      );
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await box.clear();
  }

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) async {
    if (booruConfigs.any((config) => config.anonymousReadScope != null)) {
      throw StateError('Public read contexts cannot become saved profiles');
    }
    final configs = <BooruConfig>[];

    for (final booruConfig in booruConfigs) {
      final data = booruConfig.toBooruConfigData();
      // Import/replacement starts a new local actor even when an ID is reused.
      final generation = const Uuid().v4();
      final json = {...data.toJson(), _generationKey: generation};
      final jsonString = jsonEncode(json);
      await box.put(booruConfig.id, jsonString);

      configs.add(
        data
            .toBooruConfig(
              id: booruConfig.id,
            )!
            .copyWith(localMediaGeneration: generation),
      );
    }

    return configs;
  }
}
