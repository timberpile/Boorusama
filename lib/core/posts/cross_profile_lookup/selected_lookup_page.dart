import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../blacklists/providers.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../content/content_access.dart';
import '../../content/content_access_provider.dart';
import '../post/providers.dart';
import '../post/types.dart';
import 'iqdb_lookup.dart';
import 'iqdb_remote_image.dart';
import 'iqdb_signature.dart';
import 'lookup_preferences.dart';
import 'providers.dart';
import 'results.dart';
import 'types.dart';

class SelectedLookupRequest {
  const SelectedLookupRequest({
    required this.targets,
    required this.permission,
    this.source,
    this.access,
    this.md5,
    this.localSignature,
  });

  final List<LookupTarget> targets;
  final IqdbPermission permission;
  final Post? source;
  final ContentAccessContext? access;
  final String? md5;
  final Future<String?> Function(bool Function() stopped)? localSignature;
}

typedef _Section = (LookupTarget, PostLookupMatchKind);

class SelectedLookupPage extends ConsumerStatefulWidget {
  const SelectedLookupPage({required this.request, super.key});

  final SelectedLookupRequest request;

  @override
  ConsumerState<SelectedLookupPage> createState() => _SelectedLookupPageState();
}

class _SelectedLookupPageState extends ConsumerState<SelectedLookupPage> {
  final _queue = CrossProfileLookupQueue();
  final _rows = <_Section, CrossProfileResult>{};
  final _pages = <_Section, int>{};
  final _invalidated = <_Section>{};
  Future<String?>? _signature;
  var _iqdbRevoked = false;

