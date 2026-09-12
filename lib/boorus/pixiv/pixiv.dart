// Project imports:
import '../../core/boorus/booru/types.dart';
import '../../core/boorus/engine/types.dart';
import 'pixiv_builder.dart';
import 'pixiv_repository.dart';

BooruComponents createPixiv() => BooruComponents(
  parser: DefaultBooruParser(
    config: BooruYamlConfigs.pixiv,
  ),
  createBuilder: PixivBuilder.new,
  createRepository: (ref) => PixivRepository(ref: ref),
);
