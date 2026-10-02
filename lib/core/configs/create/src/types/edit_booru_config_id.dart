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
         id: -1,
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
    final id = int.tryParse(parameters['id'] ?? '');
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

  final int id;
  final BooruType booruType;
  final String url;
  final String? initialName;

  bool get isNew => id == -1;

  Map<String, String> toQueryParameters() => {
    'type': booruType.id.toString(),
    'url': url,
    'id': id.toString(),
    'name': ?initialName,
  };

  @override
  List<Object?> get props => [id, booruType, url, initialName];
}
