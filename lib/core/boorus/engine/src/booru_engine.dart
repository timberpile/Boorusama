// Project imports:
import '../../booru/types.dart';
import '../../../posts/post/types.dart';
import 'booru_builder.dart';
import 'booru_repository.dart';

class BooruEngine {
  const BooruEngine({
    required this.booru,
    required this.builder,
    required this.repository,
  });

  final Booru booru;
  final BooruBuilder builder;
  final BooruRepository repository;

  BooruPostCapability<BooruPostData> get postCapability =>
      BooruPostCapability<BooruPostData>(
        booruType: booru.type,
        codec: repository.postDataCodec,
        presentation: builder.postPresentation,
      );
}

class BooruEngineRegistry {
  final Map<BooruType, BooruEngine> _engines = {};

  void register(BooruType type, BooruEngine engine) {
    _engines[type] = engine;
  }

  BooruEngine? getEngine(BooruType type) => _engines[type];

  BooruRepository? getRepository(BooruType type) => _engines[type]?.repository;

  BooruBuilder? getBuilder(BooruType type) => _engines[type]?.builder;

  BooruPostCapability<BooruPostData>? getPostCapability(BooruType type) =>
      _engines[type]?.postCapability;

  List<Booru> getAllBoorus() {
    return _engines.values.map((e) => e.booru).toList();
  }
}
