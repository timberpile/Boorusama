import 'package:equatable/equatable.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../content/anonymous_source_policy.dart';

/// Local source identity for an independent copy. It carries no credentials,
/// mirror ownership or access grant; every read must resolve current policy.
final class FollowingTopicSource extends Equatable {
  FollowingTopicSource({required this.booruType, required String url})
    : url = _site(url);

  factory FollowingTopicSource.fromJson(Map json) => FollowingTopicSource(
    booruType: json['booruType'] as String,
    url: json['url'] as String,
  );

  final String booruType;
  final String url;

  AnonymousSource? anonymous(AnonymousSourcePolicy policy) {
    final engine = BooruYamlConfigs.byId.values
        .where((config) => config.type.name == booruType)
        .firstOrNull
        ?.type;
    return engine == null ? null : policy.resolve(engine, Uri.parse(url));
  }

  bool matches(String engine, String site) =>
      booruType == engine && Uri.parse(url) == Uri.parse(site);

  Map<String, Object?> toJson() => {'booruType': booruType, 'url': url};

  static String _site(String value) {
    final uri = Uri.parse(value);
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid local Following source');
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  @override
  List<Object?> get props => [booruType, url];
}

final class FollowingLocalCopySourceUnavailable implements Exception {
  const FollowingLocalCopySourceUnavailable();
}
