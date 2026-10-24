import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

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
    Iterable<String> artists = const [],
  }) => postLinkShareMessage(
    BoorusamaPostLink.parse(uri),
    profileName: profileName,
    postTemplate: t.post.app_link.share_post_caption,
    postByArtistTemplate: t.post.app_link.share_post_artist_caption,
    artists: artists,
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
