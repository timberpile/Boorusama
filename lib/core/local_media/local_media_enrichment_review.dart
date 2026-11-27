import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import '../content/content_access_provider.dart';
import '../errors/types.dart' show rateLimitWaitText;
import '../posts/cross_profile_lookup/iqdb_lookup.dart';
import '../posts/cross_profile_lookup/lookup_preferences.dart';
import '../posts/cross_profile_lookup/lookup_selector.dart';
import '../posts/cross_profile_lookup/types.dart';
import '../posts/details/src/types/viewer_entry.dart';
import '../posts/details/widgets.dart';
import 'local_media_enrichment.dart';
import 'local_media_library.dart';
import 'local_media_models.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';
import 'local_media_thumbnail.dart';

typedef LocalMediaEnrichmentSummary = ({int updated, int unchanged});

class LocalMediaEnrichmentReviewPage extends ConsumerStatefulWidget {
  const LocalMediaEnrichmentReviewPage({
    required this.library,
    required this.service,
    required this.selection,
    required this.items,
    super.key,
  });

  final LocalMediaLibrary library;
  final LocalMediaEnrichmentService service;
  final List<LookupTarget> selection;
  final Map<LocalMediaReference, LocalMediaItem?> items;

  @override
  ConsumerState<LocalMediaEnrichmentReviewPage> createState() =>
      _LocalMediaEnrichmentReviewPageState();
}