  Iterable<_Section> get _sections => [
    for (final target in widget.request.targets)
      for (final method in PostLookupMatchKind.values)
        if (target.methods.contains(method)) (target, method),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final section in _sections) {
        unawaited(_load(section));
      }
    });
  }

  bool _available(_Section section, {bool requirePermission = true}) {
    if (!mounted || _invalidated.contains(section)) return false;
    final (target, method) = section;
    final preferences = ref.read(lookupPreferencesProvider);
    final access = widget.request.access;
    return ref.read(booruConfigProvider).contains(target.profile) &&
        stillSelected(preferences, target, method) &&
        (access == null ||
            identical(
              ref.read(contentAccessContextProvider(access.key)),
              access,
            )) &&
        (!requirePermission ||
            method != PostLookupMatchKind.similarImage ||
            (!_iqdbRevoked && preferences.permits(widget.request.permission)));
  }

  Future<String?> _getSignature() =>
      _signature ??= iqdbSignatureQueue.run(() async {
        bool stopped() =>
            !mounted ||
            !_sections.any(
              (section) =>
                  section.$2 == PostLookupMatchKind.similarImage &&
                  _available(section),
            );
        if (stopped()) return null;
        final request = widget.request;
        if (request.localSignature case final fromLocal?) {
          return fromLocal(stopped);
        }
        if (request.access case final access?) {
          return remoteIqdbSignature(ref, request.source!, access, stopped);
        }
        return null;
      });

  Future<void> _load(_Section section, {bool more = false}) async {
    if (!_available(section)) return;
    final (target, method) = section;
    final profile = target.profile;
    final previous = _rows[section];
    if (previous?.status == CrossProfileResultStatus.loading) return;
    final page = more ? (_pages[section] ?? 0) + 1 : 1;
    setState(
      () => _rows[section] = CrossProfileResult(
        profile: profile,
        status: CrossProfileResultStatus.loading,
        matchKind: method,
        posts: more ? previous?.posts ?? [] : [],
      ),
    );
    final cancellation = PostLookupCancellation(
      shouldCancel: () => !_available(section),
    );
    var scores = <int, double>{};
    final result = await _queue.run<PostLookupResult>(() async {
      if (cancellation.isCancelled) return const PostLookupCancelled();
      try {
        if (method == PostLookupMatchKind.similarImage) {
          final pending = _getSignature();
          final signature = await pending;
          if (cancellation.isCancelled) return const PostLookupCancelled();
          if (signature == null) {
            if (identical(_signature, pending)) _signature = null;
            return const PostLookupUnavailable(
              PostLookupUnavailableReason.missingHash,
            );
          }
          final hits = await ref.read(iqdbSearchProvider)(
            target,
            signature,
            widget.request.permission,
            () => cancellation.isCancelled,
          );
          if (hits == null) return const PostLookupInvalidResponse();
          final posts = rankIqdbHits(hits, defaultIqdbThreshold).visible;
          scores = {for (final hit in posts) hit.post!.id: hit.score};
          return PostLookupPage(
            targetOrigin: postOriginFromConfig(profile),
            posts: [for (final hit in posts) hit.post!],
            page: 1,
            hasMore: false,
            hasFilteredMatches: hits.any((hit) => hit.post == null),
            matchKind: method,
          );
        }
        if (widget.request.source case final source?) {
          return await ref
              .read(crossProfileLookupSessionProvider(source))
              .findMethod(
                profile,
                method,
                page: page,
                cancellation: cancellation,
              );
        }
        return await ref.read(localFileHashLookupProvider)(
          profile,
          widget.request.md5!,
          page: page,
          cancellation: cancellation,
        );
      } catch (_) {
        return const PostLookupInvalidResponse();
      }
    });
    if (!_available(section)) return;
    final posts = <int, Post>{
      if (more)
        for (final post in previous?.posts ?? <Post>[]) post.id: post,
      if (result is PostLookupPage)
        for (final post in result.posts) post.id: post,
    }.values.toList();
    final status = switch (result) {
      PostLookupPage(:final hasMore) =>
        posts.isEmpty && !hasMore
            ? CrossProfileResultStatus.noMatch
            : CrossProfileResultStatus.success,
      PostLookupUnavailable(reason: PostLookupUnavailableReason.missingHash) =>
        CrossProfileResultStatus.missingHash,
      _ => CrossProfileResultStatus.error,
    };
    setState(() {
      _rows[section] = CrossProfileResult(
        profile: profile,
        status: status,
        matchKind: method,
        posts: posts,
        hasMore: result is PostLookupPage && result.hasMore,
        scores: scores,
      );
      if (result is PostLookupPage) _pages[section] = result.page;
    });
  }

  Future<void> _open(_Section section, Post post) async {
    if (!_available(section)) return;
    await openCrossProfileResults(
      ref,
      [
        for (final candidate in _sections)
          if (_available(candidate)) ?_rows[candidate],
      ],
      section.$1.profile,
      post,
      canOpen: (row) => _sections.any(
        (candidate) =>
            identical(_rows[candidate], row) && _available(candidate),
      ),
    );
  }

  void _invalidate() {
    _invalidated.addAll(
      _sections.where(
        (section) => !_available(section, requirePermission: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    if (request.source case final source?) {
      ref.watch(crossProfileLookupSessionProvider(source));
    }
    ref.listen(booruConfigProvider, (_, _) => _invalidate());
    ref.listen(lookupPreferencesProvider, (_, next) {
      if (request.permission == IqdbPermission.persistent && !next.allowIqdb) {
        _iqdbRevoked = true;
      }
      _invalidate();
    });
    if (request.access case final access?) {
      final provider = contentAccessContextProvider(access.key);
      ref.watch(provider);
      ref.listen(provider, (_, _) => _invalidate());
    }
    ref.watch(lookupPreferencesProvider);
    final profiles = ref.watch(booruConfigProvider);
    final sections = _sections
        .where(
          (section) => _available(section, requirePermission: false),
        )
        .toList();
    return Scaffold(
      appBar: KurumiAppBar(title: Text(context.t.post.cross_profile.action)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (request.source case final source?)
              Text('#${source.sitePostId ?? source.id}'),
            if (sections.isEmpty)
              Text(context.t.post.cross_profile.no_profiles),
            for (final target in request.targets)
              if (profiles.contains(target.profile) &&
                  sections.any((section) => section.$1 == target)) ...[
                const SizedBox(height: 12),
                Text(
                  target.profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final section in sections.where(
                  (section) => section.$1 == target,
                ))
                  _section(context, section),
              ],
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, _Section section) {
    final (target, method) = section;
    final visibility = ref.watch(blacklistTagsProvider(target.profile.filter));
    final tags = visibility.isLoading ? null : visibility.asData?.value;
    final row = _rows[section];
    return CrossProfileResultSection(
      key: ValueKey((target.profile.id, method)),
      showMethod: true,
      result: CrossProfileResult(
        profile: target.profile,
        status: _available(section)
            ? row?.status ?? CrossProfileResultStatus.loading
            : CrossProfileResultStatus.permissionRequired,
        matchKind: method,
        posts: tags == null || !_available(section)
            ? []
            : [
                for (final post in row?.posts ?? <Post>[])
                  if (isExactLookupPostVisible(post, target.profile, tags))
                    post,
              ],
        hasMore: row?.hasMore,
        scores: row?.scores ?? {},
      ),
      onSelect: () => unawaited(_load(section)),
      onMore: () => unawaited(_load(section, more: true)),
      onOpen: (post) => unawaited(_open(section, post)),
    );
  }
}
