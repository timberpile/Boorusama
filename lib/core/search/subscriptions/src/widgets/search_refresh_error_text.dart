import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../types/search_refresh.dart';

String searchRefreshErrorText(
  BuildContext context,
  SearchRefreshErrorKind kind,
) {
  final strings = context.t.pinned_searches;
  return switch (kind) {
    SearchRefreshErrorKind.network => strings.error_network,
    SearchRefreshErrorKind.authentication => strings.error_authentication,
    SearchRefreshErrorKind.query => strings.error_query,
    SearchRefreshErrorKind.pagination => strings.error_pagination,
    SearchRefreshErrorKind.parsing => strings.error_parsing,
    SearchRefreshErrorKind.unsupported => strings.error_unsupported,
    SearchRefreshErrorKind.other => strings.error_other,
    SearchRefreshErrorKind.tagLimit => strings.error_tag_limit,
    SearchRefreshErrorKind.rateLimited => strings.error_rate_limited,
  };
}
