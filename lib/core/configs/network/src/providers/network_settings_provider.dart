// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../config/types.dart';

final networkSettingsProvider =
    Provider.family<NetworkSettings, BooruConfigAuth>(
      (ref, config) => config.booruType == BooruType.nhentai
          ? const NetworkSettings()
          : config.networkSettings ?? const NetworkSettings(),
    );
