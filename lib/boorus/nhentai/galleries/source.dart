import 'dart:convert';
import 'dart:math' as math;

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/content/groups/group_envelope_cache.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/errors/types.dart';
import '../../../core/posts/post/types.dart';
import '../posts/data.dart';
import 'mapper.dart';

final class NhentaiGallerySource extends ContentGroupSource {
  NhentaiGallerySource({
    required this.access,
    required this.fetchGallery,
    required this.mediaPolicy,
  }) : _envelopes = GroupEnvelopeCache(access: access.key);
  @override
  final ContentAccessContext access;
  final Future<NhentaiGalleryDetails> Function(int id) fetchGallery;
  final Future<NhentaiMediaPolicy> Function() mediaPolicy;
  GroupEnvelopeCache<NhentaiGalleryDetails> _envelopes;
  final _lifetime = CancelToken();
  var _cursorScope = const Uuid().v4();
  final _generations = <ContentReference, int>{};
  final _summaries = <ContentReference, ContentGroupSummary>{};
  var _disposed = false;

  void _require(ContentReference reference) {
    if (_disposed ||
        !access.accepts(reference) ||
        reference.kind != ContentKind.group ||
        !reference.sourceKey.startsWith('gallery:')) {
      throw const FormatException('Unavailable nhentai Gallery');
    }
    const ContentReferenceCodec()
        .codecFor(reference.engine)
        .canonicalize(ContentKind.group, reference.sourceKey);
  }

  void seedSummary(ContentGroupSummary summary) {
    _require(summary.reference);
    if (_generations.containsKey(summary.reference)) return;
    if (_summaries.containsKey(summary.reference)) return;
    if (_summaries.length >= 32) {
      _summaries.remove(_summaries.keys.first);
    }
    _summaries[summary.reference] = summary;
  }

  Future<NhentaiGalleryDetails> gallery(ContentReference reference) {
    _require(reference);
    return _envelopes.load(reference, () async {
      final id = int.parse(reference.sourceKey.split(':').last);
      final result = await fetchGallery(id);
      if (_disposed || result.id != id) {
        throw const FormatException('Foreign nhentai Gallery response');
      }
      return result;
    });
  }

  TaskEither<BooruError, T> _read<T>(
    ContentReference reference,
    Future<T> Function() read,
  ) => TaskEither.tryCatch(() {
    final scope = _cursorScope;
    final generation = _generations[reference];
    return runGroupRead(
      this,
      () => TaskEither.tryCatch(read, _error),
      token: _lifetime,
      current: () =>
          !_disposed &&
          _cursorScope == scope &&
          _generations[reference] == generation,
    );
  }, _error);

  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => _read(reference, () async {
    _require(reference);
    final seeded = _summaries[reference];
    if (seeded != null) return seeded;
    return nhentaiGalleryDetails(
      await gallery(reference),
      access,
      await mediaPolicy(),
    ).summary;
  });

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => _read(
    reference,
    () async => nhentaiGalleryDetails(
      await gallery(reference),
      access,
      await mediaPolicy(),
    ),
  );

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => _read(query.reference, () async {
    _require(query.reference);
    if (query.orderKey != null && query.orderKey != 'order') {
      throw const FormatException('Unsupported Gallery Page order');
    }
    final limit = (query.requestedLimit ?? 40).clamp(1, 200);
    final generation = _generations[query.reference] ?? 0;
    var offset = 0;
    if (query.cursor case final cursor?) {
      final parts = jsonDecode(cursor.token);
      if (parts is! List ||
          parts.length != 5 ||
          parts[0] != _cursorScope ||
          parts[1] != query.reference.sourceKey ||
          parts[2] != generation ||
          parts[3] is! int ||
          parts[3] < 1 ||
          parts[4] != limit) {
        throw const FormatException('Invalid Gallery Page cursor');
      }
      offset = parts[3] as int;
    }
    final dto = await gallery(query.reference);
    final manifest = dto.pages;
    if (manifest != null && manifest.isEmpty && dto.pageCount == 0) {
      if (query.cursor != null) {
        throw const FormatException('Gallery cursor past end');
      }
      return validateGroupMemberBatch(query, (
        page: ContentPage(items: const [], total: 0),
        resolved: const [],
      ));
    }
    if (manifest == null || manifest.isEmpty) {
      throw StateError('Gallery Page manifest unavailable');
    }
    final count = math.max(
      dto.pageCount ?? 0,
      manifest.map((page) => page.number).reduce(math.max),
    );
    if (dto.pageCount != null &&
        manifest.any((page) => page.number > dto.pageCount!)) {
      throw const FormatException('Inconsistent Gallery Page manifest');
    }
    if (offset >= count) throw const FormatException('Gallery cursor past end');
    // Source numbering carries gaps. Preserve listed order among present
    // Pages and leave missing-number positions explicitly unavailable.
    final sortedNumbers = manifest.map((page) => page.number).toList()..sort();
    final inManifestOrder = {
      for (final (index, page) in manifest.indexed)
        sortedNumbers[index]: page.number,
    };
    final posts = nhentaiGalleryPosts(dto, access, await mediaPolicy());
    final byNumber = {
      for (final post in posts)
        (post.booruData as NhentaiPostData).pageNumber: post,
    };
    final end = math.min(offset + limit, count);
    final members = [
      for (var slot = offset + 1; slot <= end; slot++)
        _member(dto.id, inManifestOrder[slot] ?? slot, byNumber),
    ];
    return validateGroupMemberBatch(query, (
      page: ContentPage(
        items: members,
        total: dto.pageCount,
        next: end < count
            ? ContentCursor(
                jsonEncode([
                  _cursorScope,
                  query.reference.sourceKey,
                  generation,
                  end,
                  limit,
                ]),
              )
            : null,
      ),
      resolved: [
        for (final member in members)
          if (byNumber[member.sourcePosition! + 1] case final post?)
            PostContentEntry(reference: member.reference, post: post),
      ],
    ));
  });

  GroupMember _member(int galleryId, int number, Map<int, Post> posts) {
    final reference = nhentaiPageReference(access, galleryId, number);
    return GroupMember(
      reference: reference,
      memberKey: reference.sourceKey,
      sourcePosition: number - 1,
      availability: posts.containsKey(number)
          ? MemberAvailability.available
          : MemberAvailability.unavailable,
    );
  }

  @override
  void invalidate(ContentReference reference) {
    _require(reference);
    _generations.update(reference, (value) => value + 1, ifAbsent: () => 1);
    _summaries.remove(reference);
    _envelopes.invalidate(reference);
  }

  void invalidateAll() {
    if (_disposed) return;
    _envelopes.dispose();
    _envelopes = GroupEnvelopeCache(access: access.key);
    _summaries.clear();
    _generations.clear();
    _cursorScope = const Uuid().v4();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lifetime.cancel('nhentai Gallery source disposed');
    _envelopes.dispose();
  }

  static BooruError _error(Object error, StackTrace stack) =>
      error is BooruError
      ? error
      : UnknownError(error: error, message: 'Unable to load Gallery');
}
