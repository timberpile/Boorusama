import '../content_access.dart';
import '../content_reference.dart';
import 'owned_read_cache.dart';

/// Source-owned Details/member envelopes share the common safe-read ownership.
final class GroupEnvelopeCache<T> {
  GroupEnvelopeCache({required this.access, this.maxEntries = 16}) {
    _reads = OwnedReadCache<ContentReference, T>(
      maxEntries: maxEntries,
      validateKey: (reference) =>
          reference.kind == ContentKind.group &&
          reference.engine == access.engine &&
          reference.siteNamespace == access.siteNamespace,
    );
  }
  final ContentAccessKey access;
  final int maxEntries;
  late final OwnedReadCache<ContentReference, T> _reads;
  bool seed(
    ContentReference reference,
    T value, {
    bool replaceExisting = false,
  }) => _reads.seed(reference, value, replaceExisting: replaceExisting);
  Future<T> load(ContentReference reference, Future<T> Function() loader) =>
      _reads.load(reference, loader);
  void invalidate(ContentReference reference) => _reads.invalidate(reference);
  void dispose() => _reads.dispose();
}
