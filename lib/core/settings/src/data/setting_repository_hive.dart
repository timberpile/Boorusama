// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types/settings.dart';
import '../types/settings_repository.dart';

const _settingsKey = 'settings';

class SettingsRepositoryHive implements SettingsRepository {
  SettingsRepositoryHive(
    this._db,
  );
  final Future<Box> _db;

  @override
  SettingsOrError load() => _openDb()
      .flatMap((db) => TaskEither.fromEither(_getSettingsJson(db)))
      .flatMap(
        (jsonString) =>
            TaskEither.fromEither(
              _decodeSettingsJson(jsonString),
            ).flatMap(
              (settings) => TaskEither.tryCatch(
                () async {
                  final decoded = jsonDecode(jsonString);
                  if (decoded is Map<String, dynamic> &&
                      switch (decoded['searchRefresh']) {
                        final Map refresh => refresh['schemaVersion'] != 2,
                        _ => true,
                      }) {
                    final migrated = Map<String, dynamic>.from(decoded)
                      ..['searchRefresh'] = settings.searchRefresh.toJson();
                    try {
                      await (await _db).put(_settingsKey, jsonEncode(migrated));
                    } catch (_) {
                      // Keep the safe in-memory interpretation if storage is unavailable.
                    }
                  }
                  return settings;
                },
                (e, s) => SettingsLoadError.unknown,
              ),
            ),
      );

  TaskEither<SettingsLoadError, dynamic> _openDb() => TaskEither.tryCatch(
    () => _db,
    (e, s) => SettingsLoadError.failedToOpenDatabase,
  );

  Either<SettingsLoadError, String> _getSettingsJson(dynamic db) {
    final jsonString = db.get(_settingsKey);
    return jsonString != null
        ? Either.right(jsonString)
        : Either.left(SettingsLoadError.tableNotFound);
  }

  Either<SettingsLoadError, Settings> _decodeSettingsJson(String jsonString) =>
      _tryDecodeJson(jsonString).flatMap(
        (decodedJson) => Either.tryCatch(
          () => Settings.fromJson(decodedJson),
          (e, s) => SettingsLoadError.failedToMapJsonToSettings,
        ),
      );

  Either<SettingsLoadError, dynamic> _tryDecodeJson(String jsonString) =>
      tryDecodeJson(jsonString).fold(
        (l) => Either.left(_mapJsonDecodeErrorToSettingsLoadError(l)),
        (r) => Either.right(r),
      );

  SettingsLoadError _mapJsonDecodeErrorToSettingsLoadError(
    JsonDecodeError error,
  ) => switch (error) {
    JsonDecodeError.invalidJsonFormat => SettingsLoadError.invalidJsonFormat,
    _ => SettingsLoadError.unknown,
  };

  @override
  Future<bool> save(Settings setting) async {
    final db = await _db;
    final json = jsonEncode(setting.toJson());

    await db.put(_settingsKey, json);

    return true;
  }
}