class _LocalMediaEnrichmentReviewPageState
    extends ConsumerState<LocalMediaEnrichmentReviewPage> {
  final _invalidProfiles = <BooruConfig>{};
  final _rows = <_EnrichmentRow>[];
  final _lookupCancellation = CancelToken();
  var _iqdbRevoked = false;
  var _leaving = false;
  bool get _stopped => !mounted || _leaving;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_scan));
  }

  @override
  void dispose() {
    _lookupCancellation.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    final profiles = [for (final target in widget.selection) target.profile];
    for (final entry in widget.items.entries) {
      if (_stopped) return;
      final item = entry.value;
      LocalMediaEnrichmentOutcome outcome;
      if (item == null) {
        outcome = const LocalMediaEnrichmentOutcome(
          LocalMediaEnrichmentResult.skipped,
          issue: LocalMediaEnrichmentIssue.missingFile,
        );
      } else {
        try {
          outcome = await widget.service.enrich(
            widget.library,
            item,
            profiles: profiles,
            selection: widget.selection,
            iqdbPermission: IqdbPermission.persistent,
            cancelled: () => _stopped,
            batch: widget.items.length > 1,
            lookupCancellation: _lookupCancellation,
          );
        } catch (_) {
          outcome = const LocalMediaEnrichmentOutcome(
            LocalMediaEnrichmentResult.skipped,
            issue: LocalMediaEnrichmentIssue.operationFailed,
          );
        }
      }
      if (_stopped) return;
      setState(() {
        _rows.add((
          reference: entry.key,
          format: item?.format,
          outcome: outcome,
          status: _enrichmentStatus(outcome),
        ));
      });
    }

    var summary = _successfulEnrichment(_rows);
    if (summary == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _leaving || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      summary = await showDialog<LocalMediaEnrichmentSummary>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EnrichmentResultsDialog(
          results: _rows,
          onReview: _openReview,
        ),
      );
    }
    _close(summary: widget.items.length > 1 ? summary : null);
  }

  bool _current(IqdbHit hit) =>
      !_stopped && !_iqdbRevoked && !_invalidProfiles.contains(hit.profile);

  void _close({LocalMediaEnrichmentSummary? summary}) {
    if (_stopped) return;
    _leaving = true;
    _lookupCancellation.cancel();
    Navigator.pop(context, summary);
  }

  Future<LocalMediaEnrichmentResult?> _openReview(
    LocalMediaEnrichmentReview review,
  ) => Navigator.of(context).push<LocalMediaEnrichmentResult>(
    MaterialPageRoute(
      builder: (context) => _CandidateViewer(
        review: review,
        current: _current,
        apply: (hit, current) => widget.service.applyReview(
          widget.library,
          review,
          hit,
          current: () => current() && _current(hit),
        ),
        onCompleted: (result) => Navigator.pop(context, result),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(booruConfigProvider, (_, profiles) {
      _invalidProfiles.addAll(
        widget.selection
            .map((target) => target.profile)
            .where((profile) => !profiles.contains(profile)),
      );
    });
    ref.listen(lookupPreferencesProvider, (_, preferences) {
      if (!preferences.allowIqdb) _iqdbRevoked = true;
      for (final target in widget.selection) {
        if (target.methods.contains(PostLookupMatchKind.similarImage) &&
            !stillSelected(
              preferences,
              target,
              PostLookupMatchKind.similarImage,
            )) {
          _invalidProfiles.add(target.profile);
        }
      }
    });
    final t = context.t.local_media;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leaving = true;
        } else {
          _close();
        }
      },
      child: Scaffold(
        appBar: KurumiAppBar(
          title: Text(t.enrich_other_profiles),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.enrich_progress(
                    count: _rows.length,
                    total: widget.items.length,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: widget.items.isEmpty
                      ? 0
                      : _rows.length / widget.items.length,
                ),
                const SizedBox(height: 8),
                if (_rows.length < widget.items.length)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _close,
                      child: Text(context.t.generic.action.cancel),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EnrichmentStatus { enriched, needReview, skipped, failed }

typedef _EnrichmentRow = ({
  LocalMediaReference reference,
  LocalMediaFormat? format,
  LocalMediaEnrichmentOutcome outcome,
  _EnrichmentStatus status,
});

_EnrichmentStatus _enrichmentStatus(LocalMediaEnrichmentOutcome outcome) {
  if (outcome.review != null) return _EnrichmentStatus.needReview;
  return switch (outcome.issue) {
    LocalMediaEnrichmentIssue.noMatch ||
    LocalMediaEnrichmentIssue.filteredMatches ||
    LocalMediaEnrichmentIssue.noApplicableMethod => _EnrichmentStatus.skipped,
    null =>
      outcome.result == LocalMediaEnrichmentResult.skipped
          ? _EnrichmentStatus.skipped
          : _EnrichmentStatus.enriched,
    _ => _EnrichmentStatus.failed,
  };
}

LocalMediaEnrichmentSummary? _successfulEnrichment(List<_EnrichmentRow> rows) {
  if (rows.any((row) => row.status != _EnrichmentStatus.enriched)) return null;
  final updated = rows
      .where((row) => row.outcome.result == LocalMediaEnrichmentResult.updated)
      .length;
  return (updated: updated, unchanged: rows.length - updated);
}

class _EnrichmentResultsDialog extends StatefulWidget {
  const _EnrichmentResultsDialog({
    required this.results,
    required this.onReview,
  });

  final List<_EnrichmentRow> results;
  final Future<LocalMediaEnrichmentResult?> Function(LocalMediaEnrichmentReview)
  onReview;

  @override
  State<_EnrichmentResultsDialog> createState() =>
      _EnrichmentResultsDialogState();
}

class _EnrichmentResultsDialogState extends State<_EnrichmentResultsDialog> {
  late final _rows = List.of(widget.results);
  var _inspecting = false;
  var _confirmingExit = false;

  Future<void> _review(_EnrichmentRow row) async {
    if (_inspecting || _confirmingExit) return;
    _inspecting = true;
    try {
      final result = await widget.onReview(row.outcome.review!);
      if (!mounted || result == null) return;
      final outcome = LocalMediaEnrichmentOutcome(
        result,
        issue: row.outcome.issue,
        lookupDetails: row.outcome.lookupDetails,
      );
      setState(() {
        _rows[_rows.indexOf(row)] = (
          reference: row.reference,
          format: row.format,
          outcome: outcome,
          status: result == LocalMediaEnrichmentResult.skipped
              ? _EnrichmentStatus.skipped
              : _enrichmentStatus(outcome),
        );
      });
    } finally {
      _inspecting = false;
    }
  }

  Future<void> _done() async {
    if (_inspecting || _confirmingExit) return;
    if (_rows.any((row) => row.status == _EnrichmentStatus.needReview)) {
      _confirmingExit = true;
      final discard = await _confirmDiscard(context);
      _confirmingExit = false;
      if (!mounted || !discard) return;
    }
    Navigator.pop(context, _successfulEnrichment(_rows));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.local_media;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_done());
      },
      child: KurumiDialog(
        width: 500,
        screenInset: 16,
        padding: const EdgeInsets.all(16),
        dismissible: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.enrich_results,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final status in _EnrichmentStatus.values)
                    _section(context, status),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _done,
                child: Text(context.t.generic.done),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, _EnrichmentStatus status) {
    final t = context.t.local_media;
    final rows = _rows.where((row) => row.status == status).toList();
    final title = switch (status) {
      _EnrichmentStatus.enriched => t.enrich_status_enriched,
      _EnrichmentStatus.needReview => t.enrich_status_review,
      _EnrichmentStatus.skipped => t.enrich_status_skipped,
      _EnrichmentStatus.failed => t.enrich_status_failed,
    };
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        key: PageStorageKey(status),
        shape: border,
        collapsedShape: border,
        initiallyExpanded:
            status != _EnrichmentStatus.enriched && rows.isNotEmpty,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(t.enrich_status_count(status: title, count: rows.length)),
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(t.enrich_status_empty),
            ),
          for (final row in rows) _entry(context, row),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, _EnrichmentRow row) {
    final t = context.t.local_media;
    final outcome = row.outcome;
    final review = outcome.review;
    final hasLookupReasons = outcome.lookupDetails.any(
      (lookup) => lookup.failure != null,
    );
    final details = [
      if (review != null)
        t.review_candidate_count(count: review.candidates.length),
      if (outcome.issue case final issue? when !hasLookupReasons)
        _issueLabel(context, issue),
      for (final lookup in outcome.lookupDetails) ...[
        _matchProvenance(context, lookup.profile, lookup.method),
        if (lookup.failure case final failure?)
          _lookupFailureLabel(context, failure),
      ],
      if (outcome.result == LocalMediaEnrichmentResult.updated &&
          outcome.issue != null)
        t.enrich_status_partial_saved,
      if (row.status == _EnrichmentStatus.enriched &&
          outcome.result == LocalMediaEnrichmentResult.unchanged)
        t.enrich_status_unchanged,
      if (row.status == _EnrichmentStatus.skipped && outcome.issue == null)
        t.enrich_status_skipped_review,
    ];
    return ListTile(
      key: ValueKey(('enrichment-result', row.reference)),
      leading: _ReviewThumbnail(row.reference),
      title: _ReviewFileName(row.reference, row.format),
      subtitle: details.isEmpty ? null : Text(details.join('\n')),
      trailing: review == null ? null : const Icon(Icons.chevron_right),
      onTap: review == null ? null : () => unawaited(_review(row)),
    );
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final t = context.t.local_media;
  return await showDialog<bool>(
        context: context,
        builder: (context) => KurumiDialog(
          width: 440,
          screenInset: 16,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.review_leave_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(t.review_leave_message),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(t.review_stay),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t.review_leave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

String _issueLabel(BuildContext context, LocalMediaEnrichmentIssue issue) {
  final t = context.t.local_media;
  return switch (issue) {
    LocalMediaEnrichmentIssue.missingFile => t.review_missing_file,
    LocalMediaEnrichmentIssue.noApplicableMethod => t.review_no_method,
    LocalMediaEnrichmentIssue.signatureUnavailable =>
      t.review_signature_unavailable,
    LocalMediaEnrichmentIssue.incompleteLookup => t.review_incomplete_lookup,
    LocalMediaEnrichmentIssue.filteredMatches => t.review_filtered_matches,
    LocalMediaEnrichmentIssue.noMatch => t.review_no_match,
    LocalMediaEnrichmentIssue.imageChanged => t.review_image_changed,
    LocalMediaEnrichmentIssue.matchUnavailable => t.match_unavailable,
    LocalMediaEnrichmentIssue.operationFailed => t.review_operation_failed,
  };
}

String _lookupFailureLabel(
  BuildContext context,
  LocalMediaLookupFailure failure,
) {
  final t = context.t.local_media;
  return switch (failure.kind) {
    LocalMediaLookupFailureKind.rateLimited => switch (failure.retryAt) {
      final retryAt? when retryAt.isAfter(DateTime.now()) => rateLimitWaitText(
        context,
        retryAt,
      ),
      _ => t.review_lookup_rate_limited,
    },
    LocalMediaLookupFailureKind.http => t.review_lookup_http(
      status: failure.httpStatus!,
    ),
    LocalMediaLookupFailureKind.connection =>
      context.t.search.errors.cannot_reach_server,
    LocalMediaLookupFailureKind.invalidResponse =>
      t.review_lookup_invalid_response,
    LocalMediaLookupFailureKind.filtered => t.review_filtered_matches,
    LocalMediaLookupFailureKind.interrupted => t.review_lookup_interrupted,
    LocalMediaLookupFailureKind.unknown => t.review_lookup_failed,
  };
}

String _matchProvenance(
  BuildContext context,
  BooruConfig profile,
  PostLookupMatchKind method,
) => context.t.local_media.review_match_origin(
  profile: profile.name,
  method: lookupMethodLabel(context, method),
);

Future<void> _showEnrichmentDialog(
  BuildContext context, {
  required String title,
  required WidgetBuilder body,
}) => showDialog<void>(
  context: context,
  builder: (context) => KurumiDialog(
    width: 480,
    screenInset: 16,
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Flexible(child: SingleChildScrollView(child: body(context))),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.generic.action.ok),
          ),
        ),
      ],
    ),
  ),
);

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail(this.reference);
  final LocalMediaReference reference;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LocalMediaThumbnail(reference: reference),
    ),
  );
}

