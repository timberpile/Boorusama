import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/booru/types.dart';
import '../content_access.dart';
import '../content_reference.dart';
import 'group_details.dart';
import 'group_metadata.dart';
import 'group_source.dart';
import 'group_summary.dart';
import '../../posts/post/types.dart';

enum GroupLayout { memberGrid, mediaPager }

/// Presentation stays at the UI boundary; reference/metadata codecs import no widgets.
abstract interface class BooruGroupPresentation {
  bool supports(ContentGroupSummary summary);
  GroupLayout layoutFor(ContentGroupSummary summary);
  String memberLabel(BuildContext context, ContentGroupSummary summary);
  Widget buildCard(BuildContext context, ContentGroupSummary summary);
  Widget buildDetails(BuildContext context, ContentGroupDetails details);
}

/// Optional source-owned Group actions which remain valid before Details load.
/// These are never inherited Post download/favorite/media actions.
abstract interface class BooruGroupStatusPresentation {
  List<Widget> buildStatusActions(
    BuildContext context,
    ContentGroupSummary summary,
  );
}

/// Source-bound facts for local Group and optional current-Page actions.
final class GroupBookmarkPresentationData {
  const GroupBookmarkPresentationData({
    required this.access,
    required this.summary,
    this.details,
    this.page,
  });
  final ContentAccessContext access;
  final ContentGroupSummary summary;
  final ContentGroupDetails? details;
  final Post? page;
}

/// Engine-owned local actions compose into common media and native cards.
abstract interface class BooruMediaGroupBookmarkPresentation {
  Widget buildBookmarkButton(
    BuildContext context,
    GroupBookmarkPresentationData data,
  );
  List<Widget> buildBookmarkMenuItems(
    BuildContext context,
    GroupBookmarkPresentationData data,
  );
  Widget wrapBookmarkMenu(
    BuildContext context,
    GroupBookmarkPresentationData data,
    Widget child,
  );
}

abstract interface class BooruGroupKindPresentation {
  String kindLabel(BuildContext context, ContentGroupSummary summary);
}

final class BooruGroupCapability {
  BooruGroupCapability({
    required this.engine,
    required this.keyCodec,
    this.dataCodec,
    required this.createSource,
    required this.presentation,
  }) {
    if (keyCodec.engine != engine ||
        (dataCodec != null && dataCodec!.engine != engine)) {
      throw const FormatException('Incompatible Group capability');
    }
  }
  final BooruType engine;
  final ContentKeyCodec keyCodec;
  final BooruGroupDataCodec? dataCodec;

  /// Use the caller's scope for registry-backed policy and client reads.
  /// Capturing the registration Ref can make the registry depend on itself.
  final ContentGroupSource Function(Ref ref, ContentAccessContext access)
  createSource;
  final BooruGroupPresentation presentation;
}
