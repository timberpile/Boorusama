// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../config/types.dart';

class EditBooruConfigId extends Equatable {
  const EditBooruConfigId({
    required this.id,
    required this.booruType,
    required this.url,
    this.initialName,
  });

  const EditBooruConfigId.newId({
    required BooruType booruType,
    required String url,
    String? initialName,
  }) : this(
         id: '',
         booruType: booruType,
         url: url,
         initialName: initialName,
       );

  EditBooruConfigId.fromConfig(
    BooruConfig config,
  ) : id = config.id,
      booruType = config.auth.booruType,
      url = config.url,
      initialName = null;

  static EditBooruConfigId? fromUri(Uri uri) {
    final parameters = uri.queryParameters;
    final type = int.tryParse(parameters['type'] ?? '');
    final rawId = parameters['id'];
    final id = rawId == '' || isCanonicalProfileId(rawId) ? rawId : null;
    final url = parameters['url'];

    return switch ((type, id, url)) {
      (final type?, final id?, final url?) => EditBooruConfigId(
        id: id,
        booruType: BooruType.fromLegacyId(type),
        url: url,
        initialName: parameters['name'],
      ),
      _ => null,
    };
  }

  final String id;
  final BooruType booruType;
  final String url;
  final String? initialName;

  bool get isNew => id.isEmpty;

  Map<String, String> toQueryParameters() => {
    'type': booruType.id.toString(),
    'url': url,
    'id': id,
    'name': ?initialName,
  };

  @override
  List<Object?> get props => [id, booruType, url, initialName];
}
