import 'package:flutter/widgets.dart';

import '../../boorus/booru/types.dart';
import '../content_access.dart';
import '../content_reference.dart';
import 'group_details.dart';
import 'group_metadata.dart';
import 'group_source.dart';
import 'group_summary.dart';

enum GroupLayout { memberGrid, mediaPager }

/// Presentation stays at the UI boundary; reference/metadata codecs import no widgets.
abstract interface class BooruGroupPresentation {
  bool supports(ContentGroupSummary summary);
  GroupLayout layoutFor(ContentGroupSummary summary);
  String memberLabel(BuildContext context, ContentGroupSummary summary);
  Widget buildCard(BuildContext context, ContentGroupSummary summary);
  Widget buildDetails(BuildContext context, ContentGroupDetails details);
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
  final ContentGroupSource Function(ContentAccessContext access) createSource;
  final BooruGroupPresentation presentation;
}