class _ReviewFileName extends StatelessWidget {
  const _ReviewFileName(this.reference, this.format);
  final LocalMediaReference reference;
  final LocalMediaFormat? format;

  @override
  Widget build(BuildContext context) {
    final full =
        '${reference.sha256}${format == null ? '' : '.${format!.extension}'}';
    return Tooltip(
      message: full,
      child: Text(
        '${reference.sha256.substring(0, 12)}…${format == null ? '' : '.${format!.extension}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CandidateViewer extends ConsumerStatefulWidget {
  const _CandidateViewer({
    required this.review,
    required this.current,
    required this.apply,
    required this.onCompleted,
  });

  final LocalMediaEnrichmentReview review;
  final bool Function(IqdbHit) current;
  final Future<LocalMediaEnrichmentOutcome> Function(IqdbHit, bool Function())
  apply;
  final ValueChanged<LocalMediaEnrichmentResult> onCompleted;

  @override
  ConsumerState<_CandidateViewer> createState() => _CandidateViewerState();
}

class _CandidateViewerState extends ConsumerState<_CandidateViewer> {
  late final _entries = [
    for (final hit in widget.review.candidates)
      PostViewerEntry(
        post: hit.post!,
        occurrenceId: (hit.profile.id, hit.postId),
        source: ViewerSourceBinding(hit.profile),
      ),
  ];
  final _displayedMatches = <Object>{};
  var _index = 0;
  var _showOriginal = false;
  var _applying = false;
  var _closed = false;
  LocalMediaEnrichmentIssue? _issue;
  FileImage? _originalProvider;
  ImageStream? _originalStream;
  ImageStreamListener? _originalListener;
  ImageInfo? _originalFrame;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      localMediaPresentationProvider(widget.review.item.reference),
      (_, state) {
        final local = state.valueOrNull;
        final file = local?.item.id == widget.review.item.id
            ? local?.file
            : null;
        _loadOriginal(file == null ? null : FileImage(file));
      },
      fireImmediately: true,
    );
  }

  void _loadOriginal(FileImage? provider) {
    if (_originalProvider == provider) return;
    _originalProvider = provider;
    _stopDecodingOriginal();
    setState(() {
      _originalFrame?.dispose();
      _originalFrame = null;
      _showOriginal = false;
    });
    if (provider == null) return;
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (frame, _) {
        // A cache hit can dispatch during initState. The frame must also
        // still belong to this file when it is published.
        scheduleMicrotask(() {
          if (!mounted || !identical(stream, _originalStream)) {
            frame.dispose();
            return;
          }
          _stopDecodingOriginal();
          setState(() => _originalFrame = frame);
        });
      },
      onError: (error, stack) {
        scheduleMicrotask(() {
          if (identical(stream, _originalStream)) _stopDecodingOriginal();
        });
      },
    );
    _originalStream = stream;
    _originalListener = listener;
    stream.addListener(listener);
  }

  void _stopDecodingOriginal() {
    _originalStream?.removeListener(_originalListener!);
    _originalStream = null;
    _originalListener = null;
  }

  @override
  void dispose() {
    _stopDecodingOriginal();
    _originalFrame?.dispose();
    super.dispose();
  }

  Widget _comparisonMedia(BuildContext context, int index, Widget match) {
    final frame = _originalFrame;
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [
        // Keep the candidate in the normal media pipeline and retain its zoom.
        match,
        if (_showOriginal && index == _index && frame != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: RawImage(
                  key: const ValueKey('review-original-media'),
                  image: frame.image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _apply(IqdbHit hit) async {
    final access = ref.read(contentProfileAccessProvider(hit.profile.id));
    if (access == null) return;
    final visibility = contentPostVisibilityProvider((
      access: access.key,
      post: hit.post!,
    ));
    bool current() {
      if (!mounted ||
          _closed ||
          !identical(
            ref.read(contentAccessContextProvider(access.key)),
            access,
          )) {
        return false;
      }
      final state = ref.read(visibility);
      return !state.isLoading && (state.asData?.value ?? false);
    }

    setState(() {
      _applying = true;
      _issue = null;
    });
    LocalMediaEnrichmentOutcome outcome;
    try {
      outcome = await widget.apply(hit, current);
    } catch (_) {
      outcome = const LocalMediaEnrichmentOutcome(
        LocalMediaEnrichmentResult.skipped,
        issue: LocalMediaEnrichmentIssue.operationFailed,
      );
    }
    if (!mounted || _closed) return;
    setState(() {
      _applying = false;
      _issue = outcome.issue;
    });
    final issue = outcome.issue;
    if (issue == null) {
      widget.onCompleted(outcome.result);
      return;
    }
    await _showEnrichmentDialog(
      context,
      title: context.t.local_media.review_apply_failed,
      body: (context) => Text(
        [
          _issueLabel(context, issue),
          _matchProvenance(
            context,
            hit.profile,
            PostLookupMatchKind.similarImage,
          ),
        ].join('\n'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.review.item;
    final hit = widget.review.candidates[_index];
    final access = ref.watch(contentProfileAccessProvider(hit.profile.id));
    final visibility = access == null
        ? null
        : ref.watch(
            contentPostVisibilityProvider(
              (access: access.key, post: hit.post!),
            ),
          );
    final localState = ref.watch(
      localMediaPresentationProvider(item.reference),
    );
    final local = localState.valueOrNull;
    final preferences = ref.watch(lookupPreferencesProvider);
    final t = context.t;
    final canApply =
        widget.current(hit) &&
        preferences.allowIqdb &&
        local?.item.id == item.id &&
        local?.file != null &&
        local?.item.metadataRevision == item.metadataRevision &&
        visibility != null &&
        !visibility.isLoading &&
        (visibility.asData?.value ?? false);
    final issue =
        _issue ??
        (!localState.isLoading &&
                (local?.file == null || local?.item.id != item.id)
            ? LocalMediaEnrichmentIssue.missingFile
            : local != null &&
                  local.item.metadataRevision != item.metadataRevision
            ? LocalMediaEnrichmentIssue.imageChanged
            : !widget.current(hit) ||
                  !preferences.allowIqdb ||
                  access == null ||
                  (visibility != null &&
                      !visibility.isLoading &&
                      visibility.asData?.value != true)
            ? LocalMediaEnrichmentIssue.matchUnavailable
            : null);

    return PopScope(
      canPop: !_applying,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _closed = true;
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: _applying,
                child: MixedPostDetailsPage(
                  posts: [for (final entry in _entries) entry.post],
                  entries: _entries,
                  initialIndex: 0,
                  initialThumbnailUrl: _entries.first.post.thumbnailImageUrl,
                  scrollController: null,
                  disclaimer: null,
                  mediaWrapper: _comparisonMedia,
                  onEntryDisplayed: (entry) {
                    if (!_displayedMatches.contains(entry.occurrenceId)) {
                      setState(() => _displayedMatches.add(entry.occurrenceId));
                    }
                  },
                  onPageChanged: (index) {
                    setState(() {
                      _index = index;
                      _showOriginal = false;
                      _issue = null;
                    });
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.local_media.review_match_score(
                                score: hit.score.toStringAsFixed(1),
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              _matchProvenance(
                                context,
                                hit.profile,
                                PostLookupMatchKind.similarImage,
                              ),
                            ),
                          ],
                        ),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(t.local_media.review_show_match),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(t.local_media.review_show_original),
                              enabled:
                                  _originalFrame != null &&
                                  _displayedMatches.contains(
                                    _entries[_index].occurrenceId,
                                  ),
                            ),
                          ],
                          selected: {_showOriginal},
                          showSelectedIcon: false,
                          onSelectionChanged: _applying
                              ? null
                              : (selection) => setState(
                                  () => _showOriginal = selection.single,
                                ),
                        ),
                      ],
                    ),
                    if (issue != null) Text(_issueLabel(context, issue)),
                    if (_applying) const LinearProgressIndicator(),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: _applying
                                ? null
                                : () => widget.onCompleted(
                                    LocalMediaEnrichmentResult.skipped,
                                  ),
                            child: Text(t.local_media.review_skip),
                          ),
                          FilledButton(
                            onPressed: !canApply || _applying
                                ? null
                                : () => unawaited(_apply(hit)),
                            child: Text(t.post.cross_profile.apply_match),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
