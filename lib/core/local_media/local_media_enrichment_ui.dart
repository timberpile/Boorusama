import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import '../posts/cross_profile_lookup/iqdb_signature.dart';
import '../posts/cross_profile_lookup/lookup_preferences.dart';
import '../posts/cross_profile_lookup/lookup_selector.dart';
import '../posts/cross_profile_lookup/page.dart';
import '../posts/cross_profile_lookup/selected_lookup_page.dart';
import '../posts/cross_profile_lookup/types.dart';
import '../posts/details/routes.dart';
import '../posts/post/providers.dart';
import 'local_media_enrichment.dart';
import 'local_media_enrichment_review.dart';
import 'local_media_models.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';

Future<void> findLocalMediaMatches(
  BuildContext context,
  WidgetRef ref,
  LocalMediaItem item,
) async {
  final library = await ref.read(localMediaLibraryProvider.future);
  if (!context.mounted || library == null) return;
  final lookup = await _selectLocalLookup(context, ref, [
    item,
  ], enriching: false);
  if (lookup == null || !context.mounted) return;
  openSelectedLookup(
    ref,
    SelectedLookupRequest(
      targets: lookup,
      permission: IqdbPermission.persistent,
      md5: item.md5,
      localSignature: (stopped) async {
        if (stopped() || library.find(item.reference)?.id != item.id) {
          return null;
        }
        final file = await library.resolve(item.reference);
        if (file == null || stopped()) return null;
        final signature = await iqdbSignatureFromFile(file.path);
        return stopped() || library.find(item.reference)?.id != item.id
            ? null
            : signature;
      },
    ),
  );
}

Future<void> enrichLocalMedia(
  BuildContext context,
  WidgetRef ref,
  List<LocalMediaReference> references,
) async {
  final service = ref.read(localMediaEnrichmentServiceProvider);
  final library = await ref.read(localMediaLibraryProvider.future);
  if (!context.mounted || library == null) return;
  final items = {
    for (final reference in references) reference: library.find(reference),
  };
  final lookup = await _selectLocalLookup(
    context,
    ref,
    items.values.nonNulls,
    enriching: true,
  );
  if (lookup == null || !context.mounted) return;
  final summary = await Navigator.of(context, rootNavigator: true)
      .push<LocalMediaEnrichmentSummary>(
        MaterialPageRoute(
          builder: (_) => LocalMediaEnrichmentReviewPage(
            library: library,
            service: service,
            selection: lookup,
            items: items,
          ),
        ),
      );
  if (!context.mounted || summary == null) return;
  final t = context.t.local_media;
  Kurumi.showSuccessToast(
    context,
    switch (summary) {
      (updated: final count, unchanged: 0) => t.enrich_success_updated(
        count: count,
      ),
      (updated: 0, unchanged: final count) => t.enrich_success_unchanged(
        count: count,
      ),
      (:final updated, :final unchanged) => t.enrich_success_mixed(
        updated: updated,
        unchanged: unchanged,
      ),
    },
  );
}

Future<List<LookupTarget>?> _selectLocalLookup(
  BuildContext context,
  WidgetRef ref,
  Iterable<LocalMediaItem> items, {
  required bool enriching,
}) async {
  final stillImage = items.any(
    (item) => supportsIqdbImageFormat(item.format.extension),
  );
  final container = ProviderScope.containerOf(context, listen: false);
  final targets = await selectLookupTargets(
    context,
    container,
    available: (profile) => localLookupMethods(profile, stillImage: stillImage),
    enriching: enriching,
  );
  if (targets == null || !context.mounted) return null;
  final includesExact = targets.any(
    (target) => target.methods.contains(PostLookupMatchKind.exactFile),
  );
  if (includesExact &&
      (!await _authorizeLookup(context, ref) || !context.mounted)) {
    return null;
  }
  return targets;
}

Future<bool> _authorizeLookup(BuildContext context, WidgetRef ref) async {
  if (ref.read(localMediaOnlineConsentProvider)) return true;
  var always = false;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => KurumiDialog(
        width: 460,
        screenInset: 16,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t.local_media.lookup_consent_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(context.t.local_media.lookup_consent),
              CheckboxListTile(
                value: always,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(context.t.local_media.allow_always),
                subtitle: Text(context.t.local_media.allow_always_description),
                onChanged: (value) => setState(() => always = value ?? false),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.t.generic.action.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      always
                          ? context.t.local_media.allow_lookup
                          : context.t.local_media.allow_once,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (accepted != true || !context.mounted) return false;
  if (always) {
    try {
      await ref.read(localMediaOnlineConsentProvider.notifier).setEnabled(true);
    } catch (_) {
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.local_media.lookup_consent_save_failed,
        );
      }
    }
  }
  return true;
}

class LocalMediaMatchLinks extends ConsumerWidget {
  const LocalMediaMatchLinks(this.item, {super.key});

  final LocalMediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(localMediaLibraryProvider).valueOrNull;
    if (library == null) return const SizedBox.shrink();
    final matches = library.exactMatches(item.id);
    final similar = library.similarMatches(item.id);
    final profiles = {
      for (final profile in ref.watch(booruConfigProvider))
        postOriginFromConfig(profile): profile,
    };
    final chips = [
      for (final match in matches)
        if (profiles[match.origin] case final profile?)
          ActionChip(
            label: Text('${profile.name} #${match.postId}'),
            onPressed: () =>
                unawaited(_open(context, ref, profile, match, item.md5)),
          ),
      for (final match in similar)
        if (profiles[match.origin] case final profile?)
          ActionChip(
            label: Text(
              context.t.post.cross_profile.similar_match_link(
                profile: profile.name,
                id: match.postId,
                score: match.score.toStringAsFixed(1),
              ),
            ),
            onPressed: () => unawaited(
              _open(
                context,
                ref,
                profile,
                (origin: match.origin, postId: match.postId),
                null,
              ),
            ),
          ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.local_media.also_found_on),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: chips),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    BooruConfig profile,
    LocalMediaExactMatch match,
    String? md5,
  ) async {
    try {
      final post = await resolveLocalMediaMatch(ref, profile, match, md5);
      if (!context.mounted) return;
      if (post != null) {
        goToPostDetailsPageFromPosts(
          ref: ref,
          posts: [post],
          initialIndex: 0,
          initialThumbnailUrl: post.thumbnailImageUrl,
          config: profile,
        );
        return;
      }
    } catch (_) {
      // The saved match may no longer be reachable with this profile.
    }
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.local_media.match_unavailable);
    }
  }
}
