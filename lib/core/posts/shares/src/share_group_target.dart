import '../../../boorus/booru/types.dart';
import '../../../content/content_access.dart';
import '../../links/boorusama_group_link.dart';
import '../../post/types.dart';

/// The authorized Group occurrence captured before opening a share route.
final class ShareGroupTarget {
  const ShareGroupTarget({
    required this.link,
    required this.access,
    this.groupName,
    this.author,
  });

  final BoorusamaGroupLink link;
  final ContentAccessContext access;
  final String? groupName;
  final String? author;

  String? get profileName =>
      access.key.profileId == null ? null : access.config?.name;

  ({String id, Uri url})? get pixivArtwork {
    final reference = link.reference;
    if (reference.engine != BooruType.pixiv) return null;
    final id = RegExp(r'^work:([1-9][0-9]*)$')
        .firstMatch(reference.sourceKey)?[1];
    return id == null
        ? null
        : (id: id, url: Uri.https('www.pixiv.net', '/artworks/$id'));
  }

  bool matchesPixivPage(Post post) {
    final artwork = pixivArtwork;
    final hint = post.origin.profileIdHint;
    return artwork != null &&
        post.origin.booruType == BooruType.pixiv &&
        post.origin.sourceHost == link.reference.siteNamespace &&
        post.sitePostId == artwork.id &&
        (hint == null || hint == access.key.profileId);
  }

  Uri? get poolUrl {
    final reference = link.reference;
    if (reference.engine != BooruType.danbooru) return null;
    final match = RegExp(r'^pool:([1-9][0-9]*)$')
        .firstMatch(reference.sourceKey);
    if (match == null) return null;
    final site = reference.site;
    final base = site.path.endsWith('/') ? site.path : '${site.path}/';
    return site.replace(path: '${base}pools/${match[1]}');
  }
}
