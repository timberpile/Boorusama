// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';
import 'edit_booru_config_id.dart';

enum QuickProfileAuthentication {
  required,
  optional,
  unnecessary;

  static QuickProfileAuthentication? tryParse(Object? value) => switch (value) {
    'required' => required,
    'optional' => optional,
    'unnecessary' => unnecessary,
    _ => null,
  };
}

class QuickProfileSite extends Equatable {
  const QuickProfileSite({
    required this.booruType,
    required this.url,
    required this.profileName,
    required this.authentication,
  });

  final BooruType booruType;
  final String url;
  final String profileName;
  final QuickProfileAuthentication authentication;

  EditBooruConfigId toEditId() => EditBooruConfigId.newId(
    booruType: booruType,
    url: url,
    initialName: profileName,
  );

  @override
  List<Object> get props => [
    booruType,
    url,
    profileName,
    authentication,
  ];
}

abstract final class QuickProfileSiteCatalog {
  static List<QuickProfileSite> fromBoorus(Iterable<Booru> boorus) => [
    for (final booru in boorus)
      if (booru.type != BooruType.unknown)
        for (final site in booru.config.sites)
          ?_parse(booru.type, site.url, site.metadata),
  ];

  static QuickProfileSite? _parse(
    BooruType booruType,
    String url,
    Map<String, dynamic> metadata,
  ) {
    final quickProfile = metadata['quick-profile'];
    if (quickProfile is! Map) return null;

    final rawName = quickProfile['name'];
    final authentication = QuickProfileAuthentication.tryParse(
      quickProfile['authentication'],
    );
    final uri = Uri.tryParse(url);
    if (rawName is! String ||
        rawName.trim().isEmpty ||
        authentication == null ||
        uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return QuickProfileSite(
      booruType: booruType,
      url: url,
      profileName: rawName.trim(),
      authentication: authentication,
    );
  }
}
