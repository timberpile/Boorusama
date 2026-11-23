import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'boorusama_group_link.dart';
import 'boorusama_post_link.dart';
import 'boorusama_search_link.dart';
import 'link_share_message.dart';

/// Labels and localized captions for portable link-file sharing.
extension LinkFileLabels on BuildContext {
  String get linkFileLabel => t.post.action.boorusama_link;
  String get openLinkFileLabel => '${t.post.app_link.open} (.bslink)';

  String postLinkFileMessage(
    String uri, {
    required String profileName,
    String? author,
    Iterable<String> artists = const [],
  }) => postLinkShareMessage(
    BoorusamaPostLink.parse(uri),
    profileName: profileName,
    postTemplate: t.post.app_link.share_post_caption,
    postByArtistTemplate: t.post.app_link.share_post_artist_caption,
    author: author,
    artists: artists,
  );

  String groupLinkFileMessage(
    BoorusamaGroupLink link, {
    required String? profileName,
    required String? groupName,
    required String? author,
  }) => groupLinkShareMessage(
    link,
    profileName: profileName,
    groupName: groupName,
    author: author,
    groupTemplate: t.post.app_link.share_group_caption,
    pixivWorkByArtistTemplate: t.post.app_link.share_pixiv_work_caption,
    unnamedGroupTemplate: switch (link.reference.sourceKey.split(':').first) {
      'pool' => t.post.app_link.share_pool_name,
      'related' => t.post.app_link.share_related_name,
      _ => t.post.app_link.share_work_name,
    },
  );

  String searchLinkFileMessage(
    BoorusamaSearchLink link, {
    required String profileName,
  }) => searchLinkShareMessage(
    link,
    profileName: profileName,
    searchTemplate: t.search.app_link.share_search_caption,
  );
}
