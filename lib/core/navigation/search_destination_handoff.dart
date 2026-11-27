import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../search/search/src/routes/params.dart';
import '../search/selected_tags/types.dart';
import 'destination_id.dart';
import 'navigation_controller.dart';

Future<void> switchSearchDestination(
  BuildContext context,
  NavigationController navigation,
  DestinationId destination,
  String applied,
) async {
  final (terms, omitted) = portableSearchTerms(applied);
  final profile = destination.profileId;
  final params = terms.isEmpty
      ? null
      : SearchParams(tags: SearchTagSet.fromList(terms));
  final location = switch (params) {
    final params? => Uri(
      path:
          '${destination.location}/${profile == null ? 'local-media-search' : 'search'}',
      queryParameters: {
        ...params.toQueryParams(),
        '_profile': ?profile,
      },
    ),
    null when omitted => Uri.parse(destination.location),
    null => null,
  };
  // The fresh params object also re-seeds a retained destination search when
  // the new handoff has the same URL as its original query.
  final notice = omitted ? context.t.navigation.search_filters_omitted : null;
  final root = Navigator.of(context, rootNavigator: true);
  final accepted = profile == null
      ? await navigation.selectDestination(
          destination,
          location: location,
          extra: params,
        )
      : await navigation.selectBrowseProfile(
          profile,
          location: location,
          extra: params,
        );
  if (accepted && notice != null && root.mounted) {
    Kurumi.showSimpleSnackBar(context: root.context, content: Text(notice));
  }
}

final _groupStart = RegExp(r'(?:^[~+\-]*|:)[({\[]');
final _groupCharacters = RegExp(r'[(){}\[\]"]');
final _nonPortable = RegExp(r'[\s:*?~+|&!<>=\[\]{}"\\]');

/// Carry plain exact tags and exclusions across search engines.
(List<String>, bool) portableSearchTerms(String applied) {
  final terms = <String>[];
  var omitted = false;
  var depth = 0;
  var quoted = false;
  for (final token in queryAsList(applied)) {
    if (depth > 0 ||
        quoted ||
        token.contains('"') ||
        _groupStart.hasMatch(token)) {
      for (final match in _groupCharacters.allMatches(token)) {
        switch (match.group(0)) {
          case '"':
            quoted = !quoted;
          case '(' || '{' || '[' when !quoted:
            depth++;
          case ')' || '}' || ']' when !quoted && depth > 0:
            depth--;
        }
      }
      omitted = true;
      continue;
    }
    final tag = token.startsWith('-') ? token.substring(1) : token;
    if (tag.isEmpty || tag.startsWith('-') || _nonPortable.hasMatch(tag)) {
      omitted = true;
      continue;
    }
    terms.add(token);
  }
  return (terms, omitted);
}
