import 'dart:convert';
import 'dart:math' as math;

import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/groups/group_envelope_cache.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/errors/types.dart';
import '../posts/types.dart';
import 'work_mapper.dart';

/// One captured Pixiv actor owns its shared artwork envelope and Page manifest.
/// Native listing responses may seed that envelope without an extra detail read.
final class PixivWorkSource extends ContentGroupSource {
  PixivWorkSource({
    required this.access,
    required this.fetchWork,
    this.blacklist = const {},
  }) : _envelopes = GroupEnvelopeCache(access: access.key) {
    if (access.key.engine != BooruType.pixiv ||
        access.key.profileId == null ||
        access.config == null) {
      throw const FormatException('Pixiv Works require their captured account');
    }
  }

  @override
  final ContentAccessContext access;
  final Set<String> blacklist;
  final Future<PixivIllustDto?> Function(int illustId) fetchWork;
  final GroupEnvelopeCache<PixivIllustDto> _envelopes;
  final _cancellation = CancelToken();
  final _cursorScope = const Uuid().v4();
  final _generations = <ContentReference, int>{};
  var _disposed = false;

  void _require(ContentReference reference) {
    if (_disposed ||
        !access.accepts(reference) ||
        reference.kind != ContentKind.group) {
      throw const FormatException('Foreign or unavailable Pixiv Work');
    }
    const BooruContentKeyCodec(BooruType.pixiv)
        .canonicalize(ContentKind.group, reference.sourceKey);
  }

  void seedWork(PixivIllustDto dto) {
    final summary = pixivWorkSummary(dto, access);
    _require(summary.reference);
    _requireVisible(dto);
    _seeded.add(summary.reference);
    _envelopes.seed(summary.reference, dto);
  }

  void invalidateAll() {
    for (final reference in _seeded.toList()) invalidate(reference);
    _seeded.clear();
  }

  final _seeded = <ContentReference>{};

  Future<PixivIllustDto> _work(ContentReference reference) {
    _require(reference);
    return _envelopes
        .load(reference, () async {
          final id = int.parse(reference.sourceKey.split(':').last);
          final dto = await fetchWork(id);
          if (_disposed ||
              dto == null ||
              dto.id != id ||
              !pixivWorkIsVisible(dto) ||
              PixivIllustType.parse(dto.type) == PixivIllustType.ugoira) {
            throw StateError('Pixiv Work unavailable');
          }
          return dto;
        })
        .then((dto) {
          _requireVisible(dto);
          return dto;
        });
  }

  void _requireVisible(PixivIllustDto dto) {
    final rating = Rating.parse(pixivWorkVisibility(dto).rating);
    if (!pixivWorkIsVisible(dto) ||
        !groupAllowsRating(access.config!, rating) ||
        !groupTagsPassBlacklist(
          pixivWorkTags(dto),
          blacklist,
          rating: rating,
          sourceId: dto.id,
          sourceUrl: access.baseUrl.toString(),
        )) {
      throw StateError('Pixiv Work is filtered by the current source policy');
    }
  }

  TaskEither<BooruError, T> _read<T>(Future<T> Function() action) =>
      TaskEither.tryCatch(
        () => runGroupRead(
          this,
          () => TaskEither.tryCatch(action, _error),
          token: _cancellation,
          current: () => !_disposed,
        ),
        _error,
      );

  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => _read(() async => pixivWorkSummary(await _work(reference), access));

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => _read(() async => pixivWorkDetails(await _work(reference), access));

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => _read(() async {
    _require(query.reference);
    if (query.orderKey != null && query.orderKey != 'order') {
      throw const FormatException('Unsupported Pixiv Page order');
    }
    final generation = _generations[query.reference] ?? 0;
    final limit = (query.requestedLimit ?? 40).clamp(1, 200);
    var offset = 0;
    if (query.cursor case final cursor?) {
      final value = jsonDecode(cursor.token);
      if (value is! List ||
          value.length != 5 ||
          value[0] != _cursorScope ||
          value[1] != query.reference.sourceKey ||
          value[2] != generation ||
          value[3] is! int ||
          value[3] <= 0 ||
          value[4] != limit) {
        throw const FormatException('Invalid Pixiv Page cursor');
      }
      offset = value[3] as int;
    }
    final dto = await _work(query.reference);
    final posts = pixivWorkPagePosts(dto, access);
    if (dto.pageCount case final declared? when declared > 0) {
      if (dto.metaPages.length > declared ||
          posts.any((post) => post.pageIndex >= declared)) {
        throw const FormatException('Inconsistent Pixiv Page manifest');
      }
    }
    final count = math.max(
      dto.pageCount != null && dto.pageCount! > 0 ? dto.pageCount! : 0,
      math.max(
        dto.metaPages.length,
        posts.isEmpty ? 0 : posts.last.pageIndex + 1,
      ),
    );
    if (count == 0) {
      throw StateError('Pixiv Page manifest unavailable');
    }
    if (offset >= count) {
      throw const FormatException('Pixiv Page cursor past manifest');
    }
    final end = math.min(offset + limit, count);
    final byIndex = {for (final post in posts) post.pageIndex: post};
    final members = [
      for (var index = offset; index < end; index++)
        GroupMember(
          reference: pixivPageReference(access, dto.id!, index),
          memberKey: 'work-page:${dto.id}:$index',
          sourcePosition: index,
          availability: byIndex[index] == null || byIndex[index]!.isRestricted
              ? MemberAvailability.unavailable
              : MemberAvailability.available,
        ),
    ];
    return validateGroupMemberBatch(query, (
      page: ContentPage(
        items: members,
        total: dto.pageCount != null && dto.pageCount! > 0
            ? dto.pageCount
            : null,
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
          if (member.availability == MemberAvailability.available)
            PostContentEntry(
              reference: member.reference,
              post: byIndex[member.sourcePosition]!,
            ),
      ],
    ));
  });

  @override
  void invalidate(ContentReference reference) {
    _require(reference);
    _generations.update(reference, (value) => value + 1, ifAbsent: () => 1);
    _envelopes.invalidate(reference);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancellation.cancel('Pixiv Work source disposed');
    _envelopes.dispose();
  }

  static BooruError _error(Object error, StackTrace stack) =>
      error is BooruError
      ? error
      : UnknownError(error: error, message: 'Unable to load Pixiv Work');
}
