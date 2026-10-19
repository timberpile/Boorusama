import 'destination_id.dart';
import 'page_source_context.dart';

final class NavigationPageRequest {
  const NavigationPageRequest({
    required this.logicalUri,
    required this.origin,
    this.extra,
    this.source,
  });
  final Uri logicalUri;
  final DestinationId origin;
  // Keep existing typed payloads intact for their existing page factories.
  final Object? extra;
  final PageSourceContext? source;
}
