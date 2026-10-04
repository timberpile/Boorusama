// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../types/booru_config_repository.dart';
import '../types/booru_config_data.dart';
import 'booru_config_repository_hive.dart';

Future<BooruConfigRepository> createBooruConfigsRepo({
  required Logger logger,
  required Future<void> Function(String configId)? onCreateNew,
}) async {
  logger.debugBoot('Initialize booru config box');

  final isNewBox = !await Hive.boxExists('booru_configs');
  final booruConfigBox = await Hive.openBox<String>('booru_configs');

  final booruUserRepo = HiveBooruConfigRepository(box: booruConfigBox);
  final hasOnlyUnsupportedRows =
      booruConfigBox.isNotEmpty && (await booruUserRepo.getAll()).isEmpty;
  if (onCreateNew != null && (isNewBox || hasOnlyUnsupportedRows)) {
    logger.debugBoot('Add default booru config');

    final defaultData = BooruConfigData.fromJson(
      jsonDecode(HiveBooruConfigRepository.defaultValue())
          as Map<String, dynamic>,
    );
    final id = (await booruUserRepo.add(defaultData!))!.id;

    await onCreateNew(id);
  }

  logger
    ..debugBoot('Total booru config: ${booruConfigBox.length}')
    ..debugBoot('Initialize booru user repository');
  return booruUserRepo;
}
