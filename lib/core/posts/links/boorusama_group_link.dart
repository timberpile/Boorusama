import 'package:equatable/equatable.dart';

import '../../content/content_reference.dart';
import '../../content/types.dart';
import 'boorusama_post_link.dart';

/// A portable address for a validated source Group. It contains no account or
/// local bookmark data and does not grant access to the referenced source.
final class BoorusamaGroupLink extends Equatable {
  const BoorusamaGroupLink._(this.reference);

  factory BoorusamaGroupLink.parse(String value) {
    final parameters = BoorusamaPostLink.parseResourceParameters(
      value,
      resource: 'group',
    );
    final reference = const ContentReferenceCodec().decode({
      'version': 1,
      'engine': parameters.engine.yamlName,
      'site': parameters.rawSite,
      'kind': ContentKind.group.name,
      'key': parameters.key,
    });
    return BoorusamaGroupLink._(reference);
  }

  factory BoorusamaGroupLink.fromReference(ContentReference reference) {
    const codec = ContentReferenceCodec();
    final validated = codec.decode(codec.encode(reference));
    if (validated.kind != ContentKind.group) {
      throw const FormatException('Expected a Group reference');
    }
    final link = BoorusamaGroupLink._(validated);
    // Apply the same outer grammar and URI length limit as imported links.
    return BoorusamaGroupLink.parse(link.uri.toString());
  }

  final ContentReference reference;

  Uri get uri => Uri(
    scheme: 'boorusama',
    host: 'group',
    path: BoorusamaPostLink.routePath,
    queryParameters: {
      'v': '1',
      'engine': reference.engine.yamlName,
      'site': reference.site.toString(),
      'key': reference.sourceKey,
    },
  );

  static BoorusamaGroupLink? tryParse(String value) {
    try {
      return BoorusamaGroupLink.parse(value);
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [reference];
}
