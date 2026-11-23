// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types.dart';

const _automaticMediaLoadingEnabledKey = 'automatic_media_loading_enabled';
const _zoomStudyEnabledKey = 'zoom_study_enabled';

abstract interface class DeveloperOptionsRepository {
  Future<DeveloperOptions> load();

  Future<void> save(DeveloperOptions options);
}

class HiveDeveloperOptionsRepository implements DeveloperOptionsRepository {
  HiveDeveloperOptionsRepository(this._box);

  final Future<Box<bool>> _box;

  @override
  Future<DeveloperOptions> load() async {
    final box = await _box;

    return DeveloperOptions(
      automaticMediaLoadingEnabled:
          box.get(
            _automaticMediaLoadingEnabledKey,
            defaultValue: true,
          ) ??
          true,
      zoomStudyEnabled: box.get(_zoomStudyEnabledKey) ?? false,
    );
  }

  @override
  Future<void> save(DeveloperOptions options) async {
    final box = await _box;
    await box.put(
      _automaticMediaLoadingEnabledKey,
      options.automaticMediaLoadingEnabled,
    );
    await box.put(_zoomStudyEnabledKey, options.zoomStudyEnabled);
  }
}

DeveloperOptionsRepository createDeveloperOptionsRepository() =>
    HiveDeveloperOptionsRepository(
      Hive.openBox<bool>('developer_options'),
    );
