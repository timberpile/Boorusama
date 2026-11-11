import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../../content/types.dart';
import '../../../post/types.dart';
import 'pool_details_order.dart';

/// Bridges the existing Pool manifest into shared membership values. Positions
/// belong to the source manifest, before display sorting or Post filtering.
final class PoolGroupMembers {
  PoolGroupMembers({required this.access, required this.fetchPosts});

  final ContentAccessContext access;
  final Future<List<Post>> Function(List<int> ids) fetchPosts;
  final _cursorScope = const Uuid().v4();
  final _resolved = <ContentReference, PostContentEntry>{};
  var _disposed = false;
  final _generations = <ContentReference, int>{};

  void invalidate(ContentReference reference) {
    _generations.update(reference, (value) => value + 1, ifAbsent: () => 1);
    // Refresh drops reusable Post facts, but only revokes pending reads of the
    // refreshed Group. Other Groups sharing this source may finish normally.
    _resolved.clear();
  }

  void dispose() {
    _disposed = true;
    _resolved.clear();
    _generations.clear();
  }

  Future<GroupMemberBatch> load(
    GroupMemberQuery query, {
    required List<int>? ids,
    required int defaultLimit,
    int? indexedPage,
  }) async {
    if (_disposed ||
        !access.accepts(query.reference) ||
        query.reference.kind != ContentKind.group) {
      throw const FormatException('Foreign Pool membership request');
    }
    final generation = _generations[query.reference] ?? 0;
    // An omitted manifest is not proof that a source Group is empty.
    if (ids == null) throw StateError('Pool membership is unknown');
    if (ids.any((id) => id <= 0)) {
      throw const FormatException('Invalid Pool member identity');
    }
    final order = switch (query.orderKey) {
      null || 'order' => PoolDetailsOrder.order,
      'oldest' => PoolDetailsOrder.oldest,
      'latest' => PoolDetailsOrder.latest,
      _ => throw const FormatException('Unsupported Pool member order'),
    };
    final revision = sha256.convert(utf8.encode(jsonEncode(ids))).toString();
    if (indexedPage != null && (indexedPage < 1 || query.cursor != null)) {
      throw const FormatException('Invalid indexed Pool page');
    }
    var offset = 0;
    var limit = (query.requestedLimit ?? defaultLimit).clamp(1, 200);
    if (query.cursor case final cursor?) {
      final value = jsonDecode(cursor.token);
      if (value is! List ||
          value.length != 7 ||
          value[0] != _cursorScope ||
          value[1] != query.reference.sourceKey ||
          value[2] != order.name ||
          value[3] != revision ||
          value[4] is! int ||
          value[5] is! int ||
          value[6] != 1) {
        throw const FormatException('Invalid Pool cursor');
      }
      offset = value[4] as int;
      limit = value[5] as int;
      if (offset <= 0 ||
          offset >= ids.length ||
          limit < 1 ||
          limit > 200 ||
          offset % limit != 0 ||
          (query.requestedLimit != null &&
              query.requestedLimit!.clamp(1, 200) != limit)) {
        throw const FormatException('Invalid Pool cursor range');
      }
    }
    if (indexedPage != null) {
      offset = ((indexedPage - 1) * limit).clamp(0, ids.length);
    }
    final positions = List.generate(ids.length, (index) => index);
    if (order != PoolDetailsOrder.order) {
      positions.sort((a, b) {
        final comparison = order == PoolDetailsOrder.oldest
            ? ids[a].compareTo(ids[b])
            : ids[b].compareTo(ids[a]);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    }
    final end = (offset + limit).clamp(0, ids.length);
    final slice = positions.sublist(offset, end);
    final requested = slice.map((position) => ids[position]).toSet();
    ContentReference reference(int id) => const ContentReferenceCodec().parse(
      engine: query.reference.engine,
      site: query.reference.site,
      kind: ContentKind.post,
      sourceKey: 'id:$id',
    );
    final hydrated = <int, PostContentEntry>{};
    for (final id in requested) {
      final cached = _resolved.remove(reference(id));
      if (cached != null) {
        _resolved[reference(id)] = cached;
        hydrated[id] = cached;
      }
    }
    final missing = requested.where((id) => !hydrated.containsKey(id)).toList();
    final posts = missing.isEmpty ? const <Post>[] : await fetchPosts(missing);
    if (_disposed || generation != (_generations[query.reference] ?? 0)) {
      throw StateError('Pool source changed');
    }
    for (final post in posts) {
      if (!requested.contains(post.id) || hydrated.containsKey(post.id))
        continue;
      hydrated[post.id] = PostContentEntry(
        reference: reference(post.id),
        post: post,
      );
      _resolved[reference(post.id)] = hydrated[post.id]!;
      if (_resolved.length > 512) _resolved.remove(_resolved.keys.first);
    }
    return (
      page: ContentPage(
        items: [
          for (final position in slice)
            GroupMember(
              reference: reference(ids[position]),
              memberKey: 'manifest:$revision:$position',
              sourcePosition: position,
              availability: hydrated.containsKey(ids[position])
                  ? MemberAvailability.available
                  : MemberAvailability.unknown,
            ),
        ],
        total: ids.length,
        next: end >= ids.length
            ? null
            : ContentCursor(
                jsonEncode([
                  _cursorScope,
                  query.reference.sourceKey,
                  order.name,
                  revision,
                  end,
                  limit,
                  1,
                ]),
              ),
      ),
      resolved: hydrated.values.toList(growable: false),
    );
  }
}
