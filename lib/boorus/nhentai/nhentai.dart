import '../../core/boorus/booru/types.dart';
import '../../core/boorus/engine/types.dart';
import 'galleries/capability.dart';
import 'nhentai_builder.dart';
import 'nhentai_repository.dart';

BooruComponents createNhentai() => BooruComponents(
  parser: DefaultBooruParser(config: BooruYamlConfigs.nhentai),
  createBuilder: NhentaiBuilder.new,
  createRepository: (ref) => NhentaiRepository(ref: ref),
  createGroupCapability: createNhentaiGroupCapability,
);
